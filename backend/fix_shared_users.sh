#!/usr/bin/env bash
#
# fix_shared_users.sh — let the package decide how many devices, not the router.
#
# CAUSE: the MikroTik hotspot user profile has shared-users=1. RADIUS returned Access-Accept for
# the second device (radpostauth confirms it) but the ROUTER refused the session itself, so no
# accounting start was written and the browser simply returned to the login page — no error
# anywhere, which is why this was so hard to see.
#
# DESIGN: shared-users becomes permissive and RADIUS Simultaneous-Use carries the real limit.
# One gatekeeper instead of two disagreeing ones, and — the reason this matters for you — a
# package change then takes effect through radcheck alone, with nothing to push to the router.
#
# ORDER IS DELIBERATE: every active voucher gets its Simultaneous-Use BEFORE shared-users is
# relaxed. Reversing that would briefly let an unprotected voucher run up to 10 devices.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
SHARED=10
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Which active vouchers lack a Simultaneous-Use entry?"
q -c "SELECT count(*) AS active_vouchers FROM hotspot_vouchers WHERE status='active';"
q -c "SELECT count(*) AS missing_limit FROM hotspot_vouchers hv
      WHERE hv.status='active'
        AND NOT EXISTS (SELECT 1 FROM radcheck rc
                        WHERE rc.username = hv.code || '@' || lower(left(replace(hv.isp_id::text,'-',''),8))
                          AND rc.attribute='Simultaneous-Use');"

say "2) Give every active voucher its package limit (before relaxing the router)"
q -c "INSERT INTO radcheck (username, attribute, op, value)
      SELECT hv.code || '@' || lower(left(replace(hv.isp_id::text,'-',''),8)),
             'Simultaneous-Use', ':=', COALESCE(hp.simultaneous_sessions,1)::text
        FROM hotspot_vouchers hv
        LEFT JOIN hotspot_packages hp ON hp.id = hv.package_id
       WHERE hv.status='active'
         AND NOT EXISTS (SELECT 1 FROM radcheck rc
                         WHERE rc.username = hv.code || '@' || lower(left(replace(hv.isp_id::text,'-',''),8))
                           AND rc.attribute='Simultaneous-Use');"
echo "   correct any that drifted from their package:"
q -c "UPDATE radcheck rc SET value = COALESCE(hp.simultaneous_sessions,1)::text
      FROM hotspot_vouchers hv LEFT JOIN hotspot_packages hp ON hp.id = hv.package_id
      WHERE rc.attribute='Simultaneous-Use'
        AND rc.username = hv.code || '@' || lower(left(replace(hv.isp_id::text,'-',''),8))
        AND rc.value IS DISTINCT FROM COALESCE(hp.simultaneous_sessions,1)::text;"
q -c "SELECT rc.value AS limit_set, count(*) FROM radcheck rc WHERE rc.attribute='Simultaneous-Use' GROUP BY 1 ORDER BY 1;"

say "3) Now relax shared-users on the router"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const r=await query('SELECT id,name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL');
 for(const d of r.rows){
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  try{
   const profs=(await axios.get(b+'/ip/hotspot/user/profile',{auth,timeout:20000})).data||[];
   for(const p of profs){
     const cur = p['shared-users'] || '1';
     if (String(cur) === '$SHARED') { console.log('   '+d.name+' profile '+p.name+' already shared-users=$SHARED'); continue; }
     await axios.patch(b+'/ip/hotspot/user/profile/'+encodeURIComponent(p['.id']),{'shared-users':'$SHARED'},{auth,timeout:20000});
     console.log('   '+d.name+' profile '+p.name+': shared-users '+cur+' -> $SHARED');
   }
  }catch(e){console.log('   '+d.name+': '+e.message)}
 }
 process.exit(0);
})();" 2>&1 | grep -v "^info:"

say "4) Keep it that way (router-harden re-asserts it every 2 minutes)"
sudo cp "$BE/utils/router-harden.js" "$BE/utils/.router-harden.js.bak_$TS"
sudo python3 - "$BE/utils/router-harden.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SHARED_USERS' in s:
    print("   already patched"); sys.exit(0)
anchor = "  // 2) MSS clamp"
if anchor not in s:
    print("   ERROR: anchor not found — unchanged"); sys.exit(1)
