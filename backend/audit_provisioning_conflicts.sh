#!/usr/bin/env bash
#
# audit_provisioning_conflicts.sh — does the provisioning script contain anything OLDER that
# would undo the fixes the guards enforce? Read-only apart from one cosmetic log-wording fix.
#
set -uo pipefail
BE=/var/www/rumalink/backend
SY=/usr/local/bin/rumalink-radius-clients-sync.sh
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
ok(){ echo "   ${G}OK  ${N} $*"; }
warn(){ echo "   ${Y}CHECK${N} $*"; }
bad(){ echo "   ${R}RISK${N} $*"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

TOKEN=$(q -tAc "SELECT provision_token FROM nas_devices WHERE provision_token IS NOT NULL ORDER BY created_at DESC LIMIT 1;")
curl -s "http://127.0.0.1:5000/api/provision/$TOKEN/script" > /tmp/prov.txt 2>/dev/null || true
echo "rendered $(wc -l < /tmp/prov.txt) lines"

say "1) Anything that RE-ADDS fasttrack (guards delete it every 2 min)"
grep -n "fasttrack" /tmp/prov.txt | grep -vE "^\s*[0-9]+:#" | sed 's/^/   /' || ok "no active fasttrack lines"
grep -q "action=fasttrack-connection" /tmp/prov.txt && bad "provisions a fasttrack rule" || ok "no fasttrack rule provisioned"
grep -nE "allow-fast-path|fast-path=yes" /tmp/prov.txt | sed 's/^/   /' || ok "does not enable IP fast-path"

say "2) NOFT rules (obsolete; router-harden deletes them)"
grep -n "NOFT" /tmp/prov.txt | sed 's/^/   /' || ok "no NOFT lines"
grep -q 'filter add.*RL-PPPOE-NOFT' /tmp/prov.txt && bad "still ADDS NOFT rules" || ok "no NOFT adds"

say "3) place-before usage (fragile ordering; RL_ACCEPT_ORDER exists because of this)"
grep -n "place-before" /tmp/prov.txt | sed 's/^/   /' || ok "no place-before anywhere"

say "4) The accept rule must be re-asserted LAST"
grep -n "RL-FASTTRACK accept" /tmp/prov.txt | sed 's/^/   /'
LAST=$(grep -n "ip firewall filter add chain=forward" /tmp/prov.txt | tail -1 | cut -d: -f1)
ACC=$(grep -n 'RL-FASTTRACK accept' /tmp/prov.txt | tail -1 | cut -d: -f1)
[ "$LAST" = "$ACC" ] && ok "accept is the last forward-chain add (line $ACC)" || bad "last forward add is line $LAST, accept is line $ACC"

say "5) Walled garden must REJECT, not drop"
grep -nE "rl-expired.*action=(drop|reject)" /tmp/prov.txt | sed 's/^/   /'
grep -qE "rl-expired.*action=drop" /tmp/prov.txt && bad "still uses silent drop" || ok "all expiry rules reject"

say "6) RADIUS settings the router is told to use"
grep -nE "/radius add|require-message-auth|secret=" /tmp/prov.txt | sed 's/^/   /'
grep -q "require-message-auth=no" /tmp/prov.txt && ok "router will not send Message-Authenticator (matches the server)" || bad "message-auth flag missing"

say "7) Hotspot profile — login-by and auth methods"
grep -nE "hotspot profile set|login-by|mac-auth-password|mac-cookie|http-chap" /tmp/prov.txt | sed 's/^/   /'
grep -q "http-chap" /tmp/prov.txt && bad "http-chap present (breaks MAC/CHAP auth on this platform)" || ok "no http-chap"
grep -q "mac-cookie" /tmp/prov.txt && warn "mac-cookie present — router-harden strips it; provisioning re-adds it" || ok "no mac-cookie"

say "8) Broad removals that could delete rules our guards manage"
grep -nE "filter remove \[find|nat remove \[find|queue simple remove|address-list remove" /tmp/prov.txt | sed 's/^/   /'
echo "   ${Y}each 'remove [find comment~\"...\"]' is safe only if the matching add follows it${N}"

say "9) Queue / rate-limit related lines"
grep -nE "queue type|queue simple|pcq|user profile set" /tmp/prov.txt | sed 's/^/   /' || ok "none"

say "10) Contradictions between provisioning and router-harden"
echo "   router-harden enforces:"
sudo grep -oE "RL_[A-Z_]+" "$BE/utils/router-harden.js" | sort -u | sed 's/^/     /'
echo "   provisioning asserts:"
grep -oE "RL_[A-Z_]+|RL-[A-Z-]+" /tmp/prov.txt | sort -u | sed 's/^/     /'

say "11) Does provisioning touch anything the guards also write?"
for pat in "ip-binding" "hotspot user add" "queue/simple" "radius add" "firewall filter add chain=forward"; do
  C=$(grep -c "$pat" /tmp/prov.txt || true)
  printf "   %-38s %s line(s) in provisioning\n" "$pat" "$C"
done

say "12) Cosmetic: the sync script still logs 'reloaded' after we changed it to restart"
sudo grep -n "FreeRADIUS reloaded" "$SY" | sed 's/^/   /'
sudo sed -i 's/clients-rumalink.conf updated, FreeRADIUS reloaded/clients-rumalink.conf updated, FreeRADIUS RESTARTED (client list changed)/' "$SY"
sudo bash -n "$SY" && echo "   wording corrected + syntax OK"

say "13) Full forward-chain section of the script, in order"
grep -n "ip firewall filter add chain=forward" /tmp/prov.txt | sed 's/^/   /'
