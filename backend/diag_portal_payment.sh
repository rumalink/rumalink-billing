#!/usr/bin/env bash
# READ ONLY — why doesn't the captive portal reflect the ISP's chosen payment method?
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "0) Clear stale PM2 logs so future output is unambiguous"
sudo pm2 flush rumalink-backend >/dev/null 2>&1 && echo "   flushed"

say "1) Where is the ISP's payment method stored?"
q -c "SELECT column_name FROM information_schema.columns WHERE table_name='isps' AND (column_name ILIKE '%pay%' OR column_name ILIKE '%gateway%' OR column_name ILIKE '%mpesa%' OR column_name ILIKE '%intasend%' OR column_name ILIKE '%jenga%') ORDER BY 1;"
echo "   --- payment_methods / provider tables ---"
q -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ILIKE '%payment%' OR table_name ILIKE '%mpesa%') ORDER BY 1;"
for t in payment_methods isp_payment_methods mpesa_configs; do
  echo "   --- $t ---"; q -c "SELECT * FROM $t LIMIT 5;" 2>&1 | head -12 | sed 's/^/     /'
done

say "2) What the portal endpoint actually returns"
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
echo "   isp: $ISP"
for U in "/api/payment-methods/" "/api/payment-methods/$ISP" "/api/captive/$ISP/config" "/api/captive/$ISP"; do
  printf "   %-42s " "$U"
  curl -s -o /tmp/pm.out -w "HTTP %{http_code}  " "http://127.0.0.1:5000$U" || true
  head -c 220 /tmp/pm.out | tr '\n' ' '; echo
done

say "3) paymentMethods.js — the routes it exposes"
sudo grep -nE "router\.(get|post|put)\(|module.exports" "$BE/routes/paymentMethods.js" 2>/dev/null | head -20 | sed 's/^/   /'
echo "   --- does it scope by ISP? ---"
sudo grep -nE "isp_id|ispId|req\.params" "$BE/routes/paymentMethods.js" 2>/dev/null | head -12 | sed 's/^/   /'

say "4) What classic.html asks for, and how it decides which method to show"
sudo grep -nE "payment-methods|payment_method|gateway|intasend|jenga|daraja|mpesa" "$CP/classic.html" 2>/dev/null | head -25 | sed 's/^/   /'

say "5) Compare current classic.html with the backups"
echo "   current: $(stat -c '%y  %s bytes' $CP/classic.html)"
for b in $(sudo ls -1t $CP/classic.html.*bak* 2>/dev/null | head -5); do
  printf "   %-52s %s\n" "$(basename $b)" "$(stat -c '%y  %s bytes' $b | cut -d'.' -f1,3)"
done
echo
echo "   --- line-count delta vs the newest backups ---"
for b in $(sudo ls -1t $CP/classic.html.*bak* 2>/dev/null | head -3); do
  printf "   %-52s cur=%s bak=%s  difflines=%s\n" "$(basename $b)" \
    "$(wc -l < $CP/classic.html)" "$(sudo wc -l < $b)" \
    "$(sudo diff <(sudo cat $CP/classic.html) <(sudo cat $b) 2>/dev/null | grep -c '^[<>]')"
done

say "6) What changed in the payment area specifically (newest backup vs current)"
NB=$(sudo ls -1t $CP/classic.html.*bak* 2>/dev/null | head -1)
if [ -n "$NB" ]; then
  echo "   comparing against: $(basename $NB)"
  sudo diff <(sudo grep -nE "payment-methods|payment_method|gateway|intasend|jenga" "$NB" 2>/dev/null) \
            <(sudo grep -nE "payment-methods|payment_method|gateway|intasend|jenga" "$CP/classic.html" 2>/dev/null) \
    | head -30 | sed 's/^/     /' || echo "     (no differences in payment lines)"
fi

say "7) Do the key portal features still exist in the current file?"
for m in "rlCurrentTv" "tv_mac" "is_tv" "payment-methods" "package_id" "validate-voucher" "autologin"; do
  n=$(sudo grep -c "$m" "$CP/classic.html" 2>/dev/null || true)
  printf "   %-18s %s\n" "$m" "${n:-0}"
done

say "8) Live portal fetch — what a phone would receive"
curl -sk "https://rumalinkenterprise.online/captive/classic.html?isp=$ISP" -o /tmp/portal.html -w "   HTTP %{code_effective:-}%{http_code}  %{size_download} bytes\n" || true
grep -oE "payment-methods[^\"']{0,60}" /tmp/portal.html 2>/dev/null | head -5 | sed 's/^/     /' || echo "     (no payment-methods reference served)"
