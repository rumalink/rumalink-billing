#!/usr/bin/env bash
# READ ONLY — does the Daraja callback fire, and what does sendPurchaseSms actually return?
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Did the callback handler EVER run? (CB-START / CB-VOUCHER)"
pm2 logs rumalink-backend --lines 2000 --nostream 2>/dev/null \
  | grep -iE "CB-START|CB-VOUCHER|Voucher .* activated|purchase-sms|activate-safetynet|fastConfirm" | tail -20 | sed 's/^/   /' \
  || echo "   ${Y}NOTHING — the callback handler has not run at all${N}"

say "2) The most recent paid payment, and its voucher link"
q -c "SELECT LEFT(p.id::text,8) AS pay, p.status, p.transaction_id, p.paid_at,
             p.metadata->>'is_tv' AS is_tv, p.metadata->>'tv_mac' AS tv_mac,
             p.metadata->>'rl_purchase_sms' AS sms_flag
      FROM payments p ORDER BY p.created_at DESC LIMIT 3;"
echo "   --- is there a voucher pointing at it? (the SMS query joins on this) ---"
q -c "SELECT v.code, v.is_tv, v.status, LEFT(v.payment_id::text,8) AS pay, v.buyer_phone, v.expires_at
      FROM hotspot_vouchers v ORDER BY v.updated_at DESC NULLS LAST LIMIT 6;"

say "3) DIRECT TEST — run sendPurchaseSms for the newest paid payment and print the result"
PID=$(q -tAc "SELECT id FROM payments WHERE status='paid' ORDER BY created_at DESC LIMIT 1;")
echo "   payment: $PID"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
(async()=>{
  const hs = require('$BE/utils/hotspotSms');
  const r = await hs.sendPurchaseSms('$PID');
  console.log('   result: ' + JSON.stringify(r));
  process.exit(0);
})();" 2>&1 | grep -vE "^info: SMS|^warn:" | sed 's/^/  /'
echo "   ${Y}'no voucher for payment' => the join fails: no voucher has this payment_id.${N}"

say "4) What marks a payment paid, if not the callback?"
grep -rnE "status\s*=\s*'paid'|status='paid'" "$BE/routes/"*.js "$BE/utils/"*.js 2>/dev/null \
  | grep -v -E 'node_modules|\.bak' | head -12 | sed 's/^/   /'

say "5) Is the callback URL reachable from outside?"
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
echo "   BASE_URL in .env:"; sudo grep -oE '^BASE_URL=.*' "$BE/.env" | sed 's/^/     /'
echo "   the URL given to Safaricom:"
echo "     \$BASE_URL/api/captive/$ISP/callback/<paymentId>"
curl -sk -o /dev/null -w "   public reachability test -> HTTP %{http_code} (404/400 is fine; 000 = unreachable)\n" \
  -X POST "https://rumalinkenterprise.online/api/captive/$ISP/callback/00000000-0000-0000-0000-000000000000" \
  -H 'Content-Type: application/json' -d '{"Body":{"stkCallback":{"ResultCode":1,"ResultDesc":"test"}}}' || true

say "6) Does the STK push actually use the ISP's own creds + that callback?"
sudo sed -n '680,700p' "$BE/routes/captive.js" | nl -ba -v680 | sed 's/^/   /'

say "7) Any poller that confirms mpesa payments without the callback?"
grep -rnE "queryStkStatus|stkQuery|fastConfirm|confirmPending|POLL" "$BE/utils/"*.js "$BE/routes/"*.js 2>/dev/null \
  | grep -v -E 'node_modules|\.bak' | head -12 | sed 's/^/   /'

say "8) PPPoE renewal SMS — where would it come from?"
sudo ls -1 "$BE/utils" | grep -iE "pppoe|sms" | sed 's/^/   /'
grep -rnE "sendSMS|sendSms" "$BE/routes/pppoePortal.js" "$BE/utils/pppoe"*.js 2>/dev/null | head -10 | sed 's/^/   /' \
  || echo "   ${Y}no SMS call in the PPPoE payment path — renewals would never notify${N}"
