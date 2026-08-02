#!/usr/bin/env bash
# READ ONLY — assess what changed, what still works, and which backups are available.
# Changes NOTHING. Safe to run.
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Is the service even running?"
(sudo pm2 list 2>/dev/null || pm2 list) | grep -E "rumalink|status" | sed 's/^/   /'
echo "   recent errors:"
pm2 logs rumalink-backend --lines 60 --nostream 2>/dev/null | grep -iE "error|cannot|undefined|throw" | tail -12 | sed 's/^/     /' || echo "     (none)"

say "2) Which key files were modified TODAY, and when?"
for f in routes/captive.js routes/isp.js routes/provision.js utils/strand-heal.js \
         utils/hotspotSms.js utils/sms.js utils/router-harden.js utils/fasttrack-guard.js \
         utils/expired-enforcer.js utils/queue-monitor.js utils/health-monitor.js server.js; do
  [ -f "$BE/$f" ] && printf "   %-34s %s\n" "$f" "$(stat -c '%y' "$BE/$f" | cut -d'.' -f1)"
done

say "3) Do OUR markers still exist? (absent = that fix was overwritten)"
check(){ # marker file label
  local n; n=$(sudo grep -c "$1" "$BE/$2" 2>/dev/null || echo 0)
  if [ "$n" -gt 0 ]; then echo "   ${G}PRESENT${N} $3 ($n)"; else echo "   ${R}MISSING${N} $3"; fi
}
check "RL_REUSE_BY_DEVICE"        routes/captive.js      "device-keyed voucher reuse (captive)"
check "RL_PURCHASED_BY_MAC"       routes/captive.js      "purchased_by_mac (captive)"
check "RL_ONE_VOUCHER_PER_PURCHASE" routes/captive.js    "duplicate-voucher guards"
check "RL_STORE_CLIENT_MAC"       routes/captive.js      "client MAC stamped on payment"
check "RL_PREFIX_PRESERVE"        routes/captive.js      "collision retry keeps prefix"
check "RL_UPGRADE_RETRY"          routes/captive.js      "upgrade-path retry"
check "RL_REUSE_BY_DEVICE"        utils/strand-heal.js   "device-keyed reuse (strand-heal)"
check "RL_ALREADY_FULFILLED"      utils/strand-heal.js   "no re-heal of served payments"
check "RL_PREFIX_FROM_ISP"        utils/strand-heal.js   "ISP prefix derivation"
check "RL_TOPUP_EXPIRY"           utils/strand-heal.js   "top-up expiry"
check "RL_IMPORT_PREFIX"          routes/isp.js          "dynamic import prefix"
check "RL_DEFAULT_GATEWAY"        utils/sms.js           "SMS default gateway"
check "RL_SMS_PICK_REAL"          utils/hotspotSms.js    "SMS picks the active voucher"
check "RL_NO_FASTTRACK"           utils/router-harden.js "fasttrack deleted by harden"
check "RL_NO_FASTTRACK"           routes/provision.js    "no fasttrack in provisioning"
check "RL_ACCEPT_LAST"            routes/provision.js    "accept rule ordered last"
check "RL_SECRET_CONVERGE"        routes/provision.js    "RADIUS secret convergence"
echo "   modules:"
for m in fasttrack-guard expired-enforcer queue-monitor health-monitor; do
  [ -f "$BE/utils/$m.js" ] && echo "   ${G}PRESENT${N} utils/$m.js" || echo "   ${R}MISSING${N} utils/$m.js"
done

say "4) Available backups (newest first, per file)"
for f in captive.js isp.js provision.js; do
  echo "   --- routes/$f ---"
  sudo ls -1t "$BE/routes/".$f.bak_* 2>/dev/null | head -6 | while read b; do
    printf "     %s  %s\n" "$(stat -c '%y' "$b" | cut -d'.' -f1)" "$(basename "$b")"
  done
done
for f in strand-heal.js hotspotSms.js sms.js router-harden.js; do
  echo "   --- utils/$f ---"
  sudo ls -1t "$BE/utils/".$f.bak_* 2>/dev/null | head -6 | while read b; do
    printf "     %s  %s\n" "$(stat -c '%y' "$b" | cut -d'.' -f1)" "$(basename "$b")"
  done
done

say "5) Captive portal files — modified recently?"
sudo ls -la --time-style=long-iso /var/www/rumalink/captive/*.html 2>/dev/null | sed 's/^/   /'
echo "   backups of the portal:"
sudo ls -1t /var/www/rumalink/captive/.*.bak* /var/www/rumalink/captive/*.bak* 2>/dev/null | head -10 | sed 's/^/     /' || echo "     (none found)"

say "6) Payment-method config — what the portal should be reading"
q -c "SELECT * FROM payment_provider_configs;" 2>&1 | head -20
q -c "SELECT company_name, payment_gateway FROM isps;" 2>&1
echo "   endpoint the portal calls:"
grep -rn "payment-methods" "$BE/routes/"*.js 2>/dev/null | grep -v bak | head -5 | sed 's/^/     /'

say "7) Data intact? (the important part — this is what cannot be restored from backups)"
for t in isps nas_devices hotspot_vouchers hotspot_packages payments pppoe_subscribers hotspot_bound_devices; do
  printf "   %-24s %s\n" "$t" "$(q -tAc "SELECT count(*) FROM $t;" 2>/dev/null || echo 'ERROR')"
done

say "8) Live service checks"
q -c "SELECT code, is_tv, status FROM hotspot_vouchers ORDER BY created_at DESC LIMIT 5;"
sudo -u postgres psql -d rumalink_db -tAc "SELECT username, reply, authdate FROM radpostauth ORDER BY authdate DESC LIMIT 3;" 2>/dev/null | sed 's/^/   radius: /'
curl -sk -o /dev/null -w "   portal HTTP %{http_code}\n" "https://rumalinkenterprise.online/captive/classic.html" || true
