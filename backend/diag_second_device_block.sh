#!/usr/bin/env bash
# READ ONLY — why a second device on a 2-device package is bounced to the purchase page.
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The package and its voucher"
q -c "SELECT name, duration_hours, simultaneous_sessions FROM hotspot_packages ORDER BY duration_hours;"
q -c "SELECT code, is_tv, used_by_mac, purchased_by_mac, status, expires_at
      FROM hotspot_vouchers ORDER BY created_at DESC LIMIT 5;"
q -c "SELECT username, attribute, value FROM radcheck WHERE attribute='Simultaneous-Use' ORDER BY username LIMIT 6;"

say "2) Where a voucher login / validation checks the MAC"
grep -nE "used_by_mac" "$BE/routes/captive.js" | sed 's/^/   /'
echo "   --- the validate / login endpoints ---"
grep -nE "router\.(post|get)\('/[^']*(validate|login|voucher|check)" "$BE/routes/captive.js" | sed 's/^/   /'

say "3) The voucher-check route in full"
L=$(grep -nE "router\.post\('/:ispId/validate-voucher'|router\.post\('/:ispId/voucher" "$BE/routes/captive.js" | head -1 | cut -d: -f1)
if [ -n "$L" ]; then
  sudo sed -n "${L},$((L+70))p" "$BE/routes/captive.js" | nl -ba -v"$L" | sed 's/^/   /'
else
  echo "   ${Y}no validate-voucher route — the portal may log in via RADIUS directly${N}"
  grep -nE "rlHotspotLogin|login\?username|/login" "$CP/classic.html" | head -10 | sed 's/^/   /'
fi

say "4) What the portal does with an existing voucher code"
grep -nE "voucher|code" "$CP/classic.html" | grep -iE "fetch|submit|validate|login" | head -12 | sed 's/^/   /'

say "5) MAC auto-login registration — is it single-MAC?"
grep -nE "registerMACAuth|used_by_mac|callingstationid|Calling-Station" "$BE/utils/macAuth.js" 2>/dev/null | head -15 | sed 's/^/   /'
q -c "SELECT username, attribute, value FROM radcheck WHERE username ~ '^[0-9A-Fa-f:]{17}$' ORDER BY username LIMIT 8;"

say "6) Did the second device even reach RADIUS?"
q -c "SELECT username, reply, authdate, calledstationid FROM radpostauth ORDER BY authdate DESC LIMIT 10;"
echo "   --- open sessions per username ---"
q -c "SELECT username, count(*) AS sessions, string_agg(DISTINCT callingstationid, ', ') AS macs
      FROM radacct WHERE acctstoptime IS NULL GROUP BY username ORDER BY 2 DESC LIMIT 6;"

say "7) FreeRADIUS log for the attempt"
sudo tail -40 /var/log/freeradius/radius.log 2>/dev/null | grep -iE "login|reject|multiple|simultaneous|incorrect" | tail -12 | sed 's/^/   /' || echo "   (no radius.log lines)"

say "8) Backend log during the second-device attempt"
pm2 logs rumalink-backend --lines 300 --nostream 2>/dev/null \
  | grep -iE "voucher|validate|captive|already|in use|bound" | tail -15 | sed 's/^/   /'
