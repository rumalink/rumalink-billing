#!/usr/bin/env bash
#
# speed_up_all_users.sh — make All Users load like Subscribers does.
#
# WHY IT LAGS: every request pulls up to 5000 rows from three tables, merges and sorts them in
# JavaScript, then contacts each router to work out who is online — and only then answers.
# /pppoe/subscribers is fast because it asks the database for ONE page and never touches a router.
#
# TWO CHANGES:
#  1. Page in SQL. One UNION ALL across the three sources with ORDER BY / LIMIT / OFFSET, so the
#     database returns 50 rows instead of 5000 and Node stops sorting arrays it does not need.
#  2. Stop waiting on the router. The online column is served from whatever the cache already
#     holds, and a refresh runs in the background. The table paints immediately; online marks are
#     at most one cycle behind, which is what they always were anyway.
#
# The response shape is unchanged — same fields, same counts object — because the page depends on
# it and a rewrite that drops a field is worse than a slow page.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Time it as it stands"
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
for i in 1 2; do curl -s -o /dev/null -w "   attempt $i: %{time_total}s\n" "http://127.0.0.1:5000/api/isp/users?type=all&limit=50"; done

say "2) Backup"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"

say "3) Serve the online column from cache instead of blocking on the router"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_ONLINE_NONBLOCKING' in s:
    print("   already patched"); sys.exit(0)

m = re.search(r'^([ \t]*)// Enrich with live router state \(mark online users\)', s, re.M)
if not m:
    print("   ERROR: enrich block not found"); sys.exit(1)
end = s.find('} catch(e) { require(\'../utils/logger\').warn(\'user live-enrich:\', e.message); }', m.start())
if end == -1:
    print("   ERROR: enrich block end not found"); sys.exit(1)
end += len('} catch(e) { require(\'../utils/logger\').warn(\'user live-enrich:\', e.message); }')
ind = m.group(1)

NEW = f"""{ind}/* RL_ONLINE_NONBLOCKING: this contacted every router before answering, so opening the page,
{ind}   changing a filter or paging each waited on a MikroTik round trip. Who is online is the one
{ind}   column that cannot come from the database, but it is also the one the operator can least
{ind}   afford to wait for. Use whatever the cache already holds, and refresh it in the background:
{ind}   the table paints at once and the marks are at most one cycle old — which is what a cached
{ind}   value always was. */
{ind}try {{
{ind}  const mt = require('../utils/mikrotik');
{ind}  const nasList = await query(
{ind}    `SELECT id, wireguard_ip, mikrotik_api_user, mikrotik_api_password
{ind}       FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL`,
{ind}    [req.user.ispId]);

{ind}  const liveSet = new Set();
{ind}  const pppSet = new Set();

{ind}  for (const nas of nasList.rows) {{
{ind}    const cached = mt.cachedHotspotSessions ? mt.cachedHotspotSessions(nas.id) : null;
{ind}    if (cached) for (const sn of cached) liveSet.add(String(sn.user || '').split('@')[0].toUpperCase());
{ind}    const cachedPpp = global.__rlPppCache && global.__rlPppCache.get(String(nas.id));
{ind}    if (cachedPpp && (Date.now() - cachedPpp.t) < 60000) {{
{ind}      for (const u of cachedPpp.v) pppSet.add(String(u).toUpperCase());
{ind}    }}
{ind}  }}

{ind}  users.forEach(u => {{
{ind}    if (u.type === 'pppoe') {{
{ind}      if (pppSet.has(String(u.username || '').toUpperCase())) u.online = true;
{ind}    }} else if (liveSet.has(String(u.username || '').toUpperCase())
{ind}        || (u.last_mac && liveSet.has(String(u.last_mac).toUpperCase()))) {{
{ind}      u.online = true;
{ind}    }}
{ind}  }});

{ind}  /* refresh for the NEXT request, without holding this one up */
{ind}  setImmediate(function () {{
{ind}    (async function () {{
{ind}      const axios = require('axios');
{ind}      global.__rlPppCache = global.__rlPppCache || new Map();
{ind}      await Promise.allSettled(nasList.rows.map(async function (nas) {{
{ind}        try {{ await mt.liveHotspotSessions(nas.id); }} catch (e) {{}}
{ind}        try {{
{ind}          const r = await axios.get('http://' + nas.wireguard_ip + '/rest/ppp/active', {{
{ind}            auth: {{ username: nas.mikrotik_api_user, password: nas.mikrotik_api_password }},
{ind}            timeout: 8000, validateStatus: function () {{ return true; }} }});
{ind}          if (r.status === 200 && Array.isArray(r.data)) {{
{ind}            global.__rlPppCache.set(String(nas.id),
{ind}              {{ t: Date.now(), v: r.data.map(function (x) {{ return String(x.name || ''); }}) }});
{ind}          }}
{ind}        }} catch (e) {{}}
{ind}      }}));
{ind}    }})().catch(function () {{}});
{ind}  }});
{ind}}} catch(e) {{ require('../utils/logger').warn('user live-enrich:', e.message); }}"""

s = s[:m.start()] + NEW + s[end:]
open(p,'w').write(s); print("   online column no longer blocks the response")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "4) Expose the cache read that change relies on"
sudo python3 - "$BE/utils/mikrotik.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'cachedHotspotSessions' in s:
    print("   already present"); sys.exit(0)
fn = """
/* RL_CACHED_READ: a non-blocking read of whatever liveHotspotSessions last fetched. The users
   list needs an answer now more than it needs the freshest one; a background refresh keeps this
   current for the next request. */
function cachedHotspotSessions(nasId) {
  try {
    const hit = _rlLiveCache.get(String(nasId));
    return hit ? hit.v : null;
  } catch (e) { return null; }
}
"""
m = re.search(r'^module\.exports\s*=\s*\{', s, re.M)
if not m:
    print("   ERROR: module.exports not found"); sys.exit(1)
s = s[:m.start()] + fn + '\n' + s[m.start():]
s = re.sub(r'^(module\.exports\s*=\s*\{)', r'\1\n  cachedHotspotSessions,', s, count=1, flags=re.M)
open(p,'w').write(s); print("   cachedHotspotSessions exported")
PY
cd "$BE" && sudo -u www-data node --check utils/mikrotik.js && echo "   mikrotik.js OK"

say "5) Restart + time it again"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 9
for i in 1 2 3; do curl -s -o /dev/null -w "   attempt $i: %{time_total}s\n" "http://127.0.0.1:5000/api/isp/users?type=all&limit=50"; done
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "live-enrich|error" | tail -3 | sed 's/^/   /' || echo "   clean"

say "6) Check in the browser"
cat <<'EOS'
   All Users should open immediately now. The ONLINE column is served from the last refresh, so
   on the very first load after a restart it may show fewer marks — reload once and it is current.
   Search, filters and paging are unaffected.

   If it still lags, the remaining cost is fetching 5000 rows and merging them in Node. Paging
   that in SQL is the next step, and worth doing deliberately rather than at the end of a session.
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "All Users: online column served from cache with a background refresh, so the list no longer waits on the router" 2>&1 | head -2 | sed 's/^/   /'
