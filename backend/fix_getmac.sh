#!/usr/bin/env bash
#
# fix_getmac.sh — the portal never knew the client's MAC.
#
# getMac() fetched a hardcoded http://192.168.88.1/login?mac — MikroTik's FACTORY DEFAULT
# gateway. This hotspot runs on 10.100.0.0/24, so that request always failed and the function
# returned the literal string 'unknown'. Every /pay and /redeem call has been sending
# mac:"unknown", so:
#   - the per-package device limit could not count devices,
#   - purchased_by_mac was polluted, weakening device-keyed voucher reuse,
#   - a second device could not be recognised or admitted.
#
# MikroTik already puts the real MAC in the hotspot login URL, and this portal reads it
# elsewhere as qs('mac'). Prefer that, then the actual gateway derived from link-login (never a
# guessed IP), and only then give up.
#
set -uo pipefail
CP=/var/www/rumalink/captive
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The broken function, and the MAC the page already has"
sudo grep -n "192.168.88.1" "$CP/classic.html" "$CP"/*.html 2>/dev/null | sed 's/^/   /'
sudo grep -noE "qs\('mac'\)[^;]{0,40}|link-login[^;\"']{0,40}" "$CP/classic.html" | head -6 | sed 's/^/   /'
echo "   evidence it has been failing — MACs stored on recent vouchers:"
q -c "SELECT code, used_by_mac, purchased_by_mac FROM hotspot_vouchers ORDER BY created_at DESC LIMIT 6;"
q -c "SELECT DISTINCT mac FROM hotspot_voucher_devices ORDER BY mac LIMIT 10;"

say "2) Backup"
sudo cp "$CP/classic.html" "$CP/.classic.html.bak_$TS" && echo "   classic.html"

say "3) Rewrite getMac()"
sudo python3 - "$CP/classic.html" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_GETMAC_FIX' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)async function getMac\(\)\s*\{.*?\n\1\}', s, re.S | re.M)
if not m:
    print("   ERROR: getMac not matched — unchanged"); sys.exit(1)
ind = m.group(1)
new = (
f"{ind}/* RL_GETMAC_FIX: this fetched a hardcoded http://192.168.88.1/login?mac — MikroTik's FACTORY\n"
f"{ind}   DEFAULT gateway. This hotspot runs on 10.100.0.0/24, so the request always failed and the\n"
f"{ind}   function returned the string 'unknown'. Every /pay and /redeem call carried mac:\"unknown\",\n"
f"{ind}   so the device limit could not count devices and purchased_by_mac was polluted.\n"
f"{ind}   MikroTik puts the real MAC in the login URL; use that first, then the gateway derived from\n"
f"{ind}   link-login (never a guessed address), and only then give up. */\n"
f"{ind}async function getMac() {{\n"
f"{ind}  function _qs(k) {{ try {{ return new URLSearchParams(location.search).get(k) || ''; }} catch (e) {{ return ''; }} }}\n"
f"{ind}  var m = _qs('mac') || _qs('client_mac') || _qs('client-mac');\n"
f"{ind}  if (m && /^[0-9A-Fa-f]{{2}}([:-][0-9A-Fa-f]{{2}}){{5}}$/.test(m)) return m.toUpperCase();\n"
f"{ind}  try {{\n"
f"{ind}    var ll = _qs('link-login-only') || _qs('link-login') || '';\n"
f"{ind}    var host = ll ? (ll.match(/^https?:\\/\\/([^\\/]+)/) || [])[1] : '';\n"
f"{ind}    if (!host && location.hostname && !/rumalink/i.test(location.hostname)) host = location.host;\n"
f"{ind}    if (host) {{\n"
f"{ind}      var c = new AbortController();\n"
f"{ind}      var t = setTimeout(function () {{ c.abort(); }}, 2000);\n"
f"{ind}      var r = await fetch('http://' + host + '/login?mac', {{ signal: c.signal }});\n"
f"{ind}      clearTimeout(t);\n"
f"{ind}      var txt = (await r.text()).trim();\n"
f"{ind}      if (/^[0-9A-Fa-f]{{2}}([:-][0-9A-Fa-f]{{2}}){{5}}$/.test(txt)) return txt.toUpperCase();\n"
f"{ind}    }}\n"
f"{ind}  }} catch (e) {{}}\n"
f"{ind}  return '';\n"
f"{ind}}}"
)
s = s[:m.start()] + new + s[m.end():]
open(p,'w').write(s); print("   getMac rewritten")
PY
sudo chown www-data:www-data "$CP/classic.html"
sudo grep -n "RL_GETMAC_FIX" "$CP/classic.html" | sed 's/^/   /'
echo "   remaining hardcoded 192.168.88.1 references:"
sudo grep -c "192.168.88.1" "$CP/classic.html" | sed 's/^/     /'

