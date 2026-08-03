#!/usr/bin/env bash
#
# build_device_limit_step3.sh — finish the per-package device limit.
#  a) captive.js syncRadiusForVoucher: write Simultaneous-Use (the step-2 regex missed because
#     the insert there is a multi-line template literal).
#  b) confirm the package UPDATE + param arrays carry the value.
#  c) add the "Devices allowed" field to the ISP dashboard package form.
#
set -uo pipefail
BE=/var/www/rumalink/backend
DASH=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "0) The package routes as they stand"
sudo sed -n '20,55p' "$BE/routes/hotspot.js" | nl -ba -v20 | sed 's/^/   /'

say "1) Backups"
sudo cp "$BE/routes/captive.js" "$BE/routes/.captive.js.bak_$TS" && echo "   captive.js"
sudo cp "$DASH" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   dashboard.html"

say "2) captive.js — insert before the Session-Timeout block"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SIMUL_USE' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)// Session-Timeout from expires_at\s*$', s, re.M)
if not m:
    print("   ERROR: Session-Timeout comment not found"); sys.exit(1)
ind = m.group(1)
blk = (
f"{ind}/* RL_SIMUL_USE: how many devices this package may use AT ONCE. FreeRADIUS enforces it\n"
f"{ind}   through session {{ -sql }} + simul_count_query, so the N+1th device is refused at\n"
f"{ind}   authentication and cannot route around a portal check. Written by BOTH RADIUS writers\n"
f"{ind}   (here and intasend-activate.js) — a value set by only one path would apply or not\n"
f"{ind}   depending on which gateway the ISP happens to use. */\n"
f"{ind}try {{\n"
f"{ind}  const _sim = await query(\n"
f"{ind}    'SELECT COALESCE(hp.simultaneous_sessions,1) AS n FROM hotspot_vouchers hv ' +\n"
f"{ind}    'JOIN hotspot_packages hp ON hp.id = hv.package_id WHERE hv.id = $1::uuid', [voucherId]);\n"
f"{ind}  const _n = _sim.rows[0] ? parseInt(_sim.rows[0].n, 10) : 1;\n"
f"{ind}  if (Number.isFinite(_n) && _n > 0) {{\n"
f"{ind}    await query(\n"
f"{ind}      `INSERT INTO radcheck (username, attribute, op, value)\n"
f"{ind}       VALUES ($1, 'Simultaneous-Use', ':=', $2)`,\n"
f"{ind}      [radiusUsername(r.code, r.isp_id), String(_n)]);\n"
f"{ind}  }}\n"
f"{ind}}} catch (e) {{ logger.warn('[RADIUS-SYNC] simultaneous-use: ' + e.message); }}\n\n"
)
s = s[:m.start()] + blk + s[m.start():]
open(p,'w').write(s); print("   Simultaneous-Use written in syncRadiusForVoucher")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js OK"
sudo grep -n "RL_SIMUL_USE" "$BE/routes/captive.js" "$BE/utils/intasend-activate.js" | sed 's/^/   /'

say "3) Package UPDATE — make sure the value can be edited too"
sudo python3 - "$BE/routes/hotspot.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SIMUL_FIELD' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'UPDATE hotspot_packages SET(.*?)WHERE', s, re.S)
if not m:
    print("   UPDATE not found"); sys.exit(0)
body = m.group(1)
if 'simultaneous_sessions' in body:
    print("   UPDATE already carries simultaneous_sessions"); sys.exit(0)
nums = [int(x) for x in re.findall(r'\$(\d+)', body)]
nxt = (max(nums)+1) if nums else 1
newbody = body.rstrip().rstrip(',') + f", simultaneous_sessions=${nxt} /* RL_SIMUL_FIELD */ "
s = s[:m.start(1)] + newbody + s[m.end(1):]
open(p,'w').write(s); print(f"   UPDATE: simultaneous_sessions=${nxt} added — the param array must gain the value at position {nxt}")
PY
echo "   current route bodies:"
sudo sed -n '20,55p' "$BE/routes/hotspot.js" | grep -nE "INSERT|UPDATE|\[|req.body" | sed 's/^/     /'

