#!/usr/bin/env bash
#
# move_menu_right.sh — put the ⋮ back on the right, pinned so it never needs scrolling to.
#
# A trailing column on a 1100px-wide table falls off the edge, so it has to be sticky. Sticky
# means the rows scroll UNDER it, so it needs an opaque background of its own — and earlier
# attempts guessed that colour wrongly, which is why it read as a separate block. The exact
# stack is known now: var(--card) = #111d3a, with the table wrapper's rgba(255,255,255,.02)
# over it, and the header adding a further .04.
#
set -uo pipefail
CP=/var/www/rumalink/isp
D=$CP/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) Backup"
sudo cp "$D" "$CP/.dashboard.html.bak_$TS" && echo "   .dashboard.html.bak_$TS"

say "2) Move the header cell to the end"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
old = '<th class="rl-actions-cell" style="width:44px"></th><th style="padding:12px;text-align:left">Type</th>'
if old not in s:
    print("   header cell not in the leading position — checking trailing"); 
else:
    s = s.replace(old, '<th style="padding:12px;text-align:left">Type</th>', 1)
    # append it after Created, inside the users table only
    i = s.find('id="users-tbody"')
    j = s.rfind('<th style="padding:12px;text-align:left">Created</th>', 0, i)
    if j == -1:
        print("   ERROR: Created header not found"); sys.exit(1)
    end = j + len('<th style="padding:12px;text-align:left">Created</th>')
    s = s[:end] + '<th class="rl-actions-cell" style="width:52px"></th>' + s[end:]
    print("   header moved to the end")
open(p,'w').write(s)
PY

say "3) Move the row cell to the end"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
m = re.search(r"\n\s*/\* RL_ROW_MENU_FIRST:.*?</td>'\n", s, re.S)
if not m:
    print("   leading cell not found — may already be trailing"); sys.exit(0)
block = m.group(0)
s = s[:m.start()] + "\n" + s[m.end():]
anchor = """        + '<td style="padding:12px;color:#888">' + dts(u.created_at) + '</td>'"""
i = s.find("function renderRows()")
j = s.find(anchor, i)
if j == -1:
    print("   ERROR: created cell not found in renderRows"); sys.exit(1)
cell = ("""
        /* RL_ROW_MENU_RIGHT: trailing column, pinned. The table is wider than the viewport, so a
           trailing cell would scroll out of reach — sticky keeps it against the right edge. That
           means rows pass underneath it, so it carries the same background the surrounding cells
           are composed from: var(--card) with the wrapper's translucent tint on top. */
        + '<td class="rl-actions-cell"><button type="button" class="rl-dots" title="Actions"'
        + ' onclick="event.stopPropagation();rlRowMenu(this,\\'' + u.id + '\\',\\'' + (u.type === 'pppoe' ? 'pppoe' : 'hotspot') + '\\',\\'' + esc(u.username || '') + '\\',\\'' + esc(u.phone || '') + '\\')">&#8942;</button></td>'""")
end = j + len(anchor)
s = s[:end] + cell + s[end:]
open(p,'w').write(s); print("   row cell moved to the end")
PY

say "4) Pin it, with the correct background"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
old = re.search(r'\.rl-actions-cell\{[^}]*\}\s*\nth\.rl-actions-cell\{[^}]*\}', s)
if not old:
    print("   ERROR: css rules not found"); sys.exit(1)
new = """/* RL_ACTIONS_STICKY: --card is #111d3a and the table wrapper paints rgba(255,255,255,.02) over
   it; the header adds another .04. A sticky cell must be opaque or the rows show through, so it
   reproduces that stack rather than approximating it with one solid colour. */
.rl-actions-cell{padding:12px;text-align:center;position:sticky;right:0;z-index:2;
  background-color:#111d3a;
  background-image:linear-gradient(rgba(255,255,255,.02),rgba(255,255,255,.02));
  box-shadow:-10px 0 14px -10px rgba(0,0,0,.5)}
th.rl-actions-cell{padding:12px;position:sticky;right:0;z-index:3;
  background-color:#111d3a;
  background-image:linear-gradient(rgba(255,255,255,.02),rgba(255,255,255,.02)),
                   linear-gradient(rgba(255,255,255,.04),rgba(255,255,255,.04))}
tbody tr:hover .rl-actions-cell{
  background-image:linear-gradient(rgba(255,255,255,.02),rgba(255,255,255,.02)),
                   linear-gradient(rgba(255,255,255,.03),rgba(255,255,255,.03))}"""
s = s[:old.start()] + new + s[old.end():]
open(p,'w').write(s); print("   sticky rules applied")
PY
sudo chown www-data:www-data "$D"

say "5) Verify"
echo "   header position (should be after Created):"
sudo grep -oE '<th[^>]*>Created</th><th class="rl-actions-cell"[^>]*></th>' "$D" | head -1 | sed 's/^/     /'
echo "   row cell position (should follow created_at):"
sudo grep -c "RL_ROW_MENU_RIGHT" "$D" | sed 's/^/     RL_ROW_MENU_RIGHT: /'
echo "   sticky present:"; sudo grep -c "RL_ACTIONS_STICKY" "$D" | sed 's/^/     /'
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
curl -sk -o /dev/null -w "   dashboard HTTP %{http_code}\n" https://rumalinkenterprise.online/isp/dashboard.html

say "6) Check"
echo "   Reload All Users. The ⋮ sits at the right edge and stays there while the table scrolls."
echo "   Rollback: sudo cp $CP/.dashboard.html.bak_$TS $D"
