#!/usr/bin/env bash
#
# fix_pcq_deadline.sh — remove the hotspot PCQ line that can never succeed.
#
# RL_PCQ_DROPPED (router-harden.js:105) records that RouterOS 7.19 rejects
# 'pcq-upload-default/pcq-download-default' on HOTSPOT user profiles — that combined form is
# PPP-profile syntax. router-harden stopped issuing it; provision.js:265 still does, wrapped in
# on-error={} so it fails silently on every provision. The live profile shows queue-type=(none),
# confirming it never applied. Hotspot speed comes from the RADIUS Mikrotik-Rate-Limit reply and
# the rl-<code> simple queues, both verified working.
#
# The two /queue/type definitions (lines 263-264) are KEPT: they are valid, harmless, and
# router-harden still ensures them for PPPoE profiles that reference them.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Backup + remove the dead line"
sudo cp "$BE/routes/provision.js" "$BE/routes/.provision.js.bak_$TS" && echo "   backed up"
sudo python3 - "$BE/routes/provision.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_PCQ_HOTSPOT_INVALID' in s:
    print("   already patched"); sys.exit(0)
old = ':do { /ip hotspot user profile set [find name="default"] queue-type=pcq-upload-default/pcq-download-default } on-error={}'
if old not in s:
    print("   line not found (already removed?)"); sys.exit(0)
new = ("# RL_PCQ_HOTSPOT_INVALID: removed. RouterOS 7.19 REJECTS\n"
       "# queue-type=pcq-upload-default/pcq-download-default on a HOTSPOT user profile — that combined\n"
       "# form is PPP-profile syntax. Wrapped in on-error={} it failed silently on every provision\n"
       "# (the live profile reads queue-type=(none)), and router-harden already dropped the same step\n"
       "# for logging a warning every 2 minutes. Hotspot speed is enforced by the RADIUS\n"
       "# Mikrotik-Rate-Limit reply plus the rl-<code> simple queues, both verified working.\n"
       "# The two /queue/type definitions above are kept: valid, harmless, used by PPPoE profiles.")
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   removed the invalid hotspot PCQ assignment")
PY
cd "$BE" && sudo -u www-data node --check routes/provision.js && echo "   provision.js syntax OK"

say "2) Restart + re-render the provisioning script"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 7
TOKEN=$(q -tAc "SELECT provision_token FROM nas_devices WHERE provision_token IS NOT NULL ORDER BY created_at DESC LIMIT 1;")
curl -s "http://127.0.0.1:5000/api/provision/$TOKEN/script" > /tmp/prov2.txt 2>/dev/null || true
echo "   rendered $(wc -l < /tmp/prov2.txt) lines"
if grep -q "hotspot user profile set .* queue-type=pcq" /tmp/prov2.txt; then
  echo "   ${Y}still present — check manually${N}"
else
  echo "   ${G}the invalid PCQ line is gone${N}"
fi
echo "   queue lines that remain:"
grep -n "queue type\|queue-type" /tmp/prov2.txt | sed 's/^/     /'

say "3) Re-run the key provisioning assertions"
ok(){ echo "   ${G}OK  ${N} $*"; }
bad(){ echo "   ${Y}CHECK${N} $*"; }
grep -q "action=fasttrack-connection" /tmp/prov2.txt && bad "fasttrack provisioned" || ok "no fasttrack"
grep -q "require-message-auth=no" /tmp/prov2.txt && ok "message-auth matches the server" || bad "message-auth missing"
grep -qE "rl-expired.*action=drop" /tmp/prov2.txt && bad "silent drop present" || ok "expiry rules reject"
LAST=$(grep -n "ip firewall filter add chain=forward" /tmp/prov2.txt | tail -1 | cut -d: -f1)
ACC=$(grep -n 'RL-FASTTRACK accept' /tmp/prov2.txt | tail -1 | cut -d: -f1)
[ "$LAST" = "$ACC" ] && ok "accept rule is the last forward add" || bad "accept not last"
grep -q "http-chap" /tmp/prov2.txt && grep -v "^#" /tmp/prov2.txt | grep -q "http-chap" && bad "http-chap in a live command" || ok "http-chap only in comments"

say "4) Live router unchanged and healthy"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const r=await query('SELECT name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL');
 for(const d of r.rows){
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  try{
   const f=((await axios.get(b+'/ip/firewall/filter',{auth,timeout:20000})).data||[]).filter(x=>x.chain==='forward');
   const st=(await axios.get(b+'/ip/settings',{auth,timeout:20000})).data||{};
   const ai=f.findIndex(x=>x.action==='accept'&&String(x['connection-state']||'')==='established,related'&&!x['src-address-list']);
   const li=f.map((x,i)=>String(x['src-address-list']||'')==='rl-expired'?i:-1).reduce((a,b)=>Math.max(a,b),-1);
   console.log('   '+d.name+': fasttrack='+f.filter(x=>x.action==='fasttrack-connection').length+
     ' active='+st['ipv4-fasttrack-active']+' accept-order='+((li===-1||ai>li)?'CORRECT':'WRONG'));
  }catch(e){console.log('   '+d.name+': '+e.message)}
 }
 process.exit(0);
})();"

say "5) Refresh the marker inventory and commit"
sudo grep -rhoE "RL_[A-Z0-9_]+" "$BE/routes" "$BE/utils" --include=*.js 2>/dev/null \
  | grep -v -E '\.bak' | sort -u | sudo tee /var/www/rumalink/RL_MARKERS.txt >/dev/null
echo "   $(wc -l < /var/www/rumalink/RL_MARKERS.txt) markers recorded"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Remove invalid hotspot PCQ assignment from provisioning (RouterOS 7.19 rejects it)" 2>&1 | head -2 | sed 's/^/   /'
sudo git -C /var/www/rumalink log --oneline | head -3 | sed 's/^/   /'
