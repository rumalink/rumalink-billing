#!/usr/bin/env bash
# READ ONLY — what WAN/failover monitoring and SMS already exists, and what is missing.
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) isp-monitor.js — what does it already alert on?"
sudo grep -nE "^async function|^function|sendSMS|message|status|offline|online|recipient|phone" "$BE/utils/isp-monitor.js" | head -30 | sed 's/^/   /'
echo "   --- the message(s) it sends ---"
sudo grep -nE "message *=|message:" "$BE/utils/isp-monitor.js" | head -10 | sed 's/^/   /'
echo "   --- who receives them ---"
L=$(sudo grep -n "sendSMS" "$BE/utils/isp-monitor.js" | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "$((L-25)),$((L+6))p" "$BE/utils/isp-monitor.js" | nl -ba -v"$((L-25))" | sed 's/^/     /'

say "2) mwan-applier.js — does it track which WAN is active?"
sudo grep -nE "^async function|^function|module.exports" "$BE/utils/mwan-applier.js" | sed 's/^/   /'
echo "   --- failover / distance / check-gateway logic ---"
sudo grep -nE "distance|check-gateway|failover|active|primary|backup|recursive|netwatch" "$BE/utils/mwan-applier.js" | head -20 | sed 's/^/   /'

say "3) Is there a monitor that polls WAN state?"
grep -rn "monitorDevice\|wan_status\|active_wan\|current_wan" "$BE/utils" "$BE/routes" --include=*.js 2>/dev/null | grep -v -E 'node_modules|\.bak' | head -15 | sed 's/^/   /'

say "4) Database: where is WAN config / state stored?"
q -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ILIKE '%wan%' OR table_name ILIKE '%link%' OR table_name ILIKE '%nas_event%') ORDER BY 1;"
for t in nas_wan_links wan_links nas_events; do
  echo "   --- $t ---"; q -c "SELECT column_name FROM information_schema.columns WHERE table_name='$t' ORDER BY ordinal_position;" 2>&1 | head -18
done
q -c "SELECT column_name FROM information_schema.columns WHERE table_name='nas_devices' AND (column_name ILIKE '%wan%' OR column_name ILIKE '%online%' OR column_name ILIKE '%seen%') ORDER BY 1;"

say "5) Recent nas_events (what is already recorded)"
q -c "SELECT event_type, count(*) FROM nas_events GROUP BY event_type ORDER BY 2 DESC LIMIT 12;" 2>&1
q -c "SELECT event_type, LEFT(message,60) AS message, created_at FROM nas_events ORDER BY created_at DESC LIMIT 8;" 2>&1

say "6) The ISP account owner's phone (the alert recipient)"
q -c "SELECT company_name, owner_name, phone, email FROM isps;" 2>&1

say "7) Live WAN state on the router"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const r=await query('SELECT name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL');
 for(const d of r.rows){
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  const get=async p=>{try{return (await axios.get(b+p,{auth,timeout:20000})).data||[]}catch(e){return []}};
  console.log('   --- '+d.name+' ---');
  const routes=await get('/ip/route');
  console.log('   default routes:');
  routes.filter(x=>String(x['dst-address']||'')==='0.0.0.0/0').forEach(x=>
    console.log('     gw='+(x.gateway||'?')+' distance='+(x.distance||'?')+' active='+(x.active||'false')+' comment='+(x.comment||'')));
  const nw=await get('/tool/netwatch');
  console.log('   netwatch entries: '+nw.length);
  nw.forEach(x=>console.log('     host='+x.host+' status='+x.status+' comment='+(x.comment||'')));
  const ifs=await get('/interface');
  console.log('   WAN-ish interfaces:');
  ifs.filter(x=>/wan|ether1|pppoe|lte/i.test(x.name||'')).forEach(x=>
    console.log('     '+x.name+' type='+x.type+' running='+x.running+' disabled='+x.disabled));
 }
 process.exit(0);
})();"

say "8) The device page in the ISP dashboard"
grep -oE "'/api/nas/[a-z/:-]+'|\"/api/nas/[a-z/:-]+\"" /var/www/rumalink/isp/dashboard.html 2>/dev/null | sort -u | head -15 | sed 's/^/   /'
grep -nE "wan|failover|backup link" /var/www/rumalink/isp/dashboard.html 2>/dev/null | head -10 | sed 's/^/   /'
