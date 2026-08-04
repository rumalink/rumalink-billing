#!/usr/bin/env bash
#
# make_permanent_and_errors.sh
#  A) Confirm the router-config sync is registered and runs on its own — including straight
#     after provisioning, so a new MikroTik never shows placeholder values even briefly.
#  B) Remove any remaining hardcoded addressing from the provisioning path, so a newly
#     provisioned router is described by what it actually runs.
#  C) Show the real error in the captive portal instead of bouncing the customer back to the
#     purchase page. "This code allows 1 device" is actionable; a silent redirect is not.
#
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "A1) Is the sync registered and running?"
sudo grep -n "nas-config-sync" "$BE/utils/cron.js" | sed 's/^/   /'
pm2 logs rumalink-backend --lines 200 --nostream 2>/dev/null | grep -iE "nas-config-sync" | tail -4 | sed 's/^/   /' || echo "   ${Y}no log lines yet${N}"

say "A2) Run it the moment provisioning finishes"
sudo cp "$BE/routes/provision.js" "$BE/routes/.provision.js.bak_$TS" && echo "   provision.js backed up"
sudo python3 - "$BE/routes/provision.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SYNC_AFTER_PROVISION' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)triggerRadiusClientsSync\(\);\s*$', s, re.M)
if not m:
    print("   ERROR: triggerRadiusClientsSync() call not found — unchanged"); sys.exit(1)
ind = m.group(1)
add = ("\n" + ind + "/* RL_SYNC_AFTER_PROVISION: read the freshly provisioned router and store what it actually\n"
       + ind + "   runs, so the device page never shows placeholder addressing. Deferred a little to let\n"
       + ind + "   the script finish applying on the router. Database-only; nothing is pushed back. */\n"
       + ind + "setTimeout(function () {\n"
       + ind + "  require('../utils/nas-config-sync').pass().catch(function (e) {\n"
       + ind + "    require('../utils/logger').warn('[provision] config sync: ' + e.message);\n"
       + ind + "  });\n"
       + ind + "}, 20000);")
s = s[:m.end()] + add + s[m.end():]
open(p,'w').write(s); print("   config sync now runs right after provisioning")
PY
cd "$BE" && sudo -u www-data node --check routes/provision.js && echo "   provision.js OK"

say "B) Any addressing still hardcoded in the provisioning path?"
grep -nE "192\.168\.88|10\.100\.0|172\.16\." "$BE/routes/provision.js" "$BE/routes/nas.js" 2>/dev/null \
  | grep -v -E '^\s*#|RL_|/\*|\*' | head -15 | sed 's/^/   /' || echo "   ${G}none${N}"
echo "   how the network is chosen for a new router:"
sudo sed -n '40,60p' "$BE/routes/provision.js" | nl -ba -v40 | sed 's/^/   /'

say "C1) How the portal handles a failed redeem today"
LR=$(grep -n "/redeem" "$CP/classic.html" | head -1 | cut -d: -f1)
[ -n "$LR" ] && sudo sed -n "$((LR-6)),$((LR+40))p" "$CP/classic.html" | nl -ba -v"$((LR-6))" | sed 's/^/   /'

say "C2) Show the server's message instead of redirecting"
sudo cp "$CP/classic.html" "$CP/.classic.html.bak_$TS" && echo "   classic.html backed up"
sudo python3 - "$CP/classic.html" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_REDEEM_ERRORS' in s:
    print("   already patched"); sys.exit(0)

i = s.find('/redeem')
if i == -1:
    print("   ERROR: redeem call not found"); sys.exit(1)
seg_start = max(0, i - 400)
seg = s[seg_start:i+2500]

# the response handling that follows the fetch
m = re.search(r'(const|let|var)\s+(\w+)\s*=\s*await\s+r(es)?\.json\(\)\s*;', seg)
n = 0

