#!/usr/bin/env bash
#
# restore_portal.sh — restore classic.html to the last complete version and verify the
# payment path against the ISP's configured method.
#
# FINDINGS: the backend is healthy — /api/captive/:ispId already returns the ISP's chosen
# payment_methods (mpesa_stk / 4322307). The damage is in the portal: the current file is
# 1288 lines with ZERO rlCurrentTv references, while every version up to 2026-08-01 15:59 is
# 1336 lines with the TV-selection logic intact. All data consistently points at the current
# ISP id, so nothing needs re-pointing.
#
set -uo pipefail
CP=/var/www/rumalink/captive
BE=/var/www/rumalink/backend
TS=$(date +%s)
SRC="$CP/classic.html.bak_macfix2"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) What differs between the current file and the restore candidate"
sudo cp "$CP/classic.html" /tmp/cur.html
sudo cp "$SRC" /tmp/cand.html
echo "   current   : $(wc -l < /tmp/cur.html) lines"
echo "   candidate : $(wc -l < /tmp/cand.html) lines  ($(basename $SRC), $(stat -c '%y' $SRC | cut -d'.' -f1))"
echo "   --- functions present in candidate but MISSING from current ---"
grep -oE "function [A-Za-z_][A-Za-z0-9_]*" /tmp/cand.html | sort -u > /tmp/f_cand
grep -oE "function [A-Za-z_][A-Za-z0-9_]*" /tmp/cur.html  | sort -u > /tmp/f_cur
comm -23 /tmp/f_cand /tmp/f_cur | sed 's/^/     /' || echo "     (none)"
echo "   --- functions in current but not in candidate (work we would LOSE) ---"
comm -13 /tmp/f_cand /tmp/f_cur | sed 's/^/     /' || echo "     (none)"

say "2) Key markers side by side"
printf "   %-24s %-10s %-10s\n" MARKER CURRENT CANDIDATE
for m in rlCurrentTv tv_mac is_tv payment_methods "/pay" validate-voucher package_id showMsg selectedPackage; do
  a=$(grep -c -- "$m" /tmp/cur.html || true); b=$(grep -c -- "$m" /tmp/cand.html || true)
  printf "   %-24s %-10s %-10s\n" "$m" "${a:-0}" "${b:-0}"
done

say "3) Backup the current file, then restore"
sudo cp "$CP/classic.html" "$CP/.classic.html.broken_$TS" && echo "   current saved as .classic.html.broken_$TS"
sudo cp "$SRC" "$CP/classic.html"
sudo chown www-data:www-data "$CP/classic.html"
echo "   restored: $(wc -l < $CP/classic.html) lines"

say "4) Verify the restored portal"
for m in rlCurrentTv tv_mac is_tv validate-voucher; do
  printf "   %-20s %s\n" "$m" "$(sudo grep -c -- "$m" "$CP/classic.html" || true)"
done
echo "   --- how it submits a purchase ---"
sudo grep -nE "fetch\(.*(pay|purchase)" "$CP/classic.html" | head -6 | sed 's/^/     /'

say "5) Does the portal read the ISP's payment methods?"
sudo grep -nE "payment_methods|paymentMethods|method_type|till_number|paybill" "$CP/classic.html" | head -12 | sed 's/^/   /' \
  || echo "   ${Y}the portal does not read payment_methods directly — the server chooses the gateway${N}"

say "6) Server-side gateway routing (this is what 'syncs' with the ISP's choice)"
if [ -f "$BE/utils/paymentRoute.js" ]; then
  echo "   utils/paymentRoute.js present:"
  sudo grep -nE "method_type|intasend|jenga|daraja|mpesa_stk|return" "$BE/utils/paymentRoute.js" | head -20 | sed 's/^/     /'
else
  echo "   ${Y}utils/paymentRoute.js MISSING — captive.js line 576 requires it${N}"
fi
echo "   --- the routing decision in captive.js ---"
L=$(sudo grep -n "_route.gateway" "$BE/routes/captive.js" | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "$((L-14)),$((L+4))p" "$BE/routes/captive.js" | nl -ba -v"$((L-14))" | sed 's/^/     /'

say "7) Live check — what a phone gets"
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
curl -sk -o /dev/null -w "   portal HTTP %{http_code}\n" "https://rumalinkenterprise.online/captive/classic.html?isp=$ISP"
echo "   config endpoint payment_methods:"
curl -s "http://127.0.0.1:5000/api/captive/$ISP" 2>/dev/null | tr ',' '\n' | grep -iE "method_type|label|enable_tv" | head -6 | sed 's/^/     /'

say "8) State summary"
q -c "SELECT company_name, id, hotspot_counter FROM isps;"
q -c "SELECT name, wireguard_ip, is_online FROM nas_devices;"
q -c "SELECT method_type, label, is_active, is_default FROM isp_payment_methods;"
echo
echo "   ${Y}Test now: open the portal on the phone, pick a package, confirm the STK prompt arrives.${N}"
echo "   Rollback: sudo cp $CP/.classic.html.broken_$TS $CP/classic.html"
