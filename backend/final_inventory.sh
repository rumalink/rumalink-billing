#!/usr/bin/env bash
#
# final_inventory.sh
#   1. Remove the duplicate RL-FASTTRACK accept rule (harmless but untidy; both are below the
#      expiry rules, so this is cosmetic and safe).
#   2. Verify the PM2 resurrect list properly (as root — dump.pm2 is not world-readable).
#   3. A real inventory of every RL_* marker in the codebase, so "which fixes are present" is
#      answered by the code rather than by memory. The restore looked complete on a remembered
#      checklist while RL_ACCEPT_ORDER was silently missing for a day.
#
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Does router-harden already dedupe by comment?"
sudo grep -n "deduped" "$BE/utils/router-harden.js" | sed 's/^/   /' || echo "   ${Y}no dedupe block${N}"

say "2) Remove the duplicate accept rule (keep the last one)"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const r=await query('SELECT id,name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL');
 for(const d of r.rows){
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  try{
   let f=((await axios.get(b+'/ip/firewall/filter',{auth,timeout:20000})).data||[]).filter(x=>x.chain==='forward');
   const acc=f.filter(x=>x.action==='accept'&&String(x['connection-state']||'')==='established,related'&&!x['src-address-list']&&!x['src-address']);
   console.log('   '+d.name+': '+acc.length+' bare established/related accept rule(s)');
   // keep the LAST (it is below the expiry rules); delete any earlier duplicates
   for(let i=0;i<acc.length-1;i++){
     await axios.delete(b+'/ip/firewall/filter/'+encodeURIComponent(acc[i]['.id']),{auth,timeout:20000});
     console.log('     removed duplicate '+acc[i]['.id']);
   }
   f=((await axios.get(b+'/ip/firewall/filter',{auth,timeout:20000})).data||[]).filter(x=>x.chain==='forward');
   const ai=f.findIndex(x=>x.action==='accept'&&String(x['connection-state']||'')==='established,related'&&!x['src-address-list']);
   const li=f.map((x,i)=>String(x['src-address-list']||'')==='rl-expired'?i:-1).reduce((a,b)=>Math.max(a,b),-1);
   console.log('     final: accept@'+ai+' lastExpired@'+li+' => '+((li===-1||ai>li)?'CORRECT':'WRONG'));
   f.forEach((x,i)=>console.log('       '+i+' '+x.action+(x['src-address-list']?' srclist='+x['src-address-list']:'')+'  # '+(x.comment||'')));
  }catch(e){console.log('   '+d.name+': '+e.message)}
 }
 process.exit(0);
})();"

say "3) PM2 resurrect list (read as root this time)"
sudo grep -oE '"name":"[^"]+"' /root/.pm2/dump.pm2 2>/dev/null | sort -u | sed 's/^/   /' || echo "   could not read dump"
systemctl is-enabled pm2-root.service 2>/dev/null | sed 's/^/   pm2-root.service: /'

say "4) MARKER INVENTORY — what is actually in the code"
printf "   %-28s %-34s %s\n" MARKER FILE STATUS
check(){ # marker file label
  if sudo grep -q "$1" "$BE/$2" 2>/dev/null; then
    printf "   %-28s %-34s ${G}PRESENT${N}\n" "$1" "$2"
  else
    printf "   %-28s %-34s ${Y}MISSING${N}\n" "$1" "$2"
  fi
}
check RL_REUSE_BY_DEVICE          routes/captive.js
check RL_PURCHASED_BY_MAC         routes/captive.js
check RL_PREFIX_PRESERVE          routes/captive.js
check RL_UPGRADE_RETRY            routes/captive.js
check RL_STORE_CLIENT_MAC         routes/captive.js
check RL_SMS_REQUIRE_PATH         routes/captive.js
check RL_INTASEND_INLINE_ACTIVATE routes/captive.js
check RL_DARAJA_ACTIVATE_STAMP    routes/captive.js
check RL_ROUTE_REFUSAL            routes/captive.js
check RL_REUSE_BY_DEVICE          utils/strand-heal.js
check RL_PREFIX_FROM_ISP          utils/strand-heal.js
check RL_TOPUP_EXPIRY             utils/strand-heal.js
check RL_ALREADY_FULFILLED        utils/strand-heal.js
check RL_SKIP_ACTIVATED           utils/strand-heal.js
check RL_PURCHASED_BY_MAC         utils/strand-heal.js
check RL_NO_FASTTRACK             utils/router-harden.js
check RL_ACCEPT_ORDER             utils/router-harden.js
check RL_NOFT_OBSOLETE            utils/router-harden.js
check RL_WALL_REJECT              utils/router-harden.js
check RL_NO_FASTTRACK             routes/provision.js
check RL_ACCEPT_LAST              routes/provision.js
check RL_SECRET_CONVERGE          routes/provision.js
check RL_IMPORT_PREFIX            routes/isp.js
check RL_DEFAULT_GATEWAY          utils/sms.js
check RL_SMS_PICK_REAL            utils/hotspotSms.js
check RL_TV_SMS                   utils/hotspotSms.js
check RL_INTASEND_PURCHASE_SMS    utils/intasend-activate.js
check RL_ACTIVATE_GUARD           utils/intasend-activate.js
check RL_NO_SUBSTITUTION          utils/paymentRoute.js
check RL_DARAJA_CREDS             utils/paymentRoute.js
check RL_BENEFICIARY_NAME_APPLIED routes/withdrawals.js
echo "   modules:"
for m in fasttrack-guard queue-monitor expired-enforcer health-monitor paymentRoute; do
  [ -f "$BE/utils/$m.js" ] && printf "   %-28s %-34s ${G}PRESENT${N}\n" "$m.js" "utils/" \
                           || printf "   %-28s %-34s ${Y}MISSING${N}\n" "$m.js" "utils/"
done
[ -f "$BE/routes/health.js" ] && echo "   ${G}PRESENT${N} routes/health.js" || echo "   ${Y}MISSING${N} routes/health.js"

say "5) Save the inventory so a future restore can be checked against it"
sudo grep -rhoE "RL_[A-Z0-9_]+" "$BE/routes" "$BE/utils" --include=*.js 2>/dev/null \
  | grep -v -E '\.bak' | sort -u > /tmp/rl_markers.txt
sudo cp /tmp/rl_markers.txt /var/www/rumalink/RL_MARKERS.txt
echo "   $(wc -l < /tmp/rl_markers.txt) distinct markers -> /var/www/rumalink/RL_MARKERS.txt"
echo "   after any future restore:  sudo grep -rhoE 'RL_[A-Z0-9_]+' /var/www/rumalink/backend/{routes,utils}/*.js | sort -u | diff - /var/www/rumalink/RL_MARKERS.txt"

say "6) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Dedupe accept rule; record RL marker inventory" 2>&1 | head -2 | sed 's/^/   /'
sudo git -C /var/www/rumalink log --oneline | head -3 | sed 's/^/   /'
