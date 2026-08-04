#!/usr/bin/env bash
#
# restore_totals_exact.sh
#  1. Copy the today_totals block verbatim from the backup by line number (822-852). It reads
#     usage_daily, not raw radacct — the original comment explains why: interim updates lag badly
#     on open sessions, and filtering by acctstarttime >= today drops sessions that began
#     yesterday and are still running. Recreating it from memory would get that wrong.
#  2. Find and remove the real auto-refresh timer (my previous regex matched nothing).
#
set -uo pipefail
BE=/var/www/rumalink/backend
D=/var/www/rumalink/isp/dashboard.html
SRC="$BE/routes/.isp.js.bak_1785839243"
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) The block being restored (backup lines 822-852)"
sudo sed -n '822,852p' "$SRC" | nl -ba -v822 | sed 's/^/   /'

say "2) Insert it into the current handler"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   backed up"
sudo python3 - "$BE/routes/isp.js" "$SRC" <<'PY'
import sys, re
p, src = sys.argv[1], sys.argv[2]
s = open(p).read()
if 'RL_AS_TODAY_TOTALS' in s:
    print("   already present"); sys.exit(0)
lines = open(src).read().split('\n')
block = '\n'.join(lines[821:852])          # 1-indexed 822..852
if 'today_totals' not in block:
    print("   ERROR: extracted block has no today_totals"); sys.exit(1)
# the backup indents inside a nested scope; normalise to the handler's level
block = '\n'.join(l[6:] if l.startswith('      ') else l for l in block.split('\n'))
anchor = "    _logger.info('[ACTIVE-SESS] returning '"
if anchor not in s:
    print("   ERROR: handler anchor missing"); sys.exit(1)
note = ("    /* RL_AS_TODAY_TOTALS: restored verbatim from the pre-rewrite handler. The usage cards read\n"
        "       these; my rewrite returned only { sessions } and they fell to 0 B. Deliberately sourced\n"
        "       from usage_daily rather than radacct — see the original note below. */\n")
s = s.replace(anchor, note + block + "\n\n" + anchor, 1)
if 'today_totals,' not in s:
    s = s.replace("      total: sessions.length,", "      today_totals,\n      total: sessions.length,", 1)
open(p,'w').write(s); print("   inserted")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"
sudo grep -n "today_totals" "$BE/routes/isp.js" | head -6 | sed 's/^/   /'

say "3) Where is the auto-refresh actually defined?"
sudo grep -noE "setInterval\([^)]{0,120}\)" "$D" | sed 's/^/   /'

say "4) Remove the one that reloads Active Sessions"
sudo cp "$D" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   backed up"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
n=0
out=[]
for line in s.split('\n'):
    if 'setInterval' in line and re.search(r'(loadActiveSessions|ActiveSess|sessions/active)', line):
        out.append("/* RL_AS_NO_AUTOREFRESH: this reloaded the table on a timer, redrawing it while you were")
        out.append("   reading and keeping the router polled for no benefit. Active Sessions now reloads when")
        out.append("   you open the page or press Refresh — the moments the answer needs to be current. */")
        out.append("// " + line.strip())
        n+=1
    else:
        out.append(line)
open(p,'w').write('\n'.join(out))
print(f"   {n} timer(s) commented out")
PY
sudo chown www-data:www-data "$D"
echo "   remaining session timers:"
sudo grep -cE "setInterval[^)]*(loadActiveSessions|ActiveSess)" "$D" | sed 's/^/     /'
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"

say "5) Restart + confirm the totals come back"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "ACTIVE-SESS|today_totals|error" | tail -5 | sed 's/^/   /'
sudo -u postgres psql -d rumalink_db -P pager=off -c "SELECT service, sum(bytes_in+bytes_out) AS bytes FROM usage_daily WHERE day = (now() AT TIME ZONE 'Africa/Nairobi')::date GROUP BY service;" 2>&1 | sed 's/^/   /'
echo "   ${Y}the cards should match these figures${N}"

say "6) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Restore today_totals verbatim; remove the Active Sessions auto-refresh" 2>&1 | head -2 | sed 's/^/   /'
