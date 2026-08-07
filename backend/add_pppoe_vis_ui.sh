#!/usr/bin/env bash
#
# add_pppoe_vis_ui.sh
#   1. Visibility control on the PPPoE package create form and edit modal.
#   2. Style every <select> to match the theme. Browsers draw an unstyled dropdown with their own
#      arrow and a white popup list, which is why the ones added recently look foreign next to
#      your inputs. One rule for all of them rather than fixing each as it is noticed.
#
set -uo pipefail
D=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Backup"
sudo cp "$D" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   .dashboard.html.bak_$TS"

say "2) Edit modal — add the visibility field"
sudo python3 - "$D" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'pp-edit-visible' in s:
    print("   already present"); sys.exit(0)
old = """      <div class="fg"><label>Description</label><input id="pp-edit-desc" value="${safe(p.description)}" autocomplete="off" spellcheck="false" /></div>"""
new = """      <div class="fg"><label>Description</label><input id="pp-edit-desc" value="${safe(p.description)}" autocomplete="off" spellcheck="false" /></div>
      <div class="fg"><label>Captive portal</label><select id="pp-edit-visible"><option value="true"${p.visible_in_portal!==false?' selected':''}>Shown to customers</option><option value="false"${p.visible_in_portal===false?' selected':''}>Hidden (testing only)</option></select><div style="font-size:.72rem;color:#8b93a3;margin-top:4px">Hidden packages are not offered in the portal. Anyone already on one keeps their service.</div></div>"""
if old not in s:
    print("   MISS: description field"); sys.exit(1)
s = s.replace(old, new, 1)

old_p = """      address_pool: document.getElementById('pp-edit-pool').value,
      is_active: true"""
new_p = """      address_pool: document.getElementById('pp-edit-pool').value,
      /* RL_PPPOE_VIS_UI: sent explicitly. The route COALESCEs it, so omitting it would keep the
         old value — fine for other edits, but the dropdown must be able to change it. */
      visible_in_portal: document.getElementById('pp-edit-visible').value === 'true',
      is_active: true"""
if old_p in s: s = s.replace(old_p, new_p, 1)
else: print("   MISS: save payload")
open(p,'w').write(s); print("   edit modal done")
PY

say "3) Create form — same control"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'pp-visible' in s:
    print("   already present"); sys.exit(0)
m = re.search(r'(<input id="pp-pool"[^>]*>)', s)
if not m:
    print("   MISS: pool input"); sys.exit(1)
close = s.find('</div>', m.end())
close = s.find('</div>', close+6)
field = ('\n    <div class="fg"><label>Captive portal</label>'
         '<select id="pp-visible"><option value="true">Shown to customers</option>'
         '<option value="false">Hidden (testing only)</option></select>'
         '<div style="font-size:.72rem;color:#8b93a3;margin-top:4px">Hidden packages are not offered in the portal.</div></div>')
s = s[:close+6] + field + s[close+6:]

old = "address_pool:document.getElementById('pp-pool').value})});"
new = "address_pool:document.getElementById('pp-pool').value,visible_in_portal:((document.getElementById('pp-visible')||{}).value !== 'false')})});"
if old in s: s = s.replace(old, new, 1)
else: print("   MISS: create payload")
open(p,'w').write(s); print("   create form done")
PY

say "4) Style every dropdown to match the theme"
sudo python3 - "$D" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_SELECT_THEME' in s:
    print("   already styled"); sys.exit(0)
css = """
<style>
/* RL_SELECT_THEME: left to itself a browser draws its own arrow and a white popup list, so a
   <select> sits oddly beside inputs that carry the dashboard's palette. One rule for all of them
   — the alternative is restyling each dropdown as somebody notices it. */
select, .fg select, .modal select {
  width: 100%;
  padding: 10px 34px 10px 12px;
  background-color: var(--mid);
  border: 1px solid var(--border);
  border-radius: 8px;
  color: #fff;
  font-size: .88rem;
  box-sizing: border-box;
  appearance: none; -webkit-appearance: none; -moz-appearance: none;
  background-image: url("data:image/svg+xml;charset=UTF-8,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' viewBox='0 0 12 8'%3E%3Cpath fill='%238b93a3' d='M1 1l5 5 5-5'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 12px center;
  cursor: pointer;
  transition: border-color .15s, box-shadow .15s;
}
select:hover { border-color: rgba(0,212,170,.45); }
select:focus { outline: none; border-color: #00d4aa; box-shadow: 0 0 0 3px rgba(0,212,170,.15); }
/* the popup list itself is drawn by the OS; these are the only parts we can reach */
select option { background: var(--card); color: #fff; padding: 8px; }
select:disabled { opacity: .55; cursor: not-allowed; }
</style>
"""
s = s.replace('</head>', css + '\n</head>', 1) if '</head>' in s else css + s
open(p,'w').write(s); print("   select styling added")
PY
sudo chown www-data:www-data "$D"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"
echo "   markers: $(grep -c 'pp-edit-visible' "$D") edit | $(grep -c 'pp-visible' "$D") create | $(grep -c 'RL_SELECT_THEME' "$D") css"

say "5) Check"
curl -sk -o /dev/null -w "   dashboard HTTP %{http_code}\n" https://rumalinkenterprise.online/isp/dashboard.html
q -c "SELECT name, visible_in_portal FROM pppoe_packages ORDER BY price;"
cat <<'EOS'
   Hard-refresh, open a PPPoE package to edit — "Captive portal" sits under Description, and every
   dropdown in the dashboard should now match your inputs.
   Save with it set to Hidden, then confirm:
     sudo -u postgres psql -d rumalink_db -c "SELECT name, visible_in_portal FROM pppoe_packages;"
EOS

say "6) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "PPPoE package visibility in the UI; consistent dropdown styling" 2>&1 | head -2 | sed 's/^/   /'
