#!/usr/bin/env bash
#
# fix_autologin_and_payout_name.sh
#
# FIX 1 — IntaSend autologin. The status endpoint returns radius creds only once the voucher has
#   been activated by a later pass, so the FIRST poll that reports 'paid' carries nulls and the
#   portal (classic.html:699 needs _ru && _rp) falls through to "voucher sent via SMS", leaving a
#   paying customer on the purchase page. Activate inline, before the creds are read.
#   Anchored this time on `let radius_username = null` — the line that reads them.
#
# FIX 2 — payout beneficiary name. withdrawals.js builds _dest with the ISP's company name and
#   narrative (lines 166-171) and then never uses it: line 172 passes `{ ...destination,
#   narrative: 'RumaLink withdrawal <id>' }`. Every payout therefore reaches IntaSend anonymous,
#   which is exactly what RL_BENEFICIARY_NAME was written to prevent.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "0) Backups"
sudo cp "$BE/routes/captive.js"     "$BE/routes/.captive.js.bak_$TS"     && echo "   captive.js"
sudo cp "$BE/routes/withdrawals.js" "$BE/routes/.withdrawals.js.bak_$TS" && echo "   withdrawals.js"

say "1) FIX 1 — inline activation before the credentials lookup"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_INTASEND_INLINE_ACTIVATE' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)let radius_username = null, radius_password = null;\s*$', s, re.M)
if not m:
    print("   ERROR: creds declaration not found — unchanged"); sys.exit(1)
ind = m.group(1)
block = (
f"{ind}/* RL_INTASEND_INLINE_ACTIVATE: IntaSend confirms via poll, but the voucher was activated and\n"
f"{ind}   RADIUS-synced by a LATER pass — so the first response that said 'paid' carried null creds\n"
f"{ind}   and the portal could not auto-login, stranding a paying customer on the purchase page.\n"
f"{ind}   Daraja never had this gap: its callback activates before the next poll. activateVoucher is\n"
f"{ind}   idempotent (RL_ACTIVATE_GUARD), so calling it on every paid poll is safe. */\n"
f"{ind}if (r.rows[0].status === 'paid') {{\n"
f"{ind}  try {{ await require('../utils/intasend-activate').activateVoucher(req.params.paymentId); }}\n"
f"{ind}  catch (e) {{ logger.warn('[captive] inline intasend activate: ' + e.message); }}\n"
f"{ind}}}\n"
)
s = s[:m.start()] + block + s[m.start():]
open(p,'w').write(s); print("   inline activation inserted before the creds lookup")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js syntax OK"
grep -n "RL_INTASEND_INLINE_ACTIVATE" "$BE/routes/captive.js" | sed 's/^/   /'

say "2) FIX 2 — actually send the ISP's name to IntaSend"
sudo python3 - "$BE/routes/withdrawals.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_BENEFICIARY_NAME_APPLIED' in s:
    print("   already patched"); sys.exit(0)
old = "payout = await intasend.sendPayout(method, { ...destination, narrative: `RumaLink withdrawal ${withdrawalId}` }, quote.net);"
if old not in s:
    print("   ERROR: sendPayout call not found verbatim — unchanged"); sys.exit(1)
new = ("/* RL_BENEFICIARY_NAME_APPLIED: _dest (built just above with the ISP's company name and\n"
       "             narrative) was constructed and then discarded — this call spread `destination` and\n"
       "             overwrote the narrative, so every payout reached IntaSend anonymous and\n"
       "             reconciliation across several withdrawing ISPs was impossible. Use _dest, and keep\n"
       "             the withdrawal id in the narrative for traceability. */\n"
       "          payout = await intasend.sendPayout(method, _dest, quote.net);")
s = s.replace(old, new, 1)

# put the withdrawal id back into the narrative so payouts stay traceable
oldn = "narrative: (_ispName ? _ispName + ' withdrawal' : 'RumaLink withdrawal'),"
newn = ("narrative: (_ispName ? _ispName + ' withdrawal ' + String(withdrawalId).slice(0, 8)\n"
        "                                 : 'RumaLink withdrawal ' + String(withdrawalId).slice(0, 8)),")
if oldn in s: s = s.replace(oldn, newn, 1)
open(p,'w').write(s); print("   sendPayout now uses _dest (ISP name + narrative)")
PY
cd "$BE" && sudo -u www-data node --check routes/withdrawals.js && echo "   withdrawals.js syntax OK"
sudo sed -n '160,178p' "$BE/routes/withdrawals.js" | nl -ba -v160 | sed 's/^/   /'

say "3) Does the payout client forward the name to IntaSend?"
sudo sed -n '150,185p' "$BE/utils/intasend-client.js" | nl -ba -v150 | grep -nE "name|narrative|account|transactions|buildPayout" | sed 's/^/   /'

say "4) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"

say "5) Verify the status endpoint still answers correctly"
PID=$(q -tAc "SELECT id FROM payments WHERE payment_gateway='intasend' AND status='paid' ORDER BY created_at DESC LIMIT 1;")
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
[ -n "$PID" ] && curl -s "http://127.0.0.1:5000/api/captive/$ISP/payment-status/$PID" | head -c 320 | sed 's/^/   /' && echo

say "6) Send the IntaSend confirmation that was missed"
MISS=$(q -tAc "SELECT p.id FROM payments p JOIN hotspot_vouchers v ON v.payment_id=p.id WHERE p.status='paid' AND (p.metadata->>'rl_purchase_sms') IS DISTINCT FROM 'sent' ORDER BY p.created_at DESC LIMIT 3;")
if [ -n "$MISS" ]; then
  echo "   payments without a confirmation:"; echo "$MISS" | sed 's/^/     /'
  read -r -p "   Send them now? (y/N): " GO || true
  if [ "${GO:-n}" = "y" ] || [ "${GO:-n}" = "Y" ]; then
    for PX in $MISS; do
      sudo -u www-data node -e "
      require('dotenv').config({path:'$BE/.env'});
      (async()=>{ const r=await require('$BE/utils/hotspotSms').sendPurchaseSms('$PX');
        console.log('   '+'$PX'.slice(0,8)+' -> '+JSON.stringify(r)); process.exit(0); })();" 2>&1 | grep -vE "^info: SMS" | sed 's/^/  /'
    done
  fi
else echo "   none outstanding"; fi

echo
echo "   ${Y}Now run a live IntaSend purchase: the phone should connect automatically${N}"
echo "   ${Y}and the confirmation SMS should arrive.${N}"
echo "   Rollback: sudo cp $BE/routes/.captive.js.bak_$TS $BE/routes/captive.js"
echo "             sudo cp $BE/routes/.withdrawals.js.bak_$TS $BE/routes/withdrawals.js"
