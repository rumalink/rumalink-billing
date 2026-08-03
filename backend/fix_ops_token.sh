#!/usr/bin/env bash
#
# fix_ops_token.sh — the Save / Backup / Restore buttons send the wrong token.
#
# rlOpsHdr() reads localStorage 'token' || 'adminToken' || 'rl_token' but NOT 'rl_admin_token',
# which is the key admin login writes and every other admin button uses. With the ISP dashboard
# open in the same browser, 'token' holds the ISP JWT: it passes authenticateToken (valid token)
# and fails requireAdmin (role is not 'superadmin') -> 403 "Admin access required", while a
# perfectly good admin session sits in the same browser.
#
# FIX: prefer rl_admin_token, then the other admin keys, then fall back to any JWT whose payload
# actually carries role=superadmin — so the wrong token can never be picked again.
#
set -uo pipefail
D=/var/www/rumalink/admin/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) Backup"
sudo cp "$D" "/var/www/rumalink/admin/.dashboard.html.bak_$TS" && echo "   .dashboard.html.bak_$TS"

say "2) Patch rlOpsHdr"
sudo python3 - "$D" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_OPS_ADMIN_TOKEN' in s:
    print("   already patched"); sys.exit(0)
old = "function rlOpsHdr(){ var t=null; try{t=localStorage.getItem('token')||localStorage.getItem('adminToken')||localStorage.getItem('rl_token');}catch(e){} var h={'Content-Type':'application/json'}; if(t)h['Authorization']='Bearer '+t; return h; }"
if old not in s:
    print("   ERROR: rlOpsHdr not found verbatim — unchanged"); sys.exit(1)
new = ("""/* RL_OPS_ADMIN_TOKEN: this read 'token' first and never read 'rl_admin_token' — the key the
   admin login actually writes. With the ISP dashboard open in the same browser 'token' holds the
   ISP JWT, which passes authenticateToken and fails requireAdmin, so Save/Backup/Restore returned
   403 "Admin access required" while a valid admin session sat in the same browser. Prefer the
   admin key, and as a last resort pick only a JWT that really carries role=superadmin. */
function rlOpsHdr(){
  var t=null;
  try{
    var ks=['rl_admin_token','rl_admin','adminToken','rl_token','token'];
    for(var i=0;i<ks.length && !t;i++){
      var v=localStorage.getItem(ks[i]);
      if(v && v.split('.').length===3){
        try{ var c=JSON.parse(atob(v.split('.')[1])); if(c && c.role==='superadmin') t=v; }catch(e){}
      }
    }
    if(!t){ for(var k in localStorage){ var x=localStorage.getItem(k);
      if(x && typeof x==='string' && x.split('.').length===3){
        try{ var c2=JSON.parse(atob(x.split('.')[1])); if(c2 && c2.role==='superadmin'){ t=x; break; } }catch(e){}
      } } }
  }catch(e){}
  var h={'Content-Type':'application/json'};
  if(t)h['Authorization']='Bearer '+t;
  return h;
}""")
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   rlOpsHdr now selects the admin token")
PY
sudo chown www-data:www-data "$D"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))  (0 = fine)"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"

say "3) Verify"
grep -n "RL_OPS_ADMIN_TOKEN" "$D" | sed 's/^/   /'
curl -sk -o /dev/null -w "   dashboard HTTP %{http_code}\n" https://rumalinkenterprise.online/admin/dashboard.html

say "4) The ops routes it will now reach"
grep -nE "router\.(get|post)\('/ops/" /var/www/rumalink/backend/routes/admin.js | sed 's/^/   /'

say "5) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Ops buttons: send the admin token, not whichever JWT was in localStorage first" 2>&1 | head -2 | sed 's/^/   /'
echo
echo "   ${Y}Hard-refresh the dashboard (Ctrl-Shift-R), then try Save / Backup / Restore.${N}"
echo "   Rollback: sudo cp /var/www/rumalink/admin/.dashboard.html.bak_$TS $D"
