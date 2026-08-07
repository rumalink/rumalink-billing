/**
 * MikroTik REST API client (v2) — smarter, more resilient.
 * - Auto-detects hotspot server name (no hardcoded "hotspot1")
 * - Better error surfacing (no silent swallow)
 * - Supports mac-binding so user can only login from their device
 */
const axios = require('axios');
const { query } = require('../config/database');
const logger = require('./logger');

function clientFor(device) {
  if (!device.wireguard_ip) throw new Error('Device has no WireGuard IP');
  if (!device.mikrotik_api_user || !device.mikrotik_api_password) {
    throw new Error('Device has no API credentials');
  }
  return axios.create({
    baseURL: `http://${device.wireguard_ip}/rest`,
    timeout: 8000,
    auth: { username: device.mikrotik_api_user, password: device.mikrotik_api_password },
    validateStatus: () => true,
    headers: { 'Content-Type': 'application/json' }
  });
}

async function loadDevice(idOrToken, byToken = false) {
  const col = byToken ? 'provision_token' : 'id';
  const r = await query(
    `SELECT id, name, wireguard_ip, wireguard_public_key, mikrotik_api_user, mikrotik_api_password, isp_id
     FROM nas_devices WHERE ${col} = $1::${byToken ? 'varchar' : 'uuid'} LIMIT 1`,
    [idOrToken]
  );
  if (!r.rows[0]) throw new Error('Device not found');
  return r.rows[0];
}

async function testConnectivity(deviceId) {
  const dev = await loadDevice(deviceId);
  const client = clientFor(dev);
  const t0 = Date.now();
  try {
    const r = await client.get('/system/resource');
    const latency_ms = Date.now() - t0;
    if (r.status !== 200) return { ok: false, latency_ms, error: `HTTP ${r.status}: ${JSON.stringify(r.data).substring(0, 200)}` };
    return {
      ok: true, latency_ms,
      board: r.data['board-name'], version: r.data.version, uptime: r.data.uptime,
      cpu_load: parseInt(r.data['cpu-load']) || 0,
      free_memory: parseInt(r.data['free-memory']) || 0,
      total_memory: parseInt(r.data['total-memory']) || 0
    };
  } catch (e) {
    return {
      ok: false, latency_ms: Date.now() - t0,
      error: e.code === 'ECONNABORTED' ? 'Timeout (router not reachable over WG)' :
             e.code === 'EHOSTUNREACH' ? 'Host unreachable (WG tunnel down?)' :
             e.code === 'ECONNREFUSED' ? 'Connection refused (www service not enabled on router)' :
             e.message
    };
  }
}

/* RL_LIVE_SESSIONS_CACHE: /isp/users and /isp/sessions/active both call this on every request,
   so opening the users page, changing a filter or paging all waited on a MikroTik round trip —
   and with several routers those add up. Who is online changes slowly compared with how often
   these pages are drawn, so a few seconds of cache removes the wait without showing anything
   meaningfully stale. */
const _rlLiveCache = new Map();
const _RL_LIVE_TTL = 30000; /* RL_LIVE_TTL_WIDER: who is online changes slowly next to how often these pages are drawn */

async function liveHotspotSessions(deviceId) {
  const _ck = String(deviceId);
  const _hit = _rlLiveCache.get(_ck);
  if (_hit && (Date.now() - _hit.t) < _RL_LIVE_TTL) return _hit.v;

  const dev = await loadDevice(deviceId);
  const client = clientFor(dev);
  const r = await client.get('/ip/hotspot/active');
  if (r.status !== 200) throw new Error(`Router returned HTTP ${r.status}: ${JSON.stringify(r.data).substring(0,200)}`);
  { const _v = (Array.isArray(r.data) ? r.data : []).map(s => ({
    id: s['.id'], user: s.user, address: s.address, mac_address: s['mac-address'],
    server: s.server, uptime: s.uptime, idle_time: s['idle-time'],
    bytes_in: parseInt(s['bytes-in']) || 0, bytes_out: parseInt(s['bytes-out']) || 0
  })); _rlLiveCache.set(_ck, { t: Date.now(), v: _v }); return _v; }
}

