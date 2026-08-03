#!/usr/bin/env bash
# READ ONLY — what would it take to allow N simultaneous devices per package?
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Package schema — is there any device-count column already?"
q -c "SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_name='hotspot_packages' ORDER BY ordinal_position;"
echo "   --- pppoe_packages ---"
q -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='pppoe_packages' ORDER BY ordinal_position;" 2>&1 | head -20

say "2) Existing anti-sharing / device-limit machinery"
q -c "SELECT column_name FROM information_schema.columns WHERE table_name='nas_devices' AND column_name ILIKE '%antishare%';"
q -c "SELECT name, antishare_enabled, antishare_max_devices FROM nas_devices;" 2>&1
grep -rn "antishare" "$BE/routes" "$BE/utils" --include=*.js 2>/dev/null | grep -v -E 'node_modules|\.bak' | head -12 | sed 's/^/   /'

say "3) How a voucher binds to a device today"
q -c "SELECT column_name FROM information_schema.columns WHERE table_name='hotspot_vouchers' AND (column_name ILIKE '%mac%' OR column_name ILIKE '%device%');"
echo "   --- Simultaneous-Use anywhere in RADIUS? ---"
q -c "SELECT username, attribute, op, value FROM radcheck WHERE attribute ILIKE '%simultaneous%';" 2>&1
q -c "SELECT groupname, attribute, value FROM radgroupcheck;" 2>&1 | head -10
grep -rn "Simultaneous-Use" "$BE" --include=*.js 2>/dev/null | grep -v -E 'node_modules|\.bak' | sed 's/^/   /' || echo "   not referenced in the backend"

say "4) Does FreeRADIUS have the session/simultaneous-use machinery enabled?"
sudo grep -nE "^\s*(session|sql|radutmp)" /etc/freeradius/3.0/sites-enabled/default 2>/dev/null | sed 's/^/   /'
echo "   --- session section ---"
sudo awk '/^session \{/,/^\}/' /etc/freeradius/3.0/sites-enabled/default 2>/dev/null | sed 's/^/   /'
echo "   --- is radacct populated (needed to count live sessions)? ---"
q -c "SELECT count(*) AS open_sessions FROM radacct WHERE acctstoptime IS NULL;"
q -c "SELECT username, callingstationid, acctstarttime FROM radacct WHERE acctstoptime IS NULL ORDER BY acctstarttime DESC LIMIT 5;"

say "5) Where packages are created/edited in the ISP dashboard"
grep -nE "router\.(post|put)\('/packages|hotspot_packages" "$BE/routes/isp.js" 2>/dev/null | head -12 | sed 's/^/   /'
echo "   --- the package form fields in the dashboard ---"
grep -oE 'id="pkg-[a-zA-Z0-9_-]+"' /var/www/rumalink/isp/dashboard.html 2>/dev/null | sort -u | sed 's/^/   /'

say "6) Current packages"
q -c "SELECT id, name, price, duration_hours, bandwidth_up_mbps, bandwidth_down_mbps FROM hotspot_packages;"

say "7) How MAC auto-login binds devices (the current 1-device behaviour)"
grep -nE "registerMACAuth|used_by_mac|purchased_by_mac" "$BE/utils/macAuth.js" 2>/dev/null | head -12 | sed 's/^/   /'
echo "   --- does anything limit how many MACs a voucher can serve? ---"
grep -rnE "one device|single device|already in use|device limit|max_devices" "$BE/routes/captive.js" "$BE/utils/macAuth.js" 2>/dev/null | head -10 | sed 's/^/   /' || echo "   no explicit limit found"
