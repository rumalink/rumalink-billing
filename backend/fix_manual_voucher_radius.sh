#!/usr/bin/env bash
#
# fix_manual_voucher_radius.sh — a manually created hotspot user can never log in.
#
# TWO FAULTS, both general:
#
#  1. /hotspot/manual-voucher inserts the voucher and returns. It never publishes to RADIUS, so
#     the account has no credentials at all. A purchase does this via syncRadiusForVoucher.
#
#  2. isp.js:1873 — a fallback that DOES publish — writes v.code as the Cleartext-Password
#     instead of v.password. DBDANDO was told its password was 23ax23 while RADIUS expected
#     DBDANDO, so every attempt was an Access-Reject and the portal fell back to the purchase
#     page. RUMALINK only works because yesterday's catch-up sync rewrote its entry correctly.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The mismatch, before"
q -c "SELECT v.code, v.password AS shown_to_customer,
             (SELECT rc.value FROM radcheck rc
               WHERE rc.username = v.code || '@' || lower(left(replace(v.isp_id::text,'-',''),8))
                 AND rc.attribute='Cleartext-Password') AS radius_expects
      FROM hotspot_vouchers v
      WHERE v.created_by_isp = true AND v.status='active' ORDER BY v.created_at DESC LIMIT 8;"

say "2) Backup"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"

say "3) Fault 2 — publish the real password, not the code"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_RADIUS_REAL_PW' in s:
    print("   already patched"); sys.exit(0)
old = """          await query("INSERT INTO radcheck (username, attribute, op, value) VALUES ($1, 'Cleartext-Password', ':=', $2) ON CONFLICT DO NOTHING", [realmedUser, v.code]);"""
if old not in s:
    print("   ERROR: line 1873 insert not found"); sys.exit(1)
new = """          /* RL_RADIUS_REAL_PW: this published v.code as the password while the dashboard and SMS
             give the customer v.password — so RADIUS rejected the very credentials we handed out.
             ON CONFLICT DO NOTHING also meant a wrong entry could never be corrected. */
          await query("INSERT INTO radcheck (username, attribute, op, value) VALUES ($1, 'Cleartext-Password', ':=', $2) " +
                      "ON CONFLICT (username, attribute) DO UPDATE SET value = EXCLUDED.value",
                      [realmedUser, v.password || v.code]).catch(async function () {
            await query("DELETE FROM radcheck WHERE username = $1 AND attribute = 'Cleartext-Password'", [realmedUser]).catch(function(){});
            await query("INSERT INTO radcheck (username, attribute, op, value) VALUES ($1, 'Cleartext-Password', ':=', $2)",
                        [realmedUser, v.password || v.code]).catch(function(){});
          });"""
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   publishes v.password now, and can correct a wrong entry")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "4) Fault 1 — publish to RADIUS when the ISP creates the user"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_MANUAL_PUBLISH' in s:
    print("   already patched"); sys.exit(0)
anchor = """      RETURNING id, code, expires_at, is_test, is_paid, buyer_phone
    `, [req.user.ispId, package_id, nas_id || null, code, 'active', isPaid, testFlag, amountPaid, paymentMethod, buyer_phone || null, mac_address || null, expiresAt]);"""
if anchor not in s:
    print("   ERROR: manual-voucher insert not found"); sys.exit(1)
add = anchor + """

    /* RL_MANUAL_PUBLISH: creation used to end here. A voucher with no RADIUS entry cannot
       authenticate, so every hand-made account was refused at login — the ISP had issued
       credentials the network had never been told about. A purchase publishes through
       syncRadiusForVoucher; do exactly the same so a manual user behaves like a paying one. */
    try {
      const _cap = require('./captive');
      if (_cap.syncRadiusForVoucher) {
        await _cap.syncRadiusForVoucher(result.rows[0].id);
        require('../utils/logger').info('[manual-voucher] ' + code + ' published to RADIUS');
      } else {
        require('../utils/logger').warn('[manual-voucher] syncRadiusForVoucher unavailable — ' + code + ' has no credentials');
      }
    } catch (e) {
      require('../utils/logger').error('[manual-voucher] radius publish failed for ' + code + ': ' + e.message);
    }"""
s = s.replace(anchor, add, 1)
open(p,'w').write(s); print("   manual creation now publishes to RADIUS")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "5) Correct every account already issued with the wrong password"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 7
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const {query}=require('$BE/config/database');
(async()=>{
  const cap=require('$BE/routes/captive');
  const rows=(await query(
    \"SELECT id, code FROM hotspot_vouchers WHERE created_by_isp = true AND status='active' AND (is_tv IS NOT TRUE)\"
  )).rows;
  console.log('   republishing ' + rows.length + ' manual voucher(s)');
  for (const r of rows) {
    try { if (cap.syncRadiusForVoucher) await cap.syncRadiusForVoucher(r.id); console.log('     ' + r.code); }
    catch(e){ console.log('     ' + r.code + ': ' + e.message); }
  }
  process.exit(0);
})();" 2>&1 | grep -vE "^info:" | sed 's/^/  /'

say "6) The mismatch, after"
q -c "SELECT v.code, v.password AS shown_to_customer,
             (SELECT rc.value FROM radcheck rc
               WHERE rc.username = v.code || '@' || lower(left(replace(v.isp_id::text,'-',''),8))
                 AND rc.attribute='Cleartext-Password') AS radius_expects,
             (SELECT count(*) FROM radreply rr
               WHERE rr.username = v.code || '@' || lower(left(replace(v.isp_id::text,'-',''),8))) AS reply_attrs
      FROM hotspot_vouchers v
      WHERE v.created_by_isp = true AND v.status='active' ORDER BY v.created_at DESC LIMIT 8;"
echo "   ${Y}shown_to_customer and radius_expects must now be identical${N}"

say "7) Test"
cat <<'EOS'
   Create a NEW user through Add User, then log in with the code and the password shown.
   It should authenticate first time.
     pm2 logs rumalink-backend | grep manual-voucher
   A line "published to RADIUS" confirms creation did its job.
   And for DBDANDO, its password is now the one the dashboard displays.
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Manual hotspot users: publish to RADIUS on creation, and with the real password not the code" 2>&1 | head -2 | sed 's/^/   /'
