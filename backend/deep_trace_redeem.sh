#!/usr/bin/env bash
#
# deep_trace_redeem.sh — full end-to-end trace of the second-device path. READ ONLY.
# Nothing is assumed: every layer is dumped or exercised with real data.
#
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) DID THE PACKAGE SAVE? every hotspot package with its device limit"
q -c "SELECT id, name, price, duration_hours, simultaneous_sessions, updated_at
      FROM hotspot_packages ORDER BY duration_hours;"

say "2) Vouchers, their package, and the limit that applies to each"
q -c "SELECT hv.code, hv.status, hv.is_tv, hv.used_by_mac, hv.expires_at,
             hp.name AS package, COALESCE(hp.simultaneous_sessions,1) AS allowed,
             (SELECT count(*) FROM hotspot_voucher_devices d WHERE d.voucher_id = hv.id) AS registered
      FROM hotspot_vouchers hv LEFT JOIN hotspot_packages hp ON hp.id = hv.package_id
      ORDER BY hv.created_at DESC LIMIT 8;"

say "3) The devices table"
q -c "SELECT v.code, d.mac, d.first_seen, d.last_seen
      FROM hotspot_voucher_devices d JOIN hotspot_vouchers v ON v.id = d.voucher_id
      ORDER BY d.first_seen DESC LIMIT 12;"

say "4) THE ENTIRE /redeem ROUTE — every line"
L=$(grep -n "router.post('/:ispId/redeem'" "$BE/routes/captive.js" | head -1 | cut -d: -f1)
if [ -z "$L" ]; then echo "   ${R}route not found${N}"; else
  END=$(awk -v s="$L" 'NR>s && /^\}\);$/ {print NR; exit}' "$BE/routes/captive.js")
  echo "   lines $L..${END:-?}"
  sudo sed -n "${L},${END:-$((L+140))}p" "$BE/routes/captive.js" | nl -ba -v"$L" | sed 's/^/   /'
fi

say "5) Every early return / rejection inside that route"
[ -n "$L" ] && sudo sed -n "${L},${END:-$((L+140))}p" "$BE/routes/captive.js" \
  | grep -nE "res\.status|return res|throw" | sed 's/^/     /'

say "6) LIVE TEST — walk a voucher through, one MAC at a time"
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
ROW=$(q -tAc "SELECT hv.code || '|' || COALESCE(hp.simultaneous_sessions,1)
              FROM hotspot_vouchers hv LEFT JOIN hotspot_packages hp ON hp.id=hv.package_id
              WHERE hv.status='active' AND (hv.is_tv IS NOT TRUE) ORDER BY hv.created_at DESC LIMIT 1;")
CODE=${ROW%%|*}; ALLOWED=${ROW##*|}
echo "   isp=$ISP  code=$CODE  allowed=$ALLOWED"
echo "   devices registered before the test:"
q -c "SELECT d.mac FROM hotspot_voucher_devices d JOIN hotspot_vouchers v ON v.id=d.voucher_id WHERE v.code='$CODE';"
for M in DE:AD:BE:EF:00:01 DE:AD:BE:EF:00:02 DE:AD:BE:EF:00:03; do
  echo "   --- POST /redeem  mac=$M ---"
  curl -s -i -X POST "http://127.0.0.1:5000/api/captive/$ISP/redeem" \
    -H 'Content-Type: application/json' -d "{\"code\":\"$CODE\",\"mac\":\"$M\"}" \
    | sed -n '1p;/^{/p' | sed 's/^/     /'
done
echo "   devices registered after:"
q -c "SELECT d.mac FROM hotspot_voucher_devices d JOIN hotspot_vouchers v ON v.id=d.voucher_id WHERE v.code='$CODE';"
echo "   cleaning up the synthetic MACs:"
q -c "DELETE FROM hotspot_voucher_devices WHERE mac LIKE 'DE:AD:BE:EF:%';"
q -c "DELETE FROM radcheck WHERE username LIKE 'DE:AD:BE:EF:%';"
q -c "DELETE FROM radreply WHERE username LIKE 'DE:AD:BE:EF:%';"

say "7) What the backend logged during those calls"
pm2 logs rumalink-backend --lines 120 --nostream 2>/dev/null \
  | grep -iE "redeem|voucher|device limit|already" | tail -20 | sed 's/^/   /'

say "8) THE PORTAL SIDE — is there a code-entry UI, and what does it call?"
echo "   --- elements that look like a code input ---"
grep -noE '<input[^>]{0,140}' "$CP/classic.html" | grep -iE "code|voucher|redeem" | sed 's/^/     /'
echo "   --- the function that posts to /redeem ---"
LR=$(grep -n "/redeem" "$CP/classic.html" | head -1 | cut -d: -f1)
[ -n "$LR" ] && sudo sed -n "$((LR-30)),$((LR+35))p" "$CP/classic.html" | nl -ba -v"$((LR-30))" | sed 's/^/     /'
echo "   --- is that UI ever shown? (display/hidden toggles) ---"
grep -noE "redeem[A-Za-z]*\(|showRedeem|id=\"[a-z-]*redeem[a-z-]*\"" "$CP/classic.html" | head -10 | sed 's/^/     /'

say "9) getMac() — what does the portal actually send?"
LM=$(grep -n "async function getMac\|function getMac" "$CP/classic.html" | head -1 | cut -d: -f1)
[ -n "$LM" ] && sudo sed -n "${LM},$((LM+25))p" "$CP/classic.html" | nl -ba -v"$LM" | sed 's/^/   /'

say "10) RADIUS view of the voucher"
q -c "SELECT username, attribute, op, value FROM radcheck WHERE username LIKE '$CODE@%' ORDER BY attribute;"
q -c "SELECT username, attribute, value FROM radreply WHERE username LIKE '$CODE@%' ORDER BY attribute;"
q -c "SELECT username, callingstationid, acctstarttime, acctstoptime FROM radacct
      WHERE username LIKE '$CODE@%' ORDER BY acctstarttime DESC LIMIT 6;"
q -c "SELECT username, reply, authdate FROM radpostauth ORDER BY authdate DESC LIMIT 8;"

say "11) Router: who is connected right now"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const r=await query('SELECT name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL');
 for(const d of r.rows){
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  const get=async p=>{try{return (await axios.get(b+p,{auth,timeout:20000})).data||[]}catch(e){return []}};
  const act=await get('/ip/hotspot/active');
  console.log('   hotspot active: '+act.length);
  act.forEach(x=>console.log('     user='+x.user+' mac='+x['mac-address']+' ip='+x.address));
  const hosts=await get('/ip/hotspot/host');
  console.log('   hotspot hosts (seen devices): '+hosts.length);
  hosts.slice(0,8).forEach(x=>console.log('     mac='+x['mac-address']+' ip='+(x.address||'')+' authorized='+(x.authorized||'false')));
 }
 process.exit(0);
})();"
