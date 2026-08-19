#!/usr/bin/env bash
#
# research_wan_flapping.sh — READ ONLY. Why customers get internet, then lose it, while both
# uplinks are healthy. Two days of it, so something is changing state repeatedly.
#
# Nothing is modified. Every section either reads the router or reads what we have recorded.
#
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }
NODE(){ sudo -u www-data node -e "$1" 2>&1 | grep -v "^info:"; }

say "1) The real addressing — what the gateways actually are"
NODE "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
const g=async p=>{try{return (await axios.get(b+p,{auth,timeout:15000})).data||[]}catch(e){return []}};
console.log('  addresses:');
(await g('/ip/address')).filter(x=>!/pppoe-/.test(String(x.interface))).forEach(x=>console.log('    '+x.address+'  '+x.interface));
console.log('  pppoe-client uplinks:');
(await g('/interface/pppoe-client')).forEach(x=>console.log('    '+x.name+' running='+x.running+' on '+x.interface));
console.log('  every ACTIVE route:');
(await g('/ip/route')).filter(x=>String(x.active)==='true').forEach(x=>console.log('    dst='+x['dst-address']+' gw='+(x.gateway||'-')+' immediate='+(x['immediate-gw']||'-')+' dist='+x.distance+' mark='+(x['routing-mark']||'-')));
process.exit(0)})();"
echo "   ${Y}compare with the RL-MWAN routes: 172.16.0.1 was listed there and may not exist here${N}"

say "2) Router log — is a route or link flapping?"
NODE "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
const g=async p=>{try{return (await axios.get(b+p,{auth,timeout:15000})).data||[]}catch(e){return []}};
const l=await g('/log');
const rel=l.filter(x=>/route|gateway|pppoe|link|dhcp|interface/i.test(String(x.topics)+String(x.message)));
console.log('  last 25 routing/link events:');
rel.slice(-25).forEach(x=>console.log('    '+x.time+' ['+x.topics+'] '+String(x.message).slice(0,110)));
process.exit(0)})();"

say "3) Our own record of the links"
q -c "SELECT position, name, current_status, is_active, internet_ok, quality_state, quality_parked,
             last_latency_ms, last_loss_pct, consec_fetch_fail, last_checked_at
      FROM nas_wan_links ORDER BY position;"
echo "   quality history, last 14 hours on link 1:"
q -c "SELECT date_trunc('hour', sampled_at) AS hour, count(*) AS samples,
             round(avg(latency_ms)::numeric,1) AS lat, round(avg(fetch_ms)::numeric,0) AS fetch,
             bool_or(internet_ok = false) AS saw_failure, bool_and(is_active) AS always_active
      FROM wan_quality_history
      WHERE sampled_at > now() - interval '48 hours'
        AND link_id = (SELECT id FROM nas_wan_links WHERE position=1)
      GROUP BY 1 ORDER BY 1 DESC LIMIT 14;"

say "4) Has the applier been moving traffic?"
pm2 logs rumalink-backend --lines 3000 --nostream 2>/dev/null \
  | grep -iE "\[mwan|failover|switched|BACKUP|MAIN|applied" | tail -25 | cut -c1-165 | sed 's/^/   /' || echo "   nothing logged"

say "5) NAT — is customer traffic masqueraded on the link that carries it?"
NODE "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
const g=async p=>{try{return (await axios.get(b+p,{auth,timeout:15000})).data||[]}catch(e){return []}};
console.log('  masquerade rules in order:');
(await g('/ip/firewall/nat')).filter(x=>x.action==='masquerade').forEach((x,i)=>
  console.log('    '+i+' out='+(x['out-interface']||x['out-interface-list']||'ANY')+' src='+(x['src-address']||'any')+' bytes='+(x.bytes||0)+' disabled='+(x.disabled||'false')+' # '+(x.comment||'')));
console.log('  interface list membership:');
(await g('/interface/list/member')).forEach(x=>console.log('    list='+x.list+' iface='+x.interface));
process.exit(0)})();"
echo "   ${Y}if the live WAN is not in RL-WAN, the main NAT rule never matches and replies never return${N}"

say "6) Connection tracking and load"
NODE "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
const g=async p=>{try{return (await axios.get(b+p,{auth,timeout:15000})).data||null}catch(e){return null}};
console.log('  conntrack: '+JSON.stringify(await g('/ip/firewall/connection/tracking')).slice(0,320));
const r=await g('/system/resource');
if(r) console.log('  cpu='+r['cpu-load']+'%  free-mem='+Math.round(r['free-memory']/1048576)+'MB  uptime='+r.uptime);
process.exit(0)})();"

say "7) Sessions open but not passing traffic"
q -c "SELECT username, callingstationid, framedipaddress, acctstarttime,
             acctinputoctets + acctoutputoctets AS bytes
      FROM radacct WHERE acctstoptime IS NULL ORDER BY acctstarttime DESC LIMIT 10;"

say "8) Session churn over 48h"
q -c "SELECT date_trunc('hour', acctstarttime) AS hour, count(*) AS started,
             mode() WITHIN GROUP (ORDER BY acctterminatecause) AS common_cause
      FROM radacct WHERE acctstarttime > now() - interval '48 hours'
      GROUP BY 1 ORDER BY 1 DESC LIMIT 12;"
