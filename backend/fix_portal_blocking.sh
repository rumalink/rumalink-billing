#!/usr/bin/env bash
#
# fix_portal_blocking.sh — URGENT: restore the captive portal flow.
#
# CAUSE: my getMac() rewrite performs a network request to the hotspot gateway before /pay runs.
# The old version pointed at an unreachable 192.168.88.1 and failed in milliseconds; mine reaches
# a real host behind a captive portal, where the request can stall. Because the purchase path does
# `const mac = await getMac()` BEFORE calling /pay, everything after it waits — which is why the
# spinner only appears once the STK push has already been answered.
#
# FIX: getMac() becomes instant and offline. MikroTik always puts the MAC in the hotspot login
# URL, so the fetch was never necessary. No network call means nothing to block on.
#
set -uo pipefail
CP=/var/www/rumalink/captive
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) Backups available if we need a full revert"
sudo ls -1t "$CP"/.classic.html.bak_* 2>/dev/null | head -8 | while read b; do
  printf "   %-44s %s  (%s lines)\n" "$(basename "$b")" "$(stat -c '%y' "$b" | cut -d'.' -f1)" "$(sudo wc -l < "$b")"
done
echo "   current: $(sudo wc -l < "$CP/classic.html") lines"

say "2) The blocking call as it stands"
LM=$(grep -n "async function getMac" "$CP/classic.html" | head -1 | cut -d: -f1)
[ -n "$LM" ] && sudo sed -n "${LM},$((LM+22))p" "$CP/classic.html" | nl -ba -v"$LM" | sed 's/^/   /'

say "3) Replace it with an instant, offline version"
sudo cp "$CP/classic.html" "$CP/.classic.html.bak_$TS" && echo "   backed up as .classic.html.bak_$TS"
sudo python3 - "$CP/classic.html" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
m = re.search(r'^([ \t]*)async function getMac\(\)\s*\{.*?\n\1\}', s, re.S | re.M)
if not m:
    print("   ERROR: getMac not found — unchanged"); sys.exit(1)
ind = m.group(1)
new = (
f"{ind}/* RL_GETMAC_INSTANT: this must never block. An earlier version fetched the hotspot gateway\n"
f"{ind}   to ask for the MAC; the purchase path does `await getMac()` before /pay, so a slow or\n"
f"{ind}   intercepted request stalled the whole flow — the spinner appeared only after the STK push\n"
f"{ind}   had been answered. MikroTik already puts the MAC in the hotspot login URL, so read it from\n"
f"{ind}   there and return immediately. No network call, nothing to wait on. */\n"
f"{ind}async function getMac() {{\n"
f"{ind}  try {{\n"
f"{ind}    var q = new URLSearchParams(location.search);\n"
f"{ind}    var m = q.get('mac') || q.get('client_mac') || q.get('client-mac') || '';\n"
f"{ind}    if (/^[0-9A-Fa-f]{{2}}([:-][0-9A-Fa-f]{{2}}){{5}}$/.test(m)) return m.toUpperCase();\n"
f"{ind}    if (window.RL_MAC && /^[0-9A-Fa-f]{{2}}([:-][0-9A-Fa-f]{{2}}){{5}}$/.test(window.RL_MAC)) return String(window.RL_MAC).toUpperCase();\n"
f"{ind}  }} catch (e) {{}}\n"
f"{ind}  return '';\n"
f"{ind}}}"
)
s = s[:m.start()] + new + s[m.end():]
open(p,'w').write(s); print("   getMac is now instant and makes no network request")
PY
sudo chown www-data:www-data "$CP/classic.html"
echo "   any remaining network call inside getMac:"
LM2=$(grep -n "RL_GETMAC_INSTANT" "$CP/classic.html" | head -1 | cut -d: -f1)
[ -n "$LM2" ] && sudo sed -n "${LM2},$((LM2+22))p" "$CP/classic.html" | grep -c "fetch(" | sed 's/^/     fetch calls: /'

say "4) Structure check"
echo "   div balance: $(( $(grep -o '<div' "$CP/classic.html" | wc -l) - $(grep -o '</div>' "$CP/classic.html" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$CP/classic.html" | wc -l) / $(grep -o '</script>' "$CP/classic.html" | wc -l)"
echo "   error display still present (line ~775):"
grep -n "showMsg(json.error" "$CP/classic.html" | sed 's/^/     /'
echo "   any leftover blocks of mine:"
grep -c "RL_CODE_LOGIN_UI\|RL_REDEEM_ERRORS_GLOBAL" "$CP/classic.html" | sed 's/^/     should be 0: /'

say "5) Serve check"
curl -sk -o /dev/null -w "   portal HTTP %{http_code}\n" https://rumalinkenterprise.online/captive/classic.html

say "6) If the flow is STILL wrong, revert completely"
OLD=$(sudo ls -1t "$CP"/.classic.html.bak_* 2>/dev/null | tail -1)
cat <<EOS
   The oldest backup here predates all of today's portal edits:
     $OLD
   To go back to it:
     sudo cp $OLD $CP/classic.html && sudo chown www-data:www-data $CP/classic.html
   That reverts the portal only. The backend device limit and config sync are unaffected.
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "getMac must not block the purchase flow: read the MAC from the login URL, no network call" 2>&1 | head -2 | sed 's/^/   /'
