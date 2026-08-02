#!/usr/bin/env bash
#
# restore_step3.sh — verify payment routing at runtime and rebuild the last two modules.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) paymentRoute.resolve() — full logic"
sudo sed -n '1,50p' "$BE/utils/paymentRoute.js" | nl -ba | sed 's/^/   /'

say "2) What does it resolve to for THIS ISP, right now?"
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
(async()=>{
  try{
    const pr = require('$BE/utils/paymentRoute');
    const r = await pr.resolve('$ISP');
    console.log('   gateway: ' + r.gateway);
    console.log('   has creds: ' + (r.creds ? 'YES' : 'no'));
    if (r.creds) console.log('   shortcode: ' + (r.creds.shortcode || r.creds.till_number || '(none)'));
  }catch(e){ console.log('   resolve FAILED: ' + e.message); }
  process.exit(0);
})();"
echo "   ${Y}ISP chose mpesa_stk with its own Daraja credentials -> expect gateway 'daraja' with creds.${N}"

say "3) Rebuild utils/expired-enforcer.js"
sudo tee "$BE/utils/expired-enforcer.js" > /dev/null <<'JS'
// RL_EXPIRED_ENFORCER — two jobs, each done ONCE per expiry event.
// 1) Flush tracked connections for addresses in rl-expired, so an expired customer's
//    already-open connections cannot outlive their package (order-independent, unlike
//    firewall rule ordering).
// 2) Drop the PPPoE session so the client redials and its OS connectivity probe fires
//    immediately — otherwise the pay page only appears minutes later, when the device
//    next happens to probe.
const axios = require('axios');
const { query } = require('../config/database');
const logger = require('./logger');
const TIMEOUT = 25000, BATCH = 15, INTERVAL = 60 * 1000, FULL_SWEEP_EVERY = 10;
let passCount = 0;
const lastExpired = new Map();
const kicked = new Map();
function client(dev) {
  const b = 'http://' + dev.wireguard_ip + '/rest';
  const auth = { username: dev.mikrotik_api_user, password: dev.mikrotik_api_password };
  return {
    get: p => axios.get(b + p, { auth, timeout: TIMEOUT }).then(r => r.data || []),
    del: p => axios.delete(b + p, { auth, timeout: TIMEOUT }),
  };
}
const ipOf = e => String(e.address || '').split('/')[0];
async function enforcePppoe(dev, fullSweep) {
  const c = client(dev);
  const al = await c.get('/ip/firewall/address-list');
  const expired = new Set(al.filter(x => String(x.list || '') === 'rl-expired').map(ipOf).filter(Boolean));
  const prev = lastExpired.get(dev.id) || new Set();
  lastExpired.set(dev.id, expired);
  const kickSet = kicked.get(dev.id) || new Set();
  for (const a of [...kickSet]) if (!expired.has(a)) kickSet.delete(a);
  kicked.set(dev.id, kickSet);
  if (!expired.size) return;
  const fresh = new Set([...expired].filter(a => !prev.has(a)));
  const targets = fullSweep ? expired : fresh;
  if (!targets.size) return;
  try {
    const conns = await c.get('/ip/firewall/connection');
    let n = 0;
    for (const conn of conns) {
      const s = String(conn['src-address'] || '').split(':')[0];
      const d = String(conn['dst-address'] || '').split(':')[0];
      if (targets.has(s) || targets.has(d)) { try { await c.del('/ip/firewall/connection/' + encodeURIComponent(conn['.id'])); n++; } catch (e) {} }
    }
    if (n) logger.info('[EXPIRED-ENFORCER] ' + (dev.name || dev.wireguard_ip) + ': flushed ' + n + ' connection(s)');
  } catch (e) { logger.warn('[EXPIRED-ENFORCER] conntrack: ' + e.message); }
  try {
    const active = await c.get('/ppp/active');
    for (const s of active) {
      const addr = String(s.address || '');
      if (!fresh.has(addr) || kickSet.has(addr)) continue;
      try {
        await c.del('/ppp/active/' + encodeURIComponent(s['.id']));
        kickSet.add(addr);
        logger.info('[EXPIRED-ENFORCER] ' + (dev.name || dev.wireguard_ip) + ': disconnected expired PPPoE ' + s.name + ' (' + addr + ')');
      } catch (e) {}
    }
  } catch (e) {}
}
async function enforceHotspot(dev) {
  let macs = [];
  try {
    const r = await query(
      "SELECT DISTINCT UPPER(used_by_mac) AS mac FROM hotspot_vouchers " +
      "WHERE used_by_mac IS NOT NULL AND expires_at IS NOT NULL AND expires_at < NOW() " +
      "AND expires_at > NOW() - INTERVAL '10 minutes' " +
      "AND isp_id = (SELECT isp_id FROM nas_devices WHERE id = $1::uuid)", [dev.id]);
    macs = (r.rows || []).map(x => x.mac).filter(Boolean);
  } catch (e) { return; }
  if (!macs.length) return;
  const c = client(dev);
  const kickSet = kicked.get(dev.id) || new Set();
  kicked.set(dev.id, kickSet);
  try {
    const act = await c.get('/ip/hotspot/active');
    for (const s of act) {
      const mac = String(s['mac-address'] || '').toUpperCase();
      if (!macs.includes(mac) || kickSet.has(mac)) continue;
      try { await c.del('/ip/hotspot/active/' + encodeURIComponent(s['.id']));
        logger.info('[EXPIRED-ENFORCER] ' + (dev.name || dev.wireguard_ip) + ': logged out expired hotspot ' + mac); } catch (e) {}
    }
  } catch (e) {}
  // Best effort only: works únicamente if the client is on THIS router's radio. Many sites
  // use external APs, where nothing happens — expected, not an error.
  for (const path of ['/interface/wireless/registration-table', '/interface/wifi/registration-table']) {
    try {
      const reg = await c.get(path);
      for (const s of reg) {
        const mac = String(s['mac-address'] || '').toUpperCase();
        if (!macs.includes(mac) || kickSet.has(mac)) continue;
        try { await c.del(path + '/' + encodeURIComponent(s['.id'])); kickSet.add(mac);
          logger.info('[EXPIRED-ENFORCER] ' + (dev.name || dev.wireguard_ip) + ': deauthed ' + mac); } catch (e) {}
      }
    } catch (e) {}
  }
}
async function pass() {
  passCount++;
  const fullSweep = (passCount % FULL_SWEEP_EVERY) === 0;
  let devs = [];
  try {
    const r = await query("SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password " +
      "FROM nas_devices WHERE wireguard_ip IS NOT NULL AND is_online = true");
    devs = r.rows || [];
  } catch (e) { logger.warn('[EXPIRED-ENFORCER] db: ' + e.message); return; }
  for (let i = 0; i < devs.length; i += BATCH) {
    await Promise.all(devs.slice(i, i + BATCH).map(async d => {
      try { await enforcePppoe(d, fullSweep); } catch (e) { logger.warn('[EXPIRED-ENFORCER] ' + (d.name||d.wireguard_ip) + ' pppoe: ' + e.message); }
      try { await enforceHotspot(d); } catch (e) { logger.warn('[EXPIRED-ENFORCER] ' + (d.name||d.wireguard_ip) + ' hotspot: ' + e.message); }
    }));
  }
}
function start() {
  pass().catch(e => logger.warn('[EXPIRED-ENFORCER] first pass: ' + e.message));
  setInterval(() => pass().catch(e => logger.warn('[EXPIRED-ENFORCER] pass: ' + e.message)), INTERVAL);
  logger.info('[EXPIRED-ENFORCER] Registered (every 60s) — closes the expiry leak and forces immediate portal detection');
}
module.exports = { start, pass, enforcePppoe, enforceHotspot };
JS
sudo sed -i 's/únicamente/only/' "$BE/utils/expired-enforcer.js"
sudo chown www-data:www-data "$BE/utils/expired-enforcer.js"
sudo -u www-data node --check "$BE/utils/expired-enforcer.js" && echo "   expired-enforcer.js OK"

