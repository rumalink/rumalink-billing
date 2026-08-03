#!/usr/bin/env bash
#
# fix_freeradius_autorestart.sh — stop needing a manual `systemctl restart freeradius`
# after a production reset + re-provision.
#
# CAUSE: mods-enabled/sql has read_clients = yes, so FreeRADIUS loads the RADIUS client list
# from the radius_nas_clients view AT STARTUP ONLY. The per-minute sync regenerates
# clients-rumalink.conf and issues `systemctl reload`, but a reload (SIGHUP) re-reads config
# files without re-instantiating the SQL client list — so a newly provisioned router with a new
# secret stays unknown, its Access-Requests are silently discarded, and nobody can log in until
# a full restart.
#
# FIX: restart instead of reload, but ONLY on the path that already fires when the client list
# genuinely changed (a router added/changed/removed). That is rare, so this does not bring back
# the SIGHUP memory leak — that came from reloading 1,440 times a day on an unchanged file.
#
set -uo pipefail
BE=/var/www/rumalink/backend
SY=/usr/local/bin/rumalink-radius-clients-sync.sh
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Confirm the cause"
sudo grep -n "read_clients" /etc/freeradius/3.0/mods-enabled/sql | sed 's/^/   /'
echo "   the sync script's reload line:"
sudo grep -n "systemctl reload\|systemctl restart" "$SY" | sed 's/^/     /'
echo "   how often it actually fires (reload events per hour, recent):"
grep 'reloaded' /var/log/rumalink-clients-sync.log 2>/dev/null | tail -3 | sed 's/^/     /' || echo "     (none recently — the comment-ignoring compare is working)"

say "2) Does provisioning trigger the sync immediately?"
sudo grep -n "triggerRadiusClientsSync" "$BE/routes/provision.js" | head -5 | sed 's/^/   /'
L=$(sudo grep -n "function triggerRadiusClientsSync" "$BE/routes/provision.js" | head -1 | cut -d: -f1)
[ -n "$L" ] && sudo sed -n "${L},$((L+12))p" "$BE/routes/provision.js" | nl -ba -v"$L" | sed 's/^/     /'

say "3) Backup + switch reload -> restart on the change path"
sudo cp "$SY" "/usr/local/bin/.rumalink-radius-clients-sync.sh.bak_$TS" && echo "   backed up"
sudo python3 - "$SY" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_RESTART_ON_CLIENT_CHANGE' in s:
    print("   already patched"); sys.exit(0)
old = "systemctl reload freeradius"
if old not in s:
    print("   ERROR: reload line not found — unchanged"); sys.exit(1)
new = ("# RL_RESTART_ON_CLIENT_CHANGE: a reload (SIGHUP) re-reads config files but does NOT\n"
       "# re-instantiate the SQL client list that read_clients=yes loads at startup. After a\n"
       "# production reset and re-provision the new router therefore stayed unknown and every\n"
       "# Access-Request was silently discarded until someone ran `systemctl restart freeradius`\n"
       "# by hand. Restart instead. This runs ONLY when the client list actually changed, so it\n"
       "# does not reintroduce the per-minute SIGHUP that leaked ~1MB a time.\n"
       "systemctl restart freeradius")
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   sync script now restarts FreeRADIUS when the client list changes")
PY
sudo bash -n "$SY" && echo "   sync script syntax OK"

say "4) Make provisioning trigger the sync at once (no 60s wait)"
sudo cp "$BE/routes/provision.js" "$BE/routes/.provision.js.bak_$TS"
sudo python3 - "$BE/routes/provision.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
m = re.search(r'function triggerRadiusClientsSync\(\)\s*\{(.*?)\n\}', s, re.S)
if not m:
    print("   triggerRadiusClientsSync not found — skipping"); sys.exit(0)
body = m.group(1)
if 'rumalink-radius-clients-sync.sh' in body:
    print("   already runs the sync script"); sys.exit(0)
if 'RL_SYNC_NOW' in s:
    print("   already patched"); sys.exit(0)
new_body = ("""
  /* RL_SYNC_NOW: regenerate the RADIUS client list immediately on provision instead of waiting
     for the per-minute cron. The script restarts FreeRADIUS only when the list actually changed,
     so a freshly provisioned router can authenticate within seconds rather than after a manual
     `systemctl restart freeradius`. */
  try {
    require('child_process').exec('/usr/local/bin/rumalink-radius-clients-sync.sh', { timeout: 30000 },
      function (err) { if (err) require('../utils/logger').warn('[provision] clients-sync: ' + err.message); });
  } catch (e) {}""" + body)
s = s[:m.start(1)] + new_body + s[m.end(1):]
open(p,'w').write(s); print("   provisioning now runs the client sync immediately")
PY
cd "$BE" && sudo -u www-data node --check routes/provision.js && echo "   provision.js syntax OK"

say "5) Can the backend run the sync script? (it runs as root under PM2)"
ls -la "$SY" | sed 's/^/   /'
sudo -u www-data test -x "$SY" && echo "   www-data can execute it" || echo "   ${Y}www-data cannot execute it — PM2 runs as root, so this is fine${N}"
ps -eo user,cmd | grep "[P]M2\|[n]ode.*server.js" | head -2 | awk '{print "   backend runs as: "$1}'

say "6) Test the whole path: force a client change and watch FreeRADIUS restart"
BEFORE=$(systemctl show freeradius -p ActiveEnterTimestamp --value)
echo "   freeradius started at: $BEFORE"
sudo -u postgres psql -d rumalink_db -qtAc "UPDATE nas_devices SET name = name;" >/dev/null 2>&1
sudo touch -d '2000-01-01' /etc/freeradius/3.0/clients-rumalink.conf 2>/dev/null || true
sudo rm -f /etc/freeradius/3.0/clients-rumalink.conf
sudo "$SY" 2>&1 | tail -3 | sed 's/^/   /'
sleep 5
AFTER=$(systemctl show freeradius -p ActiveEnterTimestamp --value)
echo "   freeradius started at: $AFTER"
[ "$BEFORE" != "$AFTER" ] && echo "   ${G}RESTARTED automatically${N}" || echo "   ${Y}no restart — check the change-detection logic${N}"
systemctl is-active freeradius | sed 's/^/   freeradius: /'
sudo cat /etc/freeradius/3.0/clients-rumalink.conf | sed 's/^/     /'

say "7) Prove authentication still works"
USR=$(q -tAc "SELECT username FROM radcheck WHERE username LIKE '%@%' ORDER BY id DESC LIMIT 1;")
PW=$(q -tAc "SELECT value FROM radcheck WHERE username LIKE '%@%' ORDER BY id DESC LIMIT 1;")
LOCALSEC=$(sudo grep -A3 'client localhost' /etc/freeradius/3.0/clients.conf 2>/dev/null | grep -oP '(?<=secret\s=\s).*' | tr -d '"' | head -1)
if [ -n "$USR" ]; then
  printf "User-Name = %s\nUser-Password = %s\n" "$USR" "$PW" \
    | sudo radclient -x 127.0.0.1:1812 auth "${LOCALSEC:-testing123}" 2>&1 | grep -iE "Access-Accept|Access-Reject|no response" | sed 's/^/   /'
else echo "   (no realmed voucher to test with — buy a package and retry)"; fi
q -c "SELECT username, reply, authdate FROM radpostauth ORDER BY authdate DESC LIMIT 3;"

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "FreeRADIUS restarts automatically when the client list changes (no manual restart after re-provision)" 2>&1 | head -2 | sed 's/^/   /'
