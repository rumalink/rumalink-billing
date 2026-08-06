#!/usr/bin/env bash
#
# trace_session_killer.sh — find WHICH code path is deleting the session.
#
# acctterminatecause is Admin-Reset, so something calls the API to remove it. Eight places in the
# codebase can do that. The voucher checks out (active, unexpired, MAC set, username matches), so
# the obvious suspect — the hotspotExpire sweep — should be sparing it. Rather than guess a third
# time, log every deletion with its origin and read the answer.
#
# Adds a stack-tagged log line before each removal. Nothing else changes.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Every place that can remove a hotspot session"
grep -rn "hotspot/active/remove\|hotspot/active/'" "$BE/utils"/*.js "$BE/routes"/*.js 2>/dev/null | grep -v bak | sed 's/^/   /'

say "2) Back up the files being instrumented"
for f in utils/hotspotExpire.js utils/cron.js utils/mikrotik.js routes/captive.js routes/isp.js utils/expired-enforcer.js; do
  [ -f "$BE/$f" ] && sudo cp "$BE/$f" "$BE/$(dirname $f)/.$(basename $f).bak_$TS"
done
echo "   backed up"

say "3) Log every removal, with where it came from"
sudo python3 - "$BE" <<'PY'
import sys, os, re
be = sys.argv[1]
files = ['utils/hotspotExpire.js','utils/cron.js','utils/mikrotik.js','routes/captive.js','routes/isp.js','utils/expired-enforcer.js']
total = 0
for f in files:
    p = os.path.join(be, f)
    if not os.path.exists(p): continue
    s = open(p).read()
    if 'RL_KILL_TRACE' in s: continue
    n = 0
    def tag(m):
        global n
        n += 1
        indent = m.group(1)
        return (f"{indent}/* RL_KILL_TRACE */ try {{ require('{'../utils/logger' if f.startswith('routes/') else './logger'}')"
                f".warn('[KILL-TRACE] {f} removing hotspot session: ' + new Error().stack.split('\\n').slice(1,4).join(' | ')); }} catch(e){{}}\n"
                + m.group(0))
    s2 = re.sub(r'^([ \t]*)(await axios\.delete\([^\n]*hotspot/active/[^\n]*|await axios\.post\([^\n]*hotspot/active/remove[^\n]*|await ax\.delete\([^\n]*hotspot/active/[^\n]*|await client\.post\([^\n]*hotspot/active/remove[^\n]*|await api\.delete\([^\n]*hotspot/active/[^\n]*)',
                tag, s, flags=re.M)
    if s2 != s:
        open(p,'w').write(s2)
        print(f"   {f}: {n} removal site(s) tagged")
        total += n
print(f"   {total} site(s) instrumented")
PY
for f in utils/hotspotExpire.js utils/cron.js utils/mikrotik.js routes/captive.js routes/isp.js utils/expired-enforcer.js; do
  [ -f "$BE/$f" ] && (cd "$BE" && sudo -u www-data node --check "$f" >/dev/null 2>&1 && echo "   $f OK" || echo "   ${Y}$f FAILED — restoring${N}" && sudo cp "$BE/$(dirname $f)/.$(basename $f).bak_$TS" "$BE/$f")
done

say "4) Restart with tracing on"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 10 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"

say "5) Now reconnect DBDANDO, then read the answer"
cat <<'EOS'
   Log in as DBDANDO and wait for it to drop, then run:

     pm2 logs rumalink-backend --lines 300 --nostream | grep -A2 KILL-TRACE | tail -20

   The line names the file and the call chain that removed the session. That identifies the
   culprit exactly — no more guessing.

   Also worth capturing at the same moment:
     sudo -u postgres psql -d rumalink_db -c "SELECT username, acctstarttime, acctstoptime, acctterminatecause FROM radacct WHERE username LIKE 'DBDANDO@%' ORDER BY acctstarttime DESC LIMIT 3;"
EOS

say "6) Removing the tracing afterwards"
echo "   for f in utils/hotspotExpire.js utils/cron.js utils/mikrotik.js routes/captive.js routes/isp.js utils/expired-enforcer.js; do"
echo "     sudo cp $BE/\$(dirname \$f)/.\$(basename \$f).bak_$TS $BE/\$f; done && sudo pm2 restart rumalink-backend"
