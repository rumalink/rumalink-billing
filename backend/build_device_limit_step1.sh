#!/usr/bin/env bash
#
# build_device_limit_step1.sh — per-package simultaneous device limit.
#
# Already present: hotspot_packages.simultaneous_sessions (default 1), FreeRADIUS
# `session { -sql }`, and a populated radacct. Missing: nothing writes Simultaneous-Use, the
# SQL module may lack the counting query, and the package form has no field.
#
# This step: verify FreeRADIUS can actually COUNT sessions, then write Simultaneous-Use on every
# voucher RADIUS sync. Building the UI on top of an unenforced attribute would be the same trap
# as a queue that looks configured and shapes nothing.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) CAN FreeRADIUS count live sessions? (simul_count_query)"
sudo grep -nE "simul_count_query|simul_verify_query" /etc/freeradius/3.0/mods-enabled/sql /etc/freeradius/3.0/mods-config/sql/main/postgresql/queries.conf 2>/dev/null | sed 's/^/   /' || echo "   ${Y}no simul_count_query found${N}"
echo "   --- the session section that runs it ---"
sudo awk '/^session \{/,/^\}/' /etc/freeradius/3.0/sites-enabled/default 2>/dev/null | sed 's/^/   /'
echo "   ${Y}'-sql' means: use sql, but do not fail if it errors. The count query must exist.${N}"

say "2) Package + voucher plumbing that exists"
q -c "SELECT name, simultaneous_sessions FROM hotspot_packages ORDER BY duration_hours;"
q -c "SELECT count(*) AS radcheck_rows_with_simul FROM radcheck WHERE attribute='Simultaneous-Use';"

say "3) Where vouchers get their RADIUS entries (the place to add the attribute)"
grep -n "async function syncRadiusForVoucher\|function syncRadiusForVoucher" "$BE/routes/captive.js" | sed 's/^/   /'
L=$(grep -n "syncRadiusForVoucher" "$BE/routes/captive.js" | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "${L},$((L+55))p" "$BE/routes/captive.js" | nl -ba -v"$L" | sed 's/^/   /'

say "4) The IntaSend sync (second writer of the same rows)"
sudo sed -n '8,56p' "$BE/utils/intasend-activate.js" | nl -ba -v8 | sed 's/^/   /'

say "5) Where packages are created / updated"
grep -nE "INSERT INTO hotspot_packages|UPDATE hotspot_packages" "$BE/routes/isp.js" | sed 's/^/   /'
for LN in $(grep -nE "INSERT INTO hotspot_packages|UPDATE hotspot_packages" "$BE/routes/isp.js" | cut -d: -f1); do
  echo "   --- around line $LN ---"
  sudo sed -n "$((LN-14)),$((LN+14))p" "$BE/routes/isp.js" | nl -ba -v"$((LN-14))" | sed 's/^/     /'
done

say "6) The package form in the ISP dashboard"
grep -nE "hotspot.*package|addPackage|savePackage|pkgModal|package-modal" /var/www/rumalink/isp/dashboard.html 2>/dev/null | head -12 | sed 's/^/   /'
grep -oE 'id="[a-zA-Z0-9_-]*(pkg|package)[a-zA-Z0-9_-]*"' /var/www/rumalink/isp/dashboard.html 2>/dev/null | sort -u | sed 's/^/   /'

say "7) Live test — does Simultaneous-Use actually block a second session?"
echo "   current open sessions per user:"
q -c "SELECT username, count(*) AS open_sessions FROM radacct WHERE acctstoptime IS NULL GROUP BY username ORDER BY 2 DESC LIMIT 8;"
echo "   ${Y}if a user already shows 2+ open sessions with simultaneous_sessions=1,${N}"
echo "   ${Y}nothing is enforcing the limit today.${N}"
