#!/usr/bin/env bash
#
# add_redeem_limit.sh — put the per-package device limit into the route that actually runs.
#
# /redeem currently accepts ANY mac (all three test MACs returned 200, an empty one too) and
# writes nothing to hotspot_voucher_devices, so the limit is unenforced there. Simultaneous-Use
# is set correctly in RADIUS, but that only caps concurrent SESSIONS — it does not decide which
# devices may hold the code.
#
# Also fixes the two config columns the device page reads (gateway_ip, ip_pool_start/end) which
# the earlier sync missed because it wrote hotspot_gateway / hotspot_pool_* instead.
#
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The /redeem route in full (189-233)"
sudo sed -n '189,233p' "$BE/routes/captive.js" | nl -ba -v189 | sed 's/^/   /'

say "2) The portal's redeem UI — is it visible to a new device?"
LR=$(grep -n "/redeem" "$CP/classic.html" | head -1 | cut -d: -f1)
[ -n "$LR" ] && sudo sed -n "$((LR-40)),$((LR+20))p" "$CP/classic.html" | nl -ba -v"$((LR-40))" | sed 's/^/   /'
echo "   --- elements that reveal it ---"
grep -noE 'id="[a-z0-9_-]*(voucher|redeem|code)[a-z0-9_-]*"|onclick="[a-zA-Z]*[Rr]edeem[a-zA-Z]*' "$CP/classic.html" | head -10 | sed 's/^/   /'

say "3) Backup + add the limit to /redeem"
sudo cp "$BE/routes/captive.js" "$BE/routes/.captive.js.bak_$TS" && echo "   captive.js"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_REDEEM_DEVICE_LIMIT' in s:
    print("   already patched"); sys.exit(0)
anchor = "if (!voucher.rows[0]) return res.status(404).json({ error: 'Invalid or expired voucher code.' });"
i = s.find(anchor)
if i == -1:
    print("   ERROR: voucher-not-found anchor missing — unchanged"); sys.exit(1)
ind_m = re.search(r'^([ \t]*)' + re.escape(anchor), s, re.M)
ind = ind_m.group(1) if ind_m else '    '
blk = (
f"\n{ind}/* RL_REDEEM_DEVICE_LIMIT: a package may allow several devices on one code\n"
f"{ind}   (hotspot_packages.simultaneous_sessions). This route accepted ANY mac and recorded none,\n"
f"{ind}   so the limit was unenforced here — RADIUS Simultaneous-Use caps concurrent SESSIONS, but\n"
f"{ind}   it does not decide which devices may hold the code. Record each device, admit while under\n"
f"{ind}   the limit, and refuse beyond it with a message that says why. An unreadable mac is NOT\n"
f"{ind}   counted: with paying customers online, failing open is safer than locking someone out. */\n"
f"{ind}try {{\n"
f"{ind}  const _v = voucher.rows[0];\n"
f"{ind}  const _macRaw = String(mac || '').trim().toUpperCase();\n"
f"{ind}  const _mac = /^[0-9A-F]{{2}}([:-][0-9A-F]{{2}}){{5}}$/.test(_macRaw) ? _macRaw : '';\n"
f"{ind}  if (_mac) {{\n"
f"{ind}    const _lim = (await query(\n"
f"{ind}      'SELECT COALESCE(hp.simultaneous_sessions,1) AS n FROM hotspot_vouchers hv ' +\n"
f"{ind}      'LEFT JOIN hotspot_packages hp ON hp.id=hv.package_id WHERE hv.id=$1::uuid', [_v.id])).rows[0];\n"
f"{ind}    const _max = _lim ? (parseInt(_lim.n, 10) || 1) : 1;\n"
f"{ind}    const _known = (await query('SELECT mac FROM hotspot_voucher_devices WHERE voucher_id=$1::uuid', [_v.id]))\n"
f"{ind}                     .rows.map(function (r) {{ return String(r.mac).toUpperCase(); }});\n"
f"{ind}    if (!_known.includes(_mac)) {{\n"
f"{ind}      if (_known.length >= _max) {{\n"
f"{ind}        logger.info('[redeem] ' + _v.code + ' refused ' + _mac + ' (' + _known.length + '/' + _max + ')');\n"
f"{ind}        return res.status(403).json({{ error: 'This code is already used by ' + _known.length +\n"
f"{ind}          ' device' + (_known.length > 1 ? 's' : '') + '. It allows ' + _max + '.' }});\n"
f"{ind}      }}\n"
f"{ind}      await query('INSERT INTO hotspot_voucher_devices (voucher_id, mac) VALUES ($1::uuid,$2) ON CONFLICT DO NOTHING', [_v.id, _mac]);\n"
f"{ind}      logger.info('[redeem] ' + _v.code + ' admitted ' + _mac + ' (' + (_known.length + 1) + '/' + _max + ')');\n"
f"{ind}    }} else {{\n"
f"{ind}      await query('UPDATE hotspot_voucher_devices SET last_seen=now() WHERE voucher_id=$1::uuid AND mac=$2', [_v.id, _mac]).catch(function () {{}});\n"
f"{ind}    }}\n"
f"{ind}  }}\n"
f"{ind}}} catch (e) {{ logger.warn('[redeem] device limit: ' + e.message); }}\n"
)
s = s[:i+len(anchor)] + blk + s[i+len(anchor):]
open(p,'w').write(s); print("   device limit inserted into /redeem")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js OK"
sudo grep -n "RL_REDEEM_DEVICE_LIMIT" "$BE/routes/captive.js" | sed 's/^/   /'

