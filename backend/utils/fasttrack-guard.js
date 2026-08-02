// RL_QUEUE_INTEGRITY — no ENABLED fasttrack-connection rule may exist on a managed router.
// Fasttracked packets bypass /queue/simple, silently disabling every per-user rate limit
// (hotspot rl-<code>, PPPoE, TV rl-tv-<mac>). Invisible from the dashboard; costs the ISP money.
const axios = require('axios');
const { query } = require('../config/database');
const logger = require('./logger');
const TIMEOUT = 15000, BATCH = 20, INTERVAL = 2 * 60 * 1000;
let sweepCount = 0;
function client(dev) {
  const b = 'http://' + dev.wireguard_ip + '/rest';
  const auth = { username: dev.mikrotik_api_user, password: dev.mikrotik_api_password };
  return {
    get: p => axios.get(b + p, { auth, timeout: TIMEOUT }).then(r => r.data || []),
    del: p => axios.delete(b + p, { auth, timeout: TIMEOUT }),
  };
}
async function enforce(dev) {
  const c = client(dev);
  const rules = await c.get('/ip/firewall/filter');
  const live = rules.filter(r => r.action === 'fasttrack-connection');
  if (!live.length) return false;
  const queues = await c.get('/queue/simple').catch(() => []);
  for (const r of live) await c.del('/ip/firewall/filter/' + encodeURIComponent(r['.id']));
  logger.warn('[QUEUE-INTEGRITY] ' + (dev.name || dev.wireguard_ip) + ': fasttrack rule PRESENT with ' +
    queues.length + ' active queue(s) — rate limits were NOT being enforced. Deleted. ' +
    'Investigate: router reset, re-provision, or manual firewall edit.');
  try {
    const conns = await c.get('/ip/firewall/connection');
    let n = 0;
    for (const conn of conns) { try { await c.del('/ip/firewall/connection/' + encodeURIComponent(conn['.id'])); n++; } catch (e) {} }
    if (n) logger.info('[QUEUE-INTEGRITY] ' + (dev.name || dev.wireguard_ip) + ': flushed ' + n + ' connection(s)');
  } catch (e) {}
  return true;
}
async function pass() {
  let devs = [];
  try {
    sweepCount = (sweepCount + 1) % 10;
    const all = sweepCount === 0;
    const r = await query("SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password " +
      "FROM nas_devices WHERE wireguard_ip IS NOT NULL" + (all ? "" : " AND is_online = true"));
    devs = r.rows || [];
  } catch (e) { logger.warn('[QUEUE-INTEGRITY] db: ' + e.message); return; }
  let corrected = 0;
  for (let i = 0; i < devs.length; i += BATCH) {
    const out = await Promise.all(devs.slice(i, i + BATCH).map(d =>
      enforce(d).catch(e => { logger.warn('[QUEUE-INTEGRITY] ' + (d.name || d.wireguard_ip) + ': ' + e.message); return false; })));
    corrected += out.filter(Boolean).length;
  }
  if (corrected) logger.warn('[QUEUE-INTEGRITY] corrected ' + corrected + ' router(s) this pass');
}
function start() {
  pass().catch(e => logger.warn('[QUEUE-INTEGRITY] first pass: ' + e.message));
  setInterval(() => pass().catch(e => logger.warn('[QUEUE-INTEGRITY] pass: ' + e.message)), INTERVAL);
  logger.info('[QUEUE-INTEGRITY] Registered (every 2m) — enforces: no fasttrack, so per-user queues always apply');
}
module.exports = { start, pass, enforce };
