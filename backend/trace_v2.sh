#!/usr/bin/env bash
#
# trace_v2.sh — instrument EVERY session-removal site, correctly this time.
#
# The previous attempt reverted its own work: `node --check f && echo OK || echo FAIL && cp backup f`
# binds the final && to the whole chain, so each file was restored immediately after passing its
# check. That is why nothing was traced and why grep now finds no markers.
#
# The router log shows `logged out: admin reset` ~20-30s after login, with the queue added by API
# user rl_19c3837f — our backend. So one of these ten call sites is responsible.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

FILES="utils/hotspotExpire.js utils/cron.js utils/mikrotik.js utils/expired-enforcer.js routes/captive.js routes/isp.js"

say "1) Back up"
for f in $FILES; do
  [ -f "$BE/$f" ] && sudo cp "$BE/$f" "$BE/$(dirname $f)/.$(basename $f).trace_$TS"
done
echo "   suffix .trace_$TS"

say "2) Tag every removal site"
sudo python3 - "$BE" <<'PY'
import sys, os, re
be = sys.argv[1]
files = ['utils/hotspotExpire.js','utils/cron.js','utils/mikrotik.js','utils/expired-enforcer.js','routes/captive.js','routes/isp.js']
patterns = [
  r'await axios\.delete\([^;\n]*hotspot/active/',
  r'await axios\.post\([^;\n]*hotspot/active/remove',
  r'await ax\.delete\([^;\n]*hotspot/active/',
  r'await client\.post\([^;\n]*hotspot/active/remove',
  r'await api\.delete\([^;\n]*hotspot/active/',
  r'await c\.del\([^;\n]*hotspot/active/',
  r'const r = await client\.post\([^;\n]*hotspot/active/remove',
  r'const del = await api\.delete\([^;\n]*hotspot/active/',
]
total = 0
for f in files:
    p = os.path.join(be, f)
    if not os.path.exists(p): continue
    s = open(p).read()
    if 'RL_KILL_TRACE' in s:
        print(f"   {f}: already tagged"); continue
    log = "'../utils/logger'" if f.startswith('routes/') else "'./logger'"
    out, n = [], 0
    for line in s.split('\n'):
        if any(re.search(pat, line) for pat in patterns):
            ind = re.match(r'^[ \t]*', line).group(0)
            out.append(f"{ind}/* RL_KILL_TRACE */ try {{ require({log}).error('[KILL-TRACE] {f} -> ' + (new Error().stack||'').split('\\n').slice(1,5).join(' <- ')); }} catch(_e){{}}")
            n += 1
        out.append(line)
    if n:
        open(p,'w').write('\n'.join(out))
        print(f"   {f}: {n} site(s) tagged")
        total += n
print(f"   {total} total")
PY

say "3) Syntax check — restore ONLY on failure"
BAD=0
for f in $FILES; do
  [ -f "$BE/$f" ] || continue
  if (cd "$BE" && sudo -u www-data node --check "$f" >/dev/null 2>&1); then
    printf "   ${G}OK  ${N} %s\n" "$f"
  else
    printf "   ${R}FAIL${N} %s — restoring that file only\n" "$f"
    sudo cp "$BE/$(dirname $f)/.$(basename $f).trace_$TS" "$BE/$f"
    BAD=$((BAD+1))
  fi
done
echo "   restored due to failure: $BAD"

say "4) Confirm the markers survived"
grep -c "RL_KILL_TRACE" "$BE"/utils/*.js "$BE"/routes/*.js 2>/dev/null | grep -v ":0" | sed 's/^/   /' || echo "   ${R}none present — instrumentation failed${N}"

say "5) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 10 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"

say "6) Now log in as DBDANDO and wait for the drop"
cat <<EOS
   Then:
     pm2 logs rumalink-backend --lines 400 --nostream | grep "KILL-TRACE" | tail -10

   Restore the files afterwards:
     for f in $FILES; do sudo cp \$(dirname $BE/\$f)/.\$(basename \$f).trace_$TS $BE/\$f; done
     sudo pm2 restart rumalink-backend
EOS
