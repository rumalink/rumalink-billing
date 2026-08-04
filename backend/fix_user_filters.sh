#!/usr/bin/env bash
#
# fix_user_filters.sh — PPPoE tab shows nobody; search box autofills.
#
# CAUSE: loadUsers() always requests type=all and pages 50 rows; renderRows() then filters THAT
# PAGE with u.type === state.filter. With 149 hotspot vouchers ordered newest-first, page one
# contains no PPPoE rows, so the tab correctly filters them out of a set that never had any.
# Two filters existed — one on the server, one in the browser — and only the browser's ran.
#
# FIX: send the tab's filter to the server, which already knows how to query each type, and stop
# filtering in the browser. The server also pages within that type, so PPPoE returns all 24
# whichever page you are on, and the counts stay honest.
#
set -uo pipefail
D=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) The two filters, as they stand"
sudo sed -n '4389,4396p' "$D" | nl -ba -v4389 | sed 's/^/   /'
sudo sed -n '4535,4546p' "$D" | nl -ba -v4535 | sed 's/^/   /'

say "2) Which input drives the users search?"
sudo grep -noE '<input[^>]*(state\.search|loadUsers)[^>]*>' "$D" | cut -c1-180 | sed 's/^/   /'
sudo grep -n "state.search *=" "$D" | head -5 | sed 's/^/   /'

say "3) Backup"
sudo cp "$D" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   .dashboard.html.bak_$TS"

say "4) Send the filter to the server"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SERVER_SIDE_FILTER' in s:
    print("   already patched"); sys.exit(0)
n = 0

old = "      var d = await api('/isp/users?type=all' + qs);"
new = ("      /* RL_SERVER_SIDE_FILTER: this always asked for type=all and paged 50 rows, then the\n"
       "         browser filtered that page by type. With 149 hotspot vouchers newest-first, page one\n"
       "         held no PPPoE rows, so the PPPoE tab filtered an empty set and reported no users.\n"
       "         Ask the server for the type instead — it queries and pages within it, so every tab\n"
       "         returns its full list. */\n"
       "      var d = await api('/isp/users?type=' + (state.filter || 'all') + qs);")
if old in s:
    s = s.replace(old, new, 1); n += 1
else:
    print("   MISS: loadUsers fetch line")

# the browser must stop filtering, or it will drop rows the server correctly returned
old2 = "    if (state.filter !== 'all') rows = rows.filter(function(u){ return u.type === state.filter; });"
new2 = ("    /* RL_SERVER_SIDE_FILTER: the server has already returned only this type. Filtering again\n"
        "       here would drop TVs from the Hotspot tab (their type is tv_hotspot) and re-introduce\n"
        "       the page-one problem. One filter, on the server. */")
if old2 in s:
    s = s.replace(old2, new2, 1); n += 1
else:
    m = re.search(r'^[ \t]*if \(state\.filter !== .all.\) rows = rows\.filter\([^\n]*\n', s, re.M)
    if m:
        s = s[:m.start()] + new2 + "\n" + s[m.end():]; n += 1
    else:
        print("   MISS: renderRows filter line")

# changing tab must refetch from the server, not just redraw
m3 = re.search(r"(state\.filter = tab\.getAttribute\('data-user-filter'\);)", s)
if m3:
    s = s[:m3.end()] + "\n        state.offset = 0; /* RL_SERVER_SIDE_FILTER: new type, start at page one */" + s[m3.end():]
    n += 1
    tail = s[m3.end(): m3.end() + 700]
    tail2 = tail.replace("renderRows();", "loadUsers();", 1)
    if tail2 != tail:
        s = s[:m3.end()] + tail2 + s[m3.end()+700:]
        n += 1
    else:
        print("   NOTE: tab handler still calls renderRows — check it refetches")
open(p,'w').write(s); print(f"   {n} edit(s) applied")
PY

say "5) Stop the users search autofilling"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
n = 0
def fix(m):
    global n
    tag = m.group(0)
    if 'autocomplete' in tag:
        return tag
    n += 1
    # keep a self-closing tag self-closing
    if tag.rstrip().endswith('/>'):
        return tag.rstrip()[:-2] + ' autocomplete="off" spellcheck="false" />'
    return tag[:-1] + ' autocomplete="off" spellcheck="false">'
s = re.sub(r'<input\b[^>]*type="(?:text|search)"[^>]*>', fix, s)
s = re.sub(r'<input\b(?![^>]*type=)[^>]*>', fix, s)
open(p,'w').write(s); print(f"   {n} text input(s) set to autocomplete=off")
PY
sudo chown www-data:www-data "$D"
echo "   malformed tags (0 expected):"
sudo grep -c '"/ autocomplete' "$D" | sed 's/^/     /'
echo "   inputs still without autocomplete:"
sudo grep -oE '<input\b[^>]*type="text"[^>]*>' "$D" | grep -vc autocomplete | sed 's/^/     /'

say "6) Structure check"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"
curl -sk -o /dev/null -w "   dashboard HTTP %{http_code}\n" https://rumalinkenterprise.online/isp/dashboard.html

say "7) Check in the browser"
cat <<'EOS'
   Hard-refresh the ISP dashboard, open All Users:
     All     -> 180
     Hotspot -> 149 (plus TVs, which the server groups with hotspot)
     PPPoE   -> 24, on any page
     search box empty on load
   The console line "[RL-Users-v5] received N user(s)" tells you what the server returned.
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "User filters run on the server; browser no longer re-filters a single page" 2>&1 | head -2 | sed 's/^/   /'
