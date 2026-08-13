#!/usr/bin/env bash
#
# fix_winbox_provisioning.sh — remote access for every router, not just the one set up by hand.
#
# THREE GAPS, all invisible until someone tries to connect:
#
#  1. winbox_port DEFAULTS to 8291 — the router's own port, not a forwarding port on this server.
#     Every device would claim the same one, and 8291 is outside the 20001-20050 range the Lightsail
#     firewall opens. DandoraLivePhase3 works only because 20001 was assigned by hand.
#
#  2. Nothing runs the forwarding script after provisioning. rumalink-winbox.service is oneshot at
#     boot, so a router provisioned this afternoon has no forwarding until the server next restarts.
#
#  3. Nothing re-asserts the rules. The MASQUERADE line went missing from the live table while the
#     DNAT stayed — remote access broke silently and stayed broken, because only a reboot would
#     have put it back. That is what we spent this hour chasing.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Ports as they stand"
q -c "SELECT name, winbox_port, wireguard_ip, remote_winbox_url FROM nas_devices ORDER BY created_at;"

say "2) Stop defaulting to the router's own port"
q -c "ALTER TABLE nas_devices ALTER COLUMN winbox_port DROP DEFAULT;"
echo "   ${Y}8291 is the port ON the router; this column is the port on THIS server that forwards to it${N}"

say "3) Allocate a real port when a device is created"
sudo cp "$BE/routes/nas.js" "$BE/routes/.nas.js.bak_$TS" && echo "   nas.js backed up"
sudo python3 - "$BE/routes/nas.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_WINBOX_ALLOC' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)(const|let|var)?\s*\w*\s*=?\s*await query\(\s*`\s*\n?\s*INSERT INTO nas_devices', s, re.M)
if not m:
    m = re.search(r'^([ \t]*)[^\n]*INSERT INTO nas_devices', s, re.M)
if not m:
    print("   ERROR: insert not found"); sys.exit(1)
ind = m.group(1)
blk = (
f"{ind}/* RL_WINBOX_ALLOC: winbox_port used to default to 8291 — the port on the ROUTER, not a\n"
f"{ind}   forwarding port on this server. Every device claimed the same number and none of them fell\n"
f"{ind}   inside the 20001-20050 range the firewall opens, so remote access only ever worked where\n"
f"{ind}   somebody assigned a port by hand. Take the next free one at creation. */\n"
f"{ind}let _winboxPort = null;\n"
f"{ind}try {{\n"
f"{ind}  const _used = (await query('SELECT winbox_port FROM nas_devices WHERE winbox_port IS NOT NULL')).rows\n"
f"{ind}    .map(function (r) {{ return parseInt(r.winbox_port, 10); }}).filter(function (n) {{ return n >= 20001 && n <= 20050; }});\n"
f"{ind}  for (let _p = 20001; _p <= 20050; _p++) {{\n"
f"{ind}    if (_used.indexOf(_p) === -1) {{ _winboxPort = _p; break; }}\n"
f"{ind}  }}\n"
f"{ind}  if (!_winboxPort) require('../utils/logger').warn('[nas] no free WinBox port in 20001-20050 — remote access unavailable for this device');\n"
f"{ind}}} catch (e) {{ require('../utils/logger').warn('[nas] winbox port: ' + e.message); }}\n\n"
)
s = s[:m.start()] + blk + s[m.start():]

mi = re.search(r'INSERT INTO nas_devices \(([^)]*)\)\s*\n?\s*VALUES\s*\(([^)]*)\)', s, re.S)
if mi and 'winbox_port' not in mi.group(1):
    nums = [int(x) for x in re.findall(r'\$(\d+)', mi.group(2))]
    nxt = (max(nums) + 1) if nums else 1
    s = s[:mi.start(1)] + mi.group(1).rstrip() + ", winbox_port" + s[mi.end(1):]
    mi2 = re.search(r'INSERT INTO nas_devices \(([^)]*)\)\s*\n?\s*VALUES\s*\(([^)]*)\)', s, re.S)
    s = s[:mi2.start(2)] + mi2.group(2).rstrip() + f", ${nxt}" + s[mi2.end(2):]
    print(f"   INSERT takes winbox_port as ${nxt} — append _winboxPort to its params array")
open(p,'w').write(s); print("   allocation added")
PY
cd "$BE" && sudo -u www-data node --check routes/nas.js && echo "   nas.js OK"
grep -n "INSERT INTO nas_devices" -A 6 "$BE/routes/nas.js" | head -12 | sed 's/^/   /'

