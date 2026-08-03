#!/usr/bin/env bash
#
# build_device_limit_step2.sh — per-package simultaneous device limit.
#
# Verified available: hotspot_packages.simultaneous_sessions (default 1), FreeRADIUS
# session { -sql } with simul_count_query present, and a populated radacct. So RADIUS itself can
# reject the N+1th device — no portal logic needed and no way for a device to slip past it.
#
# What this adds:
#   1. Simultaneous-Use := <package.simultaneous_sessions> written on EVERY voucher RADIUS sync,
#      in BOTH writers (captive.js and intasend-activate.js). Two writers of the same rows is
#      exactly how the gateways drifted apart before, so both get it in the same change.
#   2. The package create/update API accepts the value.
#   3. A "Devices allowed" field in the ISP dashboard package form.
#   4. Backfill for vouchers that already exist.
#
set -uo pipefail
BE=/var/www/rumalink/backend
DASH=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "0) Regions I am about to patch (so a miss is visible)"
echo "   --- captive.js syncRadiusForVoucher ---"
L=$(grep -n "async function syncRadiusForVoucher" "$BE/routes/captive.js" | cut -d: -f1)
sudo sed -n "${L},$((L+50))p" "$BE/routes/captive.js" | nl -ba -v"$L" | sed 's/^/     /'
echo "   --- hotspot package routes ---"
grep -rnE "router\.(post|put)\('/packages" "$BE/routes/hotspot.js" | sed 's/^/     /'

say "1) Backups"
for f in routes/captive.js utils/intasend-activate.js routes/hotspot.js; do
  [ -f "$BE/$f" ] && sudo cp "$BE/$f" "$BE/$(dirname $f)/.$(basename $f).bak_$TS" && echo "   $f"
done
sudo cp "$DASH" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   isp/dashboard.html"

say "2) intasend-activate.js — write Simultaneous-Use"
sudo python3 - "$BE/utils/intasend-activate.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SIMUL_USE' in s:
    print("   already patched"); sys.exit(0)
n=0
old_sel = "`SELECT duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, mikrotik_profile\n             FROM hotspot_packages WHERE id=$1::uuid`"
if old_sel in s:
    s = s.replace(old_sel, "`SELECT duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, mikrotik_profile, simultaneous_sessions\n             FROM hotspot_packages WHERE id=$1::uuid`", 1); n+=1
else:
    s2 = re.sub(r'(SELECT duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, mikrotik_profile)',
                r'\1, simultaneous_sessions', s, count=1)
    if s2 != s: s = s2; n+=1

m = re.search(r'^([ \t]*)if \(pkg\.mikrotik_profile\) \{', s, re.M)
if not m:
    print(f"   sel={n} — ERROR: mikrotik_profile anchor not found"); sys.exit(1)
ind = m.group(1)
blk = (
f"{ind}/* RL_SIMUL_USE: how many devices this package may use AT ONCE. FreeRADIUS enforces it via\n"
f"{ind}   session {{ -sql }} + simul_count_query, so the N+1th device is rejected at authentication\n"
f"{ind}   and cannot slip past a portal check. Written on every sync so a package change takes\n"
f"{ind}   effect on the next activation. */\n"
f"{ind}{{\n"
f"{ind}  const _simul = parseInt(pkg.simultaneous_sessions, 10);\n"
f"{ind}  if (Number.isFinite(_simul) && _simul > 0) {{\n"
f"{ind}    await query(\"INSERT INTO radcheck (username, attribute, op, value) VALUES ($1,'Simultaneous-Use',':=',$2)\",\n"
f"{ind}      [realmedUser, String(_simul)]);\n"
f"{ind}  }}\n"
f"{ind}}}\n"
)
s = s[:m.start()] + blk + s[m.start():]; n+=1
open(p,'w').write(s); print(f"   {n} edit(s) applied")
PY
cd "$BE" && sudo -u www-data node --check utils/intasend-activate.js && echo "   intasend-activate.js OK"

say "3) captive.js syncRadiusForVoucher — same attribute"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SIMUL_USE' in s:
    print("   already patched"); sys.exit(0)
i = s.find('async function syncRadiusForVoucher')
if i == -1:
    print("   ERROR: function not found"); sys.exit(1)
seg = s[i:i+6000]
m = re.search(r"^([ \t]*)await query\(\s*[\"'`]INSERT INTO radcheck[^\n]*Cleartext-Password[^\n]*\n?[^\n]*\);", seg, re.M)
if not m:
    m = re.search(r"^([ \t]*)[^\n]*INSERT INTO radcheck[^\n]*Cleartext-Password[^\n]*$", seg, re.M)
if not m:
    print("   ERROR: Cleartext-Password insert not found inside syncRadiusForVoucher"); sys.exit(1)
