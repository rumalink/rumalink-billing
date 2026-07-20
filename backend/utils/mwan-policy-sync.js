// v62.109 — Multi-WAN policy reconciler (VPS-side)
//
// Makes nas_wan_policies actually steer traffic. The v62.108 apply already created,
// per WAN: table rl_via_wanN (primary + fallback routes), address-list rl_wanN_users,
// and a mangle rule src-address-list=rl_wanN_users -> mark-routing=rl_via_wanN.
// What was missing: putting each matched user's LIVE IP into the right rl_wanN_users.
//
// Every ~15s, for each applied multi-WAN device:
//   - Read enabled policies (priority order, FIRST MATCH WINS).
//   - Pull active PPPoE (/ppp/active) and hotspot (/ip/hotspot/active) sessions.
//   - For each session, find the first policy it matches -> target WAN position.
//   - Ensure that session's IP is in rl_wan<pos>_users (comment "policy-auto"), and
//     remove it from any other auto list. Remove auto entries with no live session.
//   - Only touches entries we created (comment contains "policy-auto"); sentinels and
//     manual/test entries are left alone.
// The mangle + custom-table routes (v62.108) then steer the user, with fallback +
// return-on-recovery handled by Netwatch.

const { query } = require('../config/database');
const logger = require('./logger');

async function mtCall(dev, method, path, body) {
  const url = 'http://' + dev.wireguard_ip + '/rest' + path;
  const authHdr = 'Basic ' + Buffer.from(dev.mikrotik_api_user + ':' + dev.mikrotik_api_password).toString('base64');
  const opts = {
    method,
    headers: { 'Authorization': authHdr, 'Content-Type': 'application/json', 'Accept': 'application/json' },
    signal: AbortSignal.timeout(12000)
  };
  if (body !== undefined) opts.body = JSON.stringify(body);
  const resp = await fetch(url, opts);
  let data = null;
  try { data = await resp.json(); } catch (e) {}
  if (!resp.ok) {
    const m = (data && (data.detail || data.message || data.error)) || ('HTTP ' + resp.status);
    throw new Error(`${method} ${path} → ${m}`);
  }
  return data;
}

// ---- package / subscriber lookups (defensive across possible schemas) ----
async function hotspotPackageFor(code, ispId) {
  try {
    const r = await query(
      `SELECT package_id FROM hotspot_vouchers WHERE UPPER(code) = UPPER($1) AND isp_id = $2::uuid LIMIT 1`,
      [code, ispId]);
    return r.rows[0] ? r.rows[0].package_id : null;
  } catch (e) { return null; }
}
async function pppoeSubscriberRow(username, ispId) {
  for (const tbl of ['pppoe_subscribers', 'subscribers', 'pppoe_users', 'ppp_subscribers']) {
    try {
      const r = await query(`SELECT * FROM ${tbl} WHERE username = $1 LIMIT 1`, [username]);
      if (r.rows[0]) return { tbl, row: r.rows[0] };
    } catch (e) { /* table doesn't exist — try next */ }
  }
  return null;
}

async function matchSession(dev, policies, type, session) {
  const username = type === 'pppoe' ? session.name : session.user;
  for (const p of policies) {
    if (!p.target_pos) continue;
    const m = p.match_type;
    if (m === 'all_pppoe' && type === 'pppoe') return p.target_pos;
    if (m === 'all_hotspot' && type === 'hotspot') return p.target_pos;
    if (m === 'hotspot_package' && type === 'hotspot') {
      const pkg = await hotspotPackageFor(username, dev.isp_id);
      if (pkg && String(pkg) === String(p.match_value)) return p.target_pos;
    }
    if (m === 'pppoe_package' && type === 'pppoe') {
      const sub = await pppoeSubscriberRow(username, dev.isp_id);
      const pkg = sub && sub.row ? (sub.row.package_id || sub.row.pppoe_package_id) : null;
      if (pkg && String(pkg) === String(p.match_value)) return p.target_pos;
    }
    if (m === 'pppoe_subscriber' && type === 'pppoe') {
      if (String(username) === String(p.match_value)) return p.target_pos;
      const sub = await pppoeSubscriberRow(username, dev.isp_id);
      if (sub && sub.row && (String(sub.row.id) === String(p.match_value))) return p.target_pos;
    }
  }
  return null; // unmatched -> stays on main-table failover
}

