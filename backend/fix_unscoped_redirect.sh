#!/usr/bin/env bash
#
# fix_unscoped_redirect.sh — a TV with working traffic reports "no internet".
#
# FOUND: dstnat rule "RumaLink-wg-pppoe-redirect" redirects dst-port=80 to the portal with NO
# src-address restriction. Its sibling "RL-PPPOE-CAPTIVE redirect" is correctly scoped to
# 100.64.0.0/24 (the PPPoE pool); this one applies to everything, including the hotspot subnet.
#
# A bypassed TV is not intercepted by the hotspot, so its HTTP connectivity probe falls through to
# this rule, receives the portal instead of the 204 it expects, and declares the connection dead —
# while the queue counters show real traffic passing. That is the exact contradiction reported.
#
# This is the same legacy duplication already found in the filter chain: RL-PPPOE-* is current,
# RumaLink-wg-pppoe-* is an older copy that was never removed.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) The rule in full, before anything changes"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
const nat=(await axios.get(b+'/ip/firewall/nat',{auth,timeout:15000})).data||[];
nat.filter(x=>/redirect/i.test(x.comment||'')).forEach(x=>console.log('   '+JSON.stringify(x)));
process.exit(0)})();" 2>&1 | grep -v "^info:"

say "2) Scope it to the PPPoE pool, matching its working sibling"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const rows=(await query('SELECT name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL')).rows;
 for (const d of rows) {
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  try{
   const nat=(await axios.get(b+'/ip/firewall/nat',{auth,timeout:20000})).data||[];
   for (const r of nat) {
     const c=String(r.comment||'');
     if (r.chain!=='dstnat') continue;
     if (!/wg-pppoe-redirect/i.test(c)) continue;
     if (r['src-address']) { console.log('   '+d.name+': already scoped to '+r['src-address']); continue; }
     /* Disable rather than delete: it has never matched (pkts=0), and a disabled rule can be put
        back in seconds if some path did depend on it. */
     await axios.patch(b+'/ip/firewall/nat/'+encodeURIComponent(r['.id']),
       { disabled:'true', comment: c+' [RL: disabled - unscoped port-80 redirect caught bypassed TVs]' },
       {auth,timeout:20000});
     console.log('   '+d.name+': disabled unscoped redirect (was catching every subnet)');
   }
  }catch(e){console.log('   '+d.name+': '+e.message)}
 }
 process.exit(0);
})();" 2>&1 | grep -v "^info:"

say "3) Confirm the PPPoE portal redirect still works"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
const nat=(await axios.get(b+'/ip/firewall/nat',{auth,timeout:15000})).data||[];
console.log('   dstnat rules now:');
nat.filter(x=>x.chain==='dstnat').forEach(x=>console.log('     '+x.action+' src='+(x['src-address']||'ANY')+' port='+(x['dst-port']||'-')+' to='+(x['to-addresses']||'-')+' disabled='+(x.disabled||'false')+' pkts='+(x.packets||0)+' # '+(x.comment||'')));
process.exit(0)})();" 2>&1 | grep -v "^info:"
echo "   ${Y}RL-PPPOE-CAPTIVE must remain enabled and scoped to 100.64.0.0/24${N}"

say "4) Stop provisioning from recreating it"
sudo cp "$BE/routes/provision.js" "$BE/routes/.provision.js.bak_$TS"
sudo grep -n "wg-pppoe-redirect" "$BE/routes/provision.js" "$BE/utils/"*.js 2>/dev/null | grep -v bak | sed 's/^/   /' || echo "   not created by provisioning — it predates the current template"

say "5) Now test the TV"
cat <<'EOS'
   Ask the TV to reconnect (or toggle its WiFi). Its connectivity probe should now reach the
   internet instead of the portal, and it should report a working connection.

   Watch its traffic while you do:
     the rl-tv-BC09B9AB1E4B queue counters should keep climbing
EOS

say "6) Undo, if anything depended on that rule"
cat <<EOS
   The rule was disabled, not deleted. To restore it:
     find it in /ip/firewall/nat with comment containing wg-pppoe-redirect and set disabled=no
EOS
