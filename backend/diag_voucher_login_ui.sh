#!/usr/bin/env bash
# READ ONLY — is the endpoint working, and does the portal form have the globals it needs?
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Does the endpoint work at all?"
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
CODE=$(q -tAc "SELECT code FROM hotspot_vouchers WHERE status='active' AND (is_tv IS NOT TRUE) ORDER BY created_at DESC LIMIT 1;")
echo "   isp=$ISP  code=${CODE:-none}"
q -c "SELECT code, status, expires_at, used_by_mac FROM hotspot_vouchers ORDER BY created_at DESC LIMIT 4;"
echo "   POST /voucher-login:"
curl -s -X POST "http://127.0.0.1:5000/api/captive/$ISP/voucher-login" \
  -H 'Content-Type: application/json' -d "{\"code\":\"$CODE\",\"mac\":\"AA:BB:CC:DD:EE:09\"}" | sed 's/^/     /'; echo
q -c "DELETE FROM hotspot_voucher_devices WHERE mac='AA:BB:CC:DD:EE:09';" >/dev/null 2>&1
q -c "DELETE FROM radcheck WHERE username='AA:BB:CC:DD:EE:09';" >/dev/null 2>&1

say "2) Did the form actually land in the portal?"
grep -c "RL_CODE_LOGIN_UI" "$CP/classic.html" | sed 's/^/   RL_CODE_LOGIN_UI blocks: /'
grep -n "cl-code\|cl-btn\|cl-msg" "$CP/classic.html" | head -6 | sed 's/^/   /'

say "3) The globals my script assumed — do they exist?"
for v in "window.API" "window.ISP_ID" "rlClientMac" "rlHotspotLogin" "RL_MAC"; do
  printf "   %-18s %s\n" "$v" "$(grep -c "$v" "$CP/classic.html" || true)"
done
echo "   --- how the portal really knows the ISP id ---"
grep -noE "ISP_ID[^;]{0,40}|ispId[^;]{0,40}|isp_id[^;]{0,40}" "$CP/classic.html" | head -8 | sed 's/^/     /'
echo "   --- how it really builds API urls ---"
grep -noE "fetch\((window\.[A-Z_]+[^,)]{0,60}|fetch\('[^']{0,60}" "$CP/classic.html" | head -8 | sed 's/^/     /'

say "4) The existing autologin bridge (the pattern to copy)"
L=$(grep -n "rlHotspotLogin" "$CP/classic.html" | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "$((L-18)),$((L+12))p" "$CP/classic.html" | nl -ba -v"$((L-18))" | sed 's/^/   /'

say "5) How does the portal obtain the client MAC?"
grep -noE "mac[^;,)]{0,50}" "$CP/classic.html" | grep -iE "param|query|search|window|const|var|let" | head -12 | sed 's/^/   /'
echo "   --- MikroTik passes it in the URL; what does the portal read? ---"
grep -noE "URLSearchParams[^;]{0,60}|location.search[^;]{0,40}" "$CP/classic.html" | head -6 | sed 's/^/   /'

say "6) Is the form visible, or hidden behind the purchase flow?"
grep -n 'id="code-login"' "$CP/classic.html" | sed 's/^/   /'
L2=$(grep -n 'id="code-login"' "$CP/classic.html" | head -1 | cut -d: -f1)
[ -n "$L2" ] && sudo sed -n "$((L2-12)),$((L2+2))p" "$CP/classic.html" | nl -ba -v"$((L2-12))" | sed 's/^/   /'

say "7) Backend log during the attempt"
pm2 logs rumalink-backend --lines 200 --nostream 2>/dev/null | grep -iE "voucher-login|captive.*POST|error" | tail -10 | sed 's/^/   /' || echo "   (nothing)"
