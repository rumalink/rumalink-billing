#!/usr/bin/env bash
#
# fix_getmac_hang.sh — ONE change: stop getMac() hanging. Nothing else is touched.
#
# CAUSE: getMac() does
#     await fetch('http://192.168.88.1/login?mac', { timeout: 2000 })
#   `timeout` is NOT a fetch option — browsers ignore it. 192.168.88.1 does not exist on this
#   hotspot (it runs 10.100.0.1) and nothing answers, so the request never resolves and never
#   rejects: it hangs. redeemVoucher() awaits it before sending anything, so the code entry
#   silently does nothing — no request in nginx, no error on screen, spinner stuck. The payment
#   path awaits the same call, which is why its spinner lagged too.
#
# FIX: read the MAC from the hotspot login URL MikroTik already provides. No network call at all,
# so there is nothing left to hang on.
#
set -uo pipefail
CP=/var/www/rumalink/captive
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) The hanging call"
sudo grep -n "192.168.88.1" "$CP/classic.html" | sed 's/^/   /'
LM=$(grep -n "async function getMac" "$CP/classic.html" | head -1 | cut -d: -f1)
sudo sed -n "${LM},$((LM+8))p" "$CP/classic.html" | nl -ba -v"$LM" | sed 's/^/   /'
echo "   awaited by:"
sudo grep -n "await getMac()" "$CP/classic.html" | sed 's/^/     /'

say "2) Backup"
sudo cp "$CP/classic.html" "$CP/.classic.html.bak_$TS" && echo "   .classic.html.bak_$TS  ($(sudo wc -l < "$CP/classic.html") lines)"

say "3) Replace getMac with an instant, offline version"
sudo python3 - "$CP/classic.html" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_GETMAC_INSTANT' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)async function getMac\(\)\s*\{.*?\n\1\}', s, re.S | re.M)
if not m:
    print("   ERROR: getMac not found — unchanged"); sys.exit(1)
ind = m.group(1)
new = (
f"{ind}/* RL_GETMAC_INSTANT: this awaited fetch('http://192.168.88.1/login?mac', {{ timeout: 2000 }}).\n"
f"{ind}   `timeout` is not a fetch option, and 192.168.88.1 does not exist on this hotspot (it runs\n"
f"{ind}   10.100.0.1), so nothing answered and the request never settled — it hung. redeemVoucher()\n"
f"{ind}   and the payment path both await this before sending anything, so entering a code did\n"
f"{ind}   nothing at all: no request reached the server, no error appeared, the spinner just sat.\n"
f"{ind}   MikroTik already passes the MAC in the hotspot login URL. Read it there and return at\n"
f"{ind}   once — with no network call, there is nothing left to hang on. */\n"
f"{ind}async function getMac() {{\n"
f"{ind}  try {{\n"
f"{ind}    var q = new URLSearchParams(location.search);\n"
f"{ind}    var m = q.get('mac') || q.get('client_mac') || q.get('client-mac') || '';\n"
f"{ind}    if (/^[0-9A-Fa-f]{{2}}([:-][0-9A-Fa-f]{{2}}){{5}}$/.test(m)) return m.toUpperCase();\n"
f"{ind}  }} catch (e) {{}}\n"
f"{ind}  return '';\n"
f"{ind}}}"
)
s = s[:m.start()] + new + s[m.end():]
open(p,'w').write(s); print("   getMac replaced")
PY
sudo chown www-data:www-data "$CP/classic.html"

say "4) Verify"
echo "   remaining 192.168.88.1 (0 expected, comment aside):"
sudo grep -c "192.168.88.1" "$CP/classic.html" | sed 's/^/     /'
echo "   fetch calls inside getMac (0 expected):"
LM2=$(grep -n "RL_GETMAC_INSTANT" "$CP/classic.html" | head -1 | cut -d: -f1)
sudo sed -n "${LM2},$((LM2+18))p" "$CP/classic.html" | grep -c "fetch(" | sed 's/^/     /'
echo "   lines: $(sudo wc -l < "$CP/classic.html")   div balance: $(( $(grep -o '<div' "$CP/classic.html" | wc -l) - $(grep -o '</div>' "$CP/classic.html" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$CP/classic.html" | wc -l) / $(grep -o '</script>' "$CP/classic.html" | wc -l)"
echo "   redeem + payment paths intact:"
sudo grep -c "redeemVoucher\|/redeem\|/pay" "$CP/classic.html" | sed 's/^/     references: /'
curl -sk -o /dev/null -w "   portal HTTP %{http_code}\n" https://rumalinkenterprise.online/captive/classic.html

say "5) Test"
cat <<'EOS'
   On the SECOND device: hard-refresh, enter R70 in "Redeem Voucher", tap the button.
   It should now reach the server. Watch it arrive:
     pm2 logs rumalink-backend | grep -iE "redeem"
   Expect a 200 (R70 allows 2 devices, 1 registered), and the device connects.

   Then confirm the payment flow is normal again: the spinner should appear immediately
   after entering a phone number, well before the STK push arrives.
EOS

say "6) Rollback if anything looks wrong"
echo "   sudo cp $CP/.classic.html.bak_$TS $CP/classic.html && sudo chown www-data:www-data $CP/classic.html"

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "getMac no longer hangs on an unreachable 192.168.88.1; redeem and payment can proceed" 2>&1 | head -2 | sed 's/^/   /'
