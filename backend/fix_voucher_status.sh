#!/usr/bin/env bash
#
# fix_voucher_status.sh — an expired hotspot user cannot be extended.
#
# The voucher edit route validates against ['unused','used','expired']. 'used' is not a member of
# the voucher_status enum at all, and 'active' — the one status needed to revive an expired
# customer — is missing. So the single most ordinary edit (push the expiry out, set it active)
# was refused, while a value Postgres would reject was permitted.
#
# The rest of the route already anticipates 'active': there is a _wantActive branch below, and
# RL_EXPIRE_FORCE_TIME keeps status and timestamp consistent. Only the list was stale.
#
# Also fixes two malformed placeholders in the other edit route (PUT /users/:id), where
# `${idx++}` was written without the $ and produced "used_by_mac = 5" instead of "= $5".
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) What the enum really allows"
q -c "SELECT enumlabel FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid WHERE t.typname='voucher_status' ORDER BY e.enumsortorder;"
echo "   the route currently accepts:"
sudo grep -n "validStatuses" "$BE/routes/isp.js" | sed 's/^/     /'

say "2) Backup"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"

say "3) Accept the statuses the database actually has"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_VOUCHER_STATUS_ENUM' in s:
    print("   already patched"); sys.exit(0)
old = "    const validStatuses = ['unused', 'used', 'expired'];"
if old not in s:
    print("   ERROR: validStatuses line not found"); sys.exit(1)
new = ("""    /* RL_VOUCHER_STATUS_ENUM: this listed 'used', which is not a member of voucher_status, and
       omitted 'active', which is — so extending an expired customer (new expiry + active) was
       refused, while a value Postgres would have rejected was allowed through. The branches below
       already handle 'active'; only this list was stale. Mirror the enum. */
    const validStatuses = ['unused', 'active', 'expired'];""")
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   validStatuses now mirrors the enum")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "4) Fix the malformed placeholders in PUT /users/:id"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_PLACEHOLDER_FIX' in s:
    print("   already patched"); sys.exit(0)
n = 0
old1 = "if (mac !== undefined) { updates.push(`used_by_mac = ${idx++}`); params.push(mac); }"
new1 = "if (mac !== undefined) { updates.push(`used_by_mac = $${idx++}`); params.push(mac); } /* RL_PLACEHOLDER_FIX: the $ was missing, producing \"used_by_mac = 5\" — a literal, not a parameter */"
if old1 in s: s = s.replace(old1, new1, 1); n += 1
old2 = "updates.push(`package_id = ${idx++}::uuid`.replace('${D}', String.fromCharCode(36)))"
new2 = "updates.push(`package_id = $${idx++}::uuid`) /* RL_PLACEHOLDER_FIX */"
if old2 in s: s = s.replace(old2, new2, 1); n += 1
open(p,'w').write(s); print(f"   {n}/2 placeholder(s) corrected")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "5) Re-sync RADIUS after an edit, so the change reaches the customer"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_EDIT_RESYNC' in s:
    print("   already patched"); sys.exit(0)
i = s.find("router.patch('/:ispId/voucher/:voucherId'")
m = re.search(r'^\}\);\s*$', s[i:], re.M)
if not m:
    print("   ERROR: route end not found"); sys.exit(1)
seg = s[i:i+m.end()]
mj = re.search(r'([ \t]*)res\.json\(', seg)
if not mj:
    print("   NOTE: no res.json found; skipping"); sys.exit(0)
ind = mj.group(1)
blk = (f"{ind}/* RL_EDIT_RESYNC: extending a voucher only moves a database row. Without republishing the\n"
       f"{ind}   RADIUS entry the dashboard shows 'active' while the customer still cannot authenticate —\n"
       f"{ind}   the expiry drives Session-Timeout, and an expired voucher has no credentials at all. */\n"
       f"{ind}try {{\n"
       f"{ind}  const _cap = require('./captive');\n"
       f"{ind}  if (_cap.syncRadiusForVoucher) await _cap.syncRadiusForVoucher(voucherId);\n"
       f"{ind}}} catch (e) {{ require('../utils/logger').warn('[voucher-edit] radius resync: ' + e.message); }}\n")
pos = i + mj.start()
s = s[:pos] + blk + s[pos:]
open(p,'w').write(s); print("   RADIUS re-sync added after the edit")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "6) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 15 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"
sudo grep -n "RL_VOUCHER_STATUS_ENUM\|RL_EDIT_RESYNC\|RL_PLACEHOLDER_FIX" "$BE/routes/isp.js" | sed 's/^/   /'

say "7) Try it"
cat <<'EOS'
   Open an expired hotspot user, set a new expiry, set status to Active, save.
   It should accept, and the customer should be able to reconnect — the RADIUS entry is
   republished with the new Session-Timeout as part of the save.
   Check afterwards:
     sudo -u postgres psql -d rumalink_db -c "SELECT code, status, expires_at FROM hotspot_vouchers WHERE code='R89';"
     sudo -u postgres psql -d rumalink_db -c "SELECT username, attribute, value FROM radcheck WHERE username LIKE 'R89@%';"
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Voucher edit: accept 'active' (enum value) instead of 'used' (not one); fix SQL placeholders; resync RADIUS" 2>&1 | head -2 | sed 's/^/   /'