# 1) make a non-ok response show the server's error and stop
m2 = re.search(r'^([ \t]*)if \(!r(es)?\.ok\)[^\n]*\n', seg, re.M)
if m2:
    ind = m2.group(1)
    repl = (f"{ind}/* RL_REDEEM_ERRORS: a failed redeem used to fall through to the purchase page, so a\n"
            f"{ind}   customer whose code already has its allowed devices was simply asked to pay again\n"
            f"{ind}   with no explanation. Show what the server said. */\n"
            f"{ind}if (!res.ok) {{\n"
            f"{ind}  showMsg((data && data.error) ? data.error : 'Could not connect with that code.', 'error');\n"
            f"{ind}  setLoading(false);\n"
            f"{ind}  return;\n"
            f"{ind}}}\n")
    seg = seg[:m2.start()] + repl + seg[m2.end():]
    n += 1

s = s[:seg_start] + seg + s[seg_start+len(s[seg_start:i+2500]):]
open(p,'w').write(s)
print(f"   {n} handler(s) updated" if n else "   NOTE: could not match the response handler automatically")
PY

say "C3) Fallback — a global handler so no redeem error is ever silent"
sudo python3 - "$CP/classic.html" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_REDEEM_ERRORS_GLOBAL' in s:
    print("   already present"); sys.exit(0)
JS = """
<script>
/* RL_REDEEM_ERRORS_GLOBAL: whatever the page does with a failed redeem, make sure the customer
   is told why. Wraps fetch so any non-OK /redeem or /voucher-login response surfaces the
   server's own message — "This code is already used by 1 device. It allows 1." reads as an
   answer; being returned to the purchase page reads as the payment having failed. */
(function(){
  var _f = window.fetch;
  window.fetch = function(){
    var url = arguments[0];
    var pr = _f.apply(this, arguments);
    try {
      if (typeof url === 'string' && /\/(redeem|voucher-login)\b/.test(url)) {
        pr.then(function(r){
          if (r && !r.ok) {
            r.clone().json().then(function(j){
              if (j && j.error && typeof showMsg === 'function') {
                showMsg(j.error, 'error');
                if (typeof setLoading === 'function') setLoading(false);
              }
            }).catch(function(){});
          }
        }).catch(function(){});
      }
    } catch(e){}
    return pr;
  };
})();
</script>
"""
s = s.replace('</body>', JS + '\n</body>', 1) if '</body>' in s else s + JS
open(p,'w').write(s); print("   global redeem-error handler added")
PY
sudo chown www-data:www-data "$CP/classic.html"
echo "   div balance: $(( $(grep -o '<div' "$CP/classic.html" | wc -l) - $(grep -o '</div>' "$CP/classic.html" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$CP/classic.html" | wc -l) / $(grep -o '</script>' "$CP/classic.html" | wc -l)"

say "D) Restart + verify"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 30 --nostream 2>/dev/null | grep -iE "nas-config-sync|error" | tail -4 | sed 's/^/   /'
q -c "SELECT name, gateway_ip, ip_pool_start, ip_pool_end, hotspot_interface, wan_interface FROM nas_devices;"
echo "   the error a third device now receives:"
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
CODE=$(q -tAc "SELECT hv.code FROM hotspot_vouchers hv JOIN hotspot_packages hp ON hp.id=hv.package_id
               WHERE hv.status='active' AND COALESCE(hp.simultaneous_sessions,1)=1 ORDER BY hv.created_at DESC LIMIT 1;")
if [ -n "$CODE" ]; then
  curl -s -X POST "http://127.0.0.1:5000/api/captive/$ISP/redeem" -H 'Content-Type: application/json' \
    -d "{\"code\":\"$CODE\",\"mac\":\"02:99:88:77:66:01\"}" -o /dev/null
  curl -s -X POST "http://127.0.0.1:5000/api/captive/$ISP/redeem" -H 'Content-Type: application/json' \
    -d "{\"code\":\"$CODE\",\"mac\":\"02:99:88:77:66:02\"}" | head -c 160 | sed 's/^/     /'; echo
  q -c "DELETE FROM hotspot_voucher_devices WHERE mac LIKE '02:99:88:77:66:%';" >/dev/null
  q -c "DELETE FROM radcheck WHERE username LIKE '02:99:88:77:66:%';" >/dev/null
fi

say "E) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Config sync runs after provisioning; portal shows redeem errors instead of redirecting" 2>&1 | head -2 | sed 's/^/   /'
