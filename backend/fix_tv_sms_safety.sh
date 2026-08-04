#!/usr/bin/env bash
#
# fix_tv_sms_safety.sh — a TV buyer received phone login credentials.
#
# hotspotSms decides purely on v.is_tv. The payment metadata carries is_tv AND tv_mac correctly,
# but the voucher was left unmarked, so the phone template fired and sent a username and password
# for a television — credentials the buyer can use on any device. That is the wrong way for this
# to fail.
#
# FIX: treat the PAYMENT's is_tv as authoritative as well. Two independent signals, and the safe
# one wins: if either says television, the TV wording is sent and no credentials go out. Also
# backfill vouchers whose payment says TV so the rest of the system agrees.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Vouchers whose payment says TV but the voucher does not"
q -c "SELECT v.code, v.is_tv AS voucher_says, p.metadata->>'is_tv' AS payment_says,
             p.metadata->>'tv_mac' AS tv_mac, v.tv_mac AS voucher_mac,
             to_char(v.created_at,'MM-DD HH24:MI') AS made
      FROM hotspot_vouchers v JOIN payments p ON p.id = v.payment_id
      WHERE p.metadata->>'is_tv' = 'true' AND (v.is_tv IS NOT TRUE)
      ORDER BY v.created_at DESC LIMIT 10;"

say "2) Did tvBind run for those purchases?"
pm2 logs rumalink-backend --lines 800 --nostream 2>/dev/null \
  | grep -iE "tv-bind|CB-TV|TV bound|bindTvForPayment" | tail -10 | sed 's/^/   /' || echo "   ${Y}no tv-bind activity logged at all${N}"

say "3) The SMS decision as it stands"
sudo sed -n '55,75p' "$BE/utils/hotspotSms.js" | nl -ba -v55 | sed 's/^/   /'

say "4) Backup + make the payment's flag count too"
sudo cp "$BE/utils/hotspotSms.js" "$BE/utils/.hotspotSms.js.bak_$TS" && echo "   hotspotSms.js"
sudo python3 - "$BE/utils/hotspotSms.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_TV_SMS_FAILSAFE' in s:
    print("   already patched"); sys.exit(0)

# 1) bring the payment's metadata into the lookup
m = re.search(r'"SELECT v\.code, v\.password, v\.buyer_phone, v\.expires_at, v\.isp_id, v\.is_tv, v\.tv_mac, "', s)
if not m:
    print("   ERROR: voucher select not found"); sys.exit(1)
s = s[:m.start()] + '"SELECT v.code, v.password, v.buyer_phone, v.expires_at, v.isp_id, v.is_tv, v.tv_mac, p.metadata AS pay_meta, "' + s[m.end():]

# 2) decide on either signal
m2 = re.search(r'^([ \t]*)const lines = v\.is_tv', s, re.M)
if not m2:
    print("   ERROR: lines assignment not found"); sys.exit(1)
ind = m2.group(1)
guard = (
f"{ind}/* RL_TV_SMS_FAILSAFE: this decided purely on v.is_tv. When a voucher was left unmarked — the\n"
f"{ind}   payment metadata was correct, the voucher flag was not — the PHONE template fired and sent a\n"
f"{ind}   username and password for a television, which the buyer can then use on any device. The\n"
f"{ind}   payment's own is_tv is an independent signal for the same fact, so honour both and let the\n"
f"{ind}   safe answer win: if either says television, no credentials go out. */\n"
f"{ind}let _payMeta = v.pay_meta;\n"
f"{ind}try {{ if (typeof _payMeta === 'string') _payMeta = JSON.parse(_payMeta); }} catch (e) {{ _payMeta = null; }}\n"
f"{ind}const _isTv = !!(v.is_tv || (_payMeta && (_payMeta.is_tv === true || _payMeta.is_tv === 'true')));\n"
f"{ind}if (_isTv && !v.is_tv) {{\n"
f"{ind}  logger.warn('[purchase-sms] ' + v.code + ' was not marked as a TV but its payment is — sending TV wording and correcting the voucher');\n"
f"{ind}  try {{\n"
f"{ind}    await query(\"UPDATE hotspot_vouchers SET is_tv=true, tv_mac=COALESCE(tv_mac,$1) WHERE id=$2::uuid\",\n"
f"{ind}      [(_payMeta && _payMeta.tv_mac) || null, v.id]);\n"
f"{ind}  }} catch (e) {{ logger.warn('[purchase-sms] tv correction: ' + e.message); }}\n"
f"{ind}}}\n"
)
s = s[:m2.start()] + guard + s[m2.start():]
s = s.replace("const lines = v.is_tv", "const lines = _isTv", 1)
open(p,'w').write(s); print("   SMS now honours both signals")
PY
cd "$BE" && sudo -u www-data node --check utils/hotspotSms.js && echo "   hotspotSms.js OK"
echo "   does the query join payments? (needed for pay_meta):"
sudo grep -n "JOIN payments\|FROM hotspot_vouchers v" "$BE/utils/hotspotSms.js" | head -4 | sed 's/^/     /'

say "5) Correct the vouchers already mis-marked"
q -c "UPDATE hotspot_vouchers v
      SET is_tv = true,
          tv_mac = COALESCE(v.tv_mac, p.metadata->>'tv_mac'),
          used_by_mac = COALESCE(v.used_by_mac, p.metadata->>'tv_mac')
      FROM payments p
      WHERE p.id = v.payment_id AND p.metadata->>'is_tv' = 'true' AND (v.is_tv IS NOT TRUE);"
q -c "SELECT code, is_tv, tv_mac FROM hotspot_vouchers WHERE is_tv = true ORDER BY created_at DESC LIMIT 6;"

say "6) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 15 --nostream 2>/dev/null | grep -iE "purchase-sms|error" | tail -3 | sed 's/^/   /' || echo "   clean"

say "7) Test"
cat <<'EOS'
   Buy a TV package. The SMS must say the TV connects automatically and must NOT contain a
   username or password. Watch it decide:
     pm2 logs rumalink-backend | grep -iE "purchase-sms|tv-bind"
   A line saying a voucher "was not marked as a TV but its payment is" means the failsafe caught
   it — the message is still correct, but tvBind is not running and that is worth chasing.
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "TV purchases never send login credentials: SMS honours the payment's is_tv as well as the voucher's" 2>&1 | head -2 | sed 's/^/   /'
