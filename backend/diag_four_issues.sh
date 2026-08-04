#!/usr/bin/env bash
# READ ONLY — four issues: MAC-less limit bypass, manual users blocked, PPPoE password display,
# and delete not working. Nothing is changed.
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) MAC-LESS BYPASS — how many sessions can we count instead?"
sudo grep -n "RL_REDEEM_DEVICE_LIMIT" -A 6 "$BE/routes/captive.js" | head -12 | sed 's/^/   /'
echo "   open RADIUS sessions per voucher (the fallback signal):"
q -c "SELECT username, count(*) AS open_sessions, string_agg(DISTINCT callingstationid, ',') AS macs
      FROM radacct WHERE acctstoptime IS NULL GROUP BY username ORDER BY 2 DESC LIMIT 6;"

say "2) MANUAL USERS — where does 'voucher doesn't have payment' come from?"
grep -rniE "payment.*(required|missing|not found)|no payment|doesn.t have payment|awaiting payment" \
  "$BE/routes" "$BE/utils" --include=*.js 2>/dev/null | grep -v -E 'node_modules|\.bak' | head -12 | sed 's/^/   /'
echo "   --- vouchers created without a payment ---"
q -c "SELECT code, status, payment_id IS NULL AS no_payment, is_tv, expires_at, created_by_isp
      FROM hotspot_vouchers WHERE payment_id IS NULL ORDER BY created_at DESC LIMIT 8;"
echo "   --- do they have RADIUS credentials? ---"
q -c "SELECT rc.username, rc.attribute FROM radcheck rc
      WHERE rc.username IN (SELECT code || '@' || lower(left(replace(isp_id::text,'-',''),8))
                            FROM hotspot_vouchers WHERE payment_id IS NULL)
      ORDER BY rc.username LIMIT 10;"

say "3) PPPOE PASSWORD — is it stored, and does the API return it?"
q -c "SELECT column_name FROM information_schema.columns WHERE table_name='pppoe_subscribers'
        AND (column_name ILIKE '%pass%' OR column_name ILIKE '%user%') ORDER BY 1;"
q -c "SELECT username, LEFT(COALESCE(password,''),3)||'***' AS pw_stored, status FROM pppoe_subscribers LIMIT 5;"
echo "   --- what the GET route selects ---"
grep -nE "router\.get\('/subscribers|SELECT .* FROM pppoe_subscribers" "$BE/routes/pppoe.js" | head -8 | sed 's/^/   /'
echo "   --- the UPDATE route ---"
grep -nE "router\.put\('/subscribers|UPDATE pppoe_subscribers" "$BE/routes/pppoe.js" | head -8 | sed 's/^/   /'
LU=$(grep -n "router.put('/subscribers" "$BE/routes/pppoe.js" | head -1 | cut -d: -f1)
[ -n "$LU" ] && sudo sed -n "${LU},$((LU+45))p" "$BE/routes/pppoe.js" | nl -ba -v"$LU" | sed 's/^/     /'

say "4) DELETE — do the routes exist, and what do they do?"
echo "   --- hotspot voucher delete ---"
grep -rnE "router\.delete" "$BE/routes/hotspot.js" 2>/dev/null | sed 's/^/   /'
echo "   --- pppoe subscriber delete ---"
grep -rnE "router\.delete" "$BE/routes/pppoe.js" 2>/dev/null | sed 's/^/   /'
LD=$(grep -n "router.delete" "$BE/routes/pppoe.js" | head -1 | cut -d: -f1)
[ -n "$LD" ] && sudo sed -n "${LD},$((LD+40))p" "$BE/routes/pppoe.js" | nl -ba -v"$LD" | sed 's/^/     /'

say "5) What the ISP dashboard calls for delete/edit"
D=/var/www/rumalink/isp/dashboard.html
grep -noE "method: *'DELETE'|DELETE'|/subscribers/[^'\"]{0,30}|/vouchers/[^'\"]{0,30}" "$D" 2>/dev/null | head -14 | sed 's/^/   /'
echo "   --- delete handlers in the UI ---"
grep -noE "function (delete|del|remove)[A-Za-z]*\([^)]*\)" "$D" 2>/dev/null | head -10 | sed 's/^/   /'

say "6) Foreign keys that could block a delete"
q -c "SELECT tc.table_name AS child, kcu.column_name, ccu.table_name AS parent, rc.delete_rule
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu ON kcu.constraint_name=tc.constraint_name
      JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name=tc.constraint_name
      JOIN information_schema.referential_constraints rc ON rc.constraint_name=tc.constraint_name
      WHERE tc.constraint_type='FOREIGN KEY'
        AND ccu.table_name IN ('hotspot_vouchers','pppoe_subscribers')
      ORDER BY parent, child;"

say "7) Recent errors that match these actions"
pm2 logs rumalink-backend --lines 400 --nostream 2>/dev/null \
  | grep -iE "delete|update.*pppoe|no fields|payment" | tail -12 | cut -c1-160 | sed 's/^/   /'
