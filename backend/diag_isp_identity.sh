#!/usr/bin/env bash
# READ ONLY — the ISP id changed. Find what still points at the OLD id, and pick a portal restore point.
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
OLD=98d7ba07-2dd2-42d0-819e-e438ea390565
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The ISP record(s)"
q -c "SELECT id, company_name, created_at, hotspot_counter FROM isps ORDER BY created_at;"
NEW=$(q -tAc "SELECT id FROM isps LIMIT 1;")
echo "   NEW id: $NEW"
echo "   OLD id: $OLD"

say "2) What still references the OLD id?"
for t in nas_devices hotspot_vouchers hotspot_packages payments pppoe_subscribers hotspot_bound_devices notifications isp_payment_methods sms_credit_transactions; do
  o=$(q -tAc "SELECT count(*) FROM $t WHERE isp_id='$OLD'::uuid;" 2>/dev/null || echo "-")
  n=$(q -tAc "SELECT count(*) FROM $t WHERE isp_id='$NEW'::uuid;" 2>/dev/null || echo "-")
  printf "   %-26s old=%-5s new=%-5s\n" "$t" "$o" "$n"
done

say "3) The router — which ISP does it belong to?"
q -c "SELECT id, name, isp_id, wireguard_ip, is_online, provision_token IS NOT NULL AS has_token,
             LEFT(secret,10)||'…' AS secret FROM nas_devices;"

say "4) Vouchers and packages"
q -c "SELECT code, is_tv, status, isp_id, package_id FROM hotspot_vouchers ORDER BY created_at DESC LIMIT 8;"
q -c "SELECT id, isp_id, name, price, duration_hours FROM hotspot_packages;"

say "5) RADIUS entries — which realm suffix are they using?"
q -c "SELECT username, attribute FROM radcheck ORDER BY id DESC LIMIT 10;"
echo "   ${Y}realm is the first 8 chars of the ISP id: old=98d7ba07  new=5a378a4e${N}"

say "6) Full captive config the portal receives"
curl -s "http://127.0.0.1:5000/api/captive/$NEW" | head -c 1200 | sed 's/^/   /'
echo

say "7) How does the backend choose the payment gateway?"
grep -nE "isp_payment_methods|method_type|use_admin_credentials|intasend|jenga|daraja" "$BE/routes/captive.js" 2>/dev/null | head -25 | sed 's/^/   /'

say "8) Which classic.html backup is the best restore point?"
printf "   %-46s %-6s %-7s %-9s %-9s %-6s\n" FILE LINES TVSEL AUTOLOGIN PAYMETH DATE
for f in "$CP/classic.html" $(sudo ls -1t $CP/classic.html.*bak* 2>/dev/null | head -8); do
  L=$(sudo wc -l < "$f" 2>/dev/null)
  T=$(sudo grep -c "rlCurrentTv" "$f" 2>/dev/null || true)
  A=$(sudo grep -c "autologin" "$f" 2>/dev/null || true)
  P=$(sudo grep -c "payment-methods\|payment_method" "$f" 2>/dev/null || true)
  D=$(stat -c '%y' "$f" | cut -d'.' -f1)
  printf "   %-46s %-6s %-7s %-9s %-9s %s\n" "$(basename $f)" "${L:-?}" "${T:-0}" "${A:-0}" "${P:-0}" "$D"
done

say "9) Does the current portal still work end to end?"
echo "   packages endpoint:"
curl -s -o /tmp/pk.out -w "     HTTP %{http_code}  " "http://127.0.0.1:5000/api/captive/$NEW/packages"; head -c 200 /tmp/pk.out; echo
echo "   TV list endpoint:"
curl -s -o /tmp/tv.out -w "     HTTP %{http_code}  " "http://127.0.0.1:5000/api/captive/$NEW/devices"; head -c 200 /tmp/tv.out; echo
