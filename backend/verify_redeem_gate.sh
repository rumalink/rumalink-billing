#!/usr/bin/env bash
# verify_redeem_gate.sh — finish the two loose ends, then test redeem with real MACs.
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Where is the remaining hardcoded gateway?"
sudo grep -n "192.168.88" "$CP/classic.html" | sed 's/^/   /'
LN=$(sudo grep -n "192.168.88" "$CP/classic.html" | head -1 | cut -d: -f1)
[ -n "$LN" ] && sudo sed -n "$((LN-12)),$((LN+8))p" "$CP/classic.html" | nl -ba -v"$((LN-12))" | sed 's/^/   /'

say "2) Does the redeem device-limit gate exist, and in what form?"
sudo grep -n "RL_REDEEM_MULTIDEVICE\|RL_VOUCHER_LOGIN\|hotspot_voucher_devices" "$BE/routes/captive.js" | sed 's/^/   /'
echo "   --- the gate itself ---"
LG=$(sudo grep -n "RL_REDEEM_MULTIDEVICE" "$BE/routes/captive.js" | head -1 | cut -d: -f1)
[ -n "$LG" ] && sudo sed -n "$((LG-6)),$((LG+26))p" "$BE/routes/captive.js" | nl -ba -v"$((LG-6))" | sed 's/^/   /'

say "3) The /redeem route's own MAC handling (what it does BEFORE my gate)"
L=$(grep -n "router.post('/:ispId/redeem'" "$BE/routes/captive.js" | head -1 | cut -d: -f1)
END=$(awk -v s="$L" 'NR>s && /^\}\);$/ {print NR; exit}' "$BE/routes/captive.js")
echo "   route $L..$END — every mac / used_by_mac / rejection line:"
sudo sed -n "${L},${END}p" "$BE/routes/captive.js" | grep -nE "mac|res\.status|return res" | sed 's/^/     /' | cut -c1-140

say "4) LIVE: two real-looking MACs on a 2-device voucher"
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
CODE=$(q -tAc "SELECT hv.code FROM hotspot_vouchers hv JOIN hotspot_packages hp ON hp.id=hv.package_id
               WHERE hv.status='active' AND (hv.is_tv IS NOT TRUE) AND COALESCE(hp.simultaneous_sessions,1)>1
               ORDER BY hv.created_at DESC LIMIT 1;")
echo "   isp=$ISP  code=${CODE:-none (no multi-device voucher active)}"
if [ -n "$CODE" ]; then
  q -c "SELECT hv.code, COALESCE(hp.simultaneous_sessions,1) AS allowed,
               (SELECT count(*) FROM hotspot_voucher_devices d WHERE d.voucher_id=hv.id) AS registered
        FROM hotspot_vouchers hv JOIN hotspot_packages hp ON hp.id=hv.package_id WHERE hv.code='$CODE';"
  for M in 02:11:22:33:44:01 02:11:22:33:44:02 02:11:22:33:44:03; do
    S=$(curl -s -o /tmp/rr.json -w "%{http_code}" -X POST "http://127.0.0.1:5000/api/captive/$ISP/redeem" \
        -H 'Content-Type: application/json' -d "{\"code\":\"$CODE\",\"mac\":\"$M\"}")
    echo "   $M -> HTTP $S  $(head -c 130 /tmp/rr.json)"
  done
  echo "   devices now registered:"
  q -c "SELECT d.mac FROM hotspot_voucher_devices d JOIN hotspot_vouchers v ON v.id=d.voucher_id WHERE v.code='$CODE';"
  q -c "DELETE FROM hotspot_voucher_devices WHERE mac LIKE '02:11:22:33:44:%';"
  q -c "DELETE FROM radcheck WHERE username LIKE '02:11:22:33:44:%';"
  q -c "DELETE FROM radreply WHERE username LIKE '02:11:22:33:44:%';"
fi

say "5) An empty MAC must not be treated as a device"
if [ -n "$CODE" ]; then
  S=$(curl -s -o /tmp/re.json -w "%{http_code}" -X POST "http://127.0.0.1:5000/api/captive/$ISP/redeem" \
      -H 'Content-Type: application/json' -d "{\"code\":\"$CODE\",\"mac\":\"\"}")
  echo "   empty mac -> HTTP $S  $(head -c 130 /tmp/re.json)"
  q -c "SELECT count(*) AS blank_rows FROM hotspot_voucher_devices WHERE COALESCE(mac,'')='' OR UPPER(mac)='UNKNOWN';"
fi

say "6) Recent redeem log lines"
pm2 logs rumalink-backend --lines 120 --nostream 2>/dev/null | grep -iE "redeem|device limit" | tail -8 | cut -c1-150 | sed 's/^/   /'
