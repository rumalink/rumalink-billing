#!/usr/bin/env bash
#
# add_pppoe_client_visibility_ui.sh — choose which clients a PPPoE package is hidden from.
#
# The backend already answers this: GET /pppoe/packages/:id/visibility returns every subscriber
# with a hidden flag, and PUT replaces the exception list wholesale. This adds the picker.
#
# A search box because the list grows with the customer base — 22 today, but an ISP with 300 has
# no chance of finding one person by scrolling, and retrofitting search into a checkbox list is
# more work than including it now.
#
set -uo pipefail
D=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Backup"
sudo cp "$D" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   .dashboard.html.bak_$TS"

say "2) Add the picker to the edit modal"
sudo python3 - "$D" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'pp-vis-clients' in s:
    print("   already present"); sys.exit(0)

old = """      <div class="modal-actions"><button class="btn btn-outline" onclick="this.closest('.modal-overlay').remove()">Cancel</button><button class="btn btn-teal" onclick="savePPPoEPackageEdit('${p.id}')">Save Changes</button></div>"""
new = """      <div class="fg" style="margin-top:6px">
        <label>Hide from specific clients</label>
        <div style="font-size:.72rem;color:#8b93a3;margin-bottom:8px">Ticked clients will not see this package in their portal. Anyone already on it keeps their service.</div>
        <input id="pp-vis-search" type="text" placeholder="Search by username or name…" autocomplete="off" spellcheck="false"
               oninput="rlFilterVisClients(this.value)"
               style="width:100%;padding:9px 12px;background:var(--mid);border:1px solid var(--border);border-radius:8px;color:#fff;box-sizing:border-box;font-size:.86rem;margin-bottom:8px" />
        <div id="pp-vis-clients" style="max-height:210px;overflow-y:auto;border:1px solid var(--border);border-radius:8px;background:rgba(255,255,255,.02);padding:6px">
          <div style="padding:14px;text-align:center;color:#8b93a3;font-size:.82rem">Loading clients…</div>
        </div>
        <div id="pp-vis-count" style="font-size:.72rem;color:#8b93a3;margin-top:6px">&nbsp;</div>
      </div>
      <div class="modal-actions"><button class="btn btn-outline" onclick="this.closest('.modal-overlay').remove()">Cancel</button><button class="btn btn-teal" onclick="savePPPoEPackageEdit('${p.id}')">Save Changes</button></div>"""
if old not in s:
    print("   MISS: modal actions"); sys.exit(1)
s = s.replace(old, new, 1)

# load the list once the modal is in the document
old_append = """    document.body.appendChild(ov);
  } catch(e) { console.error('editPPPoEPackage:', e); toast(e.message || 'Error', 'error'); }"""
new_append = """    document.body.appendChild(ov);
    rlLoadVisClients(p.id);
  } catch(e) { console.error('editPPPoEPackage:', e); toast(e.message || 'Error', 'error'); }"""
if old_append in s: s = s.replace(old_append, new_append, 1)
else: print("   MISS: modal append")

# send the ticked list along with the package save
old_save = """    await api('/pppoe/packages/' + packageId, { method: 'PUT', body: JSON.stringify(payload) });
    toast('Package updated');"""
new_save = """    await api('/pppoe/packages/' + packageId, { method: 'PUT', body: JSON.stringify(payload) });
    /* RL_VIS_CLIENTS_SAVE: the exception list is its own endpoint, so a failure there does not
       lose the package edit. Sent as the COMPLETE intended list — unticking someone restores
       their access without a separate call. */
    try {
      var boxes = document.querySelectorAll('#pp-vis-clients input[type=checkbox]');
      if (boxes.length) {
        var hidden = [];
        boxes.forEach(function(b){ if (b.checked) hidden.push(b.getAttribute('data-sub')); });
        await api('/pppoe/packages/' + packageId + '/visibility', {
          method: 'PUT', body: JSON.stringify({ hidden_for: hidden })
        });
      }
    } catch (ve) { console.warn('visibility save:', ve); toast('Package saved, but client visibility did not: ' + ve.message, 'error'); }
    toast('Package updated');"""
if old_save in s: s = s.replace(old_save, new_save, 1)
else: print("   MISS: save handler")
open(p,'w').write(s); print("   picker added to the modal")
PY

say "3) The loader and the search filter"
sudo python3 - "$D" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_VIS_CLIENTS_JS' in s:
    print("   already present"); sys.exit(0)