say "4) Apply the forwards after provisioning, and keep them applied"
sudo tee /usr/local/bin/rumalink-winbox-guard.sh > /dev/null <<'SH'
#!/usr/bin/env bash
# RL_WINBOX_GUARD: re-runs the forwarding script every two minutes.
# The DNAT rule survived while its MASQUERADE partner went missing, so packets reached the router
# and its replies went out the router's own WAN instead of back down the tunnel — remote access
# was dead with every rule LOOKING present. Only a reboot would have restored it. The script is
# idempotent, so re-running costs nothing and a lost rule heals itself within two minutes.
exec /usr/local/bin/rumalink-winbox.sh
SH
sudo chmod +x /usr/local/bin/rumalink-winbox-guard.sh
sudo tee /etc/systemd/system/rumalink-winbox-guard.timer > /dev/null <<'SH'
[Unit]
Description=Re-assert RumaLink WinBox forwards
[Timer]
OnBootSec=90
OnUnitActiveSec=120
[Install]
WantedBy=timers.target
SH
sudo tee /etc/systemd/system/rumalink-winbox-guard.service > /dev/null <<'SH'
[Unit]
Description=Re-assert RumaLink WinBox forwards
After=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/rumalink-winbox-guard.sh
SH
sudo systemctl daemon-reload
sudo systemctl enable --now rumalink-winbox-guard.timer >/dev/null 2>&1
systemctl status rumalink-winbox-guard.timer --no-pager 2>/dev/null | head -4 | sed 's/^/   /'

say "5) And immediately when a device finishes provisioning"
sudo cp "$BE/routes/provision.js" "$BE/routes/.provision.js.bak_$TS"
sudo python3 - "$BE/routes/provision.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_WINBOX_AFTER_PROV' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)/\* RL_SYNC_AFTER_PROVISION', s, re.M)
if not m:
    m = re.search(r'^([ \t]*)triggerRadiusClientsSync\(\);\s*$', s, re.M)
if not m:
    print("   ERROR: anchor not found"); sys.exit(1)
ind = m.group(1)
blk = (f"{ind}/* RL_WINBOX_AFTER_PROV: the forwarding service is oneshot at boot, so a router provisioned\n"
       f"{ind}   today had no remote access until the server next restarted — with nothing to say why. */\n"
       f"{ind}try {{\n"
       f"{ind}  require('child_process').execFile('sudo', ['/usr/local/bin/rumalink-winbox.sh'], function (e) {{\n"
       f"{ind}    if (e) require('../utils/logger').warn('[provision] winbox forwards: ' + e.message);\n"
       f"{ind}    else require('../utils/logger').info('[provision] WinBox forwards applied');\n"
       f"{ind}  }});\n"
       f"{ind}}} catch (e) {{}}\n\n")
s = s[:m.start()] + blk + s[m.start():]
open(p,'w').write(s); print("   provisioning now applies the forwards")
PY
cd "$BE" && sudo -u www-data node --check routes/provision.js && echo "   provision.js OK"
echo "   www-data needs to run that script without a password:"
echo "www-data ALL=(root) NOPASSWD: /usr/local/bin/rumalink-winbox.sh" | sudo tee /etc/sudoers.d/rumalink-winbox >/dev/null
sudo chmod 440 /etc/sudoers.d/rumalink-winbox
sudo visudo -c 2>&1 | tail -2 | sed 's/^/   /'

say "6) Fix the existing device and verify"
q -c "UPDATE nas_devices SET winbox_port = 20001 WHERE winbox_port = 8291 OR winbox_port IS NULL RETURNING name, winbox_port;"
sudo /usr/local/bin/rumalink-winbox.sh
sudo iptables -t nat -L RL_WINBOX -n -v 2>/dev/null | sed 's/^/   /' || sudo iptables -t nat -L PREROUTING -n -v | grep -E "2000[0-9]" | sed 's/^/   /'
sudo iptables -t nat -L POSTROUTING -n -v | grep -E "8291" | sed 's/^/   /'
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1

say "7) What this changes"
cat <<'EOS'
   A new router now gets a free port from 20001-20050 at creation, its forwards are applied as soon
   as provisioning finishes, and a timer re-asserts every rule every two minutes — so a rule that
   goes missing heals itself instead of quietly disabling remote access until the next reboot.

   The range is 50 devices. Beyond that the log says so rather than failing silently, and the
   Lightsail firewall rule would need widening to match.
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "WinBox forwards: allocate a real port per device, apply after provisioning, re-assert on a timer" 2>&1 | head -2 | sed 's/^/   /'
