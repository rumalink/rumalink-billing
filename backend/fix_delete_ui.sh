#!/usr/bin/env bash
#
# fix_delete_ui.sh
#  1. "invalid input value for enum user_status: deleted" — the status column is an enum that has
#     no 'deleted' member, so the UPDATE aborted and nothing was deleted. deleted_at already marks
#     the record; setting status as well was redundant. Altering a live enum is a heavier change
#     than the feature needs, so the assignment goes instead.
#  2. Replace the row button with a three-dot menu, confirm in a styled modal that NAMES the user,
#     and pin the actions column to the right edge so it is reachable without scrolling.
#
set -uo pipefail
BE=/var/www/rumalink/backend
D=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) What the enum actually allows"
q -c "SELECT enumlabel FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid WHERE t.typname='user_status' ORDER BY e.enumsortorder;"

say "2) Stop writing a status the enum rejects"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
n=0
for old, new in [
 ("SET deleted_at = NOW(), status = 'deleted', updated_at = NOW()",
  "SET deleted_at = NOW(), updated_at = NOW() /* RL_NO_ENUM_DELETED: user_status has no 'deleted' member; deleted_at is the marker */"),
]:
    if old in s:
        s = s.replace(old, new); n += s.count(new)
open(p,'w').write(s); print(f"   {n} statement(s) corrected")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"
sudo grep -c "status = 'deleted'" "$BE/routes/isp.js" | sed 's/^/   remaining bad writes (0 expected): /'

say "3) Replace the row button with a three-dot menu"
sudo cp "$D" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   dashboard.html"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()

# remove the previous plain button cell
old_cell = re.search(r"\s*/\* RL_DELETE_BTN \*/\n\s*\+ '<td style=\"padding:12px;text-align:right\"><button type=\"button\" title=\"Delete this user\"'\n.*?</td>'\n", s, re.S)
if old_cell:
    s = s[:old_cell.start()] + "\n" + s[old_cell.end():]

if 'RL_ROW_MENU' not in s:
    anchor = """        + '<td style="padding:12px;color:#888">' + dts(u.created_at) + '</td>'"""
    if anchor not in s:
        print("   ERROR: row template not found"); sys.exit(1)
    cell = (anchor + """
        /* RL_ROW_MENU: pinned to the right edge so it stays reachable without scrolling the table */
        + '<td class="rl-actions-cell"><button type="button" class="rl-dots" title="Actions"'
        + ' onclick="event.stopPropagation();rlRowMenu(this,\\'' + u.id + '\\',\\'' + (u.type === 'pppoe' ? 'pppoe' : 'hotspot') + '\\',\\'' + esc(u.username || '') + '\\',\\'' + esc(u.phone || '') + '\\')">&#8942;</button></td>'""")
    s = s.replace(anchor, cell, 1)

# remove the old confirm-based handler
old_js = re.search(r"<script>\s*/\* RL_DELETE_BTN:.*?</script>", s, re.S)
if old_js:
    s = s[:old_js.start()] + s[old_js.end():]

