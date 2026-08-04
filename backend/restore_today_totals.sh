#!/usr/bin/env bash
#
# restore_today_totals.sh
#  1. Put back today_totals — the old response returned { sessions, today_totals } and my rewrite
#     returned only sessions, so the three usage cards fell to 0 B. Recovered from the backup so
#     it computes exactly as before rather than from my guess at what it measured.
#  2. Drop the 15s auto-refresh on Active Sessions; refresh when the nav item is clicked instead.
#  3. Stop the sessions search box autofilling.
#
set -uo pipefail
BE=/var/www/rumalink/backend
D=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) Find today_totals in the most recent backup that still has it"
SRC=""
for b in $(sudo ls -1t "$BE/routes/".isp.js.bak_* 2>/dev/null); do
  if sudo grep -q "today_totals" "$b"; then SRC="$b"; break; fi
done
echo "   source: ${SRC:-none found}"
[ -n "$SRC" ] && sudo grep -n "today_totals" "$SRC" | head -6 | sed 's/^/   /'

say "2) The computation it used"
if [ -n "$SRC" ]; then
  L=$(sudo grep -n "today_totals" "$SRC" | head -1 | cut -d: -f1)
  sudo sed -n "$((L-30)),$((L+6))p" "$SRC" | nl -ba -v"$((L-30))" | sed 's/^/   /'
fi

say "3) Backup + restore it into the new handler"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"
sudo python3 - "$BE/routes/isp.js" "${SRC:-}" <<'PY'
import sys, re
p, src = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else '')
s = open(p).read()
if 'RL_AS_TODAY_TOTALS' in s:
    print("   already present"); sys.exit(0)
if not src:
    print("   ERROR: no backup with today_totals"); sys.exit(1)
old = open(src).read()

i = old.find("router.get('/sessions/active'")
m = re.compile(r'^\}\);\s*$', re.M).search(old, i)
seg = old[i:m.end()]

# capture from the first mention of today_totals up to the response
j = seg.find('today_totals')
k = seg.rfind('\n', 0, j)
start = seg.rfind('\n', 0, k)
while start > 0 and 'today_totals' in seg[start:j]:
    start = seg.rfind('\n', 0, start)
blockstart = seg.rfind('/* RL_AS_TODAY_TOTALS', 0, j)
if blockstart == -1:
    blockstart = seg.rfind('\n', 0, seg.rfind('today_totals', 0, j) if seg.count('today_totals') > 1 else j)
resp = seg.find('res.json(', blockstart)
block = seg[blockstart:resp].rstrip()
if 'today_totals' not in block:
    print("   ERROR: could not isolate the block; paste section 2 and it can be inserted by hand"); sys.exit(1)

anchor = "    _logger.info('[ACTIVE-SESS] returning '"
if anchor not in s:
    print("   ERROR: new handler anchor missing"); sys.exit(1)
note = ("    /* RL_AS_TODAY_TOTALS: restored. The rewrite returned only { sessions }, so the three usage\n"
        "       cards read 0 B — the page takes their values from here. */\n")
s = s.replace(anchor, note + block + "\n\n" + anchor, 1)
s = s.replace("      total: sessions.length,", "      today_totals,\n      total: sessions.length,", 1)
open(p,'w').write(s); print("   today_totals restored and returned")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"
sudo grep -n "today_totals" "$BE/routes/isp.js" | head -5 | sed 's/^/   /'

say "4) Remove the 15s auto-refresh; refresh on nav click"
sudo cp "$D" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   dashboard.html"
sudo grep -noE "setInterval\([^,]{0,40}(ActiveSess|loadActiveSessions)[^,]{0,20},[^)]{0,12}\)|setInterval\(loadActiveSessions[^)]{0,20}\)" "$D" | sed 's/^/   /'
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
n=0
def kill(m):
    global n; n+=1
    return ("/* RL_AS_NO_AUTOREFRESH: a timer refreshed this every 15s, which reloaded the table while\n"
            "   you were reading it and kept the router busy. It reloads when you open the page and when\n"
            "   you press Refresh, which is when the answer actually needs to be current. */\n"
            "0 /* auto-refresh removed */")
s, c = re.subn(r'setInterval\(\s*(?:function\s*\(\)\s*\{\s*)?loadActiveSessions[^;]{0,60}?\)\s*(?:\})?\s*,\s*\d+\s*\)', kill, s)
open(p,'w').write(s); print(f"   {n} auto-refresh timer(s) removed")
PY

say "5) Sessions search: no autofill"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
n=0
def fix(m):
    global n
    t=m.group(0)
    if 'autocomplete' in t: return t
    n+=1
    return (t.rstrip()[:-2] + ' autocomplete="off" spellcheck="false" />') if t.rstrip().endswith('/>') \
           else (t[:-1] + ' autocomplete="off" spellcheck="false">')
s = re.sub(r'<input\b[^>]*>', fix, s)
open(p,'w').write(s); print(f"   {n} input(s) updated")
PY
sudo chown www-data:www-data "$D"
echo "   inputs still without autocomplete: $(sudo grep -oE '<input\b[^>]*>' "$D" | grep -vc autocomplete)"
echo "   malformed tags (0 expected): $(sudo grep -c '\"/ autocomplete' "$D")"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"

say "6) Restart + verify"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "ACTIVE-SESS|error" | tail -4 | sed 's/^/   /'
curl -sk -o /dev/null -w "   dashboard HTTP %{http_code}\n" https://rumalinkenterprise.online/isp/dashboard.html

say "7) Check"
cat <<'EOS'
   Hard-refresh, open Active Sessions:
     the three usage cards show data again
     the table does not reload by itself while you read it
     clicking Active Sessions in the nav reloads it, as does Refresh
     the search box starts empty
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Restore today_totals lost in the sessions rewrite; refresh on click, not on a timer" 2>&1 | head -2 | sed 's/^/   /'