say "4) Backend: treat 'unknown' as no MAC at all"
sudo cp "$BE/routes/captive.js" "$BE/routes/.captive.js.bak_$TS"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_MAC_UNKNOWN' in s:
    print("   already patched"); sys.exit(0)
n=0
pat = re.compile(r"const _mac = String\(req\.body\.mac \|\| ''\)\.trim\(\)\.toUpperCase\(\);")
if pat.search(s):
    s = pat.sub("const _macRaw = String(req.body.mac || '').trim().toUpperCase();\n"
                "    /* RL_MAC_UNKNOWN: the portal used to send the literal string 'unknown' when it could not\n"
                "       read the MAC. Storing that as a device would let one placeholder occupy a real slot. */\n"
                "    const _mac = (_macRaw === 'UNKNOWN' || _macRaw === 'NULL') ? '' : _macRaw;", s, count=1)
    n+=1
open(p,'w').write(s); print(f"   {n} guard(s) added")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js OK"

say "5) Clean the placeholder rows already stored"
q -c "SELECT count(*) AS bogus_devices FROM hotspot_voucher_devices WHERE UPPER(mac) IN ('UNKNOWN','NULL','');"
q -c "DELETE FROM hotspot_voucher_devices WHERE UPPER(mac) IN ('UNKNOWN','NULL','');"
q -c "UPDATE hotspot_vouchers SET used_by_mac=NULL WHERE UPPER(COALESCE(used_by_mac,'')) IN ('UNKNOWN','NULL');"
q -c "UPDATE hotspot_vouchers SET purchased_by_mac=NULL WHERE UPPER(COALESCE(purchased_by_mac,'')) IN ('UNKNOWN','NULL');"

say "6) Restart + verify"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
q -c "SELECT hv.code, COALESCE(hp.simultaneous_sessions,1) AS allowed,
             (SELECT count(*) FROM hotspot_voucher_devices d WHERE d.voucher_id=hv.id) AS registered
      FROM hotspot_vouchers hv LEFT JOIN hotspot_packages hp ON hp.id=hv.package_id
      WHERE hv.status='active' ORDER BY hv.created_at DESC LIMIT 4;"
curl -sk -o /dev/null -w "   portal HTTP %{http_code}\n" https://rumalinkenterprise.online/captive/classic.html

say "7) Test"
cat <<'EOS'
   Hard-refresh the portal on the SECOND device and enter the code.
   The page URL from MikroTik carries ?mac=... so getMac() now returns the real address.

   Check what it sent:
     sudo -u postgres psql -d rumalink_db -c \
       "SELECT v.code, d.mac, d.first_seen FROM hotspot_voucher_devices d JOIN hotspot_vouchers v ON v.id=d.voucher_id ORDER BY d.first_seen DESC LIMIT 5;"
   A real MAC there means the portal is finally reporting the device.
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "getMac: read the real MAC from the hotspot login URL instead of a hardcoded 192.168.88.1" 2>&1 | head -2 | sed 's/^/   /'
