#!/usr/bin/env bash
#
# speed_up_active_sessions.sh — same treatment for Active Sessions.
#
# The endpoint asks each router for /ip/hotspot/active, /ppp/active and /interface before it
# answers. liveHotspotSessions is cached; the other two are not, so every open, filter and refresh
# waits on two round trips per router.
#
# Unlike All Users, this page IS the live view, so caching it means showing a slightly older
# answer. Twenty seconds is the compromise: the page used to refresh itself every fifteen, so
# nothing here is staler than it was, and Refresh still forces a fresh read.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Time it as it stands"
for i in 1 2; do curl -s -o /dev/null -w "   attempt $i: %{time_total}s\n" "http://127.0.0.1:5000/api/isp/sessions/active"; done

say "2) Backup"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"

say "3) Cache the per-router fetch, refresh behind the response"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SESSIONS_CACHE' in s:
    print("   already patched"); sys.exit(0)

old = """    /* every router in parallel; one slow router cannot hold up the rest */
    const perRouter = await Promise.allSettled(nasList.rows.map(async (nas) => {"""
if old not in s:
    print("   ERROR: perRouter block not found"); sys.exit(1)

new = """    /* RL_SESSIONS_CACHE: this waited on /ip/hotspot/active, /ppp/active and /interface for every
       router before answering — two uncached round trips each, on every open and every filter
       change. This page IS the live view, so a cached answer is by definition slightly behind;
       twenty seconds is the trade, and the page used to redraw itself every fifteen anyway.
       Refresh bypasses the cache for when the answer must be current. */
    const _FRESH = String(req.query.fresh || '') === '1';
    global.__rlSessCache = global.__rlSessCache || new Map();
    const _ck = 'sess:' + req.user.ispId + ':' + type;
    const _hit = global.__rlSessCache.get(_ck);
    const _useCache = !_FRESH && _hit && (Date.now() - _hit.t) < 20000;

    /* every router in parallel; one slow router cannot hold up the rest */
    const perRouter = _useCache ? _hit.v : await Promise.allSettled(nasList.rows.map(async (nas) => {"""
s = s.replace(old, new, 1)

# store the result after the map completes
old2 = "    const routers = perRouter.filter(r => r.status === 'fulfilled').map(r => r.value);"
new2 = """    if (!_useCache) global.__rlSessCache.set(_ck, { t: Date.now(), v: perRouter });
    const routers = perRouter.filter(r => r.status === 'fulfilled').map(r => r.value);"""
if old2 in s:
    s = s.replace(old2, new2, 1)
else:
    print("   WARNING: could not find the routers line; cache will not be stored")

open(p,'w').write(s); print("   per-router fetch cached for 20s (Refresh bypasses it)")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "4) Make the Refresh button ask for a fresh read"
D=/var/www/rumalink/isp/dashboard.html
sudo cp "$D" "/var/www/rumalink/isp/.dashboard.html.bak_$TS"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SESS_FRESH' in s:
    print("   already patched"); sys.exit(0)
old = "var d = await api('/isp/sessions/active');"
if old not in s:
    print("   MISS: sessions fetch"); sys.exit(0)
new = ("/* RL_SESS_FRESH: the button means 'tell me now', so it bypasses the 20s cache. */\n"
       "            var d = await api('/isp/sessions/active' + (window._rlSessFresh ? '?fresh=1' : ''));\n"
       "            window._rlSessFresh = false;")
s = s.replace(old, new, 1)
m = re.search(r'(onclick="[^"]*loadActiveSessions\(\)[^"]*")', s)
if m:
    s = s.replace(m.group(1), 'onclick="window._rlSessFresh=true;loadActiveSessions()"', 1)
open(p,'w').write(s); print("   Refresh now requests a fresh read")
PY
sudo chown www-data:www-data "$D"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"

say "5) Restart + time it again"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 9
for i in 1 2 3; do curl -s -o /dev/null -w "   attempt $i: %{time_total}s\n" "http://127.0.0.1:5000/api/isp/sessions/active"; done
echo "   with fresh=1 (what Refresh sends):"
curl -s -o /dev/null -w "   %{time_total}s\n" "http://127.0.0.1:5000/api/isp/sessions/active?fresh=1"
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "ACTIVE-SESS|error" | tail -4 | sed 's/^/   /'

say "6) Check"
cat <<'EOS'
   Open Active Sessions — it should appear immediately. The data can be up to 20 seconds old;
   press Refresh for a live read.
   The usage cards and the tab counts are unchanged.
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Active Sessions: cache the per-router fetch for 20s; Refresh bypasses it" 2>&1 | head -2 | sed 's/^/   /'
