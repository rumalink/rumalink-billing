#!/usr/bin/env bash
# READ ONLY — why a manually created account connects but gets no traffic.
# Compares it attribute by attribute with a voucher that was actually paid for.
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) A manual account and a paid one, side by side"
q -c "SELECT code, status, created_by_isp, payment_id IS NOT NULL AS paid, package_id IS NOT NULL AS has_package,
             (password IS NOT NULL) AS has_pw, used_by_mac, expires_at
      FROM hotspot_vouchers
      WHERE status='active' AND (is_tv IS NOT TRUE)
      ORDER BY created_by_isp DESC, created_at DESC LIMIT 8;"

say "2) Their RADIUS entries — the reply attributes decide what the router grants"
echo "   MANUAL (created_by_isp):"
q -c "SELECT rc.username, rc.attribute, rc.value FROM radcheck rc
      WHERE rc.username IN (SELECT code || '@' || lower(left(replace(isp_id::text,'-',''),8))
                            FROM hotspot_vouchers WHERE created_by_isp = true AND status='active')
      ORDER BY rc.username, rc.attribute LIMIT 12;"
q -c "SELECT rr.username, rr.attribute, rr.value FROM radreply rr
      WHERE rr.username IN (SELECT code || '@' || lower(left(replace(isp_id::text,'-',''),8))
                            FROM hotspot_vouchers WHERE created_by_isp = true AND status='active')
      ORDER BY rr.username, rr.attribute LIMIT 12;"
echo "   PAID:"
q -c "SELECT rr.username, rr.attribute, rr.value FROM radreply rr
      WHERE rr.username IN (SELECT code || '@' || lower(left(replace(isp_id::text,'-',''),8))
                            FROM hotspot_vouchers WHERE payment_id IS NOT NULL AND status='active')
      ORDER BY rr.username, rr.attribute LIMIT 12;"
echo "   ${Y}a paid voucher carries Mikrotik-Rate-Limit and Session-Timeout; missing or 0M/0M means no throughput${N}"

say "3) Does the manual voucher even have a package?"
q -c "SELECT v.code, v.created_by_isp, hp.name AS package, hp.bandwidth_up_mbps AS up, hp.bandwidth_down_mbps AS down,
             hp.duration_hours
      FROM hotspot_vouchers v LEFT JOIN hotspot_packages hp ON hp.id = v.package_id
      WHERE v.status='active' ORDER BY v.created_by_isp DESC, v.created_at DESC LIMIT 8;"
echo "   ${Y}no package -> no rate limit written -> the router may shape it to nothing${N}"

say "4) What the router is doing with those sessions"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL LIMIT 1')).rows[0];
 const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
 const get=async p=>{try{return (await axios.get(b+p,{auth,timeout:15000})).data||[]}catch(e){return []}};
 const manual=(await query(\"SELECT code FROM hotspot_vouchers WHERE created_by_isp=true AND status='active'\")).rows.map(r=>r.code);
 const act=await get('/ip/hotspot/active');
 console.log('   active sessions matching a manual code:');
 act.filter(x=>manual.some(c=>String(x.user||'').startsWith(c))).forEach(x=>
   console.log('     user='+x.user+' mac='+x['mac-address']+' ip='+x.address+' uptime='+x.uptime+' bytes-in='+(x['bytes-in']||0)+' bytes-out='+(x['bytes-out']||0)));
 const qs=await get('/queue/simple');
 console.log('   queues for those sessions:');
 qs.filter(x=>manual.some(c=>String(x.name||'').includes(c))).forEach(x=>
   console.log('     '+x.name+' max-limit='+x['max-limit']+' target='+x.target+' disabled='+x.disabled));
 const al=await get('/ip/firewall/address-list');
 console.log('   rl-expired entries (a listed IP is walled off):');
 al.filter(x=>String(x.list)==='rl-expired').slice(0,10).forEach(x=>console.log('     '+x.address+' '+(x.comment||'')));
 process.exit(0);
})();" 2>&1 | grep -v "^info:"

say "5) Did those sessions authenticate, and are they accounted?"
q -c "SELECT username, reply, authdate FROM radpostauth
      WHERE username IN (SELECT code || '@' || lower(left(replace(isp_id::text,'-',''),8))
                         FROM hotspot_vouchers WHERE created_by_isp = true)
      ORDER BY authdate DESC LIMIT 8;"
q -c "SELECT username, callingstationid, framedipaddress, acctstarttime, acctstoptime,
             acctinputoctets + acctoutputoctets AS bytes
      FROM radacct
      WHERE username IN (SELECT code || '@' || lower(left(replace(isp_id::text,'-',''),8))
                         FROM hotspot_vouchers WHERE created_by_isp = true)
      ORDER BY acctstarttime DESC LIMIT 6;"
echo "   ${Y}bytes near zero on an open session means it authenticated but no traffic passed${N}"

say "6) How a manual voucher is created, versus a purchase"
grep -n "manual-voucher\|test-voucher" "$BE/routes/isp.js" | head -6 | sed 's/^/   /'
L=$(grep -n "manual-voucher" "$BE/routes/isp.js" | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "${L},$((L+45))p" "$BE/routes/isp.js" | nl -ba -v"$L" | sed 's/^/   /'
