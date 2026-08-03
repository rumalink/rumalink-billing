#!/usr/bin/env bash
#
# fix_pfx_declaration.sh — repair "Error: _pfx is not defined" in the voucher import.
#
# My previous patch applied the two USES of _pfx but its anchor for the DECLARATION assumed a
# specific indentation and missed, leaving a reference to an undeclared variable. This inserts
# the declaration with whitespace-insensitive matching and verifies it precedes both uses.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "0) Current state of the import block"
sudo grep -n "_pfx\|const kre" "$BE/routes/isp.js" | sed 's/^/   /'

say "1) Backup"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"

say "2) Insert the declaration (regex, indentation taken from the file)"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()

if re.search(r'const\s+_pfx\s*=', s):
    print("   declaration already present"); sys.exit(0)

m = re.search(r'^([ \t]*)const kre = .\^K\[0-9\]\+. \+ String\.fromCharCode\(36\);\s*$', s, re.M)
if not m:
    m = re.search(r'^([ \t]*)const kre = .*String\.fromCharCode\(36\);\s*$', s, re.M)
if not m:
    print("   ERROR: kre line not found — file unchanged"); sys.exit(1)

ind = m.group(1)
decl = (
  f"{ind}/* RL_IMPORT_PREFIX: was hardcoded 'K'. Codes must carry the ISP's own initial\n"
  f"{ind}   (Rumalink -> R1, R2...). The max-number lookup below also searched the ^K[0-9]+$ series,\n"
  f"{ind}   so for any ISP not starting with K it counted from an unrelated sequence. */\n"
  f"{ind}const _pfxRow = await query(\"SELECT company_name FROM isps WHERE id=$1::uuid\", [ispId]);\n"
  f"{ind}const _pfx = (String((_pfxRow.rows[0] && _pfxRow.rows[0].company_name) || 'X').trim().match(/[A-Za-z]/) || ['X'])[0].toUpperCase();\n"
  f"{ind}const kre = '^' + _pfx + '[0-9]+' + String.fromCharCode(36);\n"
)
s = s[:m.start()] + decl + s[m.end()+1:]
open(p,'w').write(s)
print("   declaration inserted and kre now uses the derived prefix")
PY

say "3) Verify declaration comes BEFORE every use"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
d = s.find('const _pfx =')
uses = [m.start() for m in re.finditer(r'_pfx\b', s)]
uses = [u for u in uses if u != s.find('_pfxRow') and u > 0]
print(f"   declaration at char {d}")
bad = [u for u in uses if u < d and s[u-5:u+5].find('_pfxRow') == -1]
print("   uses after declaration:", all(u >= d for u in uses if s[u-1] not in 'R'))
if d == -1:
    print("   *** DECLARATION MISSING ***")
else:
    print("   OK: _pfx is declared")
PY
sudo grep -n "_pfx" "$BE/routes/isp.js" | sed 's/^/   /'

say "4) Syntax + restart"
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js syntax OK"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 6
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "error|_pfx" | tail -5 | sed 's/^/   /' || echo "   clean"

say "5) Runtime check of the prefix derivation"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const {query}=require('$BE/config/database');
(async()=>{
  const r=await query('SELECT id, company_name FROM isps');
  for(const i of r.rows){
    const pfx=(String(i.company_name||'X').trim().match(/[A-Za-z]/)||['X'])[0].toUpperCase();
    const mx=await query(\"SELECT COALESCE(MAX((substring(code from 2))::int),0) AS m FROM hotspot_vouchers WHERE isp_id=\$1::uuid AND code ~ ('^'||\$2||'[0-9]+\$')\",[i.id,pfx]);
    console.log('   '+i.company_name+' -> prefix '+pfx+', next import code '+pfx+(Number(mx.rows[0].m||0)+1));
  }
  process.exit(0);
})();"

say "6) Try the import again"
echo "   Retry the import from the ISP dashboard. Codes should come out as R-series."
echo "   Rollback if needed: sudo cp $BE/routes/.isp.js.bak_$TS $BE/routes/isp.js && sudo pm2 restart rumalink-backend"
