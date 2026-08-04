#!/usr/bin/env bash
#
# fix_filter_and_input.sh
#  1. Repair the search input my last patch malformed: the self-closing "/" ended up between the
#     attributes -> oninput="loadSubscribers()"/ autocomplete="off">
#  2. PPPoE filter returns nobody. The page requests '/isp/users?type=all' and the filter appends
#     '&type=pppoe', so Express sees type = ['all','pppoe'] — an ARRAY. Every branch compares with
#     === against a string, all of them fail, and no source is queried at all. Normalising on the
#     server fixes it for any caller, present or future.
#
set -uo pipefail
BE=/var/www/rumalink/backend
D=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The malformed input"
sudo grep -n 'id="sub-search"' "$D" | cut -c1-200 | sed 's/^/   /'

say "2) Repair it"
sudo cp "$D" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   backed up"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
n = 0
# put the "/" back at the end of the tag
fixed, cnt = re.subn(r'/\s+(autocomplete="off" spellcheck="false")>', r' \1 />', s)
if cnt:
    s = fixed; n += cnt
open(p,'w').write(s)
print(f"   {n} tag(s) repaired")
PY
sudo grep -n 'id="sub-search"' "$D" | cut -c1-200 | sed 's/^/   /'
echo "   tag well-formed now (no stray slash):"
sudo grep -c 'oninput="loadSubscribers()"/ ' "$D" | sed 's/^/     stray-slash count (0 expected): /'

say "3) How the page builds the filter query"
sudo sed -n '4443,4462p' "$D" | nl -ba -v4443 | sed 's/^/   /'

say "4) Accept a repeated or array type on the server"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js backed up"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_TYPE_NORMALISE' in s:
    print("   already patched"); sys.exit(0)
old = "    const type = req.query.type || 'all';"
i = s.find("router.get('/users'")
j = s.find(old, i)
if j == -1:
    print("   ERROR: type declaration not found in /users"); sys.exit(1)
new = ("    /* RL_TYPE_NORMALISE: the page requests '?type=all' and the filter appends '&type=pppoe',\n"
       "       so Express hands us an ARRAY ['all','pppoe']. Every branch below compares with === to a\n"
       "       string, so all of them failed and the list came back empty — which read as 'there are no\n"
       "       PPPoE users'. Take the last value, which is the one the filter meant. */\n"
       "    const _rawType = req.query.type;\n"
       "    const type = (Array.isArray(_rawType) ? _rawType[_rawType.length - 1] : _rawType) || 'all';")
s = s[:j] + new + s[j+len(old):]
open(p,'w').write(s); print("   type normalised")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "5) Do the same for active sessions (same pattern there)"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if s.count('RL_TYPE_NORMALISE') > 1:
    print("   already patched"); sys.exit(0)
i = s.find("router.get('/sessions/active'")
old = "    const type = req.query.type || 'all';"
j = s.find(old, i)
if j == -1:
    print("   (sessions/active uses a different shape — left alone)"); sys.exit(0)
new = ("    /* RL_TYPE_NORMALISE: a repeated ?type= arrives as an array; take the last value. */\n"
       "    const _rawT = req.query.type;\n"
       "    const type = (Array.isArray(_rawT) ? _rawT[_rawT.length - 1] : _rawT) || 'all';")
s = s[:j] + new + s[j+len(old):]
open(p,'w').write(s); print("   sessions/active normalised too")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "6) Restart + prove each filter returns the right people"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
q -c "SELECT (SELECT count(*) FROM hotspot_vouchers WHERE is_tv IS NOT TRUE) AS hotspot,
             (SELECT count(*) FROM hotspot_bound_devices) AS tvs,
             (SELECT count(*) FROM pppoe_subscribers) AS pppoe;"
echo "   ${Y}the page should now show 149 hotspot + 7 TV + 24 pppoe = 180 under All${N}"
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "isp/users|error" | tail -4 | sed 's/^/   /'

say "7) Check in the browser"
cat <<'EOS'
   Reload the ISP dashboard, then:
     All    -> 180 users, paging past 50 shows different people
     Hotspot-> 149 (+7 TV depending on how the tab groups them)
     PPPoE  -> 24
     search box empty on load, and typing still filters
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Filters: accept a repeated ?type= (arrived as an array, matched nothing); repair the search input tag" 2>&1 | head -2 | sed 's/^/   /'
