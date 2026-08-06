#!/usr/bin/env bash
#
# walled_garden_ip_sync.sh — the portal API is unreachable for some phones.
#
# CAUSE: /ip/hotspot/walled-garden/ip is EMPTY. The only allowance is a HOSTNAME rule for
# rumalinkenterprise.online, which requires the router to see and match the name. Phones using
# DNS-over-HTTPS, Private DNS, a VPN, or Encrypted Client Hello never expose it, so the router
# blocks their API calls. The cached HTML still renders — which is why those users see the static
# "Already have a voucher?" section and no packages, while other phones work perfectly.
#
# FIX: resolve the portal hostname at RUNTIME and keep each router's walled garden in step. The
# address is never written into the code, so moving to another Lightsail instance or a different
# provider needs only a DNS change — the routers follow within minutes on their own.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) What the portal hostname resolves to now"
sudo grep -oE '^BASE_URL=.*' "$BE/.env" | sed 's/^/   /'
getent hosts rumalinkenterprise.online | sed 's/^/   /'

say "2) Create utils/walled-garden-sync.js"
sudo tee "$BE/utils/walled-garden-sync.js" > /dev/null <<'JS'
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
JS
sudo chown www-data:www-data "$BE/utils/walled-garden-sync.js"
sudo -u www-data node --check "$BE/utils/walled-garden-sync.js" && echo "   walled-garden-sync.js OK"

say "3) Run it once now"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
(async()=>{
  const wg=require('$BE/utils/walled-garden-sync');
  const r=await wg.resolvePortalIps();
  console.log('   host: '+r.host+'   ips: '+r.ips.join(', '));
  await wg.pass();
  console.log('   sync complete');
  process.exit(0);
})();" 2>&1 | grep -vE "^info: \[wg" | sed 's/^/  /'

say "4) Register it, and add it to provisioning"
sudo cp "$BE/utils/cron.js" "$BE/utils/.cron.js.bak_$TS"
if sudo grep -q "walled-garden-sync" "$BE/utils/cron.js"; then echo "   already registered"
else echo "try { require('./walled-garden-sync').start(); } catch (e) { require('./logger').warn('[wg-sync] start: ' + e.message); }" | sudo tee -a "$BE/utils/cron.js" >/dev/null; echo "   registered"; fi
sudo -u www-data node --check "$BE/utils/cron.js" && echo "   cron.js OK"

say "5) Restart + verify on the router"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 10
pm2 logs rumalink-backend --lines 30 --nostream 2>/dev/null | grep -iE "wg-sync" | tail -6 | sed 's/^/   /'
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
const ip=(await axios.get(b+'/ip/hotspot/walled-garden/ip',{auth,timeout:15000})).data||[];
console.log('   walled-garden IP entries ('+ip.length+'):');
ip.forEach(x=>console.log('     '+x['dst-address']+' action='+x.action+' '+(x.comment||'')));
process.exit(0)})();" 2>&1 | grep -v "^info:"

say "6) When you migrate"
cat <<'EOS'
   Change BASE_URL in .env to the new hostname (or just repoint DNS if the name stays), and every
   router follows within 10 minutes: the new address is allowed, the old one is removed. Nothing
   to edit on the routers, and no address written into the code.

   Ask an affected phone to reload the portal — the packages should appear.
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Walled garden allows the portal by resolved IP, not hostname alone (DoH/Private DNS broke it)" 2>&1 | head -2 | sed 's/^/   /'
