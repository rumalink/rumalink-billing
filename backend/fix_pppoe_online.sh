#!/usr/bin/env bash
#
# fix_pppoe_online.sh — every PPPoE user shows "offline" in All Users, including the ones online.
#
# CAUSE: the live-enrich step in /users only reads liveHotspotSessions(). PPPoE connections are
# not hotspot sessions, so no PPPoE username ever appears in the set and the flag stays false —
# the column is honest about what it checked, and what it checked was only half the network.
# Active Sessions gets this right because it also reads /ppp/active.
#
# FIX: read /ppp/active alongside it, per router, in parallel, and mark PPPoE users by username.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Who is actually connected on PPPoE right now"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL LIMIT 1')).rows[0];
const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
const a=(await axios.get(b+'/ppp/active',{auth,timeout:15000})).data||[];
console.log('   '+a.length+' PPPoE session(s):');
a.forEach(x=>console.log('     '+x.name+'  ip='+(x.address||'')+'  uptime='+(x.uptime||'')));
process.exit(0)})();" 2>&1 | grep -v "^info:"

say "2) The enrich block as it stands"
sudo grep -n "Enrich with live router state" -A 20 "$BE/routes/isp.js" | head -24 | sed 's/^/   /'

say "3) Backup + patch"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_PPPOE_ONLINE' in s:
    print("   already patched"); sys.exit(0)

old_sel = """      const nasList = await query(
        `SELECT id FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL`,
        [req.user.ispId]
      );"""
new_sel = """      /* RL_PPPOE_ONLINE: credentials are needed too, so /ppp/active can be read alongside the
         hotspot sessions. Without it every PPPoE user reported offline — the flag only ever
         reflected hotspot state, which is half the network. */
      const nasList = await query(
        `SELECT id, wireguard_ip, mikrotik_api_user, mikrotik_api_password
           FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL`,
        [req.user.ispId]
      );"""
if old_sel not in s:
    m = re.search(r'const nasList = await query\(\s*`SELECT id FROM nas_devices[^`]*`,\s*\[req\.user\.ispId\]\s*\);', s)
    if not m: print("   ERROR: nasList query not found"); sys.exit(1)
    old_sel = m.group(0)
s = s.replace(old_sel, new_sel, 1)

old_loop = """      const liveSet = new Set();
      for (const nas of nasList.rows) {
        try {
          const live = await mt.liveHotspotSessions(nas.id);
          for (const s of live) liveSet.add(String(s.user || '').split('@')[0].toUpperCase()); /* RL_REALM_DISPLAY: match bare code */
        } catch(e) { /* skip unreachable router */ }
      }"""
new_loop = """      const liveSet = new Set();
      const pppSet = new Set();
      const axios = require('axios');
      await Promise.allSettled(nasList.rows.map(async (nas) => {
        try {
          const live = await mt.liveHotspotSessions(nas.id);
          for (const s of live) liveSet.add(String(s.user || '').split('@')[0].toUpperCase()); /* RL_REALM_DISPLAY: match bare code */
        } catch (e) { /* skip unreachable router */ }
        try {
          const r = await axios.get('http://' + nas.wireguard_ip + '/rest/ppp/active', {
            auth: { username: nas.mikrotik_api_user, password: nas.mikrotik_api_password },
            timeout: 8000, validateStatus: () => true });
          if (r.status === 200 && Array.isArray(r.data)) {
            for (const sn of r.data) if (sn.name) pppSet.add(String(sn.name).toUpperCase());
          }
        } catch (e) { /* skip unreachable router */ }
      }));"""
if old_loop not in s:
    print("   ERROR: enrich loop not found"); sys.exit(1)
s = s.replace(old_loop, new_loop, 1)

old_mark = """        if (liveSet.has(String(u.username || '').toUpperCase())
            || (u.last_mac && liveSet.has(String(u.last_mac).toUpperCase()))) u.online = true;"""
new_mark = """        if (u.type === 'pppoe') {
          /* RL_PPPOE_ONLINE: a PPPoE connection is not a hotspot session, so it never appeared in
             liveSet and every subscriber read offline. Match on the username the router reports. */
          if (pppSet.has(String(u.username || '').toUpperCase())) u.online = true;
        } else if (liveSet.has(String(u.username || '').toUpperCase())
            || (u.last_mac && liveSet.has(String(u.last_mac).toUpperCase()))) u.online = true;"""
if old_mark not in s:
    print("   ERROR: marking block not found"); sys.exit(1)
s = s.replace(old_mark, new_mark, 1)
open(p,'w').write(s); print("   PPPoE online status wired in")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"
sudo grep -n "RL_PPPOE_ONLINE" "$BE/routes/isp.js" | sed 's/^/   /'

say "4) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 15 --nostream 2>/dev/null | grep -iE "isp/users|error" | tail -3 | sed 's/^/   /' || echo "   clean"

say "5) Check"
cat <<'EOS'
   Reload All Users and open the PPPoE tab. The subscribers listed in section 1 above should
   now show ONLINE; everyone else stays offline.
   The online count in the badge follows the same signal.
EOS

say "6) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "All Users: PPPoE online status read from /ppp/active (only hotspot was checked)" 2>&1 | head -2 | sed 's/^/   /'
