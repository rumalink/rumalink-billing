#!/usr/bin/env bash
#
# restore_step2.sh
#   1. Confirm the crash loop is genuinely over (the SyntaxError lines may be stale log entries).
#   2. Re-apply the two fixes whose backups predated them (SMS gateway default, SMS voucher pick).
#   3. Recreate the four deleted modules and register them.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Is it actually stable? (watching 25s)"
A=$( (sudo pm2 jlist 2>/dev/null || pm2 jlist) | sudo -u www-data node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{const j=JSON.parse(s).find(x=>x.name==='rumalink-backend');console.log(j.pm2_env.restart_time+' '+Math.round(j.pm2_env.pm_uptime))}catch(e){console.log('0 0')}})" )
echo "   restarts/uptime now: $A"
sleep 25
B=$( (sudo pm2 jlist 2>/dev/null || pm2 jlist) | sudo -u www-data node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{const j=JSON.parse(s).find(x=>x.name==='rumalink-backend');console.log(j.pm2_env.restart_time+' '+Math.round(j.pm2_env.pm_uptime))}catch(e){console.log('0 0')}})" )
echo "   restarts/uptime +25s: $B"
R1=$(echo "$A" | cut -d' ' -f1); R2=$(echo "$B" | cut -d' ' -f1)
if [ "$R1" = "$R2" ]; then echo "   ${G}STABLE — restart count did not increase${N}";
else echo "   ${R}STILL CRASHING — restart count rose $R1 -> $R2${N}"; fi
echo "   most recent log lines (with timestamps):"
pm2 logs rumalink-backend --lines 25 --nostream 2>/dev/null | tail -12 | sed 's/^/     /'

say "2) Re-apply: SMS default gateway (sms.js)"
sudo cp "$BE/utils/sms.js" "$BE/utils/.sms.js.bak_$TS"
sudo python3 - "$BE/utils/sms.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_DEFAULT_GATEWAY' in s:
    print("   already present"); sys.exit(0)
old = "const gateway = isp?.sms_gateway?.toLowerCase() || process.env.SMS_DEFAULT_GATEWAY || 'africastalking';"
if old not in s:
    print("   ERROR: anchor not found — unchanged"); sys.exit(1)
new = ("/* RL_DEFAULT_GATEWAY: defaulted to 'africastalking', which is not configured here, while the\n"
       "     logging wrapper below defaulted to 'rumalink'. Any caller that did not set sms_gateway\n"
       "     explicitly (cron expiry notices, ISP alerts) failed to send AND was logged against the\n"
       "     wrong provider. 'rumalink' is the platform reseller gateway backed by sms_provider_config. */\n"
       "  const gateway = isp?.sms_gateway?.toLowerCase() || process.env.SMS_DEFAULT_GATEWAY || 'rumalink';")
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   patched: africastalking -> rumalink")
PY
cd "$BE" && sudo -u www-data node --check utils/sms.js && echo "   sms.js OK"

say "3) Re-apply: SMS picks the activated voucher (hotspotSms.js)"
sudo cp "$BE/utils/hotspotSms.js" "$BE/utils/.hotspotSms.js.bak_$TS"
sudo python3 - "$BE/utils/hotspotSms.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_SMS_PICK_REAL' in s:
    print("   already present"); sys.exit(0)
old = '"WHERE p.id = $1::uuid LIMIT 1", [paymentId]);'
if old not in s:
    print("   ERROR: anchor not found — unchanged"); sys.exit(1)
new = ('"WHERE p.id = $1::uuid " +\n'
       '          /* RL_SMS_PICK_REAL: if more than one voucher ever points at a payment, prefer the one\n'
       '             that was actually activated — otherwise the customer is told a code that was never\n'
       '             provisioned. */\n'
       '          "ORDER BY (v.status = \'active\') DESC, v.expires_at DESC NULLS LAST, v.updated_at DESC NULLS LAST LIMIT 1",\n'
       '          [paymentId]);')
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   patched")
PY
cd "$BE" && sudo -u www-data node --check utils/hotspotSms.js && echo "   hotspotSms.js OK"

say "4) Recreate utils/fasttrack-guard.js"
sudo tee "$BE/utils/fasttrack-guard.js" > /dev/null <<'JS'
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
JS
sudo chown www-data:www-data "$BE/utils/fasttrack-guard.js"
sudo -u www-data node --check "$BE/utils/fasttrack-guard.js" && echo "   fasttrack-guard.js OK"

say "5) Recreate utils/queue-monitor.js"
sudo tee "$BE/utils/queue-monitor.js" > /dev/null <<'JS'
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
JS
sudo chown www-data:www-data "$BE/utils/queue-monitor.js"
sudo -u www-data node --check "$BE/utils/queue-monitor.js" && echo "   queue-monitor.js OK"

say "6) Register both in cron.js (idempotent)"
sudo cp "$BE/utils/cron.js" "$BE/utils/.cron.js.bak_$TS"
for m in fasttrack-guard queue-monitor; do
  if sudo grep -q "$m" "$BE/utils/cron.js"; then echo "   already registered: $m"
  else echo "try { require('./$m').start(); } catch (e) { require('./logger').warn('[$m] start: ' + e.message); }" | sudo tee -a "$BE/utils/cron.js" >/dev/null; echo "   registered: $m"; fi
done
sudo -u www-data node --check "$BE/utils/cron.js" && echo "   cron.js OK"

say "7) Restart and verify"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 10
pm2 logs rumalink-backend --lines 60 --nostream 2>/dev/null | grep -iE "QUEUE-INTEGRITY|QUEUE-MONITOR|SyntaxError|Cannot find module" | tail -8 | sed 's/^/   /'
(sudo pm2 list 2>/dev/null || pm2 list) | grep rumalink-backend | sed 's/^/   /'

say "8) Live router state"
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
   const qs=(await axios.get(b+'/queue/simple',{auth,timeout:20000})).data||[];
   console.log('   '+d.name+': fasttrack='+f.filter(x=>x.action==='fasttrack-connection').length+
     ' ipv4-fasttrack-active='+st['ipv4-fasttrack-active']+' queues='+qs.length);
  }catch(e){console.log('   '+d.name+': '+e.message)}
 }
 process.exit(0);
})();"
echo
echo "   ${Y}Next: expired-enforcer + health monitor + dashboard, then the portal payment sync.${N}"
