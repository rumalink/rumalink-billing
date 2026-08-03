#!/usr/bin/env bash
#
# fix_intasend_parity.sh — bring the IntaSend path up to Daraja parity.
#
# GAP 1 (autologin): the status poll reports 'paid' as soon as IntaSend confirms, but the
# voucher is activated and RADIUS-synced ~12s later by a separate pass. The portal reads
# radius_username/radius_password from that response (classic.html:699) and finds them null,
# so it never calls rlHotspotLogin and the customer is left on the purchase page. Daraja works
# because its callback activates + syncs BEFORE the portal's next poll.
#   FIX: activate inline, in the status endpoint, before the credentials are read.
#        activateVoucher is idempotent (RL_ACTIVATE_GUARD), so this is safe to call repeatedly.
#
# GAP 2 (no SMS): intasend-activate.js no longer calls sendPurchaseSms, so IntaSend customers
#        get no confirmation. Daraja sends it from the callback.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The exact response the portal receives (payment-status tail)"
sudo sed -n '896,945p' "$BE/routes/captive.js" | nl -ba -v896 | sed 's/^/   /'

say "2) intasend-activate.js — the end of activateVoucher"
sudo sed -n '100,120p' "$BE/utils/intasend-activate.js" | nl -ba -v100 | sed 's/^/   /'

say "3) Backups"
sudo cp "$BE/routes/captive.js" "$BE/routes/.captive.js.bak_$TS" && echo "   captive.js"
sudo cp "$BE/utils/intasend-activate.js" "$BE/utils/.intasend-activate.js.bak_$TS" && echo "   intasend-activate.js"

say "4) GAP 1 — activate inline before credentials are read"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_INTASEND_INLINE_ACTIVATE' in s:
    print("   already patched"); sys.exit(0)
old = "          /* RL_INLINE_HEAL: guarantee voucher + RADIUS creds before the overlay learns 'paid' */"
if old not in s:
    print("   ERROR: RL_INLINE_HEAL anchor not found — unchanged"); sys.exit(1)
new = ("""          /* RL_INTASEND_INLINE_ACTIVATE: IntaSend confirms the payment through a poll, but the
             voucher was activated and RADIUS-synced by a LATER pass — so this response reported
             'paid' with null credentials and the portal (classic.html:699 reads radius_username /
             radius_password) could not auto-login, stranding a paying customer on the purchase
             page. Daraja never had this gap because its callback does both before the next poll.
             activateVoucher is idempotent (RL_ACTIVATE_GUARD), so calling it here is safe. */
          try { await require('../utils/intasend-activate').activateVoucher(req.params.paymentId); }
          catch (e) { logger.warn('[captive] inline intasend activate: ' + e.message); }
""" + old)
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   inline activation added before the creds lookup")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js syntax OK"

say "5) GAP 2 — send the purchase SMS from the IntaSend activation"
sudo python3 - "$BE/utils/intasend-activate.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_INTASEND_PURCHASE_SMS' in s:
    print("   already patched"); sys.exit(0)
if 'sendPurchaseSms' in s:
    print("   a sendPurchaseSms call already exists"); sys.exit(0)
m = re.search(r'^([ \t]*)await syncRadius\(v\.id\);\s*$', s, re.M)
if not m:
    print("   ERROR: 'await syncRadius(v.id);' not found — unchanged"); sys.exit(1)
ind = m.group(1)
add = ("\n" + ind + "/* RL_INTASEND_PURCHASE_SMS: the confirmation is sent from the Daraja callback for that\n"
       + ind + "   gateway; on the IntaSend path nothing sent it, so those customers paid and heard\n"
       + ind + "   nothing. sendPurchaseSms is idempotent via the payment's rl_purchase_sms flag, so a\n"
       + ind + "   retry or a second activation pass cannot send a duplicate. */\n"
       + ind + "try { await require('./hotspotSms').sendPurchaseSms(paymentId); }\n"
       + ind + "catch (e) { logger.error('[intasend-activate] purchase sms: ' + e.message); }")
s = s[:m.end()] + add + s[m.end():]
open(p,'w').write(s); print("   purchase SMS added after syncRadius")
PY
cd "$BE" && sudo -u www-data node --check utils/intasend-activate.js && echo "   intasend-activate.js syntax OK"
grep -n "sendPurchaseSms\|logger" "$BE/utils/intasend-activate.js" | head -5 | sed 's/^/   /'

say "6) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"

say "7) Verify — the status endpoint now returns credentials for a paid IntaSend payment"
PID=$(q -tAc "SELECT id FROM payments WHERE payment_gateway='intasend' AND status='paid' ORDER BY created_at DESC LIMIT 1;")
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
echo "   payment: ${PID:-none}"
if [ -n "$PID" ]; then
  curl -s "http://127.0.0.1:5000/api/captive/$ISP/payment-status/$PID" | head -c 400 | sed 's/^/   /'
  echo
  echo "   ${Y}radius_username and radius_password must both be present for autologin.${N}"
fi

say "8) Did the missing IntaSend confirmation go out?"
q -c "SELECT LEFT(p.id::text,8) AS pay, p.payment_gateway, v.code, v.is_tv,
             p.metadata->>'rl_purchase_sms' AS sms
      FROM payments p LEFT JOIN hotspot_vouchers v ON v.payment_id=p.id
      WHERE p.status='paid' ORDER BY p.created_at DESC LIMIT 5;"
pm2 logs rumalink-backend --lines 60 --nostream 2>/dev/null | grep -iE "purchase-sms|intasend-activate" | tail -6 | sed 's/^/   /' || echo "   (none yet)"

say "9) Next: withdrawals naming"
echo "   current narrative construction:"
sudo sed -n '160,180p' "$BE/routes/withdrawals.js" | nl -ba -v160 | sed 's/^/     /'
echo
echo "   ${Y}Test a real IntaSend purchase now — the phone should connect automatically.${N}"
echo "   Rollback: sudo cp $BE/routes/.captive.js.bak_$TS $BE/routes/captive.js"
echo "             sudo cp $BE/utils/.intasend-activate.js.bak_$TS $BE/utils/intasend-activate.js"
