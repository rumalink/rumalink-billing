// utils/hotspotExpire.js — RL_HOTSPOT_EXPIRE
// Ending a hotspot voucher has to happen on the ROUTER, not just in the database.
// The router authorises a session once at login and never re-consults RADIUS afterwards, so
// deleting credentials leaves the device online until its Session-Timeout elapses — which is why
// an account could read "expired" while the customer kept browsing for hours.
//
// It also has to cover every way that device can get back in:
//   - the voucher username        (R1@<isp8>)
//   - the MAC-auth username       (the bare MAC, which is how a returning device actually logs in)
//   - the hotspot cookie          (silently re-authorises with no RADIUS request at all)
//   - the queue                   (a stale rate-limit entry left behind)
const { query } = require('../config/database');
const logger = require('./logger');
const axios = require('axios');

function realmed(code, ispId) {
  return code + '@' + String(ispId).replace(/-/g, '').slice(0, 8).toLowerCase();
}

async function deviceFor(ispId) {
  const r = await query(
    "SELECT id, wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices " +
    "WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL ORDER BY last_seen DESC NULLS LAST LIMIT 1", [ispId]);
  return r.rows[0] || null;
}

/* Kick one voucher's device off the router and strip every credential it could return with.
   `mac` must be passed in by the caller: the expiry sweep clears used_by_mac, so by the time
   this runs the voucher row may no longer remember which device it belonged to. */
async function kickVoucher(ispId, code, mac) {
  const out = { sessions: 0, cookies: 0, queues: 0, creds: 0 };
  const user = realmed(code, ispId);
  const macU = mac ? String(mac).toUpperCase() : null;

  // credentials first, so a race cannot re-authorise between the kill and the cleanup
  try {
    const a = await query("DELETE FROM radcheck WHERE username = $1 OR username = $2", [code, user]);
    const b = await query("DELETE FROM radreply WHERE username = $1 OR username = $2", [code, user]);
    out.creds += (a.rowCount || 0) + (b.rowCount || 0);
    if (macU) {
      const c = await query("DELETE FROM radcheck WHERE UPPER(username) = $1", [macU]);
      const d = await query("DELETE FROM radreply WHERE UPPER(username) = $1", [macU]);
      out.creds += (c.rowCount || 0) + (d.rowCount || 0);
    }
  } catch (e) { logger.warn('[hotspot-expire] creds: ' + e.message); }

  const dev = await deviceFor(ispId);
  if (!dev) return out;
  const auth = { username: dev.mikrotik_api_user, password: dev.mikrotik_api_password };
  const b = 'http://' + dev.wireguard_ip + '/rest';
  const get = async p => { try { return (await axios.get(b + p, { auth, timeout: 8000 })).data || []; } catch (e) { return []; } };
  const del = async (p, id) => { try { await axios.delete(b + p + '/' + encodeURIComponent(id), { auth, timeout: 8000 }); return true; } catch (e) { return false; } };

  try {
    const act = await get('/ip/hotspot/active');
    for (const s of act) {
      const u = String(s.user || '').toUpperCase();
      const m = String(s['mac-address'] || '').toUpperCase();
      if (u === user.toUpperCase() || (macU && (u === macU || m === macU))) {
        if (await del('/ip/hotspot/active', s['.id'])) out.sessions++;
      }
    }
  } catch (e) { logger.warn('[hotspot-expire] sessions: ' + e.message); }

  // A cookie logs a device straight back in without contacting RADIUS, so killing the session
  // without clearing this just produces a reconnect a few seconds later.
  try {
    const ck = await get('/ip/hotspot/cookie');
    for (const c of ck) {
      const m = String(c['mac-address'] || '').toUpperCase();
      const u = String(c.user || '').toUpperCase();
      if ((macU && m === macU) || u === user.toUpperCase()) {
        if (await del('/ip/hotspot/cookie', c['.id'])) out.cookies++;
      }
    }
  } catch (e) { logger.warn('[hotspot-expire] cookies: ' + e.message); }

  try {
    const qs = await get('/queue/simple');
    for (const q of qs) {
      const n = String(q.name || '').toUpperCase();
      if (String(q.dynamic) === 'true') continue;           // router-managed, disappears with the session
      if (n.indexOf(code.toUpperCase()) >= 0 || (macU && n.indexOf(macU.replace(/:/g, '')) >= 0) || (macU && n.indexOf(macU) >= 0)) {
        if (await del('/queue/simple', q['.id'])) out.queues++;
      }
    }
  } catch (e) { logger.warn('[hotspot-expire] queues: ' + e.message); }

  logger.info('[hotspot-expire] ' + code + (macU ? ' / ' + macU : '') +
              ' -> sessions=' + out.sessions + ' cookies=' + out.cookies + ' queues=' + out.queues + ' creds=' + out.creds);
  return out;
}

/* Sweep: any live hotspot session whose voucher is no longer valid gets removed. This is the
   safety net — it catches expiry from the cron, from an admin edit, and from a voucher deleted
   outright, without each of those paths having to remember to call the kick itself. */
async function sweep() {
  let devs;
  try {
    devs = (await query(
      "SELECT id, isp_id, wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices " +
      "WHERE wireguard_ip IS NOT NULL AND is_online = true")).rows;
  } catch (e) { return; }

  for (const dev of devs) {
    const auth = { username: dev.mikrotik_api_user, password: dev.mikrotik_api_password };
    const b = 'http://' + dev.wireguard_ip + '/rest';
    let act = [];
    try { act = (await axios.get(b + '/ip/hotspot/active', { auth, timeout: 8000 })).data || []; } catch (e) { continue; }
    if (!act.length) continue;

    for (const s of act) {
      const u = String(s.user || '');
      const m = String(s['mac-address'] || '').toUpperCase();
      try {
        // A session is legitimate if EITHER its username maps to a live voucher, or its MAC is
        // bound to one. TV devices are ip-binding bypassed and never appear here.
        const ok = await query(
          "SELECT 1 FROM hotspot_vouchers v WHERE v.isp_id = $1::uuid AND v.status = 'active' " +
          "AND v.expires_at > NOW() AND (" +
          "  v.code || '@' || LOWER(SUBSTRING(REPLACE(v.isp_id::text,'-','') FROM 1 FOR 8)) = $2 " +
          "  OR UPPER(COALESCE(v.used_by_mac,'')) = $3 ) LIMIT 1",
          [dev.isp_id, u, m]);
        if (ok.rows[0]) continue;

        await axios.delete(b + '/ip/hotspot/active/' + encodeURIComponent(s['.id']), { auth, timeout: 8000 });
        try {
          const ck = (await axios.get(b + '/ip/hotspot/cookie', { auth, timeout: 8000 })).data || [];
          for (const c of ck) {
            if (String(c['mac-address'] || '').toUpperCase() === m) {
              await axios.delete(b + '/ip/hotspot/cookie/' + encodeURIComponent(c['.id']), { auth, timeout: 8000 }).catch(function(){});
            }
          }
        } catch (e) {}
        logger.info('[hotspot-expire] swept stale session user=' + u + ' mac=' + m);
      } catch (e) { logger.warn('[hotspot-expire] sweep ' + u + ': ' + e.message); }
    }
  }
}

function start() {
  setInterval(function () { sweep().catch(function (e) { logger.warn('[hotspot-expire] ' + e.message); }); }, 60000);
  setTimeout(function () { sweep().catch(function () {}); }, 20000);
  logger.info('[hotspot-expire] stale-session sweep started (60s)');
}

module.exports = { kickVoucher, sweep, start, realmed };
