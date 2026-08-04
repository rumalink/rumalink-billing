#!/usr/bin/env bash
#
# add_delete_users.sh — delete a user from All Users and from the detail page.
#
# The route at isp.js:1207 does a hard DELETE. payments, pppoe_sessions and pppoe_invoices all
# reference these rows with NO ACTION, so Postgres refuses for anyone who has ever paid — which
# is why the buttons never worked. Forcing cascades instead would erase revenue history.
#
# SOFT DELETE: mark the record removed, strip its RADIUS credentials and router presence so
# access stops at once, and hide it from the lists. To the ISP it behaves like a delete; the
# payment trail survives, so last month's revenue still reconciles.
#
set -uo pipefail
BE=/var/www/rumalink/backend
D=/var/www/rumalink/isp/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Columns to mark a record removed"
q -c "ALTER TABLE hotspot_vouchers  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;"
q -c "ALTER TABLE pppoe_subscribers ADD COLUMN IF NOT EXISTS deleted_at timestamptz;"
q -c "CREATE INDEX IF NOT EXISTS idx_hv_deleted ON hotspot_vouchers(deleted_at);"
q -c "CREATE INDEX IF NOT EXISTS idx_ps_deleted ON pppoe_subscribers(deleted_at);"

say "2) Backups"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"
sudo cp "$D" "/var/www/rumalink/isp/.dashboard.html.bak_$TS" && echo "   dashboard.html"

say "3) Replace the hard delete with a soft one"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SOFT_DELETE' in s:
    print("   already patched"); sys.exit(0)

start = s.find("router.delete('/users/:id'")
if start == -1:
    print("   ERROR: delete route not found"); sys.exit(1)
m = re.compile(r'^\}\);\s*$', re.M).search(s, start)
end = m.end()