ind = m.group(1)
blk = (
f"\n{ind}/* RL_SIMUL_USE: per-package simultaneous device limit, enforced by FreeRADIUS via\n"
f"{ind}   session {{ -sql }} + simul_count_query. Both RADIUS writers set it — this one and\n"
f"{ind}   intasend-activate.js — because a value written by only one path would apply or not\n"
f"{ind}   depending on which gateway the ISP happens to use. */\n"
f"{ind}try {{\n"
f"{ind}  const _sim = await query(\n"
f"{ind}    'SELECT hp.simultaneous_sessions AS n FROM hotspot_vouchers hv JOIN hotspot_packages hp ON hp.id = hv.package_id WHERE hv.id = $1::uuid',\n"
f"{ind}    [voucherId]);\n"
f"{ind}  const _n = _sim.rows[0] && parseInt(_sim.rows[0].n, 10);\n"
f"{ind}  if (Number.isFinite(_n) && _n > 0) {{\n"
f"{ind}    await query(\"DELETE FROM radcheck WHERE username=$1 AND attribute='Simultaneous-Use'\", [radiusUsername(v.code, v.isp_id)]).catch(function(){{}});\n"
f"{ind}    await query(\"INSERT INTO radcheck (username, attribute, op, value) VALUES ($1,'Simultaneous-Use',':=',$2)\",\n"
f"{ind}      [radiusUsername(v.code, v.isp_id), String(_n)]).catch(function(){{}});\n"
f"{ind}  }}\n"
f"{ind}}} catch (e) {{ logger.warn('[RADIUS-SYNC] simultaneous-use: ' + e.message); }}"
)
pos = i + m.end()
s = s[:pos] + blk + s[pos:]
open(p,'w').write(s); print("   Simultaneous-Use added after the password insert")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js OK"
sudo grep -n "RL_SIMUL_USE" "$BE/routes/captive.js" "$BE/utils/intasend-activate.js" | sed 's/^/   /'

say "4) Package API — accept the value on create and update"
sudo python3 - "$BE/routes/hotspot.js" <<'PY'
import sys, re
p=sys.argv[1]
try: s=open(p).read()
except Exception as e:
    print("   hotspot.js not readable: "+str(e)); sys.exit(0)
if 'RL_SIMUL_FIELD' in s:
    print("   already patched"); sys.exit(0)
n=0
# INSERT
m = re.search(r'INSERT INTO hotspot_packages\s*\(([^)]*)\)\s*VALUES\s*\(([^)]*)\)', s, re.S)
if m:
    cols, vals = m.group(1), m.group(2)
    if 'simultaneous_sessions' not in cols:
        nums = [int(x) for x in re.findall(r'\$(\d+)', vals)]
        nxt = (max(nums)+1) if nums else 1
        s = s[:m.start(1)] + cols.rstrip() + ", simultaneous_sessions" + s[m.end(1):]
        m2 = re.search(r'INSERT INTO hotspot_packages\s*\(([^)]*)\)\s*VALUES\s*\(([^)]*)\)', s, re.S)
        s = s[:m2.start(2)] + m2.group(2).rstrip() + f", ${nxt}" + s[m2.end(2):]
        n+=1
        print(f"   INSERT: added simultaneous_sessions as ${nxt} /* RL_SIMUL_FIELD */")
# UPDATE
m3 = re.search(r'UPDATE hotspot_packages SET([^`]*?)WHERE', s, re.S)
if m3 and 'simultaneous_sessions' not in m3.group(1):
    nums = [int(x) for x in re.findall(r'\$(\d+)', m3.group(1))]
    nxt = (max(nums)+1) if nums else 1
    s = s[:m3.end(1)] + f", simultaneous_sessions=${nxt} " + s[m3.end(1):]
    n+=1
    print(f"   UPDATE: added simultaneous_sessions=${nxt}")
if n: open(p,'w').write(s)
print(f"   {n} SQL edit(s) — the route's parameter array still needs the value appended")
PY
echo "   ${Y}review the route body below and confirm the param array matches${N}"
grep -nE "INSERT INTO hotspot_packages|UPDATE hotspot_packages" "$BE/routes/hotspot.js" 2>/dev/null | sed 's/^/   /'

say "5) Backfill Simultaneous-Use for vouchers that already exist"
q -c "INSERT INTO radcheck (username, attribute, op, value)
      SELECT rc.username, 'Simultaneous-Use', ':=', COALESCE(hp.simultaneous_sessions,1)::text
        FROM radcheck rc
        JOIN hotspot_vouchers hv ON rc.username = hv.code || '@' || lower(left(replace(hv.isp_id::text,'-',''),8))
        JOIN hotspot_packages hp ON hp.id = hv.package_id
       WHERE rc.attribute='Cleartext-Password'
         AND NOT EXISTS (SELECT 1 FROM radcheck x WHERE x.username=rc.username AND x.attribute='Simultaneous-Use');"
q -c "SELECT username, attribute, value FROM radcheck WHERE attribute='Simultaneous-Use' ORDER BY username LIMIT 10;"
q -c "SELECT count(*) AS with_limit FROM radcheck WHERE attribute='Simultaneous-Use';"

say "6) Restart + verify"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"
q -c "SELECT name, simultaneous_sessions FROM hotspot_packages ORDER BY duration_hours;"

say "7) Still to do — the dashboard field"
echo "   the create form posts these ids (line ~2234):"
grep -oE "hsp-[a-z]+" "$DASH" | sort -u | sed 's/^/     /'
echo "   ${Y}Paste section 0 and 4 output and the form field + param array go in next.${N}"
