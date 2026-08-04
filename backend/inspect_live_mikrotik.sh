#!/usr/bin/env bash
#
# inspect_live_mikrotik.sh — READ ONLY. Compares what the dashboard shows against what the
# router actually runs. Changes nothing: the platform is live with paying customers.
#
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) What the DASHBOARD believes (nas_devices columns)"
q -c "SELECT name, wan_interface, hotspot_interface, bridge_ports, gateway_ip,
             dhcp_pool_start, dhcp_pool_end, dns_servers, pppoe_pool, hotspot_profile,
             antishare_enabled, hotspot_network
      FROM nas_devices;"

say "2) Where those defaults come from in the code"
grep -rnE "192\.168\.88" "$BE/routes" "$BE/utils" --include=*.js 2>/dev/null | grep -v -E 'node_modules|\.bak' | sed 's/^/   /'
echo "   --- the provisioning defaults ---"
grep -nE "gateway_ip|dhcp_pool|hotspot_network|bridge_ports|wan_interface" "$BE/routes/provision.js" | head -20 | sed 's/^/   /'

say "3) What the LIVE ROUTER actually runs"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const r=await query('SELECT id,name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL');
 for(const d of r.rows){
  const b='http://'+d.wireguard_ip+'/rest';
  const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  const get=async p=>{try{return (await axios.get(b+p,{auth,timeout:20000})).data||[]}catch(e){return {__e:e.message}}};
  console.log('   ================ '+d.name+' ('+d.wireguard_ip+') ================');

  const res=await get('/system/resource');
  console.log('   RouterOS '+(res.version||'?')+'  board '+(res['board-name']||'?')+'  uptime '+(res.uptime||'?'));

  console.log('   --- IP addresses ---');
  (await get('/ip/address')).forEach&&(await get('/ip/address')).forEach(x=>
    console.log('     '+x.address+'  iface='+x.interface+'  disabled='+x.disabled));

  console.log('   --- bridges and their ports ---');
  const br=await get('/interface/bridge');
  (br.forEach?br:[]).forEach(x=>console.log('     bridge '+x.name));
  const bp=await get('/interface/bridge/port');
  (bp.forEach?bp:[]).forEach(x=>console.log('     port '+x.interface+' -> '+x.bridge));

  console.log('   --- DHCP servers and pools ---');
  (await get('/ip/dhcp-server')).forEach&&(await get('/ip/dhcp-server')).forEach(x=>
    console.log('     '+x.name+' iface='+x.interface+' pool='+x['address-pool']+' disabled='+x.disabled));
  (await get('/ip/pool')).forEach&&(await get('/ip/pool')).forEach(x=>
    console.log('     pool '+x.name+' = '+x.ranges));
  (await get('/ip/dhcp-server/network')).forEach&&(await get('/ip/dhcp-server/network')).forEach(x=>
    console.log('     network '+x.address+' gw='+x.gateway+' dns='+(x['dns-server']||'')));

  console.log('   --- hotspot ---');
  (await get('/ip/hotspot')).forEach&&(await get('/ip/hotspot')).forEach(x=>
    console.log('     server '+x.name+' iface='+x.interface+' profile='+x.profile+' pool='+(x['address-pool']||'')));
  (await get('/ip/hotspot/profile')).forEach&&(await get('/ip/hotspot/profile')).forEach(x=>
    console.log('     profile '+x.name+' login-by='+(x['login-by']||'')+' radius='+(x['use-radius']||'')));

  console.log('   --- PPPoE ---');
  (await get('/interface/pppoe-server/server')).forEach&&(await get('/interface/pppoe-server/server')).forEach(x=>
    console.log('     pppoe-server iface='+x.interface+' profile='+(x['default-profile']||'')+' disabled='+x.disabled));
  (await get('/ppp/profile')).forEach&&(await get('/ppp/profile')).forEach(x=>
    console.log('     ppp-profile '+x.name+' local='+(x['local-address']||'')+' remote='+(x['remote-address']||'')));

  console.log('   --- interfaces ---');
  (await get('/interface')).forEach&&(await get('/interface')).forEach(x=>
    console.log('     '+x.name+'  type='+x.type+' running='+x.running+' disabled='+x.disabled));

  console.log('   --- DNS ---');
  const dns=await get('/ip/dns');
  console.log('     servers='+(dns.servers||'?')+'  allow-remote='+(dns['allow-remote-requests']||'?'));
 }
 process.exit(0);
})();"

say "4) The mismatch, side by side"
echo "   Dashboard gateway_ip vs the router's real hotspot address:"
q -c "SELECT name, gateway_ip AS dashboard_says, hotspot_network FROM nas_devices;"
echo "   ${Y}Compare with the /ip/address and dhcp-server/network output above.${N}"
echo "   Live hotspot clients are on:"
q -c "SELECT DISTINCT split_part(framedipaddress::text,'.',1)||'.'||split_part(framedipaddress::text,'.',2)||'.'||split_part(framedipaddress::text,'.',3)||'.0/24' AS subnet
      FROM radacct WHERE acctstoptime IS NULL AND framedipaddress IS NOT NULL;"

say "5) Nothing was changed"
echo "   This script is read-only. Once you confirm the real values, the next step can either"
echo "   (a) sync nas_devices FROM the router so the dashboard tells the truth, or"
echo "   (b) keep the DB authoritative and re-apply it to the router."
echo "   ${Y}With paying customers online, (a) is the safe direction — it changes no router state.${N}"
