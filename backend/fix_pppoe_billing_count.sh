#!/usr/bin/env bash
#
# fix_pppoe_billing_count.sh — the PPPoE user count bills the wrong people.
#
# The query counts sessions from pppoe_sessions UNION subscribers with status='active'.
# pppoe_sessions is EMPTY — its only writer is a RADIUS webhook that FreeRADIUS does not call,
# since accounting goes straight to radacct. So the first branch has never contributed and the
# count is simply "who is marked active right now".
#
# Two consequences, in opposite directions:
#   - daniel2 is soft-deleted but still status='active', so it is BILLED though it no longer exists
#   - Pauline, irene and skita used the network during this cycle and then expired, so they are
#     NOT billed at all
# Billed for 22 where 24 is right. The comment at line 8 says "active at any point in the window",
# which is the correct rule — the query just could not see it.
#
# Counts anyone not deleted who was a customer during the window: still active, expired during it,
# or with a real session in radacct.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Who should be billed this cycle"
q -c "WITH w AS (SELECT billing_window_start AS ws, NOW() AS we, id FROM isps LIMIT 1)
      SELECT s.username, s.status, s.deleted_at IS NOT NULL AS deleted, s.next_billing_date,
             CASE
               WHEN s.deleted_at IS NOT NULL AND s.next_billing_date < (SELECT ws FROM w) THEN 'no — deleted before the window'
               WHEN s.status='active' THEN 'yes — active'
               WHEN s.next_billing_date >= (SELECT ws FROM w) THEN 'yes — expired during the window'
               ELSE 'no — expired before it'
             END AS verdict
      FROM pppoe_subscribers s WHERE s.isp_id=(SELECT id FROM w) ORDER BY s.username;"

say "2) Counted now vs counted correctly"
q -c "WITH w AS (SELECT billing_window_start AS ws, id FROM isps LIMIT 1)
      SELECT
        (SELECT count(*) FROM pppoe_subscribers WHERE isp_id=(SELECT id FROM w) AND status='active') AS counted_today,
        (SELECT count(*) FROM pppoe_subscribers s WHERE s.isp_id=(SELECT id FROM w)
           AND (s.deleted_at IS NULL OR s.next_billing_date >= (SELECT ws FROM w))
           AND (s.status='active' OR s.next_billing_date >= (SELECT ws FROM w))) AS should_be;"

say "3) Backup"
sudo cp "$BE/utils/billing.js" "$BE/utils/.billing.js.bak_$TS" && echo "   billing.js"

say "4) Count the customers who were actually served"
sudo python3 - "$BE/utils/billing.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_PPPOE_COUNT_FIX' in s:
    print("   already patched"); sys.exit(0)

m = re.search(r'const ppp = await query\(\s*`?[\s\S]*?\) u`,\s*\n\s*\[ispId, ws, we\]\s*\n?\s*\);', s)
if not m:
    print("   ERROR: pppoe count query not found"); sys.exit(1)

new = """const ppp = await query(
    /* RL_PPPOE_COUNT_FIX: this counted pppoe_sessions UNION status='active'. pppoe_sessions is
       empty — its only writer is a RADIUS webhook FreeRADIUS never calls, because accounting goes
       to radacct — so the count was really just "active right now". That billed a soft-deleted
       subscriber still marked active, and missed everyone who expired partway through the cycle
       despite them using the network for most of it. The intent stated at the top of this file is
       "active at any point in the window"; this counts that. radacct is the real session record. */
    `SELECT COUNT(DISTINCT u.id) AS cnt FROM (
       SELECT s.id FROM pppoe_subscribers s
         WHERE s.isp_id = $1::uuid
           AND s.deleted_at IS NULL
           AND s.status = 'active'
       UNION
       SELECT s.id FROM pppoe_subscribers s
         WHERE s.isp_id = $1::uuid
           AND s.next_billing_date >= $2::timestamptz
           AND s.next_billing_date < $3::timestamptz
       UNION
       SELECT s.id FROM pppoe_subscribers s
         JOIN radacct a ON a.username = s.username
         WHERE s.isp_id = $1::uuid
           AND a.acctstarttime < $3::timestamptz
           AND (a.acctstoptime IS NULL OR a.acctstoptime >= $2::timestamptz)
     ) u`,
    [ispId, ws, we]
  );"""
s = s[:m.start()] + new + s[m.end():]
open(p,'w').write(s); print("   count now covers anyone served during the window")
PY
cd "$BE" && sudo -u www-data node --check utils/billing.js && echo "   billing.js OK"

say "5) Restart + what the invoice now says"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const {query}=require('$BE/config/database');
(async()=>{
  const b=require('$BE/utils/billing');
  const i=(await query('SELECT id, company_name, billing_window_start FROM isps LIMIT 1')).rows[0];
  const o=await b.computeOwed(i.id, i.billing_window_start, new Date());
  console.log('   '+i.company_name);
  console.log('     hotspot revenue  KES '+Number(o.hotspot_revenue||0).toFixed(2));
  console.log('     hotspot fee      KES '+Number(o.hotspot_fee||0).toFixed(2));
  console.log('     pppoe users      '+o.pppoe_users+' x KES '+Number(o.amount_per_user||0).toFixed(2));
  console.log('     pppoe fee        KES '+Number(o.pppoe_fee||0).toFixed(2));
  console.log('     total            KES '+Number(o.total||0).toFixed(2));
  process.exit(0);
})();" 2>&1 | grep -v "^info:" | sed 's/^/  /'

say "6) Worth knowing"
cat <<'EOS'
   The count goes UP, so Rumalink owes more this cycle — but the previous figure was wrong in both
   directions: billing for a deleted subscriber and not billing three real ones.

   pppoe_sessions stays empty and is no longer relied upon. If you want it populated, the writer is
   routes/radius.js:139 behind a RADIUS webhook that is not configured. radacct already holds the
   same information, so there is nothing to gain from wiring it up.
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "PPPoE billing counts everyone served in the window (pppoe_sessions is empty; radacct is the real record)" 2>&1 | head -2 | sed 's/^/   /'
