#!/usr/bin/env bash
#
# fix_user_counts.sh — the tab badges follow the filter instead of the totals.
#
# counts came from the array just returned: users.filter(u => u.type === 'hotspot').length etc.
# That was accurate while the handler always fetched every type. Now that it fetches only the
# requested one, the other tabs necessarily read 0 — viewing PPPoE reports "Hotspot 0", which
# looks like the hotspot users have vanished.
#
# The badges describe the whole account, not the current view, so count them separately and
# always. Three cheap COUNT queries, unaffected by the filter.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The counts block as it stands"
sudo grep -n "counts: {" -A 6 "$BE/routes/isp.js" | head -12 | sed 's/^/   /'

say "2) Backup"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"

say "3) Count every type, regardless of which tab is open"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_COUNTS_UNFILTERED' in s:
    print("   already patched"); sys.exit(0)

old = """      counts: {
        all: users.length,
        hotspot: users.filter(u => u.type === 'hotspot').length,
        pppoe: users.filter(u => u.type === 'pppoe').length,
        online: users.filter(u => u.online).length
      }"""
if old not in s:
    m = re.search(r'counts: \{[^}]*\}', s)
    if not m:
        print("   ERROR: counts block not found"); sys.exit(1)
    old = m.group(0)

new = """      counts: _rlCounts"""
s = s.replace(old, new, 1)

# build the counts before the response
anchor = "    const total = filtered.length;"
if anchor not in s:
    print("   ERROR: total declaration not found"); sys.exit(1)
block = """    /* RL_COUNTS_UNFILTERED: these badges describe the account, not the current view. They used
       to be derived from the array just returned, which was fine while every type was always
       fetched — but now that the handler fetches only the requested type, the other tabs read 0
       and it looks as though those users have disappeared. Count them separately, always. */
    let _rlCounts = { all: 0, hotspot: 0, pppoe: 0, online: 0 };
    try {
      const _c = await query(
        `SELECT
           (SELECT count(*) FROM hotspot_vouchers v
             WHERE v.isp_id = $1::uuid
               AND (v.payment_id IS NOT NULL OR v.created_by_isp = true OR v.expires_at IS NOT NULL)
               AND (v.is_tv IS NOT TRUE OR v.is_tv IS NULL))::int AS hotspot,
           (SELECT count(*) FROM hotspot_bound_devices bd WHERE bd.isp_id = $1::uuid)::int AS tvs,
           (SELECT count(*) FROM pppoe_subscribers s WHERE s.isp_id = $1::uuid)::int AS pppoe`,
        [req.user.ispId]);
      const _r = _c.rows[0] || { hotspot: 0, tvs: 0, pppoe: 0 };
      /* the Hotspot tab shows TVs too — the server groups them there — so the badge must match */
      _rlCounts.hotspot = (_r.hotspot || 0) + (_r.tvs || 0);
      _rlCounts.pppoe = _r.pppoe || 0;
      _rlCounts.all = _rlCounts.hotspot + _rlCounts.pppoe;
      _rlCounts.online = users.filter(u => u.online).length;
    } catch (e) {
      require('../utils/logger').warn('[isp/users] counts: ' + e.message);
      _rlCounts = { all: users.length,
                    hotspot: users.filter(u => u.type === 'hotspot' || u.type === 'tv_hotspot').length,
                    pppoe: users.filter(u => u.type === 'pppoe').length,
                    online: users.filter(u => u.online).length };
    }

"""
s = s.replace(anchor, block + anchor, 1)
open(p,'w').write(s); print("   counts now computed independently of the filter")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "4) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "isp/users|error" | tail -4 | sed 's/^/   /' || echo "   clean"

say "5) What the badges should read"
q -c "SELECT
        (SELECT count(*) FROM hotspot_vouchers v WHERE (v.is_tv IS NOT TRUE OR v.is_tv IS NULL)
           AND (v.payment_id IS NOT NULL OR v.created_by_isp = true OR v.expires_at IS NOT NULL))::int AS hotspot_vouchers,
        (SELECT count(*) FROM hotspot_bound_devices)::int AS tvs,
        (SELECT count(*) FROM pppoe_subscribers)::int AS pppoe;"
echo "   ${Y}Hotspot badge = vouchers + TVs, PPPoE badge = subscribers, All = both${N}"

say "6) Check in the browser"
cat <<'EOS'
   Hard-refresh, open All Users, click through the tabs:
     every badge keeps its number whichever tab is selected
     the LIST changes, the COUNTS do not
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Tab badges count the whole account, not the filtered page" 2>&1 | head -2 | sed 's/^/   /'