say "4) Dashboard — the package form markup"
grep -n "hsp-profile" "$DASH" | sed 's/^/   /'
LF=$(grep -n 'id="hsp-profile"' "$DASH" | head -1 | cut -d: -f1)
[ -n "$LF" ] && sudo sed -n "$((LF-8)),$((LF+4))p" "$DASH" | nl -ba -v"$((LF-8))" | sed 's/^/   /'

say "5) Add the Devices allowed field"
sudo python3 - "$DASH" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'hsp-devices' in s:
    print("   field already present"); sys.exit(0)
n=0
# a) the input, right before the mikrotik profile field
m = re.search(r'^([ \t]*)(<[^\n]*id="hsp-profile"[^\n]*>)\s*$', s, re.M)
if m:
    ind = m.group(1)
    fld = (f'{ind}<!-- RL_SIMUL_FIELD: how many devices may use ONE voucher at the same time.\n'
           f'{ind}     Enforced by RADIUS (Simultaneous-Use); 1 keeps today\'s behaviour. -->\n'
           f'{ind}<label>Devices allowed at once</label>\n'
           f'{ind}<input id="hsp-devices" type="number" min="1" max="10" value="1" placeholder="1"/>\n')
    s = s[:m.start()] + fld + s[m.start():]; n+=1
else:
    print("   NOTE: could not place the input automatically")

# b) include it when creating
old_create = "data_limit_mb:document.getElementById('hsp-data').value||null,mikrotik_profile:document.getElementById('hsp-profile').value"
if old_create in s:
    s = s.replace(old_create,
      "data_limit_mb:document.getElementById('hsp-data').value||null,simultaneous_sessions:parseInt(document.getElementById('hsp-devices').value||'1',10),mikrotik_profile:document.getElementById('hsp-profile').value", 1)
    n+=1
else:
    print("   NOTE: create payload not matched")
open(p,'w').write(s); print(f"   {n} edit(s) applied")
PY
sudo chown www-data:www-data "$DASH"
echo "   div balance: $(( $(grep -o '<div' "$DASH" | wc -l) - $(grep -o '</div>' "$DASH" | wc -l) ))"
grep -c "hsp-devices" "$DASH" | sed 's/^/   hsp-devices references: /'

say "6) Restart + prove the attribute is written on a sync"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
VID=$(q -tAc "SELECT id FROM hotspot_vouchers WHERE status='active' ORDER BY created_at DESC LIMIT 1;")
if [ -n "$VID" ]; then
  q -c "DELETE FROM radcheck WHERE attribute='Simultaneous-Use' AND username IN (SELECT code || '@' || lower(left(replace(isp_id::text,'-',''),8)) FROM hotspot_vouchers WHERE id='$VID'::uuid);"
  sudo -u www-data node -e "
  require('dotenv').config({path:'$BE/.env'});
  (async()=>{ try{ await require('$BE/routes/captive').syncRadiusForVoucher('$VID'); console.log('   re-synced'); }catch(e){ console.log('   '+e.message); } process.exit(0); })();" 2>&1 | grep -vE "^info:" | sed 's/^/  /'
  q -c "SELECT username, attribute, value FROM radcheck WHERE attribute='Simultaneous-Use' AND username IN (SELECT code || '@' || lower(left(replace(isp_id::text,'-',''),8)) FROM hotspot_vouchers WHERE id='$VID'::uuid);"
fi

say "7) Try it"
cat <<'EOS'
   1. Set a package to 2 devices in HS Packages, save.
   2. Buy that package, connect one device, then a second — both should work.
   3. Connect a third with the same voucher -> RADIUS rejects it.
   Watch:  sudo tail -f /var/log/freeradius/radius.log
           sudo -u postgres psql -d rumalink_db -c "SELECT username, attribute, value FROM radcheck WHERE attribute='Simultaneous-Use';"
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Per-package simultaneous device limit enforced via RADIUS Simultaneous-Use" 2>&1 | head -2 | sed 's/^/   /'
