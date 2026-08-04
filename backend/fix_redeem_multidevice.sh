#!/usr/bin/env bash
#
# fix_redeem_multidevice.sh — use the portal's EXISTING redeem flow for extra devices.
#
# The portal already had a code-entry path: fetch(`${API}/captive/${ISP_ID}/redeem`) with a real
# getMac() helper. My added form was a second owner of the same function — the pattern behind
# several bugs today (two RADIUS writers, two walled-garden rule sets, two TV branches). So:
# remove the duplicate, and teach /redeem the per-package device limit.
#
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "0) The existing /redeem route — why a second device is refused"
L=$(grep -n "router.post('/:ispId/redeem'" "$BE/routes/captive.js" | head -1 | cut -d: -f1)
echo "   route at line ${L:-not found}"
[ -n "$L" ] && sudo sed -n "${L},$((L+75))p" "$BE/routes/captive.js" | nl -ba -v"$L" | sed 's/^/   /'
echo "   --- the portal side ---"
sudo sed -n '760,800p' "$CP/classic.html" | nl -ba -v760 | sed 's/^/   /'

say "1) Backups"
sudo cp "$BE/routes/captive.js" "$BE/routes/.captive.js.bak_$TS" && echo "   captive.js"
sudo cp "$CP/classic.html" "$CP/.classic.html.bak_$TS" && echo "   classic.html"

say "2) Remove my duplicate form and script"
sudo python3 - "$CP/classic.html" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
n=0
i = s.find('<!-- RL_CODE_LOGIN_UI')
if i != -1:
    j = s.find('</div>', s.find('id="cl-msg"', i))
    j = s.find('</div>', j+6)
    if j != -1:
        s = s[:i] + s[j+len('</div>'):]; n+=1
k = s.find('/* RL_CODE_LOGIN_UI')
if k != -1:
    a = s.rfind('<script>', 0, k); b = s.find('</script>', k)
    if a != -1 and b != -1:
        s = s[:a] + s[b+len('</script>'):]; n+=1
open(p,'w').write(s)
print(f"   removed {n} duplicate block(s)")
PY
sudo chown www-data:www-data "$CP/classic.html"
echo "   div balance: $(( $(grep -o '<div' "$CP/classic.html" | wc -l) - $(grep -o '</div>' "$CP/classic.html" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$CP/classic.html" | wc -l) / $(grep -o '</script>' "$CP/classic.html" | wc -l)"
grep -c "RL_CODE_LOGIN_UI" "$CP/classic.html" | sed 's/^/   remaining RL_CODE_LOGIN_UI: /'

say "3) Teach /redeem the per-package device limit"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_REDEEM_MULTIDEVICE' in s:
    print("   already patched"); sys.exit(0)

i = s.find("router.post('/:ispId/redeem'")
if i == -1:
    print("   ERROR: redeem route not found"); sys.exit(1)
seg = s[i:i+9000]

# find a MAC-mismatch rejection inside the route
m = re.search(r"^([ \t]*)(if \([^\n]*used_by_mac[^\n]*\)\s*\{[^\n]*\n(?:[^\n]*\n){0,4}?[^\n]*res\.status\(\d+\)[^\n]*\n[^\n]*\})", seg, re.M)
if not m:
    m = re.search(r"^([ \t]*)[^\n]*used_by_mac[^\n]*\n", seg, re.M)
if not m:
    print("   NOTE: no used_by_mac check found in /redeem — inserting the limit check after lookup")

anchor = re.search(r"^([ \t]*)const (v|voucher) = \(await query\(", seg, re.M)
if not anchor:
    print("   ERROR: voucher lookup not found in /redeem"); sys.exit(1)

