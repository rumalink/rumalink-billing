#!/usr/bin/env bash
#
# fix_radcheck_race.sh — two activation paths racing leave a voucher with two passwords.
#
# R107 holds Cleartext-Password = 'R107' AND = 'bx89da'. FreeRADIUS treats check items as a
# conjunction, so the customer must match BOTH — impossible — and every attempt, including a
# manual login, is rejected. The customer paid, holds the right password, and cannot get online.
#
# All three writers DELETE before INSERT, so none causes this alone. They are simply not atomic:
# two ran together, both deleted, then both inserted. The differing values give it away — one read
# the voucher before its password was set and fell back to the code (pw = v.password || v.code),
# the other read it after.
#
# Timing fixes for a timing bug tend to fail the same way later, so let the database enforce it:
# a unique index on (username, attribute) makes a second row impossible, and the writers upsert
# instead of insert. Whichever path arrives last simply corrects the value.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Duplicates today"
q -c "SELECT username, attribute, count(*) AS copies, string_agg(DISTINCT value,' | ') AS distinct_values
      FROM radcheck GROUP BY 1,2 HAVING count(*)>1 ORDER BY count(DISTINCT value) DESC, username LIMIT 20;"
q -c "SELECT count(*) AS radcheck_dupes FROM (SELECT username,attribute FROM radcheck GROUP BY 1,2 HAVING count(*)>1) x;"
q -c "SELECT count(*) AS radreply_dupes FROM (SELECT username,attribute FROM radreply GROUP BY 1,2 HAVING count(*)>1) x;"

say "2) Resolve them — the voucher's own password wins"
q -c "DELETE FROM radcheck rc USING hotspot_vouchers v
      WHERE rc.username = v.code || '@' || lower(left(replace(v.isp_id::text,'-',''),8))
        AND rc.attribute = 'Cleartext-Password'
        AND v.password IS NOT NULL AND v.password <> ''
        AND rc.value IS DISTINCT FROM v.password;"
echo "   then drop any remaining exact duplicates, keeping the earliest row:"
q -c "DELETE FROM radcheck a USING radcheck b WHERE a.username=b.username AND a.attribute=b.attribute AND a.id > b.id;"
q -c "DELETE FROM radreply a USING radreply b WHERE a.username=b.username AND a.attribute=b.attribute AND a.id > b.id;"
q -c "SELECT count(*) AS remaining_dupes FROM (SELECT username,attribute FROM radcheck GROUP BY 1,2 HAVING count(*)>1) x;"

say "3) Make a second row impossible"
q -c "CREATE UNIQUE INDEX IF NOT EXISTS ux_radcheck_user_attr ON radcheck (username, attribute);"
q -c "CREATE UNIQUE INDEX IF NOT EXISTS ux_radreply_user_attr ON radreply (username, attribute);"
q -c "SELECT indexname FROM pg_indexes WHERE tablename IN ('radcheck','radreply') AND indexname LIKE 'ux_%';"
echo "   ${Y}with the index in place a racing INSERT now fails loudly instead of silently duplicating${N}"

say "4) Upsert instead of insert, in all three writers"
for f in routes/captive.js utils/intasend-activate.js; do sudo cp "$BE/$f" "$BE/$(dirname $f)/.$(basename $f).bak_$TS"; done
sudo python3 - "$BE" <<'PY'
import sys, os, re
be = sys.argv[1]
# every INSERT INTO radcheck/radreply that lacks an ON CONFLICT clause
pat = re.compile(r'(INSERT INTO rad(?:check|reply) \(username, attribute, op, value\)\s*(?:\\n)?\s*VALUES \([^)]*\))(?!\s*(?:"|\'|`)?\s*ON CONFLICT)', re.S)
total = 0
for f in ['routes/captive.js', 'utils/intasend-activate.js']:
    p = os.path.join(be, f)
    s = open(p).read()
    if 'RL_RADCHECK_UPSERT' in s:
        print(f"   {f}: already patched"); continue
    n = 0
    def rep(m):
        global n
        n += 1
        return m.group(1) + " ON CONFLICT (username, attribute) DO UPDATE SET value = EXCLUDED.value, op = EXCLUDED.op"
    s2 = pat.sub(rep, s)
    if n:
        s2 = ("/* RL_RADCHECK_UPSERT: three paths can publish a voucher's credentials and they are not\n"
              "   atomic — two ran together, both deleted the old rows, then both inserted, leaving one\n"
              "   voucher with two different passwords and no way for the customer to satisfy both.\n"
              "   Upserting means the last writer corrects the value instead of adding to it. */\n") + s2
        open(p, 'w').write(s2)
    print(f"   {f}: {n} insert(s) now upsert")
    total += n
print(f"   {total} total")
PY
for f in routes/captive.js utils/intasend-activate.js; do (cd "$BE" && sudo -u www-data node --check "$f" && echo "   $f OK") || echo "   ${Y}$f FAILED — restoring${N}"; done

say "5) Restart and verify R107"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
q -c "SELECT username, attribute, op, value FROM radcheck WHERE username LIKE 'R107@%' ORDER BY attribute;"
q -c "SELECT username, attribute, op, value FROM radreply WHERE username LIKE 'R107@%' ORDER BY attribute;"
q -c "SELECT code, password FROM hotspot_vouchers WHERE code='R107';"
echo "   ${Y}one Cleartext-Password, matching the voucher — R107 should now log in${N}"

say "6) Any stale session blocking a re-login?"
q -c "SELECT username, callingstationid, acctstarttime FROM radacct WHERE acctstoptime IS NULL AND username LIKE 'R107@%';"

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "RADIUS credentials: unique per (username, attribute) and upserted, so racing activations cannot leave two passwords" 2>&1 | head -2 | sed 's/^/   /'
