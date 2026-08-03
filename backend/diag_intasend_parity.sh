#!/usr/bin/env bash
# READ ONLY — what the Daraja path does that the IntaSend path does not, plus withdrawal naming.
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The DARAJA callback — the reference implementation (captive.js)"
L=$(grep -n "router.post('/:ispId/callback/:paymentId'" "$BE/routes/captive.js" | head -1 | cut -d: -f1)
echo "   handler starts at line $L"
[ -n "$L" ] && sudo sed -n "${L},$((L+95))p" "$BE/routes/captive.js" | nl -ba -v"$L" \
  | grep -nE "sendPurchaseSms|syncRadiusForVoucher|registerMACAuth|QUEUE-APPLY|hotspotActiveLogin|radius|password|UPDATE hotspot_vouchers|used_by_mac|Pushed" | sed 's/^/     /'

say "2) The INTASEND path — IPN handler and activator"
grep -nE "router.post\('/intasend" "$BE/routes/payments.js" | sed 's/^/   /'
echo "   --- intasend-activate.js: what does it do after activating? ---"
grep -nE "syncRadius|registerMACAuth|sendPurchaseSms|QUEUE|hotspotActiveLogin|radcheck|radreply|used_by_mac|Pushed|addHotspotUser" "$BE/utils/intasend-activate.js" | sed 's/^/     /'
echo "   --- line count / structure ---"
sudo grep -nE "^async function|^function|module.exports" "$BE/utils/intasend-activate.js" | sed 's/^/     /'

say "3) THE AUTOLOGIN CONTRACT — what does payment-status return?"
LS=$(grep -n "payment-status" "$BE/routes/captive.js" | head -1 | cut -d: -f1)
echo "   endpoint at line $LS"
[ -n "$LS" ] && sudo sed -n "${LS},$((LS+55))p" "$BE/routes/captive.js" | nl -ba -v"$LS" | sed 's/^/     /'

say "4) What the PORTAL expects back in order to autologin"
grep -nE "payment-status|autologin|auto_login|radius_user|radius_pass|loginurl|\\\$\\(login|submitLogin|doLogin" "$CP/classic.html" | head -20 | sed 's/^/   /'
echo "   --- the polling block ---"
LP=$(grep -n "payment-status" "$CP/classic.html" | head -1 | cut -d: -f1)
[ -n "$LP" ] && sudo sed -n "$((LP-6)),$((LP+40))p" "$CP/classic.html" | nl -ba -v"$((LP-6))" | sed 's/^/     /'

say "5) Recent IntaSend payment — did the voucher get RADIUS credentials?"
q -c "SELECT LEFT(p.id::text,8) AS pay, p.payment_gateway, p.status,
             v.code, v.password IS NOT NULL AS has_pw, v.used_by_mac, v.status AS v_status,
             p.metadata->>'rl_purchase_sms' AS sms
      FROM payments p LEFT JOIN hotspot_vouchers v ON v.payment_id = p.id
      ORDER BY p.created_at DESC LIMIT 5;"
q -c "SELECT username, attribute FROM radcheck ORDER BY id DESC LIMIT 8;"

say "6) Logs from the most recent IntaSend purchase"
pm2 logs rumalink-backend --lines 600 --nostream 2>/dev/null \
  | grep -iE "intasend|CB-|autologin|poller|captive.*status|purchase-sms" | tail -25 | sed 's/^/   /'

say "7) WITHDRAWALS — what name does IntaSend receive today?"
grep -nE "sendPayout|narrative|reference|company_name|account_name|api_ref" "$BE/routes/withdrawals.js" 2>/dev/null | head -20 | sed 's/^/   /'
echo "   --- the payout client ---"
sudo sed -n '180,215p' "$BE/utils/intasend-client.js" | nl -ba -v180 | sed 's/^/     /'

say "8) Withdrawal records"
q -c "SELECT column_name FROM information_schema.columns WHERE table_name='withdrawals' ORDER BY ordinal_position;" 2>/dev/null | head -25
q -c "SELECT * FROM withdrawals ORDER BY created_at DESC LIMIT 2;" 2>&1 | head -12
