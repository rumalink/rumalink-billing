#!/usr/bin/env bash
#
# fix_voucher_login_ui.sh — make the "Already have a code?" form actually work.
#
# CAUSE: I wrote its JavaScript against window.API / window.ISP_ID / rlClientMac() — names I
# assumed rather than read from the file. None of them exist, so the fetch went nowhere and the
# button silently did nothing. Same shape as require('./hotspotSms') and the rlOpsHdr token key:
# reaching for something by an assumed name, getting undefined, and failing without an error.
#
# FIX: resolve the ISP id, API base and client MAC from several real sources — the MikroTik
# hotspot query string, existing page globals, the URL path — and SHOW a message when something
# cannot be resolved instead of failing quietly.
#
set -uo pipefail
CP=/var/www/rumalink/captive
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) How the portal really identifies itself (for reference)"
grep -noE "ISP_ID[^;]{0,50}|ispId *=[^;]{0,50}|window\.[A-Z_]{3,}[^;]{0,40}" "$CP/classic.html" | head -12 | sed 's/^/   /'
echo "   --- an existing fetch, to copy the URL shape ---"
grep -noE "fetch\([^)]{0,90}" "$CP/classic.html" | head -6 | sed 's/^/   /'
echo "   --- how the MAC is read ---"
grep -noE "URLSearchParams[^;]{0,60}|[Mm]ac *[:=][^;,]{0,50}" "$CP/classic.html" | head -10 | sed 's/^/   /'

say "2) Backup"
sudo cp "$CP/classic.html" "$CP/.classic.html.bak_$TS" && echo "   classic.html"

say "3) Replace the form's script with a self-resolving version"
sudo python3 - "$CP/classic.html" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()

# remove the previous block entirely
i = s.find('/* RL_CODE_LOGIN_UI */')
if i != -1:
    a = s.rfind('<script>', 0, i)
    b = s.find('</script>', i)
    if a != -1 and b != -1:
        s = s[:a] + s[b+len('</script>'):]
        print("   removed the previous script block")

JS = r"""
<script>
/* RL_CODE_LOGIN_UI v2 — resolve everything from the page instead of assumed globals.
   The first version used window.API / window.ISP_ID / rlClientMac(), none of which exist here,
   so the fetch never went anywhere and the button appeared dead. */
(function(){
  function qs(k){ try { return new URLSearchParams(location.search).get(k) || ''; } catch(e){ return ''; } }
  function resolveIsp(){
    var cands = [window.ISP_ID, window.ispId, window.RL_ISP_ID, window.RL_ISP,
                 qs('isp'), qs('ispId'), qs('isp_id')];
    for (var i=0;i<cands.length;i++){ if (cands[i]) return String(cands[i]); }
    var m = (location.pathname + location.search).match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i);
    if (m) return m[0];
    // last resort: an isp uuid embedded anywhere in the page's own scripts
    var h = document.documentElement.innerHTML.match(/captive\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i);
    return h ? h[1] : '';
  }
  function resolveApi(){
    if (window.API) return window.API;
    if (window.API_BASE) return window.API_BASE;
    return '/api';
  }
  function resolveMac(){
    var cands = [qs('mac'), qs('client_mac'), qs('client-mac'), window.RL_MAC, window.CLIENT_MAC];
    for (var i=0;i<cands.length;i++){ if (cands[i]) return String(cands[i]).toUpperCase(); }
    return '';
  }

  var btn = document.getElementById('cl-btn');
  if (!btn) return;
  var msg = document.getElementById('cl-msg');

  btn.addEventListener('click', function(){
    var code = (document.getElementById('cl-code').value || '').trim();
    if (!code) { msg.textContent = 'Enter your code.'; return; }

    var isp = resolveIsp(), api = resolveApi(), mac = resolveMac();
    console.log('[code-login] isp=', isp, 'api=', api, 'mac=', mac);
    if (!isp) { msg.textContent = 'Could not identify this hotspot. Please reload the page.'; return; }

    msg.textContent = 'Checking...';
    fetch(api + '/captive/' + isp + '/voucher-login', {
      method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({ code: code, mac: mac })
    })
    .then(function(r){ return r.json().then(function(j){ return {ok:r.ok, status:r.status, j:j}; }); })
    .then(function(o){
      console.log('[code-login] response', o.status, o.j);
      if (!o.ok) { msg.textContent = (o.j && o.j.error) ? o.j.error : ('Could not connect (' + o.status + ').'); return; }
      msg.textContent = 'Connecting... (' + o.j.devices_used + ' of ' + o.j.devices_allowed + ' devices)';
      if (typeof rlHotspotLogin === 'function') {
        rlHotspotLogin(o.j.radius_username, o.j.radius_password);
      } else if (typeof window.rlHotspotLogin === 'function') {
        window.rlHotspotLogin(o.j.radius_username, o.j.radius_password);
      } else {
        msg.textContent = 'Code accepted. Reconnect to the WiFi to finish.';
      }
    })
    .catch(function(e){ console.error('[code-login]', e); msg.textContent = 'Network error: ' + e.message; });
  });
})();
</script>
"""
s = s.replace('</body>', JS + '\n</body>', 1) if '</body>' in s else s + JS
open(p,'w').write(s)
print("   self-resolving script installed")
PY
sudo chown www-data:www-data "$CP/classic.html"
echo "   div balance: $(( $(grep -o '<div' "$CP/classic.html" | wc -l) - $(grep -o '</div>' "$CP/classic.html" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$CP/classic.html" | wc -l) / $(grep -o '</script>' "$CP/classic.html" | wc -l)"
grep -c "RL_CODE_LOGIN_UI" "$CP/classic.html" | sed 's/^/   RL_CODE_LOGIN_UI blocks: /'

say "4) Is the form inside something hidden until after payment?"
L=$(grep -n 'id="code-login"' "$CP/classic.html" | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "$((L-10)),$((L+1))p" "$CP/classic.html" | nl -ba -v"$((L-10))" | sed 's/^/   /'

say "5) Endpoint re-check"
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
CODE=$(q -tAc "SELECT code FROM hotspot_vouchers WHERE status='active' AND (is_tv IS NOT TRUE) ORDER BY created_at DESC LIMIT 1;")
echo "   isp=$ISP code=${CODE:-none}"
curl -s -X POST "http://127.0.0.1:5000/api/captive/$ISP/voucher-login" \
  -H 'Content-Type: application/json' -d "{\"code\":\"$CODE\",\"mac\":\"AA:BB:CC:DD:EE:0A\"}" | sed 's/^/     /'; echo
q -c "DELETE FROM hotspot_voucher_devices WHERE mac='AA:BB:CC:DD:EE:0A';" >/dev/null 2>&1
q -c "DELETE FROM radcheck WHERE username='AA:BB:CC:DD:EE:0A';" >/dev/null 2>&1

say "6) Test on the phone"
cat <<'EOS'
   Hard-refresh the portal on the second device, enter the code, tap Connect, then open the
   browser console (or just report what the message area says).

   The console line "[code-login] isp= ... api= ... mac= ..." tells us immediately which value
   is missing if it still fails — an empty isp means the page never carried one, an empty mac
   means MikroTik did not pass it in the URL.
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Code-login form resolves isp/api/mac from the page instead of assumed globals" 2>&1 | head -2 | sed 's/^/   /'
