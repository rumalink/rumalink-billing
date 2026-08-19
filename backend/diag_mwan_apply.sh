#!/usr/bin/env bash
#
# diag_mwan_apply.sh — why "Apply to Router" never returns.
#
# The browser reports "Failed to fetch" and the backend logs nothing at all, which means the
# request either hung until the browser gave up or the process died before the handler's catch
# could run. Both look identical from the dashboard.
#
# So call applyPlan DIRECTLY in node, with the real device and ISP ids. No browser, no nginx, no
# PM2 — if it throws we see the stack, if it hangs we see where it stopped, and if it succeeds
# then the fault is in the transport rather than the logic.
#
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The backend really is under root — that is why pm2 looked empty"
sudo pm2 describe rumalink-backend 2>/dev/null | grep -E "status|uptime|restarts|script path" | sed 's/^/   /'
echo "   recent errors:"
sudo pm2 logs rumalink-backend --lines 40 --nostream --err 2>/dev/null | tail -12 | cut -c1-160 | sed 's/^/     /'

say "2) What the plan is being asked to apply"
q -c "SELECT id, name, multi_wan_mode, multi_wan_check_interval, multi_wan_fail_threshold, wan_quality_enabled, multi_wan_applied_at FROM nas_devices;"
q -c "SELECT position, name, interface, role, enabled, gateway, resolved_gateway, ping_target, in_pool, lb_weight FROM nas_wan_links ORDER BY position;"

say "3) Run applyPlan directly, with a stopwatch and full errors"
IDS=$(q -tAc "SELECT n.id || ' ' || n.isp_id FROM nas_devices n WHERE n.wireguard_ip IS NOT NULL LIMIT 1;")
NAS=$(echo "$IDS" | cut -d' ' -f1); ISP=$(echo "$IDS" | cut -d' ' -f2)
echo "   device=$NAS"
echo "   isp=$ISP"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
process.on('unhandledRejection', function(e){ console.log('   UNHANDLED REJECTION: ' + (e && e.stack ? e.stack.split('\n').slice(0,4).join(' | ') : e)); });
const t0 = Date.now();
const tick = setInterval(function(){ console.log('   ... still running after ' + Math.round((Date.now()-t0)/1000) + 's'); }, 10000);
(async()=>{
  try {
    const applier = require('$BE/utils/mwan-applier');
    console.log('   calling applyPlan...');
    const r = await applier.applyPlan('$NAS', '$ISP');
    clearInterval(tick);
    console.log('   RETURNED after ' + Math.round((Date.now()-t0)/1000) + 's');
    console.log('   ' + JSON.stringify(r).slice(0, 900));
  } catch (e) {
    clearInterval(tick);
    console.log('   THREW after ' + Math.round((Date.now()-t0)/1000) + 's');
    console.log('   ' + (e && e.stack ? e.stack.split('\n').slice(0,6).join('\n   ') : e));
  }
  process.exit(0);
})();
" 2>&1 | grep -vE "^info: \[" | head -60

say "4) Did it leave the router configured, or half-configured?"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
const g=async p=>{try{return (await axios.get(b+p,{auth,timeout:15000})).data||[]}catch(e){return []}};
const rt=await g('/ip/route');
console.log('   default routes:');
rt.filter(x=>String(x['dst-address'])==='0.0.0.0/0').forEach(x=>console.log('     gw='+x.gateway+' dist='+x.distance+' table='+(x['routing-table']||'main')+' active='+(x.active||'false')+' # '+(x.comment||'')));
console.log('   RL-OOKLA probe routes (created per pass, should be few):');
console.log('     count: ' + rt.filter(x=>/RL-OOKLA/.test(String(x.comment||''))).length);
const mg=await g('/ip/firewall/mangle');
console.log('   mangle marking rules: ' + mg.filter(x=>/RL-MWAN/.test(String(x.comment||''))).length);
const tbl=await g('/routing/table');
console.log('   routing tables: ' + (tbl||[]).map(x=>x.name).join(', '));
process.exit(0)})();" 2>&1 | grep -v "^info:"

say "5) Is the monitor loop also running applyPlan?"
grep -n "applyPlan\|monitorAll\|setInterval" "$BE/utils/mwan-applier.js" | tail -12 | sed 's/^/   /'

say "6) Read"
cat <<'EOS'
   Section 3 is the answer: it either RETURNED (so the logic is fine and the browser/transport is
   the problem), THREW with a stack, or kept printing "still running" — which means it hangs on a
   router call and the browser simply gave up first.
EOS
