#!/usr/bin/env bash
#
# fix_users_search.sh — All Users: search does nothing, and the list is slow.
#
# SEARCH: loadUsers() sends &search=, but none of the three source queries use it. The filtering
# happens in the browser (dashboard.html:4396) against state.users — which holds only the CURRENT
# PAGE. So typing a username that exists on page 3 finds nothing, exactly as the type filter
# behaved before. The /pppoe/subscribers route already does this properly: ILIKE in SQL across
# username, full_name and phone. Same approach here.
#
# SPEED: the route fetches up to 5000 rows from three sources on every request and then asks each
# router who is online. The row count is not the problem at your size; the router calls are.
# Widening the cache removes the wait without making the online column meaningfully staler.
#
set -uo pipefail
BE=/var/www/rumalink/backend
D=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Backups"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"
sudo cp "$D" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   dashboard.html"
sudo cp "$BE/utils/mikrotik.js" "$BE/utils/.mikrotik.js.bak_$TS" && echo "   mikrotik.js"

say "2) Filter in SQL, like the subscribers route does"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SEARCH_IN_SQL' in s:
    print("   already patched"); sys.exit(0)
n = 0

# declare a reusable pattern next to the existing search read
m = re.search(r'^([ \t]*)const search = [^\n]*$', s, re.M)
if not m:
    print("   ERROR: search declaration not found"); sys.exit(1)
ind = m.group(1)
s = s[:m.end()] + (
f"\n{ind}/* RL_SEARCH_IN_SQL: &search= was accepted and then ignored — the filtering happened in the\n"
f"{ind}   browser against the CURRENT PAGE only, so anyone beyond the first 50 rows was unfindable.\n"
f"{ind}   Filter in SQL across every source, the way /pppoe/subscribers already does. */\n"
f"{ind}const _q = (search && String(search).trim()) ? '%' + String(search).trim() + '%' : null;"
) + s[m.end():]

# hotspot vouchers
old_h = """          AND (v.is_tv IS NOT TRUE OR v.is_tv IS NULL) /* RL_TV_EXCLUDE_USERS */
        ORDER BY v.created_at DESC LIMIT $2
      `, [req.user.ispId, FETCH_CAP]);"""
new_h = """          AND (v.is_tv IS NOT TRUE OR v.is_tv IS NULL) /* RL_TV_EXCLUDE_USERS */
          AND ($3::text IS NULL OR v.code ILIKE $3 OR v.buyer_phone ILIKE $3) /* RL_SEARCH_IN_SQL */
        ORDER BY v.created_at DESC LIMIT $2
      `, [req.user.ispId, FETCH_CAP, _q]);"""
if old_h in s: s = s.replace(old_h, new_h, 1); n += 1
else: print("   MISS: hotspot query")

# pppoe subscribers
old_p = """          WHERE s.isp_id = $1::uuid AND s.deleted_at IS NULL /* RL_HIDE_DELETED */
          ORDER BY s.created_at DESC LIMIT $2
        `, [req.user.ispId, FETCH_CAP]);"""
new_p = """          WHERE s.isp_id = $1::uuid AND s.deleted_at IS NULL /* RL_HIDE_DELETED */
            AND ($3::text IS NULL OR s.username ILIKE $3 OR s.full_name ILIKE $3 OR s.phone ILIKE $3) /* RL_SEARCH_IN_SQL */
          ORDER BY s.created_at DESC LIMIT $2
        `, [req.user.ispId, FETCH_CAP, _q]);"""
if old_p in s: s = s.replace(old_p, new_p, 1); n += 1
else: print("   MISS: pppoe query")

# tv devices
old_t = '" WHERE bd.isp_id=$1::uuid ORDER BY bd.created_at DESC LIMIT $2",\n          [req.user.ispId, FETCH_CAP]);'
new_t = ('" WHERE bd.isp_id=$1::uuid AND ($3::text IS NULL OR bd.name ILIKE $3 OR bd.mac_address ILIKE $3)" + /* RL_SEARCH_IN_SQL */\n'
         '          " ORDER BY bd.created_at DESC LIMIT $2",\n          [req.user.ispId, FETCH_CAP, _q]);')
if old_t in s: s = s.replace(old_t, new_t, 1); n += 1
else: print("   NOTE: tv query shape differs — searching it can be added later")

open(p,'w').write(s); print(f"   {n} source quer(ies) now filter in SQL")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "3) Stop the browser re-filtering a single page"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SEARCH_SERVER_SIDE' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)if \(state\.search\) \{\n.*?\n\1\}\n', s, re.S | re.M)
if not m:
    print("   MISS: client-side search block"); sys.exit(0)
ind = m.group(1)
note = (f"{ind}/* RL_SEARCH_SERVER_SIDE: the server now filters across every user, not just the page\n"
        f"{ind}   in front of you. Filtering again here would hide rows it correctly returned. */\n")
s = s[:m.start()] + note + s[m.end():]
open(p,'w').write(s); print("   client-side search removed")
PY

say "4) Search should re-query, not just redraw"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SEARCH_REFETCH' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r"(state\.search = e\.target\.value \|\| '';)", s)
if not m:
    print("   MISS: search handler"); sys.exit(0)
tail = s[m.end(): m.end()+400]
new_tail = tail.replace("renderRows();", "state.offset = 0; loadUsers(); /* RL_SEARCH_REFETCH: ask the server, do not redraw the page we have */", 1)
if new_tail == tail:
    print("   NOTE: handler already refetches or differs")
else:
    s = s[:m.end()] + new_tail + s[m.end()+400:]
    open(p,'w').write(s); print("   search now refetches from the server")
PY
sudo chown www-data:www-data "$D"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"

say "5) Widen the router cache so the list stops waiting"
sudo python3 - "$BE/utils/mikrotik.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
m = re.search(r'const _RL_LIVE_TTL = (\d+);', s)
if not m:
    print("   NOTE: cache constant not found"); sys.exit(0)
cur = m.group(1)
if cur == '30000':
    print("   already 30s"); sys.exit(0)
s = s[:m.start()] + 'const _RL_LIVE_TTL = 30000; /* RL_LIVE_TTL_WIDER: who is online changes slowly next to how often these pages are drawn */' + s[m.end():]
open(p,'w').write(s); print(f"   live-session cache {cur}ms -> 30000ms")
PY
cd "$BE" && sudo -u www-data node --check utils/mikrotik.js && echo "   mikrotik.js OK"

say "6) Restart + test the search server-side"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 15 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"
q -c "SELECT count(*) AS matching_benard FROM pppoe_subscribers WHERE deleted_at IS NULL AND (username ILIKE '%benard%' OR full_name ILIKE '%benard%' OR phone ILIKE '%benard%');"
q -c "SELECT count(*) AS matching_254740 FROM hotspot_vouchers WHERE deleted_at IS NULL AND buyer_phone ILIKE '%254740%';"

say "7) Try it"
cat <<'EOS'
   Reload All Users and search for a username or phone that you know is NOT on the first page —
   it should be found now. Clearing the box restores the full list.
   The counts in section 6 tell you what the server should return for those terms.
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "All Users: search filters in SQL across every user, not the current page in the browser" 2>&1 | head -2 | sed 's/^/   /'
