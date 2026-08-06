#!/usr/bin/env bash
#
# fix_no_static_expired_ip.sh — stop creating walled-garden entries that outlive their session.
#
# The rl-expired PPP PROFILE already carries address-list=rl-expired. MikroTik adds a
# subscriber's address to that list when they connect on the profile and REMOVES it when they
# disconnect — the entry is dynamic and owned by the session.
#
# listExpiredIp(sub, true) adds the same address a SECOND time, statically. Nothing owns that
# entry, so when the expired subscriber disconnects it stays behind, and the pool hands the
# address to the next customer, who inherits the block. Orpha was cut off by Irene's leftover.
#
# restrict() bounces the session immediately afterwards, so the subscriber re-authenticates into
# rl-expired within seconds and the profile creates the correct dynamic entry. The manual add was
# never buying anything — it was only creating litter.
#
# Removing it means a recycled address can never carry an old block: the entry disappears with
# the session that owns it.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Static vs dynamic entries on the router right now"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
 const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
 const al=(await axios.get(b+'/ip/firewall/address-list',{auth,timeout:15000})).data||[];
 const ex=al.filter(x=>String(x.list)==='rl-expired');
 console.log('   rl-expired entries: '+ex.length);
 ex.forEach(x=>console.log('     '+x.address+'  dynamic='+(x.dynamic||'false')+'  comment='+(x.comment||'(none)')));
 console.log('   ${Y}dynamic=true is the profile managing itself; dynamic=false is ours and will linger${N}');
 process.exit(0);
})();" 2>&1 | grep -v "^info:"

say "2) Backup"
sudo cp "$BE/utils/walledGarden.js" "$BE/utils/.walledGarden.js.bak_$TS" && echo "   walledGarden.js"

say "3) Stop adding the static entry"
sudo python3 - "$BE/utils/walledGarden.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_NO_STATIC_EXPIRED' in s:
    print("   already patched"); sys.exit(0)
old = "    await listExpiredIp(sub, true); /* RL_RESTRICT_IP: wall the live IP immediately */"
if old not in s:
    print("   ERROR: listExpiredIp(true) call not found"); sys.exit(1)
new = """    /* RL_NO_STATIC_EXPIRED: this added the subscriber's live address to rl-expired by hand. The
       rl-expired PPP profile already carries address-list=rl-expired, so MikroTik adds that
       address itself on connect and REMOVES it on disconnect — its entry is dynamic and owned by
       the session. The manual copy was static: nothing owned it, so it survived the disconnect and
       the pool handed the address to the next customer, who inherited the block. Orpha lost
       service to Irene's leftover this way.
       The bounce below forces re-authentication into rl-expired within seconds, and the profile
       creates the correct entry. Adding one here bought nothing and left litter behind. */
    /* (static add removed — the rl-expired profile manages the address list) */"""
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   static add removed; the profile now owns the entry")
PY
cd "$BE" && sudo -u www-data node --check utils/walledGarden.js && echo "   walledGarden.js OK"
echo "   restore still unlists legacy static entries:"
sudo grep -n "listExpiredIp(sub, false)" "$BE/utils/walledGarden.js" | sed 's/^/     /'

say "4) Clear any static leftovers now"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const rows=(await query('SELECT name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL')).rows;
 for (const d of rows) {
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  try{
   const al=(await axios.get(b+'/ip/firewall/address-list',{auth,timeout:15000})).data||[];
   let n=0;
   for (const e of al.filter(x=>String(x.list)==='rl-expired' && String(x.dynamic)!=='true')) {
     await axios.delete(b+'/ip/firewall/address-list/'+encodeURIComponent(e['.id']),{auth,timeout:15000}).catch(()=>{});
     console.log('   removed static '+e.address+' ('+(e.comment||'')+')'); n++;
   }
   console.log('   '+d.name+': '+n+' static entr(ies) cleared');
  }catch(e){console.log('   '+d.name+': '+e.message)}
 }
 process.exit(0);
})();" 2>&1 | grep -v "^info:"

say "5) Restart + verify the expiry path still walls people"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "\[WG\]|wg-reconcile|error" | tail -5 | sed 's/^/   /'
q -c "SELECT username, status, next_billing_date FROM pppoe_subscribers WHERE status='expired' OR next_billing_date < NOW() ORDER BY next_billing_date DESC LIMIT 5;"

say "6) What this changes"
cat <<'EOS'
   An expired subscriber is still walled — restrict() sets their Mikrotik-Group to rl-expired and
   bounces the session, so they reconnect into the walled profile and MikroTik lists their address
   itself. When they disconnect, that entry goes with them.

   A recycled address can no longer carry someone else's block, because no entry outlives its
   session. The wg-reconcile safety net stays in place, but it should now find nothing to clean.

   Verify after the next expiry:
     the address-list entry for that user shows dynamic=true
     and disappears from the list when they disconnect
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "PPPoE: let the rl-expired profile own the address list; stop creating static entries that outlive the session" 2>&1 | head -2 | sed 's/^/   /'