NEW = """router.delete('/users/:id', async (req, res) => {
  /* RL_SOFT_DELETE: this used a hard DELETE, which Postgres refuses for anyone with payment
     history — payments, pppoe_sessions and pppoe_invoices all reference these rows. Cascading
     instead would erase revenue records. So: mark the row removed, take away its access
     immediately, and hide it from the lists. The ISP sees a delete; the accounts stay whole. */
  try {
    const { type } = req.query;
    if (type !== 'hotspot' && type !== 'pppoe') {
      return res.status(400).json({ error: 'type must be hotspot or pppoe' });
    }

    if (type === 'hotspot') {
      const v = (await query(
        `SELECT v.id, v.code, v.isp_id, v.used_by_mac FROM hotspot_vouchers v
          WHERE v.id = $1::uuid AND v.isp_id = $2::uuid LIMIT 1`,
        [req.params.id, req.user.ispId])).rows[0];
      if (!v) return res.status(404).json({ error: 'User not found' });

      const realmed = v.code + '@' + String(v.isp_id).replace(/-/g, '').slice(0, 8).toLowerCase();
      /* credentials first — the customer must lose access even if the router is unreachable */
      await query('DELETE FROM radcheck WHERE username = $1 OR username = $2', [realmed, v.code]).catch(() => {});
      await query('DELETE FROM radreply WHERE username = $1 OR username = $2', [realmed, v.code]).catch(() => {});
      if (v.used_by_mac) {
        await query('DELETE FROM radcheck WHERE username = $1', [v.used_by_mac]).catch(() => {});
        await query('DELETE FROM radreply WHERE username = $1', [v.used_by_mac]).catch(() => {});
      }
      await query('DELETE FROM hotspot_voucher_devices WHERE voucher_id = $1::uuid', [v.id]).catch(() => {});

      try {
        const mt = require('../utils/mikrotik');
        const nas = (await query(
          'SELECT id FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL', [req.user.ispId])).rows;
        for (const n of nas) {
          await mt.removeHotspotUser(n.id, v.code).catch(() => {});
          if (mt.kickHotspotUser) await mt.kickHotspotUser(n.id, v.code).catch(() => {});
        }
      } catch (e) { require('../utils/logger').warn('[delete-user] router cleanup: ' + e.message); }

      await query(
        `UPDATE hotspot_vouchers SET deleted_at = NOW(), status = 'deleted', updated_at = NOW()
          WHERE id = $1::uuid AND isp_id = $2::uuid`, [req.params.id, req.user.ispId]);
      require('../utils/logger').info('[delete-user] hotspot ' + v.code + ' removed by isp ' + req.user.ispId);

    } else {
      const sub = (await query(
        'SELECT id, username FROM pppoe_subscribers WHERE id = $1::uuid AND isp_id = $2::uuid LIMIT 1',
        [req.params.id, req.user.ispId])).rows[0];
      if (!sub) return res.status(404).json({ error: 'Subscriber not found' });

      await query('DELETE FROM radcheck WHERE username = $1', [sub.username]).catch(() => {});
      await query('DELETE FROM radreply WHERE username = $1', [sub.username]).catch(() => {});

      try {
        const axios = require('axios');
        const nas = (await query(
          `SELECT wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices
            WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL`, [req.user.ispId])).rows;
        for (const n of nas) {
          const b = 'http://' + n.wireguard_ip + '/rest';
          const auth = { username: n.mikrotik_api_user, password: n.mikrotik_api_password };
          const act = (await axios.get(b + '/ppp/active', { auth, timeout: 8000, validateStatus: () => true })).data || [];
          for (const a of act) {
            if (String(a.name) === sub.username) {
              await axios.delete(b + '/ppp/active/' + encodeURIComponent(a['.id']), { auth, timeout: 8000 }).catch(() => {});
            }
          }
          const secrets = (await axios.get(b + '/ppp/secret', { auth, timeout: 8000, validateStatus: () => true })).data || [];
          for (const sc of secrets) {
            if (String(sc.name) === sub.username) {
              await axios.delete(b + '/ppp/secret/' + encodeURIComponent(sc['.id']), { auth, timeout: 8000 }).catch(() => {});
            }
          }
        }
      } catch (e) { require('../utils/logger').warn('[delete-user] pppoe router cleanup: ' + e.message); }

      await query(
        `UPDATE pppoe_subscribers SET deleted_at = NOW(), status = 'deleted', updated_at = NOW()
          WHERE id = $1::uuid AND isp_id = $2::uuid`, [req.params.id, req.user.ispId]);
      require('../utils/logger').info('[delete-user] pppoe ' + sub.username + ' removed by isp ' + req.user.ispId);
    }

    res.json({ ok: true });
  } catch (err) {
    require('../utils/logger').error('[delete-user] ' + err.message);
    res.status(500).json({ error: err.message });
  }
});"""
s = s[:start] + NEW + s[end:]
open(p,'w').write(s); print("   soft delete in place, with RADIUS and router cleanup")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "4) Keep deleted users out of the lists and counts"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_HIDE_DELETED' in s:
    print("   already patched"); sys.exit(0)
n = 0
pairs = [
 ("WHERE v.isp_id = $1::uuid\n          AND (v.payment_id IS NOT NULL OR v.created_by_isp = true OR v.expires_at IS NOT NULL)",
  "WHERE v.isp_id = $1::uuid AND v.deleted_at IS NULL /* RL_HIDE_DELETED */\n          AND (v.payment_id IS NOT NULL OR v.created_by_isp = true OR v.expires_at IS NOT NULL)"),
 ("WHERE s.isp_id = $1::uuid\n          ORDER BY s.created_at DESC",
  "WHERE s.isp_id = $1::uuid AND s.deleted_at IS NULL /* RL_HIDE_DELETED */\n          ORDER BY s.created_at DESC"),
 ("WHERE v.isp_id = $1::uuid\n               AND (v.payment_id IS NOT NULL OR v.created_by_isp = true OR v.expires_at IS NOT NULL)",
  "WHERE v.isp_id = $1::uuid AND v.deleted_at IS NULL /* RL_HIDE_DELETED */\n               AND (v.payment_id IS NOT NULL OR v.created_by_isp = true OR v.expires_at IS NOT NULL)"),
 ("(SELECT count(*) FROM pppoe_subscribers s WHERE s.isp_id = $1::uuid)::int AS pppoe",
  "(SELECT count(*) FROM pppoe_subscribers s WHERE s.isp_id = $1::uuid AND s.deleted_at IS NULL)::int AS pppoe"),
]
for old, new in pairs:
    if old in s: s = s.replace(old, new, 1); n += 1