if 'RL_ROW_MENU_JS' not in s:
    JS = """
<style>
/* RL_ROW_MENU: the actions column stays visible while the table scrolls sideways, so you can
   always see WHICH row you are acting on. */
.rl-actions-cell{padding:12px;text-align:right;position:sticky;right:0;background:var(--card,#131a2e);box-shadow:-8px 0 12px -8px rgba(0,0,0,.55)}
th.rl-actions-cell{background:var(--mid,#182038)}
.rl-dots{background:transparent;border:1px solid rgba(255,255,255,.16);color:#cfd6e4;border-radius:6px;
  padding:2px 9px;cursor:pointer;font-size:1.05rem;line-height:1.2}
.rl-dots:hover{border-color:rgba(255,255,255,.4);color:#fff}
.rl-menu{position:fixed;z-index:9999;background:var(--card,#131a2e);border:1px solid rgba(255,255,255,.14);
  border-radius:10px;padding:6px;min-width:170px;box-shadow:0 12px 30px rgba(0,0,0,.5)}
.rl-menu button{display:block;width:100%;text-align:left;background:transparent;border:0;color:#e6e8ec;
  padding:9px 11px;border-radius:7px;cursor:pointer;font-size:.86rem}
.rl-menu button:hover{background:rgba(255,255,255,.07)}
.rl-menu button.danger{color:#ff6b6b}
.rl-menu button.danger:hover{background:rgba(231,76,60,.12)}
.rl-ov{position:fixed;inset:0;background:rgba(4,8,18,.66);display:flex;align-items:center;justify-content:center;z-index:10000;padding:18px}
.rl-dlg{background:var(--card,#131a2e);border:1px solid rgba(255,255,255,.14);border-radius:16px;padding:22px;max-width:430px;width:100%;box-shadow:0 24px 60px rgba(0,0,0,.55)}
.rl-dlg h3{margin:0 0 6px;font-size:1.06rem;color:#fff}
.rl-dlg .who{background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.1);border-radius:9px;padding:11px 13px;margin:12px 0}
.rl-dlg .who b{color:#00d4aa;font-family:monospace}
.rl-dlg p{margin:0;color:#9aa3b5;font-size:.86rem;line-height:1.55}
.rl-dlg .row{display:flex;gap:10px;justify-content:flex-end;margin-top:18px}
.rl-dlg button{border-radius:9px;padding:9px 17px;cursor:pointer;font-size:.88rem;font-weight:600;border:1px solid transparent}
.rl-dlg .cancel{background:transparent;border-color:rgba(255,255,255,.2);color:#cfd6e4}
.rl-dlg .go{background:#e74c3c;color:#fff}
.rl-dlg .go[disabled]{opacity:.6;cursor:default}
</style>
<script>
/* RL_ROW_MENU_JS: a three-dot menu per row, and a confirmation that names the user. A browser
   confirm() could not show who was being removed, which matters when the button sits off the
   right edge of a wide table. */
(function(){
  function closeMenus(){ document.querySelectorAll('.rl-menu').forEach(function(m){ m.remove(); }); }
  document.addEventListener('click', closeMenus);
  window.addEventListener('scroll', closeMenus, true);

  window.rlRowMenu = function(btn, id, type, username, phone){
    closeMenus();
    var r = btn.getBoundingClientRect();
    var m = document.createElement('div');
    m.className = 'rl-menu';
    m.innerHTML = '<button type="button" class="danger" data-act="del">Delete user</button>';
    document.body.appendChild(m);
    m.style.top = Math.min(r.bottom + 6, window.innerHeight - m.offsetHeight - 10) + 'px';
    m.style.left = Math.max(10, r.right - m.offsetWidth) + 'px';
    m.addEventListener('click', function(e){
      e.stopPropagation();
      if (e.target.getAttribute('data-act') === 'del') { closeMenus(); rlConfirmDelete(id, type, username, phone); }
    });
  };

  window.rlConfirmDelete = function(id, type, username, phone){
    var ov = document.createElement('div');
    ov.className = 'rl-ov';
    ov.innerHTML =
      '<div class="rl-dlg">' +
        '<h3>Delete this user?</h3>' +
        '<div class="who"><b>' + (username || '—') + '</b>' +
          (phone ? '<span style="color:#9aa3b5"> &middot; ' + phone + '</span>' : '') +
          '<span style="color:#9aa3b5"> &middot; ' + (type === 'pppoe' ? 'PPPoE' : 'Hotspot') + '</span></div>' +
        '<p>They lose access immediately. Their payment history is kept, so your reports stay correct.</p>' +
        '<div class="row"><button type="button" class="cancel">Cancel</button>' +
        '<button type="button" class="go">Delete</button></div>' +
      '</div>';
    document.body.appendChild(ov);
    ov.addEventListener('click', function(e){ if (e.target === ov) ov.remove(); });
    ov.querySelector('.cancel').onclick = function(){ ov.remove(); };
    ov.querySelector('.go').onclick = async function(){
      var b = this; b.disabled = true; b.textContent = 'Deleting…';
      try {
        await api('/isp/users/' + id + '?type=' + type, { method: 'DELETE' });
        ov.remove();
        if (typeof toast === 'function') toast(username + ' deleted');
        if (typeof rlLoadUsers === 'function') rlLoadUsers(); else if (typeof loadUsers === 'function') loadUsers();
      } catch (err) {
        b.disabled = false; b.textContent = 'Delete';
        if (typeof toast === 'function') toast(err.message, 'error'); else alert(err.message);
      }
    };
  };
})();
</script>
"""
    s = s.replace('</body>', JS + '\n</body>', 1) if '</body>' in s else s + JS

# make the header cell sticky too
s = s.replace('<th style="padding:12px;text-align:right">Actions</th>',
              '<th class="rl-actions-cell">Actions</th>', 1)
open(p,'w').write(s); print("   three-dot menu, styled modal and pinned column in place")
PY
sudo chown www-data:www-data "$D"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"
echo "   old confirm handler gone: $(grep -c 'RL_DELETE_BTN' "$D")"

say "4) Restart + verify"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 15 --nostream 2>/dev/null | grep -iE "delete-user|error" | tail -3 | sed 's/^/   /' || echo "   clean"
q -c "SELECT count(*) FILTER (WHERE deleted_at IS NULL) AS live, count(*) FILTER (WHERE deleted_at IS NOT NULL) AS deleted FROM hotspot_vouchers;"

say "5) Try it"
cat <<'EOS'
   Reload All Users. Each row ends with a ⋮ button that stays pinned to the right while you
   scroll sideways. Clicking it offers Delete; the confirmation names the user and their phone
   so you can see exactly who you are removing.
EOS

say "6) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Delete: row menu with a named confirmation dialog; stop writing a status the enum rejects" 2>&1 | head -2 | sed 's/^/   /'
