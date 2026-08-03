#!/usr/bin/env bash
# verify_activate_guard.sh — I now call activateVoucher on every 'paid' poll (~5s apart).
# It is guarded by payments.voucher_activated_at. If nothing SETS that column, the guard never
# trips and the TV-binding / queue logic inside would re-run every few seconds.
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Does anything SET voucher_activated_at?"
grep -rn "voucher_activated_at" "$BE" --include=*.js 2>/dev/null | grep -v -E 'node_modules|/\.|\.bak' | sed 's/^/   /'

say "2) Column state on real payments"
q -c "SELECT LEFT(id::text,8) AS pay, status, voucher_activated_at,
             metadata->>'rl_purchase_sms' AS sms
      FROM payments WHERE status='paid' ORDER BY created_at DESC LIMIT 5;" 2>&1

say "3) Harden the guard if nothing sets it"
if grep -rq "UPDATE payments SET voucher_activated_at" "$BE/utils/intasend-activate.js" 2>/dev/null; then
  echo "   ${G}already set inside activateVoucher — guard works${N}"
else
  echo "   ${Y}nothing sets it — adding the stamp so the guard actually trips${N}"
  sudo cp "$BE/utils/intasend-activate.js" "$BE/utils/.intasend-activate.js.bak_$TS"
  sudo python3 - "$BE/utils/intasend-activate.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_ACTIVATE_STAMP' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)await syncRadius\(v\.id\);\s*$', s, re.M)
if not m:
    print("   ERROR: anchor not found — unchanged"); sys.exit(1)
ind = m.group(1)
add = ("\n" + ind + "/* RL_ACTIVATE_STAMP: the idempotency guard at the top reads payments.voucher_activated_at,\n"
       + ind + "   but nothing ever wrote it, so the guard never tripped. The captive status endpoint now\n"
       + ind + "   calls this on every 'paid' poll (~5s), which would re-run the TV binding and queue work\n"
       + ind + "   indefinitely. Stamp it once here. Expiry itself is already deterministic\n"
       + ind + "   (paid_at + duration), so no time was ever stacked. */\n"
       + ind + "await query(\"UPDATE payments SET voucher_activated_at = COALESCE(voucher_activated_at, NOW()) WHERE id = $1::uuid\", [paymentId]).catch(function(){});")
s = s[:m.end()] + add + s[m.end():]
open(p,'w').write(s); print("   stamp added")
PY
  cd "$BE" && sudo -u www-data node --check utils/intasend-activate.js && echo "   syntax OK"
  sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 6
fi

say "4) Prove it: call the status endpoint 3 times and count activations"
PID=$(q -tAc "SELECT id FROM payments WHERE payment_gateway='intasend' AND status='paid' ORDER BY created_at DESC LIMIT 1;")
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
if [ -n "$PID" ]; then
  for i in 1 2 3; do curl -s -o /dev/null "http://127.0.0.1:5000/api/captive/$ISP/payment-status/$PID"; sleep 1; done
  echo "   activations logged in the last minute (should be at most 1):"
  pm2 logs rumalink-backend --lines 60 --nostream 2>/dev/null | grep -c "intasend-activate] voucher" | sed 's/^/     /'
  pm2 logs rumalink-backend --lines 40 --nostream 2>/dev/null | grep -iE "intasend-activate|already activated" | tail -5 | sed 's/^/     /' || echo "     (none — guard held)"
  echo "   expiry unchanged?"
  q -c "SELECT code, expires_at FROM hotspot_vouchers WHERE payment_id='$PID'::uuid;"
fi

say "5) Ready to test"
echo "   Run a live IntaSend purchase. Watch:"
echo "     pm2 logs rumalink-backend | grep -iE 'intasend-activate|purchase-sms|inline'"
echo "   Expect: voucher activated once, SMS sent, phone connects automatically."
