#!/usr/bin/env bash
#
# fix_users_list.sh — All Users misses people and both lists are slow.
#
# 1) MISSING USERS: each source query carries LIMIT 50, then the handler slices
#    filtered.slice(offset, offset+limit) from the combined array. Only the first 50 hotspot
#    vouchers, 50 TVs and 50 subscribers are ever fetched, so page 2 re-slices the same set and
#    anyone past row 50 of a source is invisible. The counts are wrong for the same reason.
#    Fetch the ISP's full set and let the slice do the paging.
#
# 2) SLOW: /users and /sessions/active each call the router over REST on every request. Cache
#    that lookup briefly so a page refresh, a filter change and the two endpoints together do not
#    each wait on the MikroTik.
#
# 3) The search box autofills because it has no autocomplete="off".
#
set -uo pipefail
BE=/var/www/rumalink/backend
D=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) How many users actually exist"
q -c "SELECT (SELECT count(*) FROM hotspot_vouchers WHERE is_tv IS NOT TRUE) AS hotspot,
             (SELECT count(*) FROM hotspot_bound_devices) AS tvs,
             (SELECT count(*) FROM pppoe_subscribers) AS pppoe,
             (SELECT count(*) FROM radacct WHERE acctstoptime IS NULL) AS online_now;"
echo "   ${Y}anything above 50 in a column is currently unreachable in the list${N}"

say "2) Backups"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"
sudo cp "$BE/utils/mikrotik.js" "$BE/utils/.mikrotik.js.bak_$TS" && echo "   mikrotik.js"
sudo cp "$D" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   dashboard.html"

say "3) Fetch every user, not the first 50 of each source"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_USERS_FETCH_ALL' in s:
    print("   already patched"); sys.exit(0)

start = s.find("router.get('/users'")
end   = s.find("router.put('/users/:id'", start)
seg = s[start:end]
before = seg

# the three source queries cap themselves at $2 = limit; page from the combined set instead
seg = seg.replace("ORDER BY v.created_at DESC LIMIT $2\n      `, [req.user.ispId, limit]);",
                  "ORDER BY v.created_at DESC LIMIT $2\n      `, [req.user.ispId, FETCH_CAP]);")
seg = seg.replace('" WHERE bd.isp_id=$1::uuid ORDER BY bd.created_at DESC LIMIT $2",\n          [req.user.ispId, limit]);',
                  '" WHERE bd.isp_id=$1::uuid ORDER BY bd.created_at DESC LIMIT $2",\n          [req.user.ispId, FETCH_CAP]);')
seg = seg.replace("ORDER BY s.created_at DESC LIMIT $2\n        `, [req.user.ispId, limit]);",
                  "ORDER BY s.created_at DESC LIMIT $2\n        `, [req.user.ispId, FETCH_CAP]);")

anchor = "    let users = [];"
if anchor not in seg:
    print("   ERROR: users array declaration not found"); sys.exit(1)
seg = seg.replace(anchor,
  "    /* RL_USERS_FETCH_ALL: each source query used LIMIT = the PAGE size, then the handler sliced\n"
  "       offset..offset+limit from the combined array. Only the first page of each source was ever\n"
  "       fetched, so page 2 re-sliced the same rows and anyone past row 50 of a source could not be\n"
  "       reached at all — and the counts were wrong for the same reason. Fetch the ISP's whole set\n"
  "       and let the slice below do the paging. */\n"
  "    const FETCH_CAP = 5000;\n" + anchor, 1)

changed = seg.count('FETCH_CAP') - 1
s = s[:start] + seg + s[end:]
open(p,'w').write(s)
print(f"   {changed} source quer(ies) now fetch the full set")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "4) Cache the router lookup so the lists stop waiting on it"
sudo python3 - "$BE/utils/mikrotik.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_LIVE_SESSIONS_CACHE' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^(async function liveHotspotSessions\s*\(([^)]*)\)\s*\{)', s, re.M)
if not m:
    print("   ERROR: liveHotspotSessions not found — unchanged"); sys.exit(1)
arg = (m.group(2).split(',')[0] or 'nasId').strip()
cache = (
"/* RL_LIVE_SESSIONS_CACHE: /isp/users and /isp/sessions/active both call this on every request,\n"
"   so opening the users page, changing a filter or paging all waited on a MikroTik round trip —\n"
"   and with several routers those add up. Who is online changes slowly compared with how often\n"
"   these pages are drawn, so a few seconds of cache removes the wait without showing anything\n"
"   meaningfully stale. */\n"
"const _rlLiveCache = new Map();\n"
"const _RL_LIVE_TTL = 8000;\n\n")
body_start = m.end(1)
inject = (f"\n  const _ck = String({arg});\n"
          f"  const _hit = _rlLiveCache.get(_ck);\n"
          f"  if (_hit && (Date.now() - _hit.t) < _RL_LIVE_TTL) return _hit.v;\n")
s = s[:m.start(1)] + cache + s[m.start(1):body_start] + inject + s[body_start:]

# store on the way out
m2 = re.search(r'^(async function liveHotspotSessions[\s\S]*?)\n\}', s, re.M)
if m2:
    fn = m2.group(1)
    fn2 = re.sub(r'\n(\s*)return ([^;]+);', lambda mm: f"\n{mm.group(1)}{{ const _v = {mm.group(2)}; _rlLiveCache.set(_ck, {{ t: Date.now(), v: _v }}); return _v; }}", fn)
    s = s[:m2.start(1)] + fn2 + s[m2.end(1):]
open(p,'w').write(s); print("   liveHotspotSessions now cached for 8s per router")
PY
cd "$BE" && sudo -u www-data node --check utils/mikrotik.js && echo "   mikrotik.js OK"

say "5) Stop the search box autofilling"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
n=0
def fix(mm):
    global n
    tag = mm.group(0)
    if 'autocomplete' in tag: return tag
    n += 1
    return tag[:-1] + ' autocomplete="off" spellcheck="false">'
s = re.sub(r'<input[^>]*id="(sub-search|user-search|[a-z-]*search[a-z-]*)"[^>]*>', fix, s)
open(p,'w').write(s); print(f"   {n} search input(s) set to autocomplete=off")
PY
sudo chown www-data:www-data "$D"
grep -n 'id="sub-search"' "$D" | head -2 | sed 's/^/   /'

say "6) Restart + measure"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
echo "   timing /isp/users (needs an ISP token, so this only checks it responds):"
curl -s -o /dev/null -w "     first call  %{time_total}s  HTTP %{http_code}\n" "http://127.0.0.1:5000/api/isp/users?type=all&limit=50"
curl -s -o /dev/null -w "     second call %{time_total}s  HTTP %{http_code}\n" "http://127.0.0.1:5000/api/isp/users?type=all&limit=50"
pm2 logs rumalink-backend --lines 25 --nostream 2>/dev/null | grep -iE "isp/users|ACTIVE-SESS|error" | tail -5 | sed 's/^/   /'

say "7) Check in the browser"
cat <<'EOS'
   Reload the ISP dashboard, open All Users:
     - the total should match section 1 (hotspot + tvs + pppoe)
     - paging past 50 should show different people
     - the All / Hotspot / PPPoE filters should change the list
     - the search box should start empty
   If the filters still do nothing, paste lines 4443-4460 of isp/dashboard.html and I will wire them.
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "All Users: fetch every user (paging was re-slicing page 1), cache the router lookup, stop search autofill" 2>&1 | head -2 | sed 's/^/   /'