JS = """
<script>
/* RL_VIS_CLIENTS_JS: which clients a PPPoE package is hidden from. The server returns every
   subscriber with a hidden flag, so the ticked state IS the stored state — no guessing, and
   unticking is as meaningful as ticking. */
window.rlLoadVisClients = async function(packageId){
  var box = document.getElementById('pp-vis-clients');
  if (!box) return;
  try {
    var d = await api('/pppoe/packages/' + packageId + '/visibility');
    var subs = (d && d.subscribers) || [];
    if (!subs.length) {
      box.innerHTML = '<div style="padding:14px;text-align:center;color:#8b93a3;font-size:.82rem">No PPPoE clients yet</div>';
      return;
    }
    box.innerHTML = subs.map(function(su){
      var label = (su.full_name && su.full_name !== su.username) ? (su.username + ' — ' + su.full_name) : su.username;
      return '<label class="rl-vis-row" data-search="' + String(label).toLowerCase().replace(/"/g,'') + '"' +
             ' style="display:flex;align-items:center;gap:9px;padding:7px 9px;border-radius:6px;cursor:pointer;font-size:.85rem">' +
             '<input type="checkbox" data-sub="' + su.id + '"' + (su.hidden ? ' checked' : '') +
             ' onchange="rlVisCount()" style="width:15px;height:15px;cursor:pointer;flex:0 0 auto" />' +
             '<span>' + label + '</span></label>';
    }).join('');
    rlVisCount();
  } catch (e) {
    box.innerHTML = '<div style="padding:14px;color:#e74c3c;font-size:.82rem">Could not load clients: ' + e.message + '</div>';
  }
};

window.rlFilterVisClients = function(q){
  q = String(q || '').toLowerCase().trim();
  document.querySelectorAll('#pp-vis-clients .rl-vis-row').forEach(function(row){
    row.style.display = (!q || row.getAttribute('data-search').indexOf(q) !== -1) ? 'flex' : 'none';
  });
};

window.rlVisCount = function(){
  var el = document.getElementById('pp-vis-count');
  if (!el) return;
  var n = document.querySelectorAll('#pp-vis-clients input[type=checkbox]:checked').length;
  /* say plainly what the state means — "3 selected" would not tell you whether they can see it */
  el.textContent = n === 0 ? 'Visible to all clients' :
    ('Hidden from ' + n + ' client' + (n === 1 ? '' : 's'));
  el.style.color = n === 0 ? '#8b93a3' : '#f59e0b';
};
</script>
<style>
#pp-vis-clients .rl-vis-row:hover { background: rgba(255,255,255,.05); }
#pp-vis-clients::-webkit-scrollbar { width: 8px; }
#pp-vis-clients::-webkit-scrollbar-thumb { background: rgba(255,255,255,.15); border-radius: 4px; }
</style>
"""
s = s.replace('</body>', JS + '\n</body>', 1) if '</body>' in s else s + JS
open(p,'w').write(s); print("   loader, search and counter added")
PY
sudo chown www-data:www-data "$D"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"
echo "   markers: $(grep -c 'pp-vis-clients' "$D") picker | $(grep -c 'RL_VIS_CLIENTS_JS' "$D") js"

say "4) Check the endpoint answers"
q -c "SELECT id, name FROM pppoe_packages ORDER BY price LIMIT 1;"
q -c "SELECT count(*) AS subscribers FROM pppoe_subscribers WHERE deleted_at IS NULL;"
q -c "SELECT count(*) AS exceptions_configured FROM pppoe_package_visibility;"
curl -sk -o /dev/null -w "   dashboard HTTP %{http_code}\n" https://rumalinkenterprise.online/isp/dashboard.html

say "5) Try it"
cat <<'EOS'
   Hard-refresh, edit a PPPoE package. Below "Captive portal" there is a searchable client list.
   Tick someone, save, and confirm:
     sudo -u postgres psql -d rumalink_db -c "SELECT p.name AS package, s.username FROM pppoe_package_visibility v JOIN pppoe_packages p ON p.id=v.package_id JOIN pppoe_subscribers s ON s.id=v.subscriber_id WHERE v.hidden;"

   Then open the PPPoE portal as that client — the package should be gone, while others still see it.
EOS

say "6) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "PPPoE packages: searchable per-client visibility picker" 2>&1 | head -2 | sed 's/^/   /'
