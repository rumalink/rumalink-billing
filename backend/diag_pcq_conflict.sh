#!/usr/bin/env bash
# READ ONLY — provisioning sets PCQ queue types while router-harden records RL_PCQ_DROPPED.
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) What does RL_PCQ_DROPPED say in router-harden?"
L=$(sudo grep -n "RL_PCQ_DROPPED" "$BE/utils/router-harden.js" | head -1 | cut -d: -f1)
echo "   at line $L"
[ -n "$L" ] && sudo sed -n "$((L-8)),$((L+25))p" "$BE/utils/router-harden.js" | nl -ba -v"$((L-8))" | sed 's/^/   /'

say "2) All PCQ / queue-type references in the backend"
grep -rn "pcq\|queue-type\|queue_type" "$BE/routes" "$BE/utils" --include=*.js 2>/dev/null \
  | grep -v -E 'node_modules|\.bak' | sed 's/^/   /'

say "3) The provisioning lines in question"
TOKEN=$(q -tAc "SELECT provision_token FROM nas_devices WHERE provision_token IS NOT NULL ORDER BY created_at DESC LIMIT 1;")
curl -s "http://127.0.0.1:5000/api/provision/$TOKEN/script" > /tmp/prov.txt 2>/dev/null || true
sudo sed -n '78,86p' /tmp/prov.txt | nl -ba -v78 | sed 's/^/   /'
echo "   the single queue/simple line:"
grep -n "queue/simple\|queue simple" /tmp/prov.txt | sed 's/^/     /'

say "4) What is ACTUALLY on the router right now?"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const r=await query('SELECT name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL');
 for(const d of r.rows){
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  const get=async p=>{try{return (await axios.get(b+p,{auth,timeout:20000})).data||[]}catch(e){return {__e:e.message}}};
  console.log('   --- '+d.name+' ---');
  const qt=await get('/queue/type');
  console.log('   queue types (pcq only):');
  (qt.filter?qt.filter(x=>/pcq/i.test(x.name||'')):[]).forEach(x=>console.log('     '+x.name+' kind='+x.kind+' rate='+(x['pcq-rate']||'0')));
  const up=await get('/ip/hotspot/user/profile');
  console.log('   hotspot user profiles:');
  (up.forEach?up:[]).forEach(x=>console.log('     '+x.name+' queue-type='+(x['queue-type']||'(none)')+' rate-limit='+(x['rate-limit']||'(none)')));
  const sq=await get('/queue/simple');
  console.log('   simple queues: '+(sq.length!==undefined?sq.length:'?'));
  (sq.slice?sq.slice(0,8):[]).forEach(x=>console.log('     '+x.name+' max-limit='+x['max-limit']+' target='+x.target+' rate='+x.rate));
  const dq=await get('/queue/simple?dynamic=true');
  console.log('   (dynamic queues appear in the list above with dynamic=true)');
  (sq.filter?sq.filter(x=>String(x.dynamic)==='true'):[]).forEach(x=>console.log('     DYNAMIC '+x.name+' '+x['max-limit']));
  process.exitCode=0;
 }
 process.exit(0);
})();"

say "5) Do PCQ and the per-voucher queues conflict in practice?"
echo "   A pcq queue-type on the hotspot user profile makes RouterOS create a DYNAMIC queue per"
echo "   logged-in user. Your rate limits come from RADIUS (Mikrotik-Rate-Limit) plus the static"
echo "   rl-<code> simple queues the backend creates. Two shapers on one flow either fight or"
echo "   double-count. pcq-rate=0 means 'unlimited per sub-stream', so it is probably harmless"
echo "   today — but it is unmanaged, and queue-monitor does not watch dynamic queues."
echo
echo "   ${Y}Deciding question: are there DYNAMIC queues on the router above?${N}"

say "6) git state"
sudo git -C /var/www/rumalink log --oneline | head -3 | sed 's/^/   /'
