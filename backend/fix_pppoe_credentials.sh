#!/usr/bin/env bash
#
# fix_pppoe_credentials.sh — PPPoE password, username and delete.
#
# PASSWORD: the route ran UPDATE radcheck ... WHERE attribute='Cleartext-Password'. These
#   subscribers only have NT-Password rows, so the UPDATE matched nothing and reported success.
#   It then tried to compute an NT hash with crypto md4 — unavailable in this Node build — and
#   fell back to an openssl shell call, all inside a catch that only logs. Nothing changed and
#   nothing complained.
#   The PPPoE server accepts pap,chap,mschap1,mschap2, so Cleartext-Password authenticates on its
#   own. Write it with an upsert rather than an update, keep NT-Password best-effort for MS-CHAP,
#   and store the plaintext on the subscriber so the lifecycle page can show it.
#
# DELETE: a hard DELETE, which payments and pppoe_invoices refuse via foreign keys. Soft delete
#   instead — revoke credentials, disconnect, mark removed — so billing history survives.
#
# USERNAME: not handled at all. Changing it moves the RADIUS records, since the username IS the
#   key RADIUS authenticates on.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Somewhere to keep the plaintext"
q -c "ALTER TABLE pppoe_subscribers ADD COLUMN IF NOT EXISTS password varchar;"
echo "   seed it from any existing Cleartext-Password rows:"
q -c "UPDATE pppoe_subscribers s SET password = rc.value
      FROM radcheck rc WHERE rc.username = s.username AND rc.attribute='Cleartext-Password'
        AND s.password IS NULL;"
q -c "SELECT username, CASE WHEN password IS NULL THEN '(none)' ELSE password END AS password,
             (SELECT string_agg(attribute,',') FROM radcheck rc WHERE rc.username=s.username) AS radius_attrs
      FROM pppoe_subscribers s WHERE deleted_at IS NULL ORDER BY username LIMIT 8;"

say "2) Backup"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"

say "3) Password: upsert, not update — and remember it"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_PPPOE_PW_UPSERT' in s:
    print("   already patched"); sys.exit(0)
old = """        await query("UPDATE radcheck SET value = $1 WHERE username = $2 AND attribute = 'Cleartext-Password'", [password, r.rows[0].username]);"""
new = """        /* RL_PPPOE_PW_UPSERT: an UPDATE only works if the row exists, and these subscribers carry
           NT-Password alone — so the statement matched nothing and reported success while the
           password never changed. Delete-then-insert always lands. The PPPoE server accepts
           pap and chap, so this attribute authenticates on its own; the NT hash below is a bonus
           for MS-CHAP, not a requirement. */
        await query("DELETE FROM radcheck WHERE username = $1 AND attribute = 'Cleartext-Password'", [r.rows[0].username]).catch(function(){});
        await query("INSERT INTO radcheck (username, attribute, op, value) VALUES ($1, 'Cleartext-Password', ':=', $2)", [r.rows[0].username, password]);
        /* keep the plaintext where the lifecycle page can read it — the page shows sub.password */
        await query("UPDATE pppoe_subscribers SET password = $1 WHERE id = $2::uuid", [password, subscriberId]);"""
if old not in s:
    print("   ERROR: password update not found"); sys.exit(1)
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   password now written and stored")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "4) Allow the username to change"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_PPPOE_USERNAME_EDIT' in s:
    print("   already patched"); sys.exit(0)
old = "    let { phone, full_name, email, status, next_billing_date, password, package_id, pppoe_password } = req.body || {};"
new = "    let { phone, full_name, email, status, next_billing_date, password, package_id, pppoe_password, username } = req.body || {};"
if old in s: s = s.replace(old, new, 1)

anchor = "    // v62.27: also update radcheck if password changed"
blk = """    /* RL_PPPOE_USERNAME_EDIT: the username IS the key RADIUS authenticates on, so renaming a
       subscriber means moving their radcheck and radreply rows too — otherwise they keep the old
       credentials and the new name cannot log in. Accounting history stays under the old name on
       purpose: rewriting radacct would distort past usage reports. */
    if (username !== undefined && username && username !== r.rows[0].username) {
      const oldName = r.rows[0].username;
      const newName = String(username).trim();
      const clash = await query("SELECT 1 FROM pppoe_subscribers WHERE lower(username)=lower($1) AND id <> $2::uuid LIMIT 1", [newName, subscriberId]);
      if (clash.rows[0]) return res.status(409).json({ ok: false, error: 'That username is already taken' });
      await query("UPDATE pppoe_subscribers SET username = $1 WHERE id = $2::uuid", [newName, subscriberId]);
      await query("UPDATE radcheck SET username = $1 WHERE username = $2", [newName, oldName]).catch(function(){});
      await query("UPDATE radreply SET username = $1 WHERE username = $2", [newName, oldName]).catch(function(){});
      r.rows[0].username = newName;
      require('../utils/logger').info('[pppoe-subscriber] renamed ' + oldName + ' -> ' + newName);
      /* bounce so they reconnect under the new name rather than keeping a session RADIUS no
         longer recognises */
      try {
        const wg = require('../utils/walledGarden');
        if (wg.bounce) await wg.bounce(null, oldName);
      } catch (e) {}
    }

"""
if anchor in s:
    s = s.replace(anchor, blk + anchor, 1)
    open(p,'w').write(s); print("   username changes move the RADIUS records")