async function disconnectHotspotSession(deviceId, sessionId) {
  const dev = await loadDevice(deviceId);
  const client = clientFor(dev);
  const r = await client.post('/ip/hotspot/active/remove', { '.id': sessionId });
  return { ok: r.status >= 200 && r.status < 300, status: r.status };
}

/**
 * Get the first hotspot server name on the router. Returns null if none exist.
 * RouterOS REST: GET /rest/ip/hotspot returns array of servers.
 */
async function getFirstHotspotServer(client) {
  const r = await client.get('/ip/hotspot');
  if (r.status !== 200 || !Array.isArray(r.data) || !r.data.length) return null;
  return r.data[0].name || null;
}

/**
 * Add a hotspot user. Auto-detects the server name if not provided.
 * Returns { ok, id?, error?, details? } — always surfaces errors.
 */
async function addHotspotUser(deviceId, { name, password, profile, server, mac_address, limit_uptime, rate_limit, limit_bytes_total, comment }) {
  const dev = await loadDevice(deviceId);
  const client = clientFor(dev);

  // Auto-detect server if not provided
  if (!server) {
    server = await getFirstHotspotServer(client);
    if (!server) {
      return { ok: false, error: 'No hotspot server configured on router' };
    }
  }

  const body = {
    name,
    password: password || name,
    server
  };
  if (profile) body.profile = profile;
  if (mac_address) body['mac-address'] = mac_address;
  if (limit_uptime) body['limit-uptime'] = limit_uptime;
  // NOTE: 'rate-limit' is rejected by RouterOS REST for /ip/hotspot/user.
  // The proper way is to set it on a user-profile. Skip for now - bandwidth
  // limits are configured per-profile on the router itself.
  // if (rate_limit) body['rate-limit'] = rate_limit;
  if (limit_bytes_total) body['limit-bytes-total'] = limit_bytes_total;
  if (comment) body.comment = comment;

  const r = await client.put('/ip/hotspot/user', body);
  if (r.status >= 200 && r.status < 300) {
    logger.info(`[MT] Added user ${name} to ${dev.name} (server=${server})`);
    return { ok: true, id: r.data['.id'], server };
  }
  const errMsg = r.data?.detail || r.data?.message || JSON.stringify(r.data).substring(0, 200);
  logger.warn(`[MT] addHotspotUser failed for ${name} on ${dev.name}: HTTP ${r.status} - ${errMsg}`);
  return { ok: false, status: r.status, error: errMsg, details: r.data };
}

async function removeHotspotUser(deviceId, name) {
  const dev = await loadDevice(deviceId);
  const client = clientFor(dev);
  const find = await client.get('/ip/hotspot/user', { params: { name } });
  if (find.status !== 200 || !Array.isArray(find.data) || !find.data.length) {
    return { ok: false, error: 'User not found on router', not_found: true };
  }
  const id = find.data[0]['.id'];
  const del = await client.post('/ip/hotspot/user/remove', { '.id': id });
  return { ok: del.status >= 200 && del.status < 300 };
}



/**
 * Log a user into the hotspot directly (creates an /ip hotspot active session).
 * Used when the captive's "Already Paid? Login" flow fails because the
 * client-side loginurl is stale. Backend uses this to forcibly create the
 * active session for the user.
 *
 * Returns { ok, error?, details? }.
 */
async function hotspotActiveLogin(deviceId, { user, password, ip, mac_address }) {
  const dev = await loadDevice(deviceId);
  const client = clientFor(dev);
  const body = { user, password };
  if (ip) body.ip = ip;
  if (mac_address) body['mac-address'] = mac_address;

  const r = await client.post('/ip/hotspot/active/login', body);
  if (r.status >= 200 && r.status < 300) {
    return { ok: true, response: r.data };
  }
  return {
    ok: false,
    status: r.status,
    error: r.data?.detail || r.data?.message || JSON.stringify(r.data).substring(0, 200),
    details: r.data
  };
}



