#!/usr/bin/env bash
#
# research_failover.sh — the whole failover and load-balancing path, read only.
#
# Two questions: why Apply never returns, and why the router flips to backup while the primary is
# healthy. Everything here either reads state or runs applyPlan DETACHED to a file, so nothing is
# lost when a pipe closes or a timeout kills the process — which is what has been eating the
# output so far.
#
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Start applyPlan in the background, logging to a file"
IDS=$(q -tAc "SELECT n.id || ' ' || n.isp_id FROM nas_devices n WHERE n.wireguard_ip IS NOT NULL LIMIT 1;")
NAS=$(echo "$IDS" | cut -d' ' -f1); ISP=$(echo "$IDS" | cut -d' ' -f2)
sudo rm -f /tmp/rl_apply.log
sudo -u www-data nohup timeout 240 node -e "
require('dotenv').config({path:'$BE/.env'});
const fs=require('fs');
const log=function(m){ fs.appendFileSync('/tmp/rl_apply.log', new Date().toISOString()+' '+m+'\n'); };
process.on('unhandledRejection',function(e){ log('UNHANDLED: '+(e&&e.stack?e.stack.split('\n').slice(0,5).join(' | '):e)); });
process.on('uncaughtException',function(e){ log('UNCAUGHT: '+(e&&e.stack?e.stack.split('\n').slice(0,5).join(' | '):e)); });
const t0=Date.now();
const tick=setInterval(function(){ log('still running '+Math.round((Date.now()-t0)/1000)+'s'); },5000);
(async()=>{
  try {
    const a=require('$BE/utils/mwan-applier');
    log('loaded module');
    const r=await a.applyPlan('$NAS','$ISP');
    log('RETURNED after '+Math.round((Date.now()-t0)/1000)+'s: '+JSON.stringify(r).slice(0,700));
  } catch(e) { log('THREW after '+Math.round((Date.now()-t0)/1000)+'s: '+(e&&e.stack?e.stack.split('\n').slice(0,8).join(' | '):e)); }
  clearInterval(tick); process.exit(0);
})();
" >/dev/null 2>&1 &
echo "   started — result appears in /tmp/rl_apply.log"

say "2) What decides a failover — the monitor loop"
grep -n "setInterval\|MONITOR_MS\|monitorAll\|async function monitorDevice" "$BE/utils/mwan-applier.js" | tail -8 | sed 's/^/   /'
echo "   the switch decision:"
L=$(grep -n "RL_FAILOVER_OUTCOME\|function pickActive\|chooseActive\|shouldFailover" "$BE/utils/mwan-applier.js" | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "$((L-8)),$((L+30))p" "$BE/utils/mwan-applier.js" | nl -ba -v"$((L-8))" | sed 's/^/   /'

say "3) Probe routes — both links target 8.8.8.8, so they may be fighting over the same /32"
q -c "SELECT position, name, ping_target, resolved_gateway FROM nas_wan_links ORDER BY position;"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
const r=(await axios.get(b+'/ip/route',{auth,timeout:15000})).data||[];
const probes=r.filter(x=>/RL-OOKLA/.test(String(x.comment||'')));
console.log('   probe /32 routes on the router: '+probes.length);
probes.forEach(x=>console.log('     dst='+x['dst-address']+' gw='+x.gateway+' active='+(x.active||'false')+' # '+x.comment));
const dup={}; probes.forEach(x=>{dup[x['dst-address']]=(dup[x['dst-address']]||0)+1;});
Object.keys(dup).forEach(k=>{ if(dup[k]>1) console.log('     ${Y}DUPLICATE for '+k+': '+dup[k]+' routes — each pass deletes the other link'+'${N}'); });
process.exit(0)})();" 2>&1 | grep -v "^info:"

say "4) Has it been flipping? verdicts and switches we recorded"
q -c "SELECT position, name, is_active, current_status, probe_verdict, probe_stage, fetch_ms,
             consec_fetch_fail, quality_state, last_checked_at
      FROM nas_wan_links ORDER BY position;"
echo "   why is quality history empty? checking the recorder:"
q -c "SELECT count(*) AS rows_total, max(sampled_at) AS newest FROM wan_quality_history;"
grep -c "RL_QUALITY_HISTORY" "$BE/utils/mwan-applier.js" | sed 's/^/     marker present: /'

say "5) Link events we logged"
q -c "SELECT * FROM nas_link_events ORDER BY created_at DESC LIMIT 12;" 2>/dev/null || echo "   (no nas_link_events table)"

say "6) The router's own view right now"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
const g=async p=>{try{return (await axios.get(b+p,{auth,timeout:15000})).data||[]}catch(e){return []}};
console.log('   default routes:');
(await g('/ip/route')).filter(x=>String(x['dst-address'])==='0.0.0.0/0').forEach(x=>
  console.log('     gw='+x.gateway+' dist='+x.distance+' table='+(x['routing-table']||'main')+' active='+(x.active||'false')+' # '+(x.comment||'')));
console.log('   netwatch:');
(await g('/tool/netwatch')).forEach(x=>console.log('     host='+x.host+' status='+x.status+' # '+(x.comment||'')));
console.log('   recent route/link log:');
(await g('/log')).filter(x=>/route|gateway|netwatch/i.test(String(x.topics)+String(x.message))).slice(-12).forEach(x=>
  console.log('     '+x.time+' ['+x.topics+'] '+String(x.message).slice(0,100)));
process.exit(0)})();" 2>&1 | grep -v "^info:"

say "7) Wait for the apply result"
for i in $(seq 1 24); do
  sleep 10
  if sudo grep -qE "RETURNED|THREW|UNHANDLED|UNCAUGHT" /tmp/rl_apply.log 2>/dev/null; then break; fi
done
echo "   /tmp/rl_apply.log:"
sudo tail -25 /tmp/rl_apply.log 2>/dev/null | sed 's/^/     /' || echo "     (empty — it never even loaded the module)"
