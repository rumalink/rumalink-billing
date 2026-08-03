#!/usr/bin/env bash
# READ ONLY — why is no SMS sent on purchase (hotspot TV/phone and PPPoE renewal)?
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Recent payments — which gateway, and did the SMS flag get set?"
q -c "SELECT LEFT(id::text,8) AS id, payment_method, payment_gateway, status,
             metadata->>'rl_purchase_sms' AS sms_flag, metadata->>'is_tv' AS is_tv,
             transaction_id IS NOT NULL AS receipt, to_char(created_at,'MM-DD HH24:MI') AS at
      FROM payments ORDER BY created_at DESC LIMIT 8;"

say "2) SMS credit + gateway config"
q -c "SELECT company_name, sms_balance, COALESCE(NULLIF(sms_gateway,''),'(unset -> rumalink)') AS gateway FROM isps;"
q -c "SELECT provider, is_active, (api_key IS NOT NULL AND api_key<>'') AS has_key, sender_id, base_url FROM sms_provider_config;"
echo "   ${Y}sms_balance must be >= 1 for the rumalink gateway to send.${N}"

say "3) sms_logs — the last 10 attempts (failures included)"
q -c "SELECT recipient, gateway, status, LEFT(message,44) AS msg, to_char(sent_at,'MM-DD HH24:MI:SS') AS at
      FROM sms_logs ORDER BY sent_at DESC LIMIT 10;"
q -c "SELECT status, count(*) FROM sms_logs GROUP BY status;"

say "4) Who calls sendPurchaseSms?"
grep -rn "sendPurchaseSms" "$BE" --include=*.js 2>/dev/null | grep -v -E 'node_modules|/\.|\.bak' | sed 's/^/   /'

say "5) Does the DARAJA callback path send it?"
echo "   --- daraja / stk callback handlers in captive.js ---"
grep -nE "stkCallback|daraja|mpesa/callback|router\.post.*callback|ResultCode" "$BE/routes/captive.js" | head -15 | sed 's/^/     /'
L=$(grep -n "stkCallback" "$BE/routes/captive.js" | head -1 | cut -d: -f1)
if [ -n "$L" ]; then
  echo "   --- lines $L..$((L+60)) : does it activate + send SMS? ---"
  sudo sed -n "${L},$((L+60))p" "$BE/routes/captive.js" | grep -nE "sendPurchaseSms|syncRadius|activate|status='paid'|UPDATE payments|voucher" | sed 's/^/     /'
fi

say "6) Which callback URL does the Daraja push tell Safaricom to use?"
grep -nE "CallBackURL|callbackUrl" "$BE/routes/captive.js" "$BE/utils/"*.js 2>/dev/null | grep -v -E 'node_modules|\.bak' | head -10 | sed 's/^/   /'
echo "   --- is that route mounted? ---"
grep -nE "app.use\('/api/payments" "$BE/server.js" | sed 's/^/   /'
grep -nE "router\.post\('/(mpesa|daraja|stk)" "$BE/routes/payments.js" 2>/dev/null | head -8 | sed 's/^/   /'

say "7) PPPoE renewal — does onPaid send SMS?"
grep -nE "sendSms|sendSMS|sendPurchaseSms|Sms" "$BE/routes/pppoePortal.js" 2>/dev/null | head -12 | sed 's/^/   /'

say "8) Backend log — any SMS activity or errors at all?"
pm2 logs rumalink-backend --lines 400 --nostream 2>/dev/null \
  | grep -iE "purchase-sms|SMS sent|SMS failed|sms-log|Insufficient SMS" | tail -12 | sed 's/^/   /' || echo "   ${Y}(no SMS activity logged at all — the sender is never reached)${N}"

say "9) Live test — send one SMS through the current code"
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
read -r -p "   Phone to test (blank to skip): " T || true
if [ -n "${T:-}" ]; then
  sudo -u www-data node -e "
  require('dotenv').config({path:'$BE/.env'});
  const {query}=require('$BE/config/database');
  const {sendSMS}=require('$BE/utils/sms');
  (async()=>{
    const isp=(await query('SELECT * FROM isps WHERE id=\$1::uuid',['$ISP'])).rows[0];
    try{ await sendSMS({to:'$T',message:(isp.company_name||'RumaLink')+': SMS path test.',isp});
      console.log('   SENT'); }catch(e){ console.log('   FAILED: '+e.message); }
    process.exit(0);
  })();" 2>&1 | grep -vE "^info:|^warn:" | sed 's/^/  /'
else echo "   skipped"; fi