/**
 * Backend-driven RADIUS authentication.
 * Sends Access-Request to local FreeRADIUS as a NAS client (localhost).
 * Parses Access-Accept response for Mikrotik-Rate-Limit and Session-Timeout.
 * Returns parsed attributes ready to apply via REST.
 */
async function radiusAuthVoucher(username, password) {
  const { execFile } = require('child_process');
  const fs = require('fs');
  return new Promise((resolve, reject) => {
    let secret;
    try {
      secret = fs.readFileSync('/etc/freeradius/.localtest_secret', 'utf8').trim();
    } catch (e) {
      return reject(new Error('Local RADIUS secret not readable: ' + e.message));
    }
    const userAttrs = `User-Name="${username}",User-Password="${password}"`;
    const proc = execFile('radclient',
      ['-x', '-t', '3', '-r', '1', '127.0.0.1:1812', 'auth', secret],
      { timeout: 5000 },
      (err, stdout, stderr) => {
        if (err) return reject(new Error('radclient: ' + err.message + ' | ' + stderr));
        const attrs = {};
        const lines = stdout.split('\n');
        let accepted = false;
        for (const line of lines) {
          if (line.includes('Received Access-Accept')) accepted = true;
          if (line.includes('Access-Reject')) accepted = false;
          const m = line.match(/^\s+(\S+)\s*=\s*"?([^"]*)"?\s*$/);
          if (m && (m[1].startsWith('Mikrotik') || m[1].includes('Session-Timeout') || m[1].includes('Idle-Timeout'))) {
            attrs[m[1]] = m[2];
          }
        }
        resolve({ accepted, attrs, raw: stdout });
      });
    proc.stdin.write(userAttrs + '\n');
    proc.stdin.end();
  });
}




/**
 * Self-contained queue rate limit helpers - v48
 * Queries nas_devices for the router's API creds and applies queue/simple
 */
async function applyQueueRateLimit(deviceId, { username, ip, max_limit }) {
  if (!max_limit || max_limit === '0M/0M') return { ok: true, skipped: 'no limit' };
  try {
    const axios = require('axios');
    const { query } = require('../config/database');
    const r = await query(
      `SELECT wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE id = $1::uuid LIMIT 1`,
      [deviceId]
    );
    if (!r.rows[0]) return { ok: false, error: 'NAS device not found' };
    const { wireguard_ip, mikrotik_api_user, mikrotik_api_password } = r.rows[0];
    const baseURL = `http://${wireguard_ip}/rest`;
    const auth = { username: mikrotik_api_user, password: mikrotik_api_password };
    const queueName = 'rl-' + username;
    const targetCidr = ip + '/32';

    // 1. Fetch ALL queues
    const existing = await axios.get(baseURL + '/queue/simple', { auth, timeout: 5000 });
    const queues = existing.data || [];

    // 2. Remove ANY queue that targets the same IP (regardless of name)
    //    This prevents stale queues from previous sessions on same IP
    const removed = [];
    for (const q of queues) {
      const t = q.target || '';
      // Match exact target like "192.168.100.249/32" or "192.168.100.249"
      const targetMatches = t === targetCidr || t === ip || t.split(',').includes(targetCidr) || t.split(',').includes(ip);
      // Or matches our queue naming convention
      const isRumaLink = (q.name || '').startsWith('rl-') || (q.comment || '').startsWith('RumaLink:');
      if (targetMatches && isRumaLink && q.name !== queueName) {
        try {
          await axios.delete(`${baseURL}/queue/simple/${q['.id']}`, { auth, timeout: 5000 });
          removed.push(q.name);
        } catch(e) { /* ignore */ }
      }
    }

    // 3. Check if our queue already exists - PATCH if so, PUT if not
    let target = null;
    for (const q of queues) {
      if (q.name === queueName) { target = q; break; }
    }

    if (target) {
      const patchResp = await axios.patch(`${baseURL}/queue/simple/${target['.id']}`, {
        target: targetCidr,
        'max-limit': max_limit,
        disabled: 'false'
      }, { auth, timeout: 5000 });
      return { ok: true, updated: queueName, removed_stale: removed, status: patchResp.status };
    } else {
      const putResp = await axios.put(baseURL + '/queue/simple', {
        name: queueName,
        target: targetCidr,
        'max-limit': max_limit,
        comment: 'RumaLink:' + username
      }, { auth, timeout: 5000 });
      return { ok: true, created: queueName, removed_stale: removed, status: putResp.status };
    }
  } catch (e) {
    return { ok: false, error: e.message, response: e.response && e.response.data };
  }
}


