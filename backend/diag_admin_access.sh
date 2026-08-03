#!/usr/bin/env bash
# READ ONLY — why does an authenticated admin get "Admin access required" (403)?
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) What does requireAdmin actually check?"
sudo grep -n "Admin access required" "$BE/middleware/auth.js" | sed 's/^/   /'
L=$(sudo grep -n "requireAdmin" "$BE/middleware/auth.js" | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "$((L-2)),$((L+22))p" "$BE/middleware/auth.js" | nl -ba -v"$((L-2))" | sed 's/^/   /'
echo "   --- authenticateToken: what it puts on req.user ---"
A=$(sudo grep -n "function authenticateToken\|const authenticateToken" "$BE/middleware/auth.js" | head -1 | cut -d: -f1)
[ -n "$A" ] && sudo sed -n "${A},$((A+30))p" "$BE/middleware/auth.js" | nl -ba -v"$A" | sed 's/^/   /'

say "2) What does ADMIN LOGIN sign into the token?"
grep -n "jwt.sign" "$BE/routes/auth.js" | sed 's/^/   /'
for LN in $(grep -n "jwt.sign" "$BE/routes/auth.js" | cut -d: -f1); do
  echo "   --- around line $LN ---"
  sudo sed -n "$((LN-12)),$((LN+8))p" "$BE/routes/auth.js" | nl -ba -v"$((LN-12))" | sed 's/^/     /'
done

say "3) Where is 'Admin access required' returned from?"
grep -rn "Admin access required" "$BE" --include=*.js 2>/dev/null | grep -v -E 'node_modules|\.bak' | sed 's/^/   /'

say "4) The admins table"
q -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='admins' ORDER BY ordinal_position;"
q -c "SELECT id, email, role, is_active FROM admins;" 2>&1 | head -10

say "5) Which admin routes are failing? (recent 401/403)"
pm2 logs rumalink-backend --lines 400 --nostream 2>/dev/null \
  | grep -E '"(GET|POST|PUT|DELETE) /api/[^"]*" (401|403)' \
  | grep -oE '"(GET|POST|PUT|DELETE) /api/[^ ]+ HTTP/1.1" (401|403)' | sort | uniq -c | sort -rn | head -15 | sed 's/^/   /'

say "6) The save/backup/restore endpoints the dashboard calls"
grep -nE "router\.(post|get|put)\('/(backup|restore|save|settings)" "$BE/routes/admin.js" | head -15 | sed 's/^/   /'
echo "   --- how admin.js guards its routes ---"
sudo sed -n '1,12p' "$BE/routes/admin.js" | nl -ba | sed 's/^/   /'

say "7) What the dashboard sends"
grep -oE "localStorage.getItem\('[^']+'\)" /var/www/rumalink/admin/dashboard.html 2>/dev/null | sort -u | sed 's/^/   /'
grep -n "backup\|restore" /var/www/rumalink/admin/dashboard.html 2>/dev/null | grep -iE "fetch|api" | head -8 | sed 's/^/   /'

say "8) Decode a live admin token (no secrets printed)"
echo "   In the browser console on the admin dashboard, run:"
echo "     JSON.parse(atob((localStorage.getItem('rl_admin_token')||'').split('.')[1]))"
echo "   ${Y}Paste the result — it shows exactly which claims your token carries.${N}"