open(p,'w').write(s); print(f"   {n} query/queries now skip deleted records")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "5) Add the delete button to each row"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_DELETE_BTN' in s:
    print("   already patched"); sys.exit(0)
old = """        + '<td style="padding:12px;color:#888">' + dts(u.created_at) + '</td>'
        + '</tr>';"""
new = """        + '<td style="padding:12px;color:#888">' + dts(u.created_at) + '</td>'
        /* RL_DELETE_BTN */
        + '<td style="padding:12px;text-align:right"><button type="button" title="Delete this user"'
        + ' onclick="event.stopPropagation();rlDeleteUser(\\'' + u.id + '\\',\\'' + (u.type === 'pppoe' ? 'pppoe' : 'hotspot') + '\\',\\'' + esc(u.username || '') + '\\')"'
        + ' style="background:transparent;border:1px solid rgba(231,76,60,.45);color:#e74c3c;border-radius:6px;padding:4px 9px;cursor:pointer;font-size:.78rem">Delete</button></td>'
        + '</tr>';"""
if old not in s:
    print("   MISS: row template"); sys.exit(1)
s = s.replace(old, new, 1)

JS = """
<script>
/* RL_DELETE_BTN: removing a user takes away access immediately but keeps their payment history —
   a hard delete is refused by the database for anyone who has ever paid, and forcing it would
   erase revenue records. */
window.rlDeleteUser = async function(id, type, label){
  if (!confirm('Delete ' + (label || 'this user') + '?\\n\\nThey lose access straight away. Their payment history is kept for your records.')) return;
  try {
    await api('/isp/users/' + id + '?type=' + type, { method: 'DELETE' });
    if (typeof toast === 'function') toast('Deleted');
    if (typeof rlLoadUsers === 'function') rlLoadUsers();
    else if (typeof loadUsers === 'function') loadUsers();
  } catch (e) {
    if (typeof toast === 'function') toast(e.message, 'error'); else alert(e.message);
  }
};
</script>
"""
s = s.replace('</body>', JS + '\n</body>', 1) if '</body>' in s else s + JS
open(p,'w').write(s); print("   row button + handler added")
PY

say "6) Widen the header row for the new column"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
n = s.count('colspan="8"')
s = s.replace('colspan="8"', 'colspan="9"')
m = re.search(r'(<th[^>]*>\s*Created\s*</th>)', s, re.I)
if m and 'RL_DELETE_TH' not in s:
    s = s[:m.end()] + '<th style="padding:12px;text-align:right">/* RL_DELETE_TH */</th>'.replace('/* RL_DELETE_TH */', '') + s[m.end():]
    s = s.replace('<th style="padding:12px;text-align:right"></th>', '<th style="padding:12px;text-align:right">Actions</th>', 1)
open(p,'w').write(s); print(f"   {n} colspan(s) widened; Actions header added")
PY
sudo chown www-data:www-data "$D"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"

say "7) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 15 --nostream 2>/dev/null | grep -iE "delete-user|error" | tail -3 | sed 's/^/   /' || echo "   clean"
q -c "SELECT count(*) FILTER (WHERE deleted_at IS NULL) AS live, count(*) FILTER (WHERE deleted_at IS NOT NULL) AS deleted FROM hotspot_vouchers;"

say "8) Try it"
cat <<'EOS'
   Reload All Users. Each row has a Delete button; deleting removes the user from the list,
   drops their RADIUS credentials and disconnects them from the router.
   To bring one back if you delete by mistake:
     sudo -u postgres psql -d rumalink_db -c "UPDATE hotspot_vouchers SET deleted_at=NULL, status='active' WHERE code='R99';"
EOS

say "9) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Delete users from All Users: soft delete with RADIUS and router cleanup, payment history preserved" 2>&1 | head -2 | sed 's/^/   /'
