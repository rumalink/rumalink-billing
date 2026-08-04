#!/usr/bin/env bash
#
# fix_sessions_speed.sh — Active Sessions is slow, and reloads itself while you read it.
#
#  1. The 15s timer (dashboard.html:4302) reloads the table on a schedule, and All Users has a
#     30s one (4582). Both redraw a page you are already looking at and keep the router polled.
#     Removed — the lists load when you open them and when you press Refresh.
#
#  2. today_totals loops over every bound TV calling tvRouterStats() one at a time, and each of
#     those is a router round trip. Seven TVs meant seven sequential calls on EVERY request. Run
#     them together and cache the result briefly: TV byte counters move slowly, the page does not
#     need them recomputed for each viewer.
#
set -uo pipefail
BE=/var/www/rumalink/backend
D=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) Remove both auto-refresh timers"
sudo cp "$D" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   backed up"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_NO_AUTOREFRESH' in s:
    print("   already patched"); sys.exit(0)
n=0

pairs = [
 ("""  setInterval(function(){
    if (isActivePageVisible()) loadActiveSessions();   /* RL_AS_RACE_FIX */
  }, 15000);""",
  """  /* RL_NO_AUTOREFRESH: this reloaded Active Sessions every 15s — redrawing the table while you
     were reading it, and polling the router on a schedule nobody asked for. It loads when you open
     the page and when you press Refresh, which is when the answer needs to be current. */"""),
 ("""  setInterval(function(){
    var page = findUsersPage();
    if (page && page.offsetParent !== null && page.style.display !== 'none') loadUsers();
  }, 30000);""",
  """  /* RL_NO_AUTOREFRESH: All Users reloaded every 30s for the same reason. Removed. */"""),
]
for old, new in pairs:
    if old in s:
        s = s.replace(old, new, 1); n += 1
    else:
        print("   MISS: " + old.split('\n')[0][:50])
open(p,'w').write(s); print(f"   {n}/2 timer(s) removed")
PY
sudo chown www-data:www-data "$D"
echo "   remaining interval reloads:"
sudo grep -nE "setInterval\(function\(\)\{?" -A 3 "$D" | grep -cE "loadActiveSessions|loadUsers" | sed 's/^/     /'
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"

say "2) Make sure the nav click still reloads"
sudo grep -nE "loadActiveSessions\(\)" "$D" | head -8 | sed 's/^/   /'

say "3) TV usage: run the router calls together, and cache them"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js backed up"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_TV_USAGE_PARALLEL' in s:
    print("   already patched"); sys.exit(0)
old = """              let tvBytes = 0;
              for (const t of tvs) { const rs = await tvu.tvRouterStats(req.user.ispId, t.mac_address); tvBytes += (rs.bytes_in + rs.bytes_out); }"""
if old not in s:
    m = re.search(r'\n[ \t]*let tvBytes = 0;\n[ \t]*for \(const t of tvs\)[^\n]*\n', s)
    if not m:
        print("   ERROR: TV loop not found"); sys.exit(1)
    old = m.group(0).strip('\n')
new = """              /* RL_TV_USAGE_PARALLEL: this awaited tvRouterStats once per TV, and each call is a
                 router round trip — seven TVs meant seven sequential trips on every request, which is
                 most of why this endpoint felt slow. Run them together, and cache for 30s: queue byte
                 counters move slowly and every viewer was recomputing the same number. */
              let tvBytes = 0;
              const _tvKey = 'tv:' + req.user.ispId;
              const _now = Date.now();
              global.__rlTvCache = global.__rlTvCache || new Map();
              const _c = global.__rlTvCache.get(_tvKey);
              if (_c && (_now - _c.t) < 30000) {
                tvBytes = _c.v;
              } else {
                const _stats = await Promise.allSettled(
                  tvs.map(t => tvu.tvRouterStats(req.user.ispId, t.mac_address)));
                for (const r of _stats) {
                  if (r.status === 'fulfilled' && r.value) tvBytes += (r.value.bytes_in + r.value.bytes_out);
                }
                global.__rlTvCache.set(_tvKey, { t: _now, v: tvBytes });
              }"""
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   TV stats now parallel + cached 30s")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "4) Restart, then time the endpoint twice"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 15 --nostream 2>/dev/null | grep -iE "ACTIVE-SESS|error" | tail -3 | sed 's/^/   /'
echo "   (both 401 without a token, but the server-side work still runs before auth on some setups)"
for i in 1 2; do curl -s -o /dev/null -w "     call $i: %{time_total}s\n" "http://127.0.0.1:5000/api/isp/sessions/active"; done

say "5) Check in the browser"
cat <<'EOS'
   Hard-refresh, open Active Sessions:
     it should fill quickly and then STAY still — no reload every 15s
     clicking Active Sessions in the nav reloads it; so does Refresh
     the usage cards keep their figures
   Watch the server side while you click:
     pm2 logs rumalink-backend | grep ACTIVE-SESS
   One log line per click is what you want to see, not one every 15 seconds.
EOS

say "6) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Remove the 15s/30s auto-refresh timers; TV usage stats run in parallel and cache" 2>&1 | head -2 | sed 's/^/   /'
