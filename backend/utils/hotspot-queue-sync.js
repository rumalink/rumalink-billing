// v62.107 — Hotspot queue reconciler (VPS-side)
//
// PROBLEM: RumaLink's hotspot uses a RADIUS-HYBRID flow (hotspot use-radius=false).
// The backend creates a STATIC /queue/simple pinned to the IP captured at login.
// When a user reconnects and gets a new pool IP, the static queue stays on the old
// IP, so the RADIUS rate limit no longer matches the user's traffic and the cap leaks.
//
// FIX: every ~15s, reconcile simple queues against ACTIVE hotspot sessions:
//   - For each active session (user=voucher code, address=live IP), ensure a queue
//     named rl-<code> exists with target=<live IP>/32 and max-limit = the user's
//     RADIUS Mikrotik-Rate-Limit. Create or PATCH as needed.
//   - Remove orphan rl-* queues whose user has no active session (these are the
//     stale ones causing the leak). Self-healing: if a fresh queue is briefly
//     removed, the next pass recreates it from the active session.
//
// Runs entirely on the VPS (a few REST calls per device). The MikroTik just holds
// the queues. This guarantees RADIUS rate limits follow the user across reconnects
// and WAN failovers.

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
  try { data = await resp.json(); } catch(e) {}
  if (!resp.ok) {
    const errMsg = (data && (data.detail || data.message || data.error)) || ('HTTP ' + resp.status);
    throw new Error(`${method} ${path} → ${errMsg}`);
  }
  return data;
}

function rateToBps(part) {
  if (!part) return 0;
  const m = String(part).trim().match(/^(\d+(?:\.\d+)?)\s*([kKmMgG]?)/);
  if (!m) return 0;
  let n = parseFloat(m[1]);
  const u = (m[2] || '').toLowerCase();
  if (u === 'k') n *= 1e3; else if (u === 'm') n *= 1e6; else if (u === 'g') n *= 1e9;
  return Math.round(n);
}
function canonRate(rate) {
  if (!rate) return '';
  return String(rate).split('/').map(rateToBps).join('/');
}

// Look up the RADIUS Mikrotik-Rate-Limit for a hotspot session user (voucher code)
async function rateForUser(user) {
  // session user is the voucher code; radreply may store it as "CODE" or "CODE@ispprefix"
  const rr = await query(
    `SELECT value FROM radreply
     WHERE attribute = 'Mikrotik-Rate-Limit'
       AND (username = $1 OR username LIKE $1 || '@%')
     ORDER BY (username = $1) DESC
     LIMIT 1`,
    [user]
  );
  return rr.rows[0] ? rr.rows[0].value : null;
}

async function syncDeviceQueues(dev) {
  let active = [], queues = [];
  try { active = await mtCall(dev, 'GET', '/ip/hotspot/active'); } catch(e) { return { skipped: true }; }
  try { queues = await mtCall(dev, 'GET', '/queue/simple'); } catch(e) { return { skipped: true }; }

  let created = 0, updated = 0, removed = 0;

  // Map active sessions by user (voucher code)
  const activeByUser = {};
  for (const s of active) {
    if (s.user && s.address) activeByUser[s.user] = s;
  }

  // Ensure each active session has a correct queue
  for (const user of Object.keys(activeByUser)) {
    const s = activeByUser[user];
    const rate = await rateForUser(user);
    if (!rate) continue;  // no rate limit configured for this user → leave alone
    const queueName = 'rl-' + user;
    const target = s.address + '/32';
    const existing = queues.find(q => q.name === queueName);
    try {
      if (existing) {
        const targetWrong = (existing.target || '') !== target;
        const rateWrong = canonRate(existing['max-limit']) !== canonRate(rate);
        if (targetWrong || rateWrong) {
          await mtCall(dev, 'PATCH', '/queue/simple/' + existing['.id'], { target, 'max-limit': rate });
          updated++;
          logger.info(`[queue-sync] ${dev.wireguard_ip} ${queueName}: target=${target} max-limit=${rate} (was target=${existing.target} limit=${existing['max-limit']})`);
        }
      } else {
        if (!/^K[0-9]+@/i.test(String(user)) && !/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/i.test(String(user).trim()) /* RL_NO_DUP_MAC */) await mtCall(dev, 'PUT', '/queue/simple', { name: queueName, target, 'max-limit': rate, comment: 'RumaLink rate-limit (synced)' }); /* RL_NO_DUP_QUEUE: RADIUS reply already rate-limits hotspot logins dynamically */
        created++;
        logger.info(`[queue-sync] ${dev.wireguard_ip} created ${queueName} target=${target} max-limit=${rate}`);
      }
    } catch (e) {
      logger.warn(`[queue-sync] ${queueName}: ${e.message}`);
    }
  }

  // Remove orphan rl-* queues whose user has no active session (the stale ones)
  for (const q of queues) {
    if (!q.name || !q.name.startsWith('rl-')) continue;
    // RL_TV_QUEUE_SKIP: TV queues (rl-tv-*) belong to bypass-bound TVs that have NO hotspot session,
    // so they must not be reaped as orphans. The TV-EXPIRE cron removes them at package expiry.
    if (q.name.startsWith('rl-tv-')) continue;
    const user = q.name.slice(3);
    if (!activeByUser[user]) {
      try {
        await mtCall(dev, 'POST', '/queue/simple/remove', { '.id': q['.id'] });
        removed++;
        logger.info(`[queue-sync] ${dev.wireguard_ip} removed orphan ${q.name} (target=${q.target}, no active session)`);
      } catch (e) {
        logger.warn(`[queue-sync] remove ${q.name}: ${e.message}`);
      }
    }
  }

  return { created, updated, removed, active: active.length };
}

async function syncAll() {
  try {
    const devs = await query(
      `SELECT id, isp_id, wireguard_ip, mikrotik_api_user, mikrotik_api_password
       FROM nas_devices
       WHERE wireguard_ip IS NOT NULL AND mikrotik_api_user IS NOT NULL AND mikrotik_api_password IS NOT NULL`
    );
    let touched = 0;
    for (const d of devs.rows) {
      try {
        const r = await syncDeviceQueues(d);
        if (r && !r.skipped && (r.created || r.updated || r.removed)) touched++;
      } catch (e) {
        logger.warn(`[queue-sync] device ${d.id}: ${e.message}`);
      }
    }
    return touched;
  } catch (e) {
    logger.error('[queue-sync] syncAll: ' + e.message);
    return 0;
  }
}

module.exports = { syncAll, syncDeviceQueues };
