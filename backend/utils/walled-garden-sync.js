// RL_WG_IP_SYNC — keep the portal reachable for every phone, on whatever address it lives at.
//
// The walled garden allowed the portal by HOSTNAME only. That works when the router can see the
// DNS lookup or the TLS SNI — and increasingly it cannot: Android Private DNS, iOS iCloud Private
// Relay, DNS-over-HTTPS and Encrypted Client Hello all hide it. Those phones loaded the cached
// HTML and were then blocked from the API, so they saw a half-drawn portal with no packages while
// other handsets on the same network worked perfectly.
//
// The address is resolved at runtime rather than written into the code, so migrating to another
// VPS or provider is a DNS change and nothing more: every router picks up the new address on its
// next pass. A hostname rule is kept alongside it as a belt-and-braces measure.
const dns = require('dns').promises;
const axios = require('axios');
const { query } = require('../config/database');
const logger = require('./logger');

const INTERVAL = 10 * 60 * 1000;
const TAG = 'RumaLink portal (auto-resolved)';

function portalHost() {
  const raw = process.env.BASE_URL || process.env.PORTAL_URL || '';
  try { return new URL(raw).hostname; } catch (e) { return String(raw).replace(/^https?:\/\//, '').split('/')[0]; }
}

async function resolvePortalIps() {
  const host = portalHost();
  if (!host) return { host: null, ips: [] };
  const ips = new Set();
  try { (await dns.resolve4(host)).forEach(ip => ips.add(ip)); } catch (e) {
    logger.warn('[wg-sync] could not resolve ' + host + ': ' + e.message);
  }
  /* the WireGuard address the routers reach us on is fixed and local, not part of DNS */
  ips.add('10.8.0.1');
  return { host, ips: Array.from(ips) };
}

async function syncDevice(dev, host, ips) {
  const b = 'http://' + dev.wireguard_ip + '/rest';
  const auth = { username: dev.mikrotik_api_user, password: dev.mikrotik_api_password };
  const get = p => axios.get(b + p, { auth, timeout: 15000 }).then(r => r.data || []);

  const current = await get('/ip/hotspot/walled-garden/ip');
  const have = new Set(current.map(x => String(x['dst-address'] || '').split('/')[0]));
  let added = 0;

  for (const ip of ips) {
    if (have.has(ip)) continue;
    await axios.put(b + '/ip/hotspot/walled-garden/ip',
      { 'dst-address': ip, action: 'accept', comment: TAG }, { auth, timeout: 15000 });
    added++;
    logger.info('[wg-sync] ' + dev.name + ': allowed ' + ip + ' (' + host + ')');
  }

  /* Remove addresses we added that the hostname no longer resolves to — after a migration the old
     server must stop being reachable, or a stale entry keeps pointing customers at nothing. Only
     entries carrying our own tag are touched; anything the ISP added by hand is left alone. */
  for (const row of current) {
    const addr = String(row['dst-address'] || '').split('/')[0];
    if (String(row.comment || '') !== TAG) continue;
    if (ips.includes(addr)) continue;
    await axios.delete(b + '/ip/hotspot/walled-garden/ip/' + encodeURIComponent(row['.id']), { auth, timeout: 15000 }).catch(() => {});
    logger.info('[wg-sync] ' + dev.name + ': removed stale ' + addr);
  }

  /* keep the hostname rule too — it costs nothing and helps any client that does use the router's DNS */
  if (host) {
    const wg = await get('/ip/hotspot/walled-garden');
    if (!wg.some(x => String(x['dst-host'] || '') === host)) {
      await axios.put(b + '/ip/hotspot/walled-garden',
        { 'dst-host': host, action: 'allow', comment: TAG }, { auth, timeout: 15000 }).catch(() => {});
      logger.info('[wg-sync] ' + dev.name + ': allowed host ' + host);
    }
  }
  return added;
}

async function pass() {
  const { host, ips } = await resolvePortalIps();
  if (!ips.length) return;
  let devs = [];
  try {
    devs = (await query(
      'SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL')).rows;
  } catch (e) { logger.warn('[wg-sync] db: ' + e.message); return; }
  for (const d of devs) {
    try { await syncDevice(d, host, ips); }
    catch (e) { logger.warn('[wg-sync] ' + d.name + ': ' + e.message); }
  }
}

function start() {
  pass().catch(e => logger.warn('[wg-sync] first pass: ' + e.message));
  setInterval(() => pass().catch(e => logger.warn('[wg-sync] pass: ' + e.message)), INTERVAL);
  logger.info('[wg-sync] Registered (every 10m) — portal reachable by IP, resolved from BASE_URL');
}

module.exports = { start, pass, resolvePortalIps, syncDevice };