say "4) Do not reset the clock when a SECOND device redeems"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_REDEEM_KEEP_EXPIRY' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r"UPDATE hotspot_vouchers SET status='active', used_by_mac=\$1, used_at=NOW\(\), expires_at=\$2,", s)
if not m:
    print("   NOTE: expiry update not matched — review manually"); sys.exit(0)
s = s[:m.start()] + ("/* RL_REDEEM_KEEP_EXPIRY: a second device redeeming the same code must not restart the\n"
                     "           clock — COALESCE keeps the expiry the first device already paid for. */\n           "
                     "UPDATE hotspot_vouchers SET status='active', used_by_mac=COALESCE(used_by_mac,$1), used_at=COALESCE(used_at,NOW()), expires_at=COALESCE(expires_at,$2),") + s[m.end():]
open(p,'w').write(s); print("   expiry preserved for additional devices")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js OK"

say "5) The two config columns the device page actually reads"
q -c "UPDATE nas_devices SET gateway_ip = hotspot_gateway WHERE hotspot_gateway IS NOT NULL AND gateway_ip IS DISTINCT FROM hotspot_gateway;" 2>&1
q -c "UPDATE nas_devices SET ip_pool_start = hotspot_pool_start, ip_pool_end = hotspot_pool_end
      WHERE hotspot_pool_start IS NOT NULL;" 2>&1
q -c "SELECT name, gateway_ip, ip_pool_start, ip_pool_end, hotspot_gateway FROM nas_devices;" 2>&1 | head -6
sudo python3 - "$BE/utils/nas-config-sync.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'gateway_ip' in s: print("   sync already covers gateway_ip"); sys.exit(0)
old = "    hotspot_profile: server.profile || null,"
new = ("    hotspot_profile: server.profile || null,\n"
       "    /* the device page reads these column names, not the hotspot_* ones */\n"
       "    gateway_ip: gateway,\n"
       "    ip_pool_start: ranges[0] || null,\n"
       "    ip_pool_end: ranges[1] || null,")
if old in s:
    s = s.replace(old, new, 1); open(p,'w').write(s); print("   sync now writes gateway_ip / ip_pool_*")
else: print("   NOTE: could not extend the sync automatically")
PY
cd "$BE" && sudo -u www-data node --check utils/nas-config-sync.js && echo "   nas-config-sync.js OK"

say "6) Restart + test the limit"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
CODE=$(q -tAc "SELECT hv.code FROM hotspot_vouchers hv JOIN hotspot_packages hp ON hp.id=hv.package_id
               WHERE hv.status='active' AND (hv.is_tv IS NOT TRUE) AND COALESCE(hp.simultaneous_sessions,1)>1
               ORDER BY hv.created_at DESC LIMIT 1;")
echo "   code=$CODE (allows >1 device)"
for M in 02:11:22:33:44:01 02:11:22:33:44:02 02:11:22:33:44:03; do
  S=$(curl -s -o /tmp/r.json -w "%{http_code}" -X POST "http://127.0.0.1:5000/api/captive/$ISP/redeem" \
      -H 'Content-Type: application/json' -d "{\"code\":\"$CODE\",\"mac\":\"$M\"}")
  echo "   $M -> HTTP $S  $(head -c 110 /tmp/r.json)"
done
q -c "SELECT d.mac FROM hotspot_voucher_devices d JOIN hotspot_vouchers v ON v.id=d.voucher_id WHERE v.code='$CODE';"
q -c "DELETE FROM hotspot_voucher_devices WHERE mac LIKE '02:11:22:33:44:%';"
q -c "DELETE FROM radcheck WHERE username LIKE '02:11:22:33:44:%';"
echo "   ${Y}expect 200, 200, 403${N}"

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Per-package device limit enforced in /redeem; second device keeps the original expiry" 2>&1 | head -2 | sed 's/^/   /'
