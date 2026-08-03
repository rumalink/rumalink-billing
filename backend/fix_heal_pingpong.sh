#!/usr/bin/env bash
#
# fix_heal_pingpong.sh — stop strand-heal re-healing already-activated payments.
#
# OBSERVED (09:27:31-32): a new purchase topped up voucher R1, which re-pointed R1.payment_id
# to the new payment. The PREVIOUS payment then looked voucherless, so strand-heal "healed" it
# by re-pointing R1 back — sending a SECOND purchase SMS and adding ANOTHER hour of access
# (expiry moved 10:27 -> 11:27). R1 now points at the old payment again, so the new one looks
# unfulfilled and the next pass repeats it: a ping-pong that burns an SMS credit and grants
# free time on every cycle.
#
# WHY THE EXISTING GUARD MISSED IT: RL_ALREADY_FULFILLED tests metadata.rl_purchase_sms, and
# that payment had never had an SMS sent (the IntaSend path was not sending them until today).
#
# FIX: use payments.voucher_activated_at — stamped by activateVoucher the moment a voucher is
# activated for that payment. It is the precise, unambiguous record of fulfilment, independent
# of which voucher currently points where.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Evidence of the ping-pong"
q -c "SELECT LEFT(id::text,8) AS pay, status, voucher_activated_at IS NOT NULL AS activated,
             metadata->>'rl_healed' AS healed, metadata->>'rl_purchase_sms' AS sms,
             to_char(created_at,'HH24:MI:SS') AS at
      FROM payments ORDER BY created_at DESC LIMIT 6;"
q -c "SELECT code, LEFT(payment_id::text,8) AS points_at, expires_at, updated_at
      FROM hotspot_vouchers ORDER BY updated_at DESC NULLS LAST LIMIT 4;"
echo "   duplicate SMS in the last hour:"
q -c "SELECT recipient, count(*) AS sent, min(sent_at) AS first, max(sent_at) AS last
      FROM sms_logs WHERE sent_at > now() - interval '1 hour' GROUP BY recipient;"

say "2) The stray-payment query strand-heal uses"
sudo grep -n "rl_healed') IS NULL" "$BE/utils/strand-heal.js" | sed 's/^/   /'
sudo sed -n '76,86p' "$BE/utils/strand-heal.js" | nl -ba -v76 | sed 's/^/   /'

say "3) Backup + patch"
sudo cp "$BE/utils/strand-heal.js" "$BE/utils/.strand-heal.js.bak_$TS" && echo "   backed up"
sudo python3 - "$BE/utils/strand-heal.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_SKIP_ACTIVATED' in s:
    print("   already patched"); sys.exit(0)
old = "\"AND (p.metadata->>'rl_healed') IS NULL \" + /* RL_HEAL_MARK: each payment healed exactly once */"
if old not in s:
    print("   ERROR: anchor not found — unchanged"); sys.exit(1)
new = ("\"AND (p.metadata->>'rl_healed') IS NULL \" + /* RL_HEAL_MARK: each payment healed exactly once */\n"
       "            /* RL_SKIP_ACTIVATED: a voucher is a long-lived per-device credential, so a NEW purchase\n"
       "               tops it up and re-points payment_id — leaving the PREVIOUS payment with no voucher\n"
       "               attached even though it was fully served. Healing it re-pointed the voucher back,\n"
       "               sent a duplicate SMS and granted a second period of access (10:27 -> 11:27), and the\n"
       "               newer payment then looked unfulfilled: a ping-pong costing an SMS credit and free\n"
       "               time on every pass. voucher_activated_at is stamped when a voucher is activated FOR\n"
       "               THIS payment, so it records fulfilment regardless of where the voucher now points. */\n"
       "            \"AND p.voucher_activated_at IS NULL \" +")
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   patched: activated payments are no longer re-healed")
PY
cd "$BE" && sudo -u www-data node --check utils/strand-heal.js && echo "   syntax OK"

say "4) Mark the already-served payments so the loop stops immediately"
q -c "UPDATE payments SET metadata = COALESCE(metadata,'{}'::jsonb) || jsonb_build_object('rl_healed','served')
      WHERE voucher_activated_at IS NOT NULL AND (metadata->>'rl_healed') IS NULL;"

say "5) Restart and watch 90s — no further heals or duplicate SMS"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1
sleep 90
pm2 logs rumalink-backend --lines 120 --nostream 2>/dev/null \
  | grep -iE "strand-heal.*(REUSED|NEW voucher)|purchase-sms" | tail -8 | sed 's/^/   /' || echo "   ${G}no heals, no SMS — the loop has stopped${N}"

say "6) Final state"
q -c "SELECT code, LEFT(payment_id::text,8) AS points_at, status, expires_at FROM hotspot_vouchers ORDER BY updated_at DESC NULLS LAST LIMIT 4;"
q -c "SELECT count(*) AS sms_last_10_min FROM sms_logs WHERE sent_at > now() - interval '10 minutes';"
q -c "SELECT company_name, sms_balance FROM isps;"

echo
echo "   ${Y}Buy again on IntaSend: expect ONE activation, ONE SMS, and the correct expiry.${N}"
echo "   Rollback: sudo cp $BE/utils/.strand-heal.js.bak_$TS $BE/utils/strand-heal.js && sudo pm2 restart rumalink-backend"
