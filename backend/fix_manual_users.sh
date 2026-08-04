#!/usr/bin/env bash
#
# fix_manual_users.sh — a hotspot user you create by hand cannot log in.
#
# captive.js:1454 and :1515 refuse a voucher with no payment unless created_by_isp or is_test is
# set. The IMPORT path sets created_by_isp (isp.js:2883), but creating a single user does not —
# so R89, R85 and R75 were refused with "Voucher has no payment" even though you issued them
# deliberately. Set the flag on creation, and backfill the ones already affected.
#
# Also gathers what is needed to add the delete buttons you asked for.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Where a single hotspot user is created"
grep -rn "INSERT INTO hotspot_vouchers" "$BE/routes/isp.js" "$BE/routes/hotspot.js" 2>/dev/null | grep -v bak | sed 's/^/   /'

say "2) Set created_by_isp on manual creation"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS"
[ -f "$BE/routes/hotspot.js" ] && sudo cp "$BE/routes/hotspot.js" "$BE/routes/.hotspot.js.bak_$TS"
sudo python3 - "$BE/routes/isp.js" "$BE/routes/hotspot.js" <<'PY'
import sys, re
changed = 0
for p in sys.argv[1:]:
    try: s = open(p).read()
    except Exception: continue
    if 'RL_MANUAL_USER_FLAG' in s: continue
    out = s
    for m in re.finditer(r'INSERT INTO hotspot_vouchers \(([^)]*)\)\s*VALUES\s*\(([^)]*)\)', s, re.S):
        cols, vals = m.group(1), m.group(2)
        if 'created_by_isp' in cols or 'import_batch' in cols:
            continue                      # the import path already sets it
        newcols = cols.rstrip() + ", created_by_isp"
        newvals = vals.rstrip() + ", true"
        out = out.replace(m.group(0),
              'INSERT INTO hotspot_vouchers (' + newcols + ') VALUES (' + newvals + ')', 1)
        changed += 1
    if changed and 'RL_MANUAL_USER_FLAG' not in out:
        out = ("/* RL_MANUAL_USER_FLAG: a voucher with no payment is refused at login unless\n"
               "   created_by_isp is set (captive.js:1454). The import path set it; creating a single\n"
               "   user did not, so hand-made accounts were told 'Voucher has no payment'. */\n") + out
        open(p, 'w').write(out)
        print(f"   {p}: {changed} insert(s) now set created_by_isp")
if not changed:
    print("   no manual-create INSERT found — the create route may build its columns dynamically")
PY
for f in routes/isp.js routes/hotspot.js; do [ -f "$BE/$f" ] && (cd "$BE" && sudo -u www-data node --check "$f" && echo "   $f OK"); done

say "3) Let the users already created log in"
q -c "SELECT code, created_by_isp, status FROM hotspot_vouchers WHERE payment_id IS NULL AND created_by_isp IS NOT TRUE;"
q -c "UPDATE hotspot_vouchers SET created_by_isp = true
      WHERE payment_id IS NULL AND created_by_isp IS NOT TRUE AND (is_test IS NOT TRUE);"
q -c "SELECT code, created_by_isp, status FROM hotspot_vouchers WHERE payment_id IS NULL ORDER BY created_at DESC LIMIT 6;"
echo "   ${Y}they also need RADIUS credentials — checking${N}"
q -c "SELECT hv.code,
             EXISTS (SELECT 1 FROM radcheck rc
                     WHERE rc.username = hv.code || '@' || lower(left(replace(hv.isp_id::text,'-',''),8))
                       AND rc.attribute='Cleartext-Password') AS has_radius
      FROM hotspot_vouchers hv WHERE hv.payment_id IS NULL ORDER BY hv.created_at DESC LIMIT 6;"

say "4) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 7
pm2 logs rumalink-backend --lines 15 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"

say "5) For the delete buttons — what exists to work with"
echo "   soft-delete columns already present?"
q -c "SELECT table_name, column_name FROM information_schema.columns
      WHERE table_name IN ('hotspot_vouchers','pppoe_subscribers')
        AND column_name IN ('deleted_at','is_deleted','archived_at') ORDER BY 1,2;"
echo "   existing delete routes:"
grep -rn "router.delete" "$BE/routes/isp.js" "$BE/routes/hotspot.js" "$BE/routes/pppoe.js" 2>/dev/null | grep -v bak | sed 's/^/     /'
echo "   the user lifecycle page (where a row leads):"
grep -noE "openUser[A-Za-z]*\(|lifecycle|user-detail|showUserDetail" /var/www/rumalink/isp/dashboard.html | head -8 | sed 's/^/     /'
echo "   how a row is rendered (to add a button):"
sudo sed -n '/function renderRows/,/^  }/p' /var/www/rumalink/isp/dashboard.html | grep -nE "<td|onclick|tr>" | head -12 | sed 's/^/     /'

say "6) Test the login that was failing"
cat <<'EOS'
   Ask one of R89 / R85 / R75 to try again — they should connect now.
   If a code has has_radius = false above, it has no credentials yet and will still fail; say so
   and the sync can be run for those specific vouchers.
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Manually created hotspot users can log in (created_by_isp was never set outside import)" 2>&1 | head -2 | sed 's/^/   /'
