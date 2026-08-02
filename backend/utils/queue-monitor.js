// RL_QUEUE_MONITOR — detects the failure config inspection CANNOT catch: a queue that exists,
// is correctly targeted, has the right max-limit — and is not enforcing. Signature: observed
// rate materially exceeds the queue's own max-limit. Cause-agnostic by design.
const axios = require('axios');
const { query } = require('../config/database');
const logger = require('./logger');
const TIMEOUT = 25000, BATCH = 15, INTERVAL = 30 * 1000;
const TOLERANCE = 1.25, FLOOR_BPS = 500000, STRIKES = 2;
const strikes = new Map();
function parsePair(v) {
  const s = String(v || '');
  if (!s.includes('/')) return [0, 0];
  return s.split('/').slice(0, 2).map(x => {
    const m = String(x).trim().match(/^([\d.]+)\s*([kKmMgG])?/);
    if (!m) return 0;
    let n = parseFloat(m[1]) || 0;
    const u = (m[2] || '').toLowerCase();
    if (u === 'k') n *= 1e3; else if (u === 'm') n *= 1e6; else if (u === 'g') n *= 1e9;
    return n;
  });
}
async function check(dev) {
  const b = 'http://' + dev.wireguard_ip + '/rest';
  const auth = { username: dev.mikrotik_api_user, password: dev.mikrotik_api_password };
  const queues = (await axios.get(b + '/queue/simple', { auth, timeout: TIMEOUT })).data || [];
  const label = dev.name || dev.wireguard_ip;
  for (const q of queues) {
    if (String(q.disabled) === 'true') continue;
    const [limUp, limDn] = parsePair(q['max-limit']);
    const [rUp, rDn] = parsePair(q.rate);
    for (const [dir, lim, rate] of [['up', limUp, rUp], ['down', limDn, rDn]]) {
      const key = dev.id + '|' + q.name + '|' + dir;
      if (!(lim > 0 && rate > FLOOR_BPS && rate > lim * TOLERANCE)) { strikes.delete(key); continue; }
      const n = (strikes.get(key) || 0) + 1;
      strikes.set(key, n);
      if (n < STRIKES) continue;
      logger.error('[QUEUE-BYPASS] ' + label + ' queue=' + q.name + ' ' + dir +
        ' observed=' + (Math.round(rate / 1e5) / 10) + 'M but max-limit=' + (Math.round(lim / 1e5) / 10) +
        'M — queue NOT enforcing; customers consuming UNMETERED bandwidth.');
      strikes.set(key, 0);
    }
  }
}
async function pass() {
  let devs = [];
  try {
    const r = await query("SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password " +
      "FROM nas_devices WHERE wireguard_ip IS NOT NULL AND is_online = true");
    devs = r.rows || [];
  } catch (e) { logger.warn('[QUEUE-MONITOR] db: ' + e.message); return; }
  for (let i = 0; i < devs.length; i += BATCH) {
    await Promise.all(devs.slice(i, i + BATCH).map(d =>
      check(d).catch(e => logger.warn('[QUEUE-MONITOR] ' + (d.name || d.wireguard_ip) + ': ' + e.message))));
  }
}
function start() {
  pass().catch(e => logger.warn('[QUEUE-MONITOR] first pass: ' + e.message));
  setInterval(() => pass().catch(e => logger.warn('[QUEUE-MONITOR] pass: ' + e.message)), INTERVAL);
  logger.info('[QUEUE-MONITOR] Registered (every 30s) — alarms if any queue exceeds its own max-limit');
}
module.exports = { start, pass, check, parsePair };