say "4) Is the health monitor stack still present?"
for f in utils/health-monitor.js routes/health.js; do
  [ -f "$BE/$f" ] && echo "   present: $f" || echo "   ${Y}missing: $f${N}"
done
[ -f /var/www/rumalink/admin/health.html ] && echo "   present: admin/health.html" || echo "   ${Y}missing: admin/health.html${N}"
sudo grep -c "vps-health" /var/www/rumalink/admin/dashboard.html 2>/dev/null | sed 's/^/   dashboard nav refs: /'
q -c "SELECT count(*) AS system_health_rows FROM system_health;" 2>&1 | head -3 | sed 's/^/   /'

say "5) Register expired-enforcer"
sudo cp "$BE/utils/cron.js" "$BE/utils/.cron.js.bak_$TS"
if sudo grep -q "expired-enforcer" "$BE/utils/cron.js"; then echo "   already registered"
else echo "try { require('./expired-enforcer').start(); } catch (e) { require('./logger').warn('[expired-enforcer] start: ' + e.message); }" | sudo tee -a "$BE/utils/cron.js" >/dev/null; echo "   registered"; fi
sudo -u www-data node --check "$BE/utils/cron.js" && echo "   cron.js OK"

say "6) Restart and verify all guards"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 10
pm2 logs rumalink-backend --lines 80 --nostream 2>/dev/null | grep -oE "\[(QUEUE-MONITOR|QUEUE-INTEGRITY|EXPIRED-ENFORCER|HEALTH|router-harden|strand-heal)\][^{]*" | sort -u | sed 's/^/   /'
(sudo pm2 list 2>/dev/null || pm2 list) | grep rumalink-backend | sed 's/^/   /'

say "7) Final state"
q -c "SELECT company_name, id FROM isps;"
q -c "SELECT name, wireguard_ip, is_online FROM nas_devices;"
q -c "SELECT method_type, label, is_default FROM isp_payment_methods;"
curl -sk -o /dev/null -w "   portal HTTP %{http_code}\n" "https://rumalinkenterprise.online/captive/classic.html"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const r=await query('SELECT name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL');
 for(const d of r.rows){
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  try{
   const f=(await axios.get(b+'/ip/firewall/filter',{auth,timeout:20000})).data||[];
   const st=(await axios.get(b+'/ip/settings',{auth,timeout:20000})).data||{};
   console.log('   router '+d.name+': fasttrack='+f.filter(x=>x.action==='fasttrack-connection').length+' active='+st['ipv4-fasttrack-active']);
  }catch(e){console.log('   router '+d.name+': '+e.message)}
 }
 process.exit(0);
})();"
