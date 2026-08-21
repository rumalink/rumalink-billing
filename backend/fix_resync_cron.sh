#!/usr/bin/env bash
#
# fix_resync_cron.sh — the every-minute cron writes the wrong password.
#
# /usr/local/bin/rumalink-radius-resync.sh inserts Cleartext-Password = v.code. The customer is
# told v.password by SMS and by the portal, so anyone whose credentials this cron writes cannot
# log in. It runs sixty times an hour, which is why deleting the bad rows only fixed things for
# under a minute: the next pass put them straight back.
#
# It is also how R107 ended up with two passwords. Node deletes then inserts; the cron ran in the
# gap, saw no rows, and inserted the code. Both survived, and FreeRADIUS requires a password to
# match BOTH — so every attempt was rejected.
#
# Two corrections: write the voucher's real password, and upsert so a wrong value already present
# is corrected rather than skipped. The old NOT EXISTS also tested the username alone, so a
# voucher holding only Simultaneous-Use would never be given a password at all.
#
set -uo pipefail
S=/usr/local/bin/rumalink-radius-resync.sh
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The damage right now"
q -c "SELECT count(*) AS wrong_password FROM hotspot_vouchers v
      JOIN radcheck rc ON rc.username = v.code||'@'||lower(left(replace(v.isp_id::text,'-',''),8))
      WHERE rc.attribute='Cleartext-Password' AND v.password IS NOT NULL AND v.password<>''
        AND rc.value IS DISTINCT FROM v.password;"
q -c "SELECT v.code, v.password AS told_to_customer, rc.value AS radius_wants
      FROM hotspot_vouchers v
      JOIN radcheck rc ON rc.username = v.code||'@'||lower(left(replace(v.isp_id::text,'-',''),8))
      WHERE rc.attribute='Cleartext-Password' AND v.password IS NOT NULL AND v.password<>''
        AND rc.value IS DISTINCT FROM v.password
      ORDER BY v.created_at DESC LIMIT 8;"

say "2) Back up and correct the cron"
sudo cp "$S" "${S}.bak_$TS" && echo "   ${S}.bak_$TS"
sudo python3 - "$S" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_RESYNC_REAL_PW' in s:
    print("   already patched"); sys.exit(0)

old = """  'Cleartext-Password', ':=', v.code
FROM hotspot_vouchers v
WHERE v.status IN ('unused', 'active')
  AND (v.expires_at IS NULL OR v.expires_at > NOW())
  AND NOT EXISTS (
    SELECT 1 FROM radcheck rc
    WHERE rc.username = v.code || '@' || LOWER(SUBSTRING(REPLACE(v.isp_id::text, '-', '') FROM 1 FOR 8))
  );"""
new = """  -- RL_RESYNC_REAL_PW: this wrote v.code. The customer is given v.password by SMS and by the
  -- portal, so every voucher this touched became unusable — and running each minute, it undid any
  -- correction within sixty seconds. It also raced the backend: Node deletes then inserts, this
  -- slipped into the gap, and the voucher ended up with two different passwords that FreeRADIUS
  -- required BOTH of. The NOT EXISTS tested the username alone, so a voucher holding only
  -- Simultaneous-Use never received a password either. Upsert the real one.
  'Cleartext-Password', ':=', COALESCE(NULLIF(v.password, ''), v.code)
FROM hotspot_vouchers v
WHERE v.status IN ('unused', 'active')
  AND (v.expires_at IS NULL OR v.expires_at > NOW())
ON CONFLICT (username, attribute) DO UPDATE SET value = EXCLUDED.value, op = EXCLUDED.op;"""
if old not in s:
    print("   ERROR: password insert not found — not modified"); sys.exit(1)
s = s.replace(old, new, 1)

# the reply inserts must upsert too, or they now throw against the unique index
import re
n = 0
def fix(m):
    global n
    body = m.group(0)
    if 'ON CONFLICT' in body: return body
    n += 1
    return body.rstrip().rstrip(';') + "\nON CONFLICT (username, attribute) DO UPDATE SET value = EXCLUDED.value, op = EXCLUDED.op;"
s = re.sub(r'INSERT INTO radreply[\s\S]*?;\n', lambda m: fix(m), s)
open(p,'w').write(s)
print(f"   password corrected; {n} radreply insert(s) now upsert")
PY
sudo bash -n "$S" && echo "   script syntax OK"

say "3) Fix strand-heal, which is already failing against the index"
sudo cp "$BE/utils/strand-heal.js" "$BE/utils/.strand-heal.js.bak_$TS"
sudo python3 - "$BE/utils/strand-heal.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_STRAND_UPSERT' in s:
    print("   already patched"); sys.exit(0)
n = 0
def fix(m):
    global n
    body = m.group(0)
    if 'ON CONFLICT' in body: return body
    n += 1
    return body + " ON CONFLICT (username, attribute) DO UPDATE SET value = EXCLUDED.value, op = EXCLUDED.op"
s2 = re.sub(r'"INSERT INTO rad(?:check|reply)[^"]*"(?:\s*\+\s*"[^"]*")*', fix, s)
if n:
    s2 = ("/* RL_STRAND_UPSERT: these plain INSERTs now hit the unique index and throw — the log showed\n"
          "   'mac creds: duplicate key value violates unique constraint', which meant MAC auto-reconnect\n"
          "   credentials silently stopped being written. Upsert instead. */\n") + s2
    open(p,'w').write(s2)
print(f"   {n} insert(s) now upsert")
PY
cd "$BE" && sudo -u www-data node --check utils/strand-heal.js && echo "   strand-heal.js OK"

say "4) Repair the vouchers the cron broke"
q -c "UPDATE radcheck rc SET value = v.password
      FROM hotspot_vouchers v
      WHERE rc.username = v.code||'@'||lower(left(replace(v.isp_id::text,'-',''),8))
        AND rc.attribute='Cleartext-Password'
        AND v.password IS NOT NULL AND v.password<>''
        AND rc.value IS DISTINCT FROM v.password;"

say "5) Clear the TV vouchers that still hold a login"
q -c "DELETE FROM radcheck WHERE username IN (
        SELECT v.code||'@'||lower(left(replace(v.isp_id::text,'-',''),8))
        FROM hotspot_vouchers v WHERE v.is_tv = true);"
q -c "DELETE FROM radreply WHERE username IN (
        SELECT v.code||'@'||lower(left(replace(v.isp_id::text,'-',''),8))
        FROM hotspot_vouchers v WHERE v.is_tv = true);"

say "6) Run the corrected cron once and confirm it holds"
sudo "$S" >/dev/null 2>&1 || true
sleep 2
q -c "SELECT count(*) AS wrong_password_after FROM hotspot_vouchers v
      JOIN radcheck rc ON rc.username = v.code||'@'||lower(left(replace(v.isp_id::text,'-',''),8))
      WHERE rc.attribute='Cleartext-Password' AND v.password IS NOT NULL AND v.password<>''
        AND rc.value IS DISTINCT FROM v.password;"
echo "   ${Y}wait 90s and re-run that query — it must stay at zero through a cron pass${N}"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1

say "7) Commit"
sudo cp "$S" "$BE/scripts_rumalink-radius-resync.sh" 2>/dev/null || true
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Resync cron wrote the voucher code as the password, overwriting real credentials every minute" 2>&1 | head -2 | sed 's/^/   /'
