#!/usr/bin/env bash
# READ ONLY — who actually receives each SMS, and why PPPoE renewals/expiry send nothing.
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Is 0740258495 hardcoded anywhere?"
grep -rnE "0740258495|254740258495" "$BE" --include=*.js 2>/dev/null | grep -v -E 'node_modules|\.bak' | sed 's/^/   /' || echo "   ${G}not hardcoded in any .js${N}"
sudo grep -rn "0740258495\|254740258495" /usr/local/bin/rumalink-*.sh "$BE/.env" 2>/dev/null | sed 's/^/   /' || echo "   not in scripts or .env"
echo "   any other hardcoded Kenyan numbers:"
grep -rnE "'(0|254)7[0-9]{8}'|\"(0|254)7[0-9]{8}\"" "$BE" --include=*.js 2>/dev/null | grep -v -E 'node_modules|\.bak' | head -10 | sed 's/^/   /' || echo "   none"

say "2) Who does the OTP go to?"
sudo sed -n '40,75p' "$BE/utils/verification.js" | nl -ba -v40 | sed 's/^/   /'
echo "   --- callers of the verification sender ---"
grep -rn "sendPhoneOtp\|sendOtp\|startVerification" "$BE/routes" --include=*.js 2>/dev/null | grep -v -E '\.bak' | head -8 | sed 's/^/   /'

say "3) Current ISP record + who the failover alert would text"
q -c "SELECT id, company_name, owner_name, phone, email FROM isps;"
q -c "SELECT id, phone, email FROM admins;" 2>&1 | head -5
echo "   --- ispAlert recipient logic ---"
sudo grep -n "phone\|normalizePhone\|SELECT id, company_name" "$BE/utils/ispAlert.js" | sed 's/^/   /'

say "4) Recent SMS — who actually received them?"
q -c "SELECT recipient, gateway, status, LEFT(message,46) AS msg, to_char(sent_at,'MM-DD HH24:MI') AS at
      FROM sms_logs ORDER BY sent_at DESC LIMIT 12;"
q -c "SELECT recipient, count(*) FROM sms_logs GROUP BY recipient ORDER BY 2 DESC;"

say "5) PPPoE — does ANY code send SMS to a subscriber?"
grep -rn "sendSMS\|sendSms\|sendSmsCompat" "$BE/routes/pppoePortal.js" "$BE/routes/pppoe.js" "$BE/utils/pppoe"*.js 2>/dev/null | grep -v -E '\.bak' | sed 's/^/   /' || echo "   ${Y}NONE — PPPoE never sends SMS${N}"
echo "   --- pppoe cron / expiry paths ---"
grep -rn "pppoe" "$BE/utils/cron.js" | grep -iE "expir|sms|renew|notify" | sed 's/^/   /' || echo "   (no pppoe SMS in cron)"
grep -rn "onPaid" "$BE/routes/pppoePortal.js" | sed 's/^/   /'

say "6) The subscriber table — is there a phone to text?"
q -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='pppoe_subscribers' ORDER BY ordinal_position;"
q -c "SELECT id, username, name, phone, status, next_billing_date FROM pppoe_subscribers;" 2>&1 | head -8

say "7) What the hotspot expiry SMS does (the model to copy for PPPoE)"
sudo sed -n '10,40p' "$BE/utils/cron.js" | nl -ba -v10 | sed 's/^/   /'

say "8) PPPoE payment flow — where a renewal is confirmed"
L=$(grep -n "async function onPaid" "$BE/routes/pppoePortal.js" | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "${L},$((L+50))p" "$BE/routes/pppoePortal.js" | nl -ba -v"$L" | sed 's/^/   /'
