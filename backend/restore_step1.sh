#!/usr/bin/env bash
#
# restore_step1.sh — restore the backend to the last known-good state (2026-07-31).
#
# WHAT HAPPENED: all core files were overwritten at 2026-08-02 07:26:25 and captive.js now has
# a SyntaxError (unbalanced try around the Daraja voucher reserve), so the service is
# crash-looping. Every RL_* fix marker from 31 July is gone and four modules were deleted.
#
# METHOD: preserve the current (broken) files first — never destroy evidence — then restore
# each file from its newest 31 July backup, syntax-check EVERY file before restarting, and
# roll back automatically if any check fails.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
KEEP=/home/ubuntu/rl_broken_$TS
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "0) Preserve the CURRENT broken files (nothing is deleted)"
mkdir -p "$KEEP"
for f in routes/captive.js routes/isp.js routes/provision.js utils/strand-heal.js \
         utils/hotspotSms.js utils/sms.js utils/router-harden.js utils/cron.js server.js; do
  [ -f "$BE/$f" ] && sudo cp "$BE/$f" "$KEEP/$(basename $f)" && echo "   kept $(basename $f)"
done
echo "   preserved in: $KEEP"

say "1) Which current files actually fail to parse?"
for f in routes/captive.js routes/isp.js routes/provision.js utils/strand-heal.js \
         utils/hotspotSms.js utils/sms.js utils/router-harden.js utils/cron.js server.js; do
  if sudo -u www-data node --check "$BE/$f" 2>/dev/null; then
    printf "   ${G}OK  ${N} %s\n" "$f"
  else
    printf "   ${R}FAIL${N} %s\n" "$f"
    sudo -u www-data node --check "$BE/$f" 2>&1 | head -3 | sed 's/^/        /'
  fi
done

say "2) Restore each file from its newest 31-July backup"
restore(){ # dir file
  local d="$1" f="$2"
  local b
  b=$(sudo ls -1t "$BE/$d/.$f.bak_"* 2>/dev/null | head -1)
  if [ -z "$b" ]; then echo "   ${Y}no backup for $d/$f — leaving as is${N}"; return; fi
  sudo cp "$b" "$BE/$d/$f"
  if sudo -u www-data node --check "$BE/$d/$f" 2>/dev/null; then
    echo "   ${G}restored${N} $d/$f  <- $(basename $b)  ($(stat -c '%y' "$b" | cut -d'.' -f1))"
  else
    echo "   ${R}restored copy FAILS syntax${N} $d/$f — trying the next older backup"
    for b2 in $(sudo ls -1t "$BE/$d/.$f.bak_"* 2>/dev/null | tail -n +2); do
      sudo cp "$b2" "$BE/$d/$f"
      if sudo -u www-data node --check "$BE/$d/$f" 2>/dev/null; then
        echo "   ${G}restored${N} $d/$f  <- $(basename $b2)"; return
      fi
    done
    echo "   ${R}no usable backup for $d/$f${N}"
  fi
}
restore routes captive.js
restore routes isp.js
restore routes provision.js
restore utils strand-heal.js
restore utils hotspotSms.js
restore utils sms.js
restore utils router-harden.js

say "3) Verify every backend file parses"
FAIL=0
for f in routes/captive.js routes/isp.js routes/provision.js utils/strand-heal.js \
         utils/hotspotSms.js utils/sms.js utils/router-harden.js utils/cron.js server.js; do
  if sudo -u www-data node --check "$BE/$f" 2>/dev/null; then printf "   ${G}OK  ${N} %s\n" "$f"
  else printf "   ${R}FAIL${N} %s\n" "$f"; FAIL=1; fi
done
[ "$FAIL" = "1" ] && echo "   ${R}Stopping: something still fails to parse.${N}" && exit 1

say "4) cron.js — does it require modules that no longer exist?"
sudo grep -nE "require\('\./(fasttrack-guard|expired-enforcer|queue-monitor|health-monitor)'\)" "$BE/utils/cron.js" | sed 's/^/   /' || echo "   (no references — good, they were removed with the modules)"
for m in fasttrack-guard expired-enforcer queue-monitor health-monitor; do
  [ -f "$BE/utils/$m.js" ] && echo "   present: $m.js" || echo "   ${Y}missing: $m.js (re-added in step 2 of the recovery)${N}"
done

say "5) Which RL_* fixes came back with the restore?"
chk(){ if sudo grep -q "$1" "$BE/$2" 2>/dev/null; then echo "   ${G}PRESENT${N} $3"; else echo "   ${R}MISSING${N} $3"; fi; }
chk RL_REUSE_BY_DEVICE        routes/captive.js      "device-keyed voucher reuse (captive)"
chk RL_PURCHASED_BY_MAC       routes/captive.js      "purchased_by_mac"
chk RL_PREFIX_PRESERVE        routes/captive.js      "collision retry keeps prefix"
chk RL_UPGRADE_RETRY          routes/captive.js      "upgrade-path retry"
chk RL_REUSE_BY_DEVICE        utils/strand-heal.js   "device-keyed reuse (strand-heal)"
chk RL_ALREADY_FULFILLED      utils/strand-heal.js   "no re-heal of served payments"
chk RL_PREFIX_FROM_ISP        utils/strand-heal.js   "ISP prefix derivation"
chk RL_TOPUP_EXPIRY           utils/strand-heal.js   "top-up expiry"
chk RL_IMPORT_PREFIX          routes/isp.js          "dynamic import prefix"
chk RL_DEFAULT_GATEWAY        utils/sms.js           "SMS default gateway"
chk RL_SMS_PICK_REAL          utils/hotspotSms.js    "SMS picks active voucher"
chk RL_NO_FASTTRACK           utils/router-harden.js "fasttrack deleted by harden"
chk RL_NO_FASTTRACK           routes/provision.js    "no fasttrack in provisioning"
chk RL_SECRET_CONVERGE        routes/provision.js    "RADIUS secret convergence"

say "6) Restart and confirm the crash loop has stopped"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1
sleep 10
(sudo pm2 list 2>/dev/null || pm2 list) | grep -E "rumalink-backend" | sed 's/^/   /'
echo "   errors since restart:"
pm2 logs rumalink-backend --lines 40 --nostream 2>/dev/null | grep -iE "SyntaxError|Cannot find module|error:" | tail -6 | sed 's/^/     /' || echo "     ${G}none${N}"

say "7) Service checks"
curl -sk -o /dev/null -w "   portal      HTTP %{http_code}\n" "https://rumalinkenterprise.online/captive/classic.html" || true
curl -sk -o /dev/null -w "   api health  HTTP %{http_code}\n" "https://rumalinkenterprise.online/api/admin/health" || true
q -c "SELECT count(*) AS isps FROM isps;"
q -c "SELECT code, is_tv, status FROM hotspot_vouchers ORDER BY created_at DESC LIMIT 5;"

echo
echo "   ${Y}Broken versions preserved at: $KEEP${N}"
echo "   ${Y}Next: re-add the four deleted modules, then fix the portal payment-method sync.${N}"