async function removeQueueRateLimit(deviceId, username) {
  try {
    const axios = require('axios');
    const { query } = require('../config/database');
    const r = await query(
      `SELECT wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE id = $1::uuid LIMIT 1`,
      [deviceId]
    );
    if (!r.rows[0]) return { ok: false, error: 'NAS device not found' };
    const { wireguard_ip, mikrotik_api_user, mikrotik_api_password } = r.rows[0];
    const baseURL = `http://${wireguard_ip}/rest`;
    const auth = { username: mikrotik_api_user, password: mikrotik_api_password };
    const queueName = 'rl-' + username;

    const existing = await axios.get(baseURL + '/queue/simple', { auth, timeout: 5000 });
    const queues = existing.data || [];
    for (const q of queues) {
      if (q.name === queueName) {
        await axios.delete(`${baseURL}/queue/simple/${q['.id']}`, { auth, timeout: 5000 });
        return { ok: true, removed: queueName };
      }
    }
    return { ok: true, skipped: 'not found' };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}


// Disconnect an active PPPoE session by username (REST /ppp/active lookup -> remove).
// This forces instant re-auth so a new RADIUS profile (e.g. rl-expired) applies immediately.
// Heavy lifting stays on our server; the router just drops one session.
async function disconnectPppoe(deviceId, username) {
  try {
    const device = await loadDevice(deviceId);
    const client = clientFor(device);
    // Find active session(s) for this username.
    const list = await client.get(`/ppp/active?name=${encodeURIComponent(username)}`);
    if (list.status >= 400) return { ok: false, error: 'API ' + list.status + ': ' + JSON.stringify(list.data).slice(0,160) };
    const rows = Array.isArray(list.data) ? list.data : [];
    if (!rows.length) return { ok: true, removed: 0, note: 'no active session (will apply on next connect)' };
    let removed = 0;
    for (const s of rows) {
      const id = s['.id'];
      if (!id) continue;
      const del = await client.delete(`/ppp/active/${encodeURIComponent(id)}`);
      if (del.status < 400) removed++;
      else logger.warn(`[mikrotik] disconnectPppoe remove ${username} id=${id} -> ${del.status}`);
    }
    logger.info(`[mikrotik] disconnectPppoe ${username}: removed ${removed} session(s)`);
    return { ok: removed > 0, removed };
  } catch (e) {
    logger.error(`[mikrotik] disconnectPppoe ${username}: ${e.message}`);
    return { ok: false, error: e.message };
  }
}

// ── RL_IP_BINDING: TV auto-access. A 'bypassed' ip-binding lets a MAC through the hotspot with no
//    login. We pair it with a simple queue (applyQueueRateLimit) for the capacity cap, and remove
//    both at expiry. ──
async function addIpBindingBypass(deviceId, opts) {
  const mac_address = opts && opts.mac_address;
  const comment = opts && opts.comment;
  const dev = await loadDevice(deviceId);
  const client = clientFor(dev);
  const mac = String(mac_address || '').toUpperCase();
  try {
    const cur = await client.get('/ip/hotspot/ip-binding');
    const mine = Array.isArray(cur.data) ? cur.data.filter(function(b) { return (b['mac-address'] || '').toUpperCase() === mac; }) : [];
    const good = mine.filter(function(b) { return String(b.type || '') === 'bypassed'; });
    if (good.length === 1 && mine.length === 1) {
      try {
        const active = await client.get('/ip/hotspot/active');
        if (Array.isArray(active.data)) {
          for (const a of active.data.filter(function(x) { return (x['mac-address'] || '').toUpperCase() === mac; })) {
            await client.post('/ip/hotspot/active/remove', { numbers: a['.id'] });
          }
        }
      } catch (e) {}
      return { ok: true, unchanged: true, id: good[0]['.id'] };
    }
    for (const b of mine) {
      await client.post('/ip/hotspot/ip-binding/remove', { numbers: b['.id'] });
    }
  } catch (e) {}
  const body = { 'mac-address': mac, type: 'bypassed', comment: comment || 'RumaLink-TV' };
  const r = await client.put('/ip/hotspot/ip-binding', body);
  try {
    const active = await client.get('/ip/hotspot/active');
    if (Array.isArray(active.data)) {
      for (const a of active.data.filter(function(x) { return (x['mac-address'] || '').toUpperCase() === mac; })) {
        await client.post('/ip/hotspot/active/remove', { numbers: a['.id'] });
      }
    }
    const host = await client.get('/ip/hotspot/host');
    if (Array.isArray(host.data)) {
      for (const h of host.data.filter(function(x) { return (x['mac-address'] || '').toUpperCase() === mac; })) {
        await client.post('/ip/hotspot/host/remove', { numbers: h['.id'] });
      }
    }
  } catch (e) {}
  return { ok: r.status >= 200 && r.status < 300, status: r.status, response: r.data };
}

async function removeIpBinding(deviceId, mac_address) {
  const dev = await loadDevice(deviceId);
  const client = clientFor(dev);
  const mac = String(mac_address||'').toUpperCase();
  let removed = 0;
  try {
    const cur = await client.get('/ip/hotspot/ip-binding');
    if (Array.isArray(cur.data)) {
      for (const b of cur.data) {
        if ((b['mac-address']||'').toUpperCase() === mac) {
          await client.post('/ip/hotspot/ip-binding/remove', { '.id': b['.id'] });
          removed++;
        }
      }
    }
  } catch (e) { return { ok:false, error:e.message }; }
  return { ok:true, removed };
}
// Find a MAC's current IP from the router (DHCP leases or hotspot hosts) so we can cap it.
async function findIpForMac(deviceId, mac_address) {
  const dev = await loadDevice(deviceId);
  const client = clientFor(dev);
  const mac = String(mac_address||'').toUpperCase();
  // try DHCP leases
  try {
    const l = await client.get('/ip/dhcp-server/lease');
    if (Array.isArray(l.data)) {
      const hit = l.data.find(x => (x['mac-address']||'').toUpperCase() === mac);
      if (hit && hit.address) return hit.address;
    }
  } catch (e) {}
  // try hotspot hosts
  try {
    const h = await client.get('/ip/hotspot/host');
    if (Array.isArray(h.data)) {
      const hit = h.data.find(x => (x['mac-address']||'').toUpperCase() === mac);
      if (hit && hit.address) return hit.address;
    }
  } catch (e) {}
  return null;
}


/* RL_CACHED_READ: a non-blocking read of whatever liveHotspotSessions last fetched. The users
   list needs an answer now more than it needs the freshest one; a background refresh keeps this
   current for the next request. */
function cachedHotspotSessions(nasId) {
  try {
    const hit = _rlLiveCache.get(String(nasId));
    return hit ? hit.v : null;
  } catch (e) { return null; }
}

module.exports = {
  cachedHotspotSessions,
  addIpBindingBypass,
  removeIpBinding,
  findIpForMac,
  disconnectPppoe,
  applyQueueRateLimit,
  removeQueueRateLimit,
  radiusAuthVoucher,
  hotspotActiveLogin,
  testConnectivity,
  liveHotspotSessions,
  disconnectHotspotSession,
  addHotspotUser,
  removeHotspotUser,
  getFirstHotspotServer,
  clientFor,
  loadDevice
};
