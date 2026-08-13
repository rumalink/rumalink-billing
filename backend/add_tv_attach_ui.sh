#!/usr/bin/env bash
#
# add_tv_attach_ui.sh — "Add a TV to my package" on the captive portal.
#
# The endpoints are in. This is the customer's side of it: a button under Already Paid? Login, a
# modal that asks for their username, and then — only once the package is known to allow another
# device — the TV step.
#
# The order matters. Checking the voucher BEFORE asking for a TV means someone on a one-device
# package is told so immediately, instead of choosing a television and being refused afterwards.
#
set -uo pipefail
CP=/var/www/rumalink/captive
D=$CP/classic.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) Backup"
sudo cp "$D" "$CP/.classic.html.bak_$TS" && echo "   .classic.html.bak_$TS"

say "2) Button, modal and flow"
sudo python3 - "$D" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_TV_ADD_UI' in s:
    print("   already present"); sys.exit(0)

BLOCK = """
<div class="rl-ta-ov" id="rl-ta">
  <div class="rl-ta-box">
    <button class="rl-ta-x" type="button" onclick="rlTaClose()">×</button>
    <h2>📺 Add a TV to your package</h2>

    <div id="rl-ta-step1">
      <div class="rl-ta-hint">Enter the username you were given when you paid. If your package allows more than one device, you can put a TV on it.</div>
      <input id="rl-ta-code" type="text" placeholder="Username (e.g. R123)" autocapitalize="characters" autocomplete="off" spellcheck="false"/>
      <div id="rl-ta-msg1" class="rl-ta-msg"></div>
      <button class="rl-ta-go" type="button" id="rl-ta-check">Continue</button>
    </div>

    <div id="rl-ta-step2" style="display:none">
      <div class="rl-ta-ok" id="rl-ta-summary"></div>
      <div class="rl-ta-hint">Choose the TV to add.</div>
      <div id="rl-ta-list" class="rl-ta-list"></div>
      <button class="rl-ta-alt" type="button" onclick="rlTaNewTv()">+ My TV is not listed — set it up</button>
      <div id="rl-ta-msg2" class="rl-ta-msg"></div>
      <button class="rl-ta-go" type="button" id="rl-ta-add" disabled>Add TV</button>
    </div>

    <div id="rl-ta-step3" style="display:none;text-align:center;padding:14px 0">
      <div class="rl-ta-spin"></div>
      <div class="rl-ta-hint" style="margin-top:12px">Adding your TV…</div>
    </div>

    <div id="rl-ta-step4" style="display:none;text-align:center;padding:10px 0">
      <div style="font-size:2.6rem;line-height:1">✅</div>
      <div id="rl-ta-done" style="font-weight:700;margin:8px 0 4px;font-size:1.02rem"></div>
      <div id="rl-ta-done-sub" class="rl-ta-hint"></div>
      <button class="rl-ta-go" type="button" onclick="rlTaClose()" style="margin-top:14px">Done</button>
    </div>
  </div>
</div>

<style>
/* RL_TV_ADD_UI */
.rl-ta-ov{position:fixed;inset:0;background:rgba(0,0,0,.55);display:none;align-items:center;justify-content:center;z-index:10050;padding:16px}
.rl-ta-ov.open{display:flex}
.rl-ta-box{background:#fff;color:#1a1a2e;border-radius:16px;padding:22px;max-width:420px;width:100%;position:relative;max-height:88vh;overflow-y:auto;box-shadow:0 20px 50px rgba(0,0,0,.3)}
.rl-ta-box h2{margin:0 0 14px;font-size:1.12rem}
.rl-ta-x{position:absolute;top:12px;right:14px;background:none;border:none;font-size:1.5rem;color:#999;cursor:pointer;line-height:1}
.rl-ta-hint{font-size:.84rem;color:#667;line-height:1.55;margin-bottom:12px}
.rl-ta-box input[type=text]{width:100%;padding:12px;border:1px solid #dde;border-radius:10px;font-size:1rem;box-sizing:border-box;margin-bottom:10px;text-transform:uppercase;font-family:monospace;letter-spacing:1px}
.rl-ta-go{width:100%;padding:13px;border:none;border-radius:10px;background:#00d4aa;color:#0d1530;font-weight:750;font-size:.98rem;cursor:pointer}
.rl-ta-go[disabled]{opacity:.5;cursor:default}
.rl-ta-alt{width:100%;padding:11px;border:1px dashed #ccd;border-radius:10px;background:transparent;color:#556;font-size:.86rem;cursor:pointer;margin-bottom:10px}
.rl-ta-msg{font-size:.85rem;margin:10px 0;line-height:1.5;display:none}
.rl-ta-msg.show{display:block}
.rl-ta-msg.err{color:#c0392b}
.rl-ta-ok{background:#eafaf6;border:1px solid #b8ece0;border-radius:10px;padding:11px 13px;font-size:.85rem;margin-bottom:12px;line-height:1.5}
.rl-ta-list{max-height:190px;overflow-y:auto;margin-bottom:10px}
.rl-ta-tv{display:flex;align-items:center;gap:10px;padding:11px 12px;border:1px solid #e3e6ef;border-radius:10px;margin-bottom:7px;cursor:pointer}
.rl-ta-tv.sel{border-color:#00d4aa;background:#f2fdfa}
.rl-ta-tv-n{font-weight:650;font-size:.92rem}
.rl-ta-tv-m{font-size:.74rem;color:#889;font-family:monospace}
.rl-ta-spin{width:38px;height:38px;border:3px solid #e6e9f2;border-top-color:#00d4aa;border-radius:50%;margin:0 auto;animation:rlta .8s linear infinite}
@keyframes rlta{to{transform:rotate(360deg)}}
</style>

<script>
/* RL_TV_ADD_UI: the voucher is checked BEFORE a TV is chosen, so someone on a one-device package
   hears why straight away rather than picking a television and being refused after. */
(function(){
  var CODE = null, PICK = null;
  function el(i){ return document.getElementById(i); }
  function msg(i, t, bad){ var m = el(i); m.textContent = t || ''; m.className = 'rl-ta-msg' + (t ? ' show' : '') + (bad ? ' err' : ''); }
  function step(n){ [1,2,3,4].forEach(function(x){ var e = el('rl-ta-step' + x); if (e) e.style.display = (x === n ? '' : 'none'); }); }

  window.rlTaOpen = function(){ CODE = null; PICK = null; el('rl-ta-code').value = ''; msg('rl-ta-msg1',''); msg('rl-ta-msg2',''); step(1); el('rl-ta').classList.add('open'); setTimeout(function(){ el('rl-ta-code').focus(); }, 80); };
  window.rlTaClose = function(){ el('rl-ta').classList.remove('open'); };
  el('rl-ta').addEventListener('click', function(e){ if (e.target.id === 'rl-ta') rlTaClose(); });

  el('rl-ta-check').addEventListener('click', async function(){
    var code = (el('rl-ta-code').value || '').trim().toUpperCase();
    if (!code) { msg('rl-ta-msg1', 'Enter your username.', true); return; }
    var b = this; b.disabled = true; b.textContent = 'Checking…'; msg('rl-ta-msg1','');
    try {
      var r = await fetch(API + '/captive/' + ISP_ID + '/tv/check-voucher', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ code: code }) });
      var d = await r.json();
      if (!r.ok) { msg('rl-ta-msg1', d.error || 'Could not check that username.', true); return; }
      CODE = d.code;
      el('rl-ta-summary').innerHTML = '<strong>' + d.package_name + '</strong> — ' + d.remaining +
        ' more device' + (d.remaining > 1 ? 's' : '') + ' allowed.' +
        (d.expires_at ? '<br>Your TV will work until ' + new Date(d.expires_at).toLocaleString('en-KE') + '.' : '');
      await rlTaLoad();
      step(2);
    } catch (e) { msg('rl-ta-msg1', 'Network error. Try again.', true); }
    finally { b.disabled = false; b.textContent = 'Continue'; }
  });

  window.rlTaLoad = async function(){
    var box = el('rl-ta-list');
    box.innerHTML = '<div class="rl-ta-hint">Loading your TVs…</div>';
    try {
      var r = await fetch(API + '/captive/' + ISP_ID + '/tv/list');
      var d = await r.json();
      var tvs = d.tvs || [];
      if (!tvs.length) { box.innerHTML = '<div class="rl-ta-hint">No TVs saved yet — set one up below.</div>'; return; }
      box.innerHTML = tvs.map(function(t){
        return '<div class="rl-ta-tv" data-id="' + t.id + '"><div><div class="rl-ta-tv-n">' +
               (t.name || 'TV') + '</div><div class="rl-ta-tv-m">' + (t.mac_address || '') + '</div></div></div>';
      }).join('');
      Array.prototype.forEach.call(box.querySelectorAll('.rl-ta-tv'), function(row){
        row.addEventListener('click', function(){
          Array.prototype.forEach.call(box.querySelectorAll('.rl-ta-tv'), function(o){ o.classList.remove('sel'); });
          row.classList.add('sel'); PICK = row.getAttribute('data-id'); el('rl-ta-add').disabled = false;
        });
      });
    } catch (e) { box.innerHTML = '<div class="rl-ta-hint">Could not load your TVs.</div>'; }
  };

  window.rlTaNewTv = function(){
    /* reuse the setup form that already exists rather than building a second one — two forms
       writing the same table is how they drift apart */
    rlTaClose();
    if (typeof rlOpenSetupTv === 'function') rlOpenSetupTv();
  };

  el('rl-ta-add').addEventListener('click', async function(){
    if (!CODE || !PICK) return;
    step(3);
    try {
      var r = await fetch(API + '/captive/' + ISP_ID + '/tv/attach', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code: CODE, tv_id: PICK }) });
      var d = await r.json();
      if (!r.ok) { step(2); msg('rl-ta-msg2', d.error || 'Could not add that TV.', true); return; }
      el('rl-ta-done').textContent = d.tv_name + ' is connected';
      el('rl-ta-done-sub').textContent = (d.note ? d.note + ' ' : '') +
        'Using ' + d.devices_used + ' of ' + d.devices_allowed + ' devices' +
        (d.expires_at ? ', until ' + new Date(d.expires_at).toLocaleString('en-KE') : '') + '.';
      step(4);
    } catch (e) { step(2); msg('rl-ta-msg2', 'Network error. Try again.', true); }
  });
})();
</script>
"""
s = s.replace('</body>', BLOCK + '\n</body>', 1) if '</body>' in s else s + BLOCK
open(p,'w').write(s); print("   modal, styles and flow added")
PY