BLOCK = """  // 1c) RL_SHARED_USERS — the hotspot user profile must NOT cap simultaneous logins. It ships
  //     with shared-users=1, so a second device on a multi-device package got Access-Accept from
  //     RADIUS and was then refused by the router itself: no accounting start, no error, the
  //     browser just returned to the login page. The real per-package limit is carried by RADIUS
  //     (Simultaneous-Use), which means a package change takes effect through radcheck with
  //     nothing to push here. Keep the router permissive so the two never disagree.
  try {
    const profs = await get('/ip/hotspot/user/profile');
    for (const pr of profs) {
      if (String(pr['shared-users'] || '1') !== '10') {
        await patch('/ip/hotspot/user/profile/' + encodeURIComponent(pr['.id']), { 'shared-users': '10' });
        logger.info('[router-harden] ' + d.name + ' hotspot profile ' + pr.name + ' shared-users -> 10 (RADIUS carries the real limit)');
      }
    }
  } catch (e) { logger.warn('[router-harden] shared-users: ' + e.message); }

"""
s = s.replace(anchor, BLOCK + anchor, 1)
open(p,'w').write(s); print("   router-harden now keeps shared-users permissive")
PY
cd "$BE" && sudo -u www-data node --check utils/router-harden.js && echo "   router-harden.js OK"

say "5) Provision new routers the same way"
sudo cp "$BE/routes/provision.js" "$BE/routes/.provision.js.bak_$TS"
sudo python3 - "$BE/routes/provision.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SHARED_USERS_PROV' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([^\n]*ip hotspot user profile[^\n]*)$', s, re.M)
anchor = ':do { /ip hotspot profile set [find name="rl-hsprof"]'
i = s.find(anchor)
if i == -1:
    print("   NOTE: hotspot profile line not found; router-harden still enforces it"); sys.exit(0)
line = ('# RL_SHARED_USERS_PROV: the default hotspot user profile caps simultaneous logins at 1, which\n'
        '# silently overrides the per-package limit RADIUS sends. Keep it permissive here too.\n'
        ':do { /ip hotspot user profile set [find] shared-users=10 } on-error={}\n')
s = s[:i] + line + s[i:]
open(p,'w').write(s); print("   provisioning sets shared-users=10 for new routers")
PY
cd "$BE" && sudo -u www-data node --check routes/provision.js && echo "   provision.js OK"

say "6) A package change must update its live vouchers"
sudo cp "$BE/routes/hotspot.js" "$BE/routes/.hotspot.js.bak_$TS"
sudo python3 - "$BE/routes/hotspot.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_PKG_LIMIT_PROPAGATE' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)res\.json\(([^\n]*)\);\s*$', s[s.find('UPDATE hotspot_packages'):], re.M)
if not m:
    print("   NOTE: could not find the update response; propagation not wired"); sys.exit(0)
base = s.find('UPDATE hotspot_packages')
ind = m.group(1)
blk = (f"{ind}/* RL_PKG_LIMIT_PROPAGATE: changing a package's device count must reach the vouchers already\n"
       f"{ind}   issued from it. The limit lives in radcheck, so this is a database update — nothing is\n"
       f"{ind}   pushed to the router, which is the point of keeping shared-users permissive. */\n"
       f"{ind}try {{\n"
       f"{ind}  await query(\"UPDATE radcheck rc SET value = COALESCE(hp.simultaneous_sessions,1)::text \" +\n"
       f"{ind}    \"FROM hotspot_vouchers hv JOIN hotspot_packages hp ON hp.id = hv.package_id \" +\n"
       f"{ind}    \"WHERE rc.attribute='Simultaneous-Use' AND hv.status='active' AND hp.id = $1::uuid \" +\n"
       f"{ind}    \"AND rc.username = hv.code || '@' || lower(left(replace(hv.isp_id::text,'-',''),8))\", [req.params.id]);\n"
       f"{ind}}} catch (e) {{ require('../utils/logger').warn('[packages] limit propagate: ' + e.message); }}\n")
pos = base + m.start()
s = s[:pos] + blk + s[pos:]
open(p,'w').write(s); print("   package updates now propagate the limit to live vouchers")
PY
cd "$BE" && sudo -u www-data node --check routes/hotspot.js && echo "   hotspot.js OK"

say "7) Restart + verify"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices LIMIT 1')).rows[0];
const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
const p=(await axios.get(b+'/ip/hotspot/user/profile',{auth,timeout:15000})).data||[];
p.forEach(x=>console.log('   profile '+x.name+' shared-users='+(x['shared-users']||'1')));
process.exit(0)})();" 2>&1 | grep -v "^info:"
q -c "SELECT rc.username, rc.value AS devices FROM radcheck rc WHERE rc.attribute='Simultaneous-Use' AND rc.username LIKE 'R70%';"

say "8) Try the second device again"
echo "   R70 allows 2 and has 1 session. 'Already Paid? Login' should now connect it."
echo "   watch:  sudo -u postgres psql -d rumalink_db -c \"SELECT username, callingstationid, acctstarttime FROM radacct WHERE username LIKE 'R70%' AND acctstoptime IS NULL;\""

say "9) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Router stops capping simultaneous logins; RADIUS carries the per-package device limit" 2>&1 | head -2 | sed 's/^/   /'
