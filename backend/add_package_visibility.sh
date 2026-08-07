#!/usr/bin/env bash
#
# add_package_visibility.sh — hide a hotspot package from the captive portal.
#
# is_active already exists and the portal filters on it, but it means "retired". A test package
# needs something different: invisible to customers, yet fully honoured for anyone already on it
# and still purchasable by you directly. Overloading is_active would mean hiding a package could
# cut off paying customers — the same trap as one column carrying two meanings, which caused the
# used_by_mac / purchased_by_mac confusion earlier.
#
# visible_in_portal (default true) is therefore separate:
#   is_active=false          -> retired, gone from every list
#   visible_in_portal=false  -> not offered to customers; existing vouchers keep working, and the
#                               package can still be bought by id for testing
#
set -uo pipefail
BE=/var/www/rumalink/backend
D=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Add the column"
q -c "ALTER TABLE hotspot_packages ADD COLUMN IF NOT EXISTS visible_in_portal boolean NOT NULL DEFAULT true;"
q -c "SELECT name, price, is_active, visible_in_portal FROM hotspot_packages ORDER BY price;"

say "2) Backups"
sudo cp "$BE/routes/captive.js" "$BE/routes/.captive.js.bak_$TS" && echo "   captive.js"
sudo cp "$BE/routes/hotspot.js" "$BE/routes/.hotspot.js.bak_$TS" && echo "   hotspot.js"
sudo cp "$D" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   dashboard.html"

say "3) Hide it from the customer portal only"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_PORTAL_VISIBILITY' in s:
    print("   already patched"); sys.exit(0)
old = "'SELECT id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb FROM hotspot_packages WHERE isp_id=$1::uuid AND is_active=true ORDER BY price ASC',"
if old not in s:
    print("   ERROR: portal package query not found"); sys.exit(1)
new = ("/* RL_PORTAL_VISIBILITY: visible_in_portal hides a package from CUSTOMERS without retiring it.\n"
       "         Only this list is filtered — the purchase route still accepts the package by id, so a test\n"
       "         package can be bought deliberately, and anyone already holding a voucher on a hidden\n"
       "         package keeps their service until it expires. */\n"
       "      'SELECT id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb FROM hotspot_packages WHERE isp_id=$1::uuid AND is_active=true AND visible_in_portal=true ORDER BY price ASC',")
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   portal list now respects visibility")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js OK"
echo "   the purchase route is deliberately unchanged:"
sudo sed -n '374p' "$BE/routes/captive.js" | sed 's/^/     /'

say "4) The ISP's own package list keeps showing everything"
sudo python3 - "$BE/routes/hotspot.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_PKG_VISIBLE_FIELD' in s:
    print("   already patched"); sys.exit(0)
n = 0
m = re.search(r'FROM hotspot_packages WHERE isp_id = \$1 AND is_active = true ORDER BY price ASC', s)
if m:
    seg = s[max(0,m.start()-400):m.start()]
    if 'visible_in_portal' not in seg:
        s = re.sub(r'(SELECT[^`]*?)(\s+FROM hotspot_packages WHERE isp_id = \$1 AND is_active = true)',
                   r'\1, visible_in_portal /* RL_PKG_VISIBLE_FIELD: the ISP sees hidden packages; customers do not */\2',
                   s, count=1)
        n += 1
# accept the flag on create and update
if 'visible_in_portal' not in s or n:
    m2 = re.search(r'INSERT INTO hotspot_packages\s*\(([^)]*)\)\s*VALUES\s*\(([^)]*)\)', s, re.S)
    if m2 and 'visible_in_portal' not in m2.group(1):
        nums = [int(x) for x in re.findall(r'\$(\d+)', m2.group(2))]
        nxt = (max(nums)+1) if nums else 1
        s = s[:m2.start(1)] + m2.group(1).rstrip() + ", visible_in_portal" + s[m2.end(1):]
        m3 = re.search(r'INSERT INTO hotspot_packages\s*\(([^)]*)\)\s*VALUES\s*\(([^)]*)\)', s, re.S)
        s = s[:m3.start(2)] + m3.group(2).rstrip() + f", ${nxt}" + s[m3.end(2):]
        print(f"   INSERT: visible_in_portal as ${nxt} — add the value to the param array")
        n += 1
open(p,'w').write(s); print(f"   {n} edit(s)")
PY
cd "$BE" && sudo -u www-data node --check routes/hotspot.js && echo "   hotspot.js OK"
echo "   ${Y}review the package routes below — the param array may need the value appending${N}"
grep -nE "INSERT INTO hotspot_packages|UPDATE hotspot_packages" "$BE/routes/hotspot.js" | sed 's/^/     /'

say "5) A checkbox on the package form"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'hsp-visible' in s:
    print("   already present"); sys.exit(0)
m = re.search(r'(<input id="hsp-devices"[^>]*>)', s)
if not m:
    print("   ERROR: devices field not found"); sys.exit(1)
field = ('\n    <label style="display:flex;align-items:center;gap:8px;margin-top:12px;cursor:pointer;font-size:.88rem">'
         '<input id="hsp-visible" type="checkbox" checked style="width:16px;height:16px;cursor:pointer" />'
         '<span>Show in captive portal</span></label>'
         '\n    <div style="font-size:.75rem;color:#8b93a3;margin-top:4px">Uncheck for a test package: customers will not see or buy it, '
         'but anyone already on it keeps their service.</div>')
s = s[:m.end()] + field + s[m.end():]

old = "simultaneous_sessions:parseInt(document.getElementById('hsp-devices').value||'1',10)"
if old in s:
    s = s.replace(old, old + ",visible_in_portal:((document.getElementById('hsp-visible')||{}).checked !== false)", 1)
    print("   create payload carries the flag")
open(p,'w').write(s); print("   checkbox added")
PY
sudo chown www-data:www-data "$D"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"

say "6) Restart + prove the portal hides it"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
echo "   packages the portal offers now:"
curl -s "http://127.0.0.1:5000/api/captive/$ISP/packages" 2>/dev/null | head -c 300 | sed 's/^/     /'; echo
echo "   hiding '1 Month' as a test:"
q -c "UPDATE hotspot_packages SET visible_in_portal=false WHERE name='1 Month' RETURNING name, visible_in_portal;"
sleep 1
curl -s "http://127.0.0.1:5000/api/captive/$ISP" 2>/dev/null | tr ',' '\n' | grep -c '"name"' | sed 's/^/     packages returned: /'
echo "   restoring it:"
q -c "UPDATE hotspot_packages SET visible_in_portal=true WHERE name='1 Month' RETURNING name, visible_in_portal;"

say "7) How to use it"
cat <<'EOS'
   Uncheck "Show in captive portal" when creating a test package, or set it directly:
     sudo -u postgres psql -d rumalink_db -c "UPDATE hotspot_packages SET visible_in_portal=false WHERE name='My Test';"

   Customers stop seeing it immediately. You can still buy it yourself by package id, and any
   voucher already issued on it keeps working until it expires.
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Hotspot packages: hide from the captive portal without retiring them" 2>&1 | head -2 | sed 's/^/   /'
