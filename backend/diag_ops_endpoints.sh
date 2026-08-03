#!/usr/bin/env bash
# READ ONLY — the ops buttons 403 while every other admin call works.
set -uo pipefail
BE=/var/www/rumalink/backend
D=/var/www/rumalink/admin/dashboard.html
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) What does rlOpsHdr() send?"
grep -n "rlOpsHdr" "$D" | sed 's/^/   /'
L=$(grep -n "function rlOpsHdr" "$D" | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "${L},$((L+12))p" "$D" | nl -ba -v"$L" | sed 's/^/   /'

say "2) Do the /api/admin/ops/* routes exist at all?"
grep -rn "ops/save\|ops/backup\|ops/restore\|'/ops" "$BE/routes" --include=*.js 2>/dev/null | grep -v -E '\.bak' | sed 's/^/   /' \
  || echo "   ${Y}NO /ops routes found anywhere in the backend${N}"
echo "   --- all router paths defined in admin.js containing ops/backup/restore/reset ---"
grep -nE "router\.(get|post|put|delete)\('/[^']*(ops|backup|restore|reset|save)" "$BE/routes/admin.js" | sed 's/^/   /' || echo "   (none)"

say "3) Which system endpoints DO exist? (the other buttons call these)"
grep -nE "router\.(get|post)\('/system/" "$BE/routes/admin.js" | sed 's/^/   /' || echo "   ${Y}none — /api/admin/system/* is missing too${N}"

say "4) What the dashboard buttons actually call"
grep -oE "'/api/admin/[a-z/-]+'|\(window\.API\|\|'/api'\)\+'/admin/[a-z/-]+'" "$D" 2>/dev/null | sort -u | sed 's/^/   /'
echo "   --- ops buttons in the markup ---"
grep -nE "rl-backup-status|rl-restore-file|rl-reset-btn|rlOps" "$D" | head -12 | sed 's/^/   /'

say "5) Live probe with YOUR admin credentials"
read -r -p "   Admin email [admin@rumalink.co.ke]: " EM || true
EM=${EM:-admin@rumalink.co.ke}
read -r -s -p "   Admin password (not echoed, not stored): " PW || true; echo
TOK=$(curl -s -X POST "http://127.0.0.1:5000/api/auth/admin/login" \
  -H 'Content-Type: application/json' -d "{\"email\":\"$EM\",\"password\":\"$PW\"}" \
  | sudo -u www-data node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{const j=JSON.parse(s);console.log(j.token||j.accessToken||'')}catch(e){console.log('')}})")
if [ -z "$TOK" ]; then echo "   ${Y}login failed — check the credentials (nothing was changed)${N}"; else
  echo "   got a token; claims:"
  echo "$TOK" | cut -d. -f2 | base64 -d 2>/dev/null | head -c 300 | sed 's/^/     /'; echo
  for EP in /api/admin/stats /api/admin/health /api/admin/system/backups /api/admin/ops/save /api/admin/ops/backup; do
    printf "   %-34s " "$EP"
    curl -s -o /tmp/o.json -w "HTTP %{http_code}  " -X POST "http://127.0.0.1:5000$EP" \
      -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' -d '{}'
    head -c 90 /tmp/o.json | tr '\n' ' '; echo
  done
  echo "   ${Y}404 = route missing (button calls a path that does not exist)${N}"
  echo "   ${Y}403 = route exists but the token was rejected${N}"
fi

say "6) Was an ops route lost in the overwrite?"
sudo ls -1t "$BE/routes/".admin.js.bak_* "$BE/routes/"admin.js.*bak* 2>/dev/null | head -6 | while read b; do
  printf "   %-46s ops routes: %s\n" "$(basename $b)" "$(sudo grep -c "'/ops" "$b" 2>/dev/null || echo 0)"
done
echo "   current admin.js ops routes: $(grep -c "'/ops" "$BE/routes/admin.js" || echo 0)"
