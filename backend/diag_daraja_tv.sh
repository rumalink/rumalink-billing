#!/usr/bin/env bash
# READ ONLY — a Daraja TV purchase also connects the buyer's phone; IntaSend does not.
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) INTASEND's TV branch — the behaviour that works"
sudo grep -n "is_tv\|tv_mac\|addIpBindingBypass\|bound_devices" "$BE/utils/intasend-activate.js" | sed 's/^/   /'
L=$(sudo grep -n "meta.is_tv" "$BE/utils/intasend-activate.js" | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "$((L-6)),$((L+30))p" "$BE/utils/intasend-activate.js" | nl -ba -v"$((L-6))" | sed 's/^/   /'

say "2) DARAJA callback — does it have ANY TV handling?"
S=$(sudo grep -n "router.post('/:ispId/callback/:paymentId'" "$BE/routes/captive.js" | cut -d: -f1)
E=$((S+220))
echo "   callback spans lines $S..$E"
sudo sed -n "${S},${E}p" "$BE/routes/captive.js" | grep -nE "is_tv|tv_mac|bound_devices|IpBinding|registerMACAuth|used_by_mac|QUEUE-APPLY|hotspotActiveLogin|addHotspotUser" | sed 's/^/     /'
echo "   ${Y}if is_tv / tv_mac do not appear above, the Daraja path treats a TV sale as an ordinary one${N}"

say "3) Does the Daraja callback register MAC auth for the BUYER'S phone?"
sudo sed -n "${S},${E}p" "$BE/routes/captive.js" | grep -nE "registerMACAuth|CallingStation|targetMac|mac" | head -20 | sed 's/^/     /'

say "4) The portal: does it skip autologin when buying for a TV?"
grep -nE "rlCurrentTv|_tv|is_tv" "$CP/classic.html" | grep -iE "login|autologin|rlHotspotLogin|poll" | head -12 | sed 's/^/   /'
echo "   --- the autologin decision after payment ---"
LP=$(grep -n "RL_AUTOLOGIN_BRIDGE" "$CP/classic.html" | head -1 | cut -d: -f1)
[ -n "$LP" ] && sudo sed -n "$((LP-8)),$((LP+18))p" "$CP/classic.html" | nl -ba -v"$((LP-8))" | sed 's/^/     /'

say "5) State from the last TV purchases (which MACs got access?)"
q -c "SELECT code, is_tv, tv_mac, used_by_mac, purchased_by_mac, status, expires_at
      FROM hotspot_vouchers ORDER BY created_at DESC LIMIT 6;"
echo "   RADIUS entries (a phone MAC here means the phone was granted access):"
q -c "SELECT username, attribute FROM radcheck ORDER BY id DESC LIMIT 10;"
q -c "SELECT username, attribute, value FROM radreply ORDER BY id DESC LIMIT 10;"
q -c "SELECT name, mac_address, is_bound, bound_ip, active_voucher_id IS NOT NULL AS linked FROM hotspot_bound_devices;"

say "6) Who is actually online on the router right now?"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const r=await query('SELECT name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL');
 for(const d of r.rows){
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  const get=async p=>{try{return (await axios.get(b+p,{auth,timeout:20000})).data||[]}catch(e){return []}};
  console.log('   --- '+d.name+' ---');
  const act=await get('/ip/hotspot/active');
  console.log('   hotspot active sessions: '+act.length);
  act.forEach(x=>console.log('     user='+x.user+' mac='+x['mac-address']+' ip='+x.address));
  const bind=await get('/ip/hotspot/ip-binding');
  console.log('   ip-bindings:');
  bind.forEach(x=>console.log('     '+x['mac-address']+' type='+x.type+' comment='+(x.comment||'')));
  const qs=await get('/queue/simple');
  console.log('   simple queues:');
  qs.forEach(x=>console.log('     '+x.name+' '+x['max-limit']+' target='+x.target));
 }
 process.exit(0);
})();"

say "7) Recent Daraja TV purchase in the logs"
pm2 logs rumalink-backend --lines 800 --nostream 2>/dev/null \
  | grep -iE "CB-START|CB-VOUCHER|CB-QUEUE|tv|bound|registerMAC|purchase-sms" | tail -20 | sed 's/^/   /'