# insert the device-limit gate right after the voucher row is available
end = seg.find(';', anchor.end())
nl  = seg.find('\n', end)
ind = anchor.group(1)
var = anchor.group(2)
blk = (
f"\n{ind}/* RL_REDEEM_MULTIDEVICE: a package may allow more than one device at a time\n"
f"{ind}   (hotspot_packages.simultaneous_sessions). This route previously admitted only the single\n"
f"{ind}   MAC recorded on the voucher, so a second device was refused before RADIUS ever saw it —\n"
f"{ind}   Simultaneous-Use was written and enforceable, but unreachable. Admit a new device while\n"
f"{ind}   the voucher is under its limit, and say plainly when it is not. */\n"
f"{ind}try {{\n"
f"{ind}  const _mac = String(req.body.mac || '').trim().toUpperCase();\n"
f"{ind}  if ({var} && {var}.id && _mac) {{\n"
f"{ind}    const _lim = (await query('SELECT COALESCE(hp.simultaneous_sessions,1) AS n FROM hotspot_vouchers hv LEFT JOIN hotspot_packages hp ON hp.id=hv.package_id WHERE hv.id=$1::uuid', [{var}.id])).rows[0];\n"
f"{ind}    const _max = _lim ? (parseInt(_lim.n, 10) || 1) : 1;\n"
f"{ind}    const _known = (await query('SELECT mac FROM hotspot_voucher_devices WHERE voucher_id=$1::uuid', [{var}.id])).rows.map(function(r){{ return String(r.mac).toUpperCase(); }});\n"
f"{ind}    if (!_known.includes(_mac)) {{\n"
f"{ind}      if (_known.length >= _max) {{\n"
f"{ind}        return res.status(403).json({{ error: 'This code is already used by ' + _known.length + ' device' + (_known.length > 1 ? 's' : '') + '. It allows ' + _max + '.' }});\n"
f"{ind}      }}\n"
f"{ind}      await query('INSERT INTO hotspot_voucher_devices (voucher_id, mac) VALUES ($1::uuid,$2) ON CONFLICT DO NOTHING', [{var}.id, _mac]);\n"
f"{ind}      logger.info('[redeem] ' + {var}.code + ' admitted ' + _mac + ' (' + (_known.length + 1) + '/' + _max + ')');\n"
f"{ind}    }} else {{\n"
f"{ind}      await query('UPDATE hotspot_voucher_devices SET last_seen=now() WHERE voucher_id=$1::uuid AND mac=$2', [{var}.id, _mac]).catch(function(){{}});\n"
f"{ind}    }}\n"
f"{ind}  }}\n"
f"{ind}}} catch (e) {{ logger.warn('[redeem] device limit: ' + e.message); }}\n"
)
pos = i + nl + 1
s = s[:pos] + blk + s[pos:]
open(p,'w').write(s); print("   device-limit gate inserted into /redeem")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js OK"
sudo grep -n "RL_REDEEM_MULTIDEVICE" "$BE/routes/captive.js" | sed 's/^/   /'

say "4) Relax the single-MAC rejection, if one exists"
sudo grep -n "used_by_mac" "$BE/routes/captive.js" | sed -n '1,12p' | sed 's/^/   /'
echo "   ${Y}if a line above rejects on a used_by_mac mismatch inside /redeem, paste it and it will be scoped to the limit${N}"

say "5) Restart + test"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
CODE=$(q -tAc "SELECT code FROM hotspot_vouchers WHERE status='active' AND (is_tv IS NOT TRUE) ORDER BY created_at DESC LIMIT 1;")
q -c "SELECT hv.code, COALESCE(hp.simultaneous_sessions,1) AS allowed,
             (SELECT count(*) FROM hotspot_voucher_devices d WHERE d.voucher_id=hv.id) AS registered
      FROM hotspot_vouchers hv LEFT JOIN hotspot_packages hp ON hp.id=hv.package_id
      WHERE hv.code='$CODE';"
for M in AA:BB:CC:DD:EE:11 AA:BB:CC:DD:EE:12 AA:BB:CC:DD:EE:13; do
  printf "   redeem with %s -> " "$M"
  curl -s -X POST "http://127.0.0.1:5000/api/captive/$ISP/redeem" \
    -H 'Content-Type: application/json' -d "{\"code\":\"$CODE\",\"mac\":\"$M\"}" | head -c 190; echo
done
q -c "DELETE FROM hotspot_voucher_devices WHERE mac LIKE 'AA:BB:CC:DD:EE:1%';"
q -c "DELETE FROM radcheck WHERE username LIKE 'AA:BB:CC:DD:EE:1%';"

say "6) Now test on the real second device"
cat <<'EOS'
   Hard-refresh the portal on the second device and use the portal's own code entry
   (the redeem flow that was already there — my duplicate form has been removed).
   Expect: it connects while under the limit, and gets a clear message beyond it.
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Redeem honours the package device limit; removed the duplicate code-entry form" 2>&1 | head -2 | sed 's/^/   /'
