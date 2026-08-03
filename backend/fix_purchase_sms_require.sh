#!/usr/bin/env bash
#
# fix_purchase_sms_require.sh — customers pay and hear nothing.
#
# CAUSE: routes/captive.js calls require('./hotspotSms'), but hotspotSms.js lives in utils/.
# From routes/ that path resolves to routes/hotspotSms.js, which does not exist, so require
# throws MODULE_NOT_FOUND — and the call is wrapped in `catch (e) {}`, which discards it.
# The callback runs, the voucher activates, and the confirmation SMS silently never happens.
# strand-heal.js uses the same './hotspotSms' correctly because it lives in utils/.
# server.js also contains a self-patching block that re-injects the wrong path on boot.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Confirm the module is not where captive.js looks for it"
ls -la "$BE/routes/hotspotSms.js" 2>/dev/null | sed 's/^/   /' || echo "   routes/hotspotSms.js: DOES NOT EXIST  <- require('./hotspotSms') fails here"
ls -la "$BE/utils/hotspotSms.js"  2>/dev/null | sed 's/^/   /'
echo "   the failing call:"
grep -n "require('./hotspotSms')" "$BE/routes/captive.js" | sed 's/^/     /'
echo "   proof it throws:"
sudo -u www-data node -e "
process.chdir('$BE/routes');
try { require('./hotspotSms'); console.log('     loaded (unexpected)'); }
catch(e){ console.log('     ' + e.code + ': ' + e.message.split('\n')[0]); }"

say "2) Backups"
sudo cp "$BE/routes/captive.js" "$BE/routes/.captive.js.bak_$TS" && echo "   captive.js"
sudo cp "$BE/server.js" "$BE/.server.js.bak_$TS" && echo "   server.js"

say "3) Fix the require path in captive.js, and stop swallowing the error"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
old = "try { await require('./hotspotSms').sendPurchaseSms(req.params.paymentId); } catch (e) {}"
new = ("try { await require('../utils/hotspotSms').sendPurchaseSms(req.params.paymentId); }\n"
       "          /* RL_SMS_REQUIRE_PATH: this was require('./hotspotSms'), which resolves to\n"
       "             routes/hotspotSms.js — the module lives in utils/. require threw\n"
       "             MODULE_NOT_FOUND and the empty catch discarded it, so every customer paid\n"
       "             and heard nothing while the log showed a clean activation. Never swallow\n"
       "             this one: a missing confirmation is a support call. */\n"
       "          catch (e) { logger.error('[purchase-sms] send failed for payment ' + req.params.paymentId + ': ' + e.message); }")
n = s.count(old)
if n:
    s = s.replace(old, new)
    open(p,'w').write(s); print(f"   fixed {n} call site(s) in captive.js")
elif "'../utils/hotspotSms'" in s:
    print("   already fixed")
else:
    print("   ERROR: call site not found — captive.js unchanged")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js syntax OK"

say "4) Fix the self-patching block in server.js so it cannot re-inject the wrong path"
sudo python3 - "$BE/server.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
n=0
if "require(\\'./hotspotSms\\')" in s:
    s = s.replace("require(\\'./hotspotSms\\')", "require(\\'../utils/hotspotSms\\')"); n+=1
if "sendPurchaseSms(req.params.paymentId)" in s and "'./hotspotSms'" in s:
    s = s.replace("'./hotspotSms'", "'../utils/hotspotSms'"); n+=1
if n:
    open(p,'w').write(s); print(f"   server.js patcher corrected ({n} replacement(s))")
else:
    print("   server.js: no wrong path found (or already corrected)")
PY
sudo -u www-data node --check "$BE/server.js" && echo "   server.js syntax OK"
echo "   remaining references:"
grep -n "hotspotSms" "$BE/server.js" "$BE/routes/captive.js" | sed 's/^/     /'

say "5) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "error|purchase-sms" | tail -4 | sed 's/^/   /' || echo "   clean"

say "6) Verify the module now resolves from captive.js's location"
sudo -u www-data node -e "
process.chdir('$BE/routes');
try { const m = require('../utils/hotspotSms'); console.log('   resolves OK, exports: ' + Object.keys(m).join(', ')); }
catch(e){ console.log('   STILL FAILING: ' + e.message); }"

say "7) Send the confirmations customers never received"
q -c "SELECT LEFT(p.id::text,8) AS pay, v.code, v.is_tv, p.metadata->>'rl_purchase_sms' AS sms_flag
      FROM payments p JOIN hotspot_vouchers v ON v.payment_id = p.id
      WHERE p.status='paid' AND (p.metadata->>'rl_purchase_sms') IS DISTINCT FROM 'sent'
      ORDER BY p.created_at DESC;"
read -r -p "   Send the missing confirmations now? (y/N): " GO || true
if [ "${GO:-n}" = "y" ] || [ "${GO:-n}" = "Y" ]; then
  sudo -u www-data node -e "
  require('dotenv').config({path:'$BE/.env'});
  const {query}=require('$BE/config/database');
  const hs=require('$BE/utils/hotspotSms');
  (async()=>{
    const r=await query(\"SELECT p.id FROM payments p JOIN hotspot_vouchers v ON v.payment_id=p.id WHERE p.status='paid' AND (p.metadata->>'rl_purchase_sms') IS DISTINCT FROM 'sent' ORDER BY p.created_at DESC LIMIT 5\");
    for(const row of r.rows){ const out=await hs.sendPurchaseSms(row.id); console.log('   '+row.id.slice(0,8)+' -> '+JSON.stringify(out)); }
    process.exit(0);
  })();" 2>&1 | grep -vE "^info: SMS" | sed 's/^/  /'
else echo "   skipped"; fi

say "8) PPPoE renewals — the separate gap"
echo "   onPaid in pppoePortal.js:"
grep -nE "onPaid|module.exports" "$BE/routes/pppoePortal.js" 2>/dev/null | head -8 | sed 's/^/     /'
L=$(grep -n "async function onPaid" "$BE/routes/pppoePortal.js" 2>/dev/null | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "${L},$((L+45))p" "$BE/routes/pppoePortal.js" | nl -ba -v"$L" | sed 's/^/     /'
echo "   ${Y}paste this section and the renewal confirmation SMS will be added to that path.${N}"
