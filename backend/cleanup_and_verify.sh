#!/usr/bin/env bash
#
# cleanup_and_verify.sh
#  1. Remove my global fetch wrapper. classic.html:775 already shows json.error on a failed
#     redeem, so the wrapper is a SECOND owner of the same behaviour — the exact pattern behind
#     the two RADIUS writers, the duplicate walled-garden rules and the duplicate voucher forms.
#     It would also display the message twice.
#  2. Verify the whole device-limit path end to end.
#
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The portal already handles redeem errors (line ~775)"
sudo sed -n '766,780p' "$CP/classic.html" | nl -ba -v766 | sed 's/^/   /'

say "2) Remove the redundant global wrapper"
sudo cp "$CP/classic.html" "$CP/.classic.html.bak_$TS" && echo "   backed up"
sudo python3 - "$CP/classic.html" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
i = s.find('RL_REDEEM_ERRORS_GLOBAL')
if i == -1:
    print("   not present — nothing to remove"); sys.exit(0)
a = s.rfind('<script>', 0, i)
b = s.find('</script>', i)
if a == -1 or b == -1:
    print("   could not locate the block cleanly — left in place"); sys.exit(0)
s = s[:a] + s[b+len('</script>'):]
open(p,'w').write(s); print("   removed (classic.html:775 already does this)")
PY
sudo chown www-data:www-data "$CP/classic.html"
echo "   div balance: $(( $(grep -o '<div' "$CP/classic.html" | wc -l) - $(grep -o '</div>' "$CP/classic.html" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$CP/classic.html" | wc -l) / $(grep -o '</script>' "$CP/classic.html" | wc -l)"

say "3) End-to-end: a 1-device code and a 2-device code"
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
for LIMIT in 1 2; do
  CODE=$(q -tAc "SELECT hv.code FROM hotspot_vouchers hv JOIN hotspot_packages hp ON hp.id=hv.package_id
                 WHERE hv.status='active' AND (hv.is_tv IS NOT TRUE)
                   AND COALESCE(hp.simultaneous_sessions,1)=$LIMIT
                 ORDER BY hv.created_at DESC LIMIT 1;")
  [ -z "$CODE" ] && { echo "   (no active voucher with limit $LIMIT)"; continue; }
  echo "   --- code $CODE allows $LIMIT device(s) ---"
  for i in 1 2 3; do
    M="02:AA:BB:CC:0$LIMIT:0$i"
    S=$(curl -s -o /tmp/x.json -w "%{http_code}" -X POST "http://127.0.0.1:5000/api/captive/$ISP/redeem" \
        -H 'Content-Type: application/json' -d "{\"code\":\"$CODE\",\"mac\":\"$M\"}")
    echo "     device $i -> HTTP $S  $(head -c 95 /tmp/x.json)"
  done
  q -c "DELETE FROM hotspot_voucher_devices WHERE mac LIKE '02:AA:BB:CC:%';" >/dev/null
  q -c "DELETE FROM radcheck WHERE username LIKE '02:AA:BB:CC:%';" >/dev/null
done

say "4) Everything that keeps this true without you"
pm2 logs rumalink-backend --lines 200 --nostream 2>/dev/null \
  | grep -oE "\[(nas-config-sync|QUEUE-MONITOR|QUEUE-INTEGRITY|EXPIRED-ENFORCER|HEALTH|router-harden|strand-heal)\][^{]*" \
  | sort -u | sed 's/^/   /'
q -c "SELECT name, gateway_ip, ip_pool_start, ip_pool_end, hotspot_interface, wan_interface, hotspot_profile FROM nas_devices;"
q -c "SELECT name, simultaneous_sessions FROM hotspot_packages ORDER BY duration_hours;"

say "5) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Remove duplicate redeem-error handler; portal already surfaces the message" 2>&1 | head -2 | sed 's/^/   /'
sudo git -C /var/www/rumalink log --oneline | head -5 | sed 's/^/   /'