say "3) The button, under Already Paid? Login"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'rl-add-tv-btn' in s:
    print("   already present"); sys.exit(0)
m = re.search(r"(apBtn\.textContent\s*=\s*'🔑 Already Paid\? Login';)", s)
if not m:
    print("   MISS: Already Paid button"); sys.exit(1)
tail = s[m.end():]
m2 = re.search(r'document\.body\.appendChild\(apBtn\);', tail)
if not m2:
    print("   MISS: append"); sys.exit(1)
add = """
    /* RL_TV_ADD_UI: sits directly under Already Paid? Login — the two belong together, both being
       "I have paid, now connect something". */
    var tvBtn = apBtn.cloneNode(false);
    tvBtn.id = 'rl-add-tv-btn';
    tvBtn.textContent = '📺 Add a TV to my package';
    tvBtn.onclick = function(){ if (typeof rlTaOpen === 'function') rlTaOpen(); };
    document.body.appendChild(tvBtn);
    try {
      var _r = apBtn.getBoundingClientRect();
      tvBtn.style.bottom = (parseInt(getComputedStyle(apBtn).bottom || '20', 10) + _r.height + 10) + 'px';
    } catch (e) {}
"""
pos = m.end() + m2.end()
s = s[:pos] + add + s[pos:]
open(p,'w').write(s); print("   button added")
PY
sudo chown www-data:www-data "$D"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"
echo "   markers: $(grep -c 'RL_TV_ADD_UI' "$D") ui | $(grep -c 'rl-add-tv-btn' "$D") button"
curl -sk -o /dev/null -w "   portal HTTP %{http_code}\n" https://rumalinkenterprise.online/captive/classic.html

say "4) Try it"
cat <<'EOS'
   Hard-refresh the portal. Under "Already Paid? Login" there is "Add a TV to my package":
     enter a username -> a one-device package says so and stops there
     a multi-device package shows what remains, then the TV list
     no TVs saved -> the existing setup form opens
     pick one, Add TV -> spinner -> "<name> is connected", with the expiry
EOS

say "5) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Portal: add a TV to an existing voucher, checked before the TV is chosen" 2>&1 | head -2 | sed 's/^/   /'
