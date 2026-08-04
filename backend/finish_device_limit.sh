#!/usr/bin/env bash
#
# finish_device_limit.sh — complete the package UPDATE param array and the dashboard field.
#
# Step 3 added `simultaneous_sessions=$8` to the UPDATE SQL. If the route's parameter array
# still passes only 7 values, every package edit now throws "bind message supplies 7 parameters".
# This verifies that first and appends the value, then confirms the dashboard field.
#
set -uo pipefail
BE=/var/www/rumalink/backend
DASH=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The package routes in full (INSERT and UPDATE with their params)"
sudo sed -n '18,60p' "$BE/routes/hotspot.js" | nl -ba -v18 | sed 's/^/   /'

say "2) Does the UPDATE param count match its placeholders?"
sudo -u www-data node -e "
const fs=require('fs');
const s=fs.readFileSync('$BE/routes/hotspot.js','utf8');
const m=s.match(/UPDATE hotspot_packages SET[\s\S]*?WHERE[^\`']*/);
if(!m){console.log('   UPDATE not found');process.exit(0);}
const sql=m[0];
const ph=[...new Set((sql.match(/\\\$\d+/g)||[]).map(x=>+x.slice(1)))].sort((a,b)=>a-b);
console.log('   placeholders in SQL: '+ph.join(', ')+'   (max \$'+Math.max(...ph)+')');
const after=s.slice(s.indexOf(sql)+sql.length, s.indexOf(sql)+sql.length+400);
const arr=after.match(/\[([^\]]*)\]/);
if(arr){
  const items=arr[1].split(',').filter(x=>x.trim());
  console.log('   values passed: '+items.length);
  items.forEach((x,i)=>console.log('     \$'+(i+1)+' = '+x.trim().slice(0,50)));
  if(items.length < Math.max(...ph)) console.log('   *** MISMATCH: SQL needs '+Math.max(...ph)+', array has '+items.length+' ***');
  else console.log('   counts match');
}else console.log('   could not read the param array');
"

say "3) Backup + append the missing value"
sudo cp "$BE/routes/hotspot.js" "$BE/routes/.hotspot.js.bak_$TS" && echo "   hotspot.js"
sudo python3 - "$BE/routes/hotspot.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SIMUL_PARAM' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'(UPDATE hotspot_packages SET[\s\S]*?WHERE[^`\']*[`\'])\s*,\s*\n?(\s*)\[([^\]]*)\]', s)
if not m:
    print("   ERROR: UPDATE + param array not matched — unchanged"); sys.exit(1)
params = m.group(3)
if 'simultaneous_sessions' in params:
    print("   value already present"); sys.exit(0)
ph = [int(x[1:]) for x in re.findall(r'\$\d+', m.group(1))]
need = max(ph) if ph else 0
have = len([x for x in params.split(',') if x.strip()])
print(f"   SQL needs {need} values, array has {have}")
if have >= need:
    print("   nothing to append"); sys.exit(0)
items = [x.strip() for x in params.split(',') if x.strip()]
# the id is normally last; insert the new value before it
newparams = ',\n' + m.group(2) + '  ' + ',\n      '.join(items[:-1]) + \
            ',\n      Math.max(1, parseInt(simultaneous_sessions ?? 1, 10) || 1), /* RL_SIMUL_PARAM: devices allowed at once */\n      ' + items[-1] + '\n' + m.group(2)
s = s[:m.start(3)] + newparams + s[m.end(3):]
open(p,'w').write(s); print("   value appended before the id")
PY
sudo python3 - "$BE/routes/hotspot.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'simultaneous_sessions' in s and 'req.body' in s:
    m = re.search(r'const \{([^}]*)\} = req\.body;', s)
    if m and 'simultaneous_sessions' not in m.group(1):
        s = s[:m.end(1)] + ', simultaneous_sessions' + s[m.end(1):]
        open(p,'w').write(s); print("   simultaneous_sessions destructured from req.body")
    else:
        print("   already destructured (or a different shape)")
PY
cd "$BE" && sudo -u www-data node --check routes/hotspot.js && echo "   hotspot.js syntax OK"

say "4) Re-check the counts"
sudo -u www-data node -e "
const fs=require('fs');
const s=fs.readFileSync('$BE/routes/hotspot.js','utf8');
const m=s.match(/UPDATE hotspot_packages SET[\s\S]*?WHERE[^\`']*/);
const sql=m[0];
const ph=[...new Set((sql.match(/\\\$\d+/g)||[]).map(x=>+x.slice(1)))].sort((a,b)=>a-b);
const after=s.slice(s.indexOf(sql)+sql.length, s.indexOf(sql)+sql.length+600);
const arr=after.match(/\[([^\]]*)\]/);
const items=arr?arr[1].split(',').filter(x=>x.trim()):[];
console.log('   SQL max \$'+Math.max(...ph)+'   values '+items.length+'   -> '+(items.length>=Math.max(...ph)?'OK':'STILL MISMATCHED'));
"

say "5) Dashboard field"
grep -c "hsp-devices" "$DASH" | sed 's/^/   hsp-devices references: /'
grep -n "hsp-devices" "$DASH" | head -4 | sed 's/^/   /'
echo "   edit form (does it populate the field?):"
grep -n "hsp-profile'\).value *=" "$DASH" | head -3 | sed 's/^/   /'

say "6) Restart + live check"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"
q -c "SELECT name, simultaneous_sessions FROM hotspot_packages ORDER BY duration_hours;"
q -c "SELECT count(*) AS vouchers_with_limit FROM radcheck WHERE attribute='Simultaneous-Use';"

say "7) Edit a package through the API to prove the UPDATE works"
PKG=$(q -tAc "SELECT id FROM hotspot_packages ORDER BY duration_hours LIMIT 1;")
echo "   package $PKG — set to 2 devices, then read it back:"
q -c "UPDATE hotspot_packages SET simultaneous_sessions=2 WHERE id='$PKG'::uuid RETURNING name, simultaneous_sessions;"
echo "   ${Y}now edit that same package in the dashboard and save — it must not error${N}"

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Device limit: package UPDATE carries simultaneous_sessions; dashboard field" 2>&1 | head -2 | sed 's/^/   /'
