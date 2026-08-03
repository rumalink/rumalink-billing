#!/usr/bin/env bash
# READ ONLY — confirm the SMS balance is the blocker, and locate the paybill option to hide.
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) SMS balance — the real reason the expiry notices stopped"
q -c "SELECT company_name, sms_balance FROM isps;"
q -c "SELECT txn_type, sms_count, isp_balance_after, note, to_char(created_at,'MM-DD HH24:MI') AS at
      FROM sms_credit_transactions ORDER BY created_at DESC LIMIT 8;"
echo "   ${Y}sendSMS refuses below 1 credit; every message costs 1.${N}"
echo "   messages that failed for balance in the last hour:"
pm2 logs rumalink-backend --lines 400 --nostream 2>/dev/null | grep -c "Insufficient SMS balance" | sed 's/^/     /'

say "2) Is the ISP warned when the balance runs low?"
grep -rn "SMS_BALANCE_EMPTY\|sms_balance" "$BE/utils" "$BE/routes" --include=*.js 2>/dev/null \
  | grep -v -E 'node_modules|\.bak' | grep -iE "warn|alert|notify|low" | sed 's/^/   /' \
  || echo "   ${Y}nothing warns the ISP before it hits zero — messages just stop${N}"

say "3) The PPPoE portal file"
ls -la --time-style=long-iso "$CP/pppoe.html" | sed 's/^/   /'
echo "   lines: $(sudo wc -l < "$CP/pppoe.html")"

say "4) Every payment-option reference in the PPPoE portal"
sudo grep -nE "paybill|Paybill|PayBill|till|Till|mpesa|M-Pesa|stk|STK|method_type" "$CP/pppoe.html" | sed 's/^/   /'

say "5) The payment-option markup block"
L=$(sudo grep -niE "paybill" "$CP/pppoe.html" | head -1 | cut -d: -f1)
if [ -n "$L" ]; then
  echo "   --- lines $((L-25))..$((L+25)) ---"
  sudo sed -n "$((L-25)),$((L+25))p" "$CP/pppoe.html" | nl -ba -v"$((L-25))" | sed 's/^/   /'
else
  echo "   ${Y}no 'paybill' text in pppoe.html — the option may be rendered from the API${N}"
  echo "   payment methods the API returns for this ISP:"
  q -c "SELECT method_type, label, till_number, paybill_number, is_active, is_default FROM isp_payment_methods;"
fi

say "6) Does the portal render options from /api/payment-methods or the captive config?"
sudo grep -nE "fetch\(|/api/" "$CP/pppoe.html" | head -15 | sed 's/^/   /'

say "7) Any element ids/classes usable as a hide target"
sudo grep -oE 'id="[a-zA-Z0-9_-]*(pay|method|bill|till)[a-zA-Z0-9_-]*"' "$CP/pppoe.html" | sort -u | sed 's/^/   /'
sudo grep -oE 'class="[^"]*(pay|method)[^"]*"' "$CP/pppoe.html" | sort -u | head -10 | sed 's/^/   /'
