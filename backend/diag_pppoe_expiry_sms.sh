#!/usr/bin/env bash
# READ ONLY — why the PPPoE expiry SMS still does not arrive.
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Subscriber state — does the sweep's WHERE clause still match?"
q -c "SELECT username, phone, status, next_billing_date, payment_sms_sent_at,
             (status='active' AND next_billing_date < NOW()) AS matches_sweep
      FROM pppoe_subscribers;"
echo "   ${Y}the sweep selects ONLY status='active' AND next_billing_date < NOW()${N}"

say "2) Who else sets a subscriber to 'expired'?"
grep -rnE "pppoe_subscribers SET[^;]*status\s*=\s*'expired'|status='expired'" "$BE" --include=*.js 2>/dev/null \
  | grep -v -E 'node_modules|\.bak' | sed 's/^/   /'

say "3) Does walledGarden.restrict() set the status, and can it throw?"
sudo grep -n "async function restrict\|status\|timeout:" "$BE/utils/walledGarden.js" | head -20 | sed 's/^/   /'
L=$(sudo grep -n "async function restrict" "$BE/utils/walledGarden.js" | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "${L},$((L+40))p" "$BE/utils/walledGarden.js" | nl -ba -v"$L" | sed 's/^/   /'

say "4) Router timeouts in walledGarden (8s was failing earlier)"
sudo grep -c "timeout: *8000" "$BE/utils/walledGarden.js" | sed 's/^/   timeout:8000 occurrences: /'
sudo grep -c "timeout: *25000" "$BE/utils/walledGarden.js" | sed 's/^/   timeout:25000 occurrences: /'

say "5) What the expiry sweep actually logged"
pm2 logs rumalink-backend --lines 900 --nostream 2>/dev/null \
  | grep -iE "expiry-enforcer|walled|restrict|EXPIRY-ENFORCE" | tail -20 | sed 's/^/   /' || echo "   ${Y}nothing — the sweep never selected this subscriber${N}"

say "6) Recent SMS (was an expiry notice sent at all?)"
q -c "SELECT recipient, LEFT(message,60) AS msg, status, to_char(sent_at,'MM-DD HH24:MI:SS') AS at
      FROM sms_logs ORDER BY sent_at DESC LIMIT 8;"

say "7) The sweep block as it stands now"
S=$(sudo grep -n "_pppoeExpiryBusy = true" "$BE/utils/cron.js" | head -1 | cut -d: -f1)
[ -n "$S" ] && sudo sed -n "$((S-4)),$((S+55))p" "$BE/utils/cron.js" | nl -ba -v"$((S-4))" | sed 's/^/   /'

say "8) Is the subscriber currently walled on the router?"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const r=await query('SELECT name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL');
 for(const d of r.rows){
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  const get=async p=>{try{return (await axios.get(b+p,{auth,timeout:20000})).data||[]}catch(e){return []}};
  const al=await get('/ip/firewall/address-list');
  console.log('   rl-expired entries: '+al.filter(x=>x.list==='rl-expired').length);
  al.filter(x=>x.list==='rl-expired').forEach(x=>console.log('     '+x.address+'  '+(x.comment||'')));
  const ppp=await get('/ppp/active');
  console.log('   active PPPoE: '+ppp.length);
  ppp.forEach(x=>console.log('     '+x.name+' '+x.address));
 }
 process.exit(0);
})();"
