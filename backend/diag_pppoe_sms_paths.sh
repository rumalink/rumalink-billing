#!/usr/bin/env bash
# READ ONLY — what PPPoE SMS exists today, and what the OTP route actually targets.
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) OTP — who calls issueCode, and with what target?"
grep -rn "issueCode" "$BE/routes" "$BE/utils" --include=*.js 2>/dev/null | grep -v -E '\.bak' | sed 's/^/   /'
for f in "$BE/routes/verification.js"; do
  echo "   --- $(basename $f): the phone branch ---"
  sudo grep -nE "issueCode|phone|req.body|isp.phone|owner" "$f" 2>/dev/null | head -20 | sed 's/^/     /'
done
echo "   --- signup: is verification started with the ENTERED number? ---"
grep -nE "issueCode|verification|phone" "$BE/routes/auth.js" 2>/dev/null | head -15 | sed 's/^/   /'

say "2) Every OTP ever sent, and to whom"
q -c "SELECT target, channel, created_at FROM verification_codes ORDER BY created_at DESC LIMIT 10;" 2>&1
q -c "SELECT recipient, LEFT(message,40) AS msg, sent_at FROM sms_logs WHERE message ILIKE '%verification code%' ORDER BY sent_at DESC LIMIT 6;"
echo "   ${Y}compare 'target' with the ISP phone on file: $(q -tAc "SELECT phone FROM isps LIMIT 1;")${N}"

say "3) PPPoE SMS that already exists"
echo "   --- pppoe.js line 155-175 ---"
sudo sed -n '155,175p' "$BE/routes/pppoe.js" | nl -ba -v155 | sed 's/^/     /'
echo "   --- pppoe.js line 395-415 ---"
sudo sed -n '395,415p' "$BE/routes/pppoe.js" | nl -ba -v395 | sed 's/^/     /'

say "4) The PPPoE expiry reminder cron"
sudo sed -n '60,100p' "$BE/utils/cron.js" | nl -ba -v60 | sed 's/^/   /'

say "5) The PPPoE expiry sweep (does it notify on actual expiry?)"
sudo sed -n '663,706p' "$BE/utils/cron.js" | nl -ba -v663 | sed 's/^/   /'

say "6) End of onPaid — where a renewal confirmation would go"
L=$(grep -n "async function onPaid" "$BE/routes/pppoePortal.js" | head -1 | cut -d: -f1)
END=$(awk -v s="$L" 'NR>s && /^\}/ {print NR; exit}' "$BE/routes/pppoePortal.js")
echo "   onPaid spans $L..$END"
[ -n "$END" ] && sudo sed -n "$((END-45)),${END}p" "$BE/routes/pppoePortal.js" | nl -ba -v"$((END-45))" | sed 's/^/   /'

say "7) Subscribers and their phones"
q -c "SELECT username, full_name, phone, status, next_billing_date, payment_sms_sent_at, expiry_reminder_sent FROM pppoe_subscribers;"