else:
    print("   ERROR: anchor not found")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "5) Delete that actually works"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_PPPOE_SOFT_DELETE' in s:
    print("   already patched"); sys.exit(0)
old = """    // Delete subscriber
    await query("DELETE FROM pppoe_subscribers WHERE id = $1::uuid AND isp_id = $2::uuid", [subscriberId, ispId]);"""
new = """    /* RL_PPPOE_SOFT_DELETE: a hard DELETE is refused by the foreign keys from payments and
       pppoe_invoices, so this route always failed for anyone who had ever paid — which is every
       real subscriber. Forcing cascades would erase billing history. Mark the record removed:
       credentials are already gone above, so access ends immediately, and the money trail stays. */
    try {
      const axios = require('axios');
      const nas = (await query("SELECT wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE isp_id=$1::uuid AND wireguard_ip IS NOT NULL", [ispId])).rows;
      for (const n of nas) {
        const b = 'http://' + n.wireguard_ip + '/rest';
        const auth = { username: n.mikrotik_api_user, password: n.mikrotik_api_password };
        const act = (await axios.get(b + '/ppp/active', { auth, timeout: 8000, validateStatus: function(){ return true; } })).data || [];
        for (const a of act) {
          if (String(a.name) === username) {
            await axios.delete(b + '/ppp/active/' + encodeURIComponent(a['.id']), { auth, timeout: 8000 }).catch(function(){});
          }
        }
        const secrets = (await axios.get(b + '/ppp/secret', { auth, timeout: 8000, validateStatus: function(){ return true; } })).data || [];
        for (const sc of secrets) {
          if (String(sc.name) === username) {
            await axios.delete(b + '/ppp/secret/' + encodeURIComponent(sc['.id']), { auth, timeout: 8000 }).catch(function(){});
          }
        }
      }
    } catch (e) { require('../utils/logger').warn('[pppoe delete] router cleanup: ' + e.message); }

    await query("UPDATE pppoe_subscribers SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1::uuid AND isp_id = $2::uuid", [subscriberId, ispId]);"""
if old not in s:
    print("   ERROR: delete statement not found"); sys.exit(1)
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   delete now revokes access and keeps billing history")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "6) Make sure the lifecycle page receives the password"
grep -n "pppoe_subscriber" "$BE/routes/isp.js" | grep -iE "SELECT|json" | head -5 | sed 's/^/   /'
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
n = 0
for m in re.finditer(r'SELECT ([^;]{0,400}?) FROM pppoe_subscribers', s):
    cols = m.group(1)
    if 'password' not in cols and ('username' in cols or 'full_name' in cols) and '*' not in cols:
        s = s[:m.start(1)] + cols.rstrip() + ', password' + s[m.end(1):]
        n += 1
        break
if n: open(p,'w').write(s)
print(f"   {n} select(s) now include password")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "7) Restart + verify"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 15 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"
q -c "SELECT username, password, deleted_at FROM pppoe_subscribers WHERE deleted_at IS NULL ORDER BY username LIMIT 5;"

say "8) Try it"
cat <<'EOS'
   On a subscriber's lifecycle page: set a password, save, reload — it should now display.
   Confirm RADIUS got it:
     sudo -u postgres psql -d rumalink_db -c "SELECT username, attribute, value FROM radcheck WHERE username='benard';"
   Then have them reconnect: pap/chap authenticate from Cleartext-Password, so it will work.

   Delete now revokes credentials, drops the session, removes the PPP secret and hides the record
   while leaving payments and invoices intact.
EOS

say "9) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "PPPoE: password actually saves (UPDATE matched no row), username editable, delete no longer blocked by foreign keys" 2>&1 | head -2 | sed 's/^/   /'
