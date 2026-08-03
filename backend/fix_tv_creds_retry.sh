#!/usr/bin/env bash
#
# fix_tv_creds_retry.sh — retry with regex anchors.
# The previous attempt matched exact indentation and missed, so a TV payment still returns
# radius credentials and the portal logs the buyer's phone in.
# This version strips the credentials immediately before res.json() — a single, unambiguous
# insertion point rather than restructuring the branch.
#
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "0) Show the exact text so the anchors are certain"
sudo grep -n "let radius_username" "$BE/routes/captive.js" | sed 's/^/   /'
sudo grep -n "radius_password$" "$BE/routes/captive.js" | head -4 | sed 's/^/   /'
sudo grep -n "res.json({" "$BE/routes/captive.js" | sed -n '1,6p' | sed 's/^/   /'
sudo grep -n "var _ru = json.radius_username" "$CP/classic.html" | sed 's/^/   /'

say "1) Backups"
sudo cp "$BE/routes/captive.js" "$BE/routes/.captive.js.bak_$TS" && echo "   captive.js"
sudo cp "$CP/classic.html" "$CP/.classic.html.bak_$TS" && echo "   classic.html"

say "2) Strip credentials for a TV voucher, right before the response"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_TV_NO_CREDS' in s:
    print("   already patched"); sys.exit(0)

# a) declare the flag alongside the credential vars
m = re.search(r'^([ \t]*)let radius_username = null, radius_password = null;\s*$', s, re.M)
if not m:
    print("   ERROR: credential declaration not found"); sys.exit(1)
s = s[:m.end()] + s[m.end():]
s = s.replace(m.group(0), m.group(1) + "let radius_username = null, radius_password = null, is_tv_purchase = false;", 1)

# b) strip them just before res.json({ payment_id: ... })
m2 = re.search(r'^([ \t]*)res\.json\(\{\s*\n\s*payment_id: r\.rows\[0\]\.id,', s, re.M)
if not m2:
    print("   ERROR: res.json anchor not found"); sys.exit(1)
ind = m2.group(1)
guard = (
f"{ind}/* RL_TV_NO_CREDS: a television is bypassed at the router and can never sign in, so login\n"
f"{ind}   credentials are meaningless for it — but returning them made the portal auto-login the\n"
f"{ind}   BUYER'S PHONE on the TV's voucher: two devices on one purchase, with the phone's own\n"
f"{ind}   session invisible in the dashboard. Strip them here, after every other path has run, so\n"
f"{ind}   the guard cannot be bypassed by whichever branch produced the credentials. */\n"
f"{ind}try {{\n"
f"{ind}  const _tvq = await query(\"SELECT is_tv FROM hotspot_vouchers WHERE payment_id = $1::uuid LIMIT 1\", [req.params.paymentId]);\n"
f"{ind}  if (_tvq.rows[0] && _tvq.rows[0].is_tv === true) {{\n"
f"{ind}    radius_username = null; radius_password = null; is_tv_purchase = true;\n"
f"{ind}  }}\n"
f"{ind}}} catch (e) {{ logger.warn('[captive] tv creds guard: ' + e.message); }}\n"
)
s = s[:m2.start()] + guard + s[m2.start():]

# c) return the flag
m3 = re.search(r'(radius_username,\s*\n\s*radius_password)(\s*\n\s*\}\);)', s)
if m3:
    s = s[:m3.start()] + m3.group(1) + ",\n            is_tv: is_tv_purchase" + m3.group(2) + s[m3.end():]
    print("   is_tv added to the response")
else:
    print("   WARNING: could not add is_tv to the response body (creds are still stripped)")
open(p,'w').write(s); print("   credential guard inserted")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js syntax OK"
sudo grep -n "RL_TV_NO_CREDS" "$BE/routes/captive.js" | sed 's/^/   /'

say "3) Portal message for a TV purchase"
sudo python3 - "$CP/classic.html" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_TV_NO_AUTOLOGIN' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)var _ru = json\.radius_username, _rp = json\.radius_password;\s*$', s, re.M)
if not m:
    print("   anchor not found — server guard alone still prevents the phone login"); sys.exit(0)
ind = m.group(1)
block = (
f"{ind}/* RL_TV_NO_AUTOLOGIN: a TV purchase must not connect this phone. The server no longer returns\n"
f"{ind}   credentials for a TV voucher, so the check below already fails safely — this just makes the\n"
f"{ind}   message accurate instead of a generic voucher notice. */\n"
f"{ind}if (json.is_tv) {{\n"
f"{ind}  showMsg('\\u2705 Payment received! Your TV is now connected. It comes online automatically \\u2014 no login needed.', 'success');\n"
f"{ind}  document.getElementById('pay-section').style.display = 'none';\n"
f"{ind}  setLoading(false);\n"
f"{ind}  return;\n"
f"{ind}}}\n"
)
s = s[:m.start()] + block + s[m.start():]
open(p,'w').write(s); print("   portal TV message added")
PY
sudo chown www-data:www-data "$CP/classic.html"
echo "   div balance: $(( $(grep -o '<div' "$CP/classic.html" | wc -l) - $(grep -o '</div>' "$CP/classic.html" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$CP/classic.html" | wc -l) / $(grep -o '</script>' "$CP/classic.html" | wc -l)"

say "4) Restart + PROVE the TV payment returns no credentials"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
PID=$(q -tAc "SELECT payment_id FROM hotspot_vouchers WHERE is_tv=true AND payment_id IS NOT NULL ORDER BY created_at DESC LIMIT 1;")
echo "   TV payment $PID:"
[ -n "$PID" ] && curl -s "http://127.0.0.1:5000/api/captive/$ISP/payment-status/$PID" | sed 's/^/     /'; echo
echo "   ${Y}radius_username and radius_password must be null, is_tv must be true${N}"
PID2=$(q -tAc "SELECT payment_id FROM hotspot_vouchers WHERE (is_tv IS NOT TRUE) AND payment_id IS NOT NULL ORDER BY created_at DESC LIMIT 1;")
echo "   PHONE payment $PID2 (credentials must still be present):"
[ -n "$PID2" ] && curl -s "http://127.0.0.1:5000/api/captive/$ISP/payment-status/$PID2" | sed 's/^/     /'; echo

say "5) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "TV vouchers never return login credentials; portal shows the TV confirmation" 2>&1 | head -2 | sed 's/^/   /'
echo
echo "   ${Y}Hard-refresh the portal on the phone, then buy a TV package on Daraja.${N}"