function ipOf(addr) { return String(addr || '').split('/')[0]; }

async function applyDesired(dev, desired) {
  let lists = [];
  try { lists = await mtCall(dev, 'GET', '/ip/firewall/address-list'); } catch (e) { return; }
  const auto = lists.filter(a => /^rl_wan\d+_users$/.test(a.list || '') && (a.comment || '').includes('policy-auto'));

  // Ensure each desired IP is in the right list
  for (const ip of Object.keys(desired)) {
    const pos = desired[ip];
    const listName = `rl_wan${pos}_users`;
    // remove from other auto lists
    for (const e of auto) {
      if (ipOf(e.address) === ip && e.list !== listName) {
        try { await mtCall(dev, 'POST', '/ip/firewall/address-list/remove', { '.id': e['.id'] }); } catch (x) {}
      }
    }
    const exists = auto.find(e => e.list === listName && ipOf(e.address) === ip);
    if (!exists) {
      try {
        await mtCall(dev, 'PUT', '/ip/firewall/address-list', { list: listName, address: ip, comment: 'RL-MWAN policy-auto' });
        logger.info(`[policy-sync] ${dev.wireguard_ip} assigned ${ip} -> ${listName}`);
      } catch (e) { logger.warn(`[policy-sync] add ${ip}: ${e.message}`); }
    }
  }
  // Remove auto entries that are no longer desired (logged-out / re-matched users)
  for (const e of auto) {
    const ip = ipOf(e.address);
    if (!desired[ip]) {
      try {
        await mtCall(dev, 'POST', '/ip/firewall/address-list/remove', { '.id': e['.id'] });
        logger.info(`[policy-sync] ${dev.wireguard_ip} unassigned ${ip} from ${e.list}`);
      } catch (x) {}
    }
  }
}

async function syncDevicePolicies(dev) {
  const pr = await query(
    `SELECT p.*, l.position AS target_pos
     FROM nas_wan_policies p
     LEFT JOIN nas_wan_links l ON l.id = p.target_link_id
     WHERE p.nas_id = $1::uuid AND p.enabled = true
     ORDER BY p.priority ASC`, [dev.id]);
  const policies = pr.rows;

  let ppp = [], hs = [];
  try { ppp = await mtCall(dev, 'GET', '/ppp/active'); } catch (e) {}
  try { hs = await mtCall(dev, 'GET', '/ip/hotspot/active'); } catch (e) {}

  const desired = {}; // ip -> wan position
  for (const s of ppp) {
    if (!s.address) continue;
    const pos = await matchSession(dev, policies, 'pppoe', s);
    if (pos) desired[ipOf(s.address)] = pos;
  }
  for (const s of hs) {
    if (!s.address) continue;
    const pos = await matchSession(dev, policies, 'hotspot', s);
    if (pos) desired[ipOf(s.address)] = pos;
  }

  await applyDesired(dev, desired);
  return { policies: policies.length, assigned: Object.keys(desired).length };
}

async function syncAll() {
  try {
    const devs = await query(
      `SELECT id, isp_id, wireguard_ip, mikrotik_api_user, mikrotik_api_password
       FROM nas_devices
       WHERE wireguard_ip IS NOT NULL AND mikrotik_api_user IS NOT NULL AND mikrotik_api_password IS NOT NULL
         AND multi_wan_applied_at IS NOT NULL AND multi_wan_mode IS NOT NULL AND multi_wan_mode != 'none'`);
    for (const d of devs.rows) {
      try { await syncDevicePolicies(d); }
      catch (e) { logger.warn(`[policy-sync] device ${d.id}: ${e.message}`); }
    }
    return devs.rows.length;
  } catch (e) {
    logger.error('[policy-sync] syncAll: ' + e.message);
    return 0;
  }
}

module.exports = { syncAll, syncDevicePolicies };
