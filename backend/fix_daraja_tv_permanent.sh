#!/usr/bin/env bash
#
# fix_daraja_tv_permanent.sh — a TV purchase must bind the TV and never connect the buyer's phone.
#
# CAUSE (two layers):
#  1. The Daraja callback has NO TV handling — no is_tv/tv_mac, no ip-binding bypass, no queue,
#     no hotspot_bound_devices link. IntaSend does all of it in RL_TV_BIND. So on Daraja the TV
#     sale was treated as an ordinary hotspot sale.
#  2. The portal autologins whenever payment-status returns credentials (classic.html:700), with
#     no notion of whether the purchase was for a TV — so the phone gets connected.
#
# FIX:
#  A. utils/tvBind.js — ONE implementation of TV binding, used by both gateways. Duplicated
#     logic across payment paths is what let these two drift apart in the first place.
#  B. Daraja callback calls it.
#  C. payment-status returns NO radius credentials for a TV voucher, and flags is_tv. A TV is
#     bypassed at the router and can never log in, so credentials are meaningless for it — and
#     this guard holds no matter which portal version is deployed.
#
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "0) Backups"
for f in routes/captive.js utils/intasend-activate.js; do
  sudo cp "$BE/$f" "$BE/$(dirname $f)/.$(basename $f).bak_$TS" && echo "   $f"
done
sudo cp "$CP/classic.html" "$CP/.classic.html.bak_$TS" && echo "   classic.html"

say "A) utils/tvBind.js — one owner for TV binding"
sudo tee "$BE/utils/tvBind.js" > /dev/null <<'JS'
// RL_TV_BIND_SHARED — bind a purchased TV: bypass it at the router, cap it, link the device row.
//
// This lived only inside intasend-activate.js. The Daraja callback had no TV handling at all, so
// the same purchase behaved differently depending on which gateway the ISP used: on Daraja the TV
// sale was treated as an ordinary hotspot sale and the buyer's PHONE was connected instead.
// One implementation, called by both paths, is the only way these stay in step.
const { query } = require('../config/database');
const logger = require('./logger');

async function bindTvForPayment(paymentId) {
  try {
    const pm = (await query('SELECT metadata, isp_id FROM payments WHERE id=$1::uuid', [paymentId])).rows[0];
    const meta = (pm && pm.metadata) || {};
    if (!meta.is_tv || !meta.tv_mac) return { ok: false, reason: 'not a TV purchase' };

    const mt = require('./mikrotik');
    const tvMac = String(meta.tv_mac).toUpperCase();
    const dev = (await query(
      'SELECT id FROM nas_devices WHERE isp_id=$1::uuid AND wireguard_ip IS NOT NULL ORDER BY last_seen DESC NULLS LAST LIMIT 1',
      [pm.isp_id])).rows[0];
    if (!dev) return { ok: false, reason: 'no online router' };

    const pkg = (await query(
      'SELECT hp.bandwidth_down_mbps, hp.bandwidth_up_mbps FROM hotspot_packages hp ' +
      'JOIN hotspot_vouchers hv ON hv.package_id=hp.id WHERE hv.payment_id=$1::uuid LIMIT 1',
      [paymentId])).rows[0];

    await mt.addIpBindingBypass(dev.id, { mac_address: tvMac, comment: 'RumaLink-TV ' + tvMac });
    const ip = await mt.findIpForMac(dev.id, tvMac).catch(() => null);
    const maxLimit = pkg ? ((pkg.bandwidth_up_mbps || pkg.bandwidth_down_mbps || 0) + 'M/' + (pkg.bandwidth_down_mbps || 0) + 'M') : null;
    if (ip && maxLimit && maxLimit !== '0M/0M') {
      await mt.applyQueueRateLimit(dev.id, { username: 'tv-' + tvMac.replace(/:/g, ''), ip, max_limit: maxLimit }).catch(() => {});
    }
    await query(
      'UPDATE hotspot_bound_devices SET is_bound=true, bound_ip=$1, ' +
      'active_voucher_id=(SELECT id FROM hotspot_vouchers WHERE payment_id=$2::uuid LIMIT 1), ' +
      'package_id=(SELECT package_id FROM hotspot_vouchers WHERE payment_id=$2::uuid LIMIT 1), ' +
      'expires_at=(SELECT expires_at FROM hotspot_vouchers WHERE payment_id=$2::uuid LIMIT 1), ' +
      'updated_at=NOW() WHERE isp_id=$3::uuid AND lower(mac_address)=lower($4)',
      [ip, paymentId, pm.isp_id, tvMac]).catch(() => {});

    /* The voucher must be marked as the TV's, or the confirmation SMS uses the phone wording and
       the credentials guard below cannot recognise it. */
    await query(
      'UPDATE hotspot_vouchers SET is_tv=true, tv_mac=$1, used_by_mac=$1, ' +
      'purchased_by_mac=COALESCE(purchased_by_mac,$1) WHERE payment_id=$2::uuid',
      [tvMac, paymentId]).catch(() => {});

    logger.info('[tv-bind] TV bound: ' + tvMac + ' ip=' + (ip || '?') + ' cap=' + (maxLimit || 'none'));
    return { ok: true, tvMac, ip, maxLimit };
  } catch (e) {
    logger.error('[tv-bind] ' + e.message);
    return { ok: false, error: e.message };
  }
}

module.exports = { bindTvForPayment };
JS
sudo chown www-data:www-data "$BE/utils/tvBind.js"
sudo -u www-data node --check "$BE/utils/tvBind.js" && echo "   tvBind.js syntax OK"

say "B) Daraja callback calls it"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_DARAJA_TV_BIND' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)await syncRadiusForVoucher\(voucher\.id\)\.catch\(\(\)=>\{\}\);\s*$', s, re.M)
if not m:
    print("   ERROR: anchor not found — unchanged"); sys.exit(1)
ind = m.group(1)
add = ("\n" + ind + "/* RL_DARAJA_TV_BIND: this path had no TV handling at all, so a TV sale bought from a\n"
       + ind + "   phone bound nothing, capped nothing, and left the buyer's PHONE connected on the\n"
       + ind + "   voucher instead. IntaSend did it correctly; the shared module keeps them in step. */\n"
       + ind + "try { await require('../utils/tvBind').bindTvForPayment(req.params.paymentId); }\n"
       + ind + "catch (e) { logger.warn('[CB-TV] bind: ' + e.message); }")
s = s[:m.end()] + add + s[m.end():]
open(p,'w').write(s); print("   Daraja callback now binds the TV")
PY

say "C) payment-status must not hand login credentials to a TV purchase"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_TV_NO_CREDS' in s:
    print("   already patched"); sys.exit(0)
old = '"SELECT code, password, isp_id FROM hotspot_vouchers WHERE payment_id = "+String.fromCharCode(36)+"1::uuid LIMIT 1",'
if old not in s:
    print("   ERROR: creds query not found — unchanged"); sys.exit(1)
s = s.replace(old, '"SELECT code, password, isp_id, is_tv FROM hotspot_vouchers WHERE payment_id = "+String.fromCharCode(36)+"1::uuid LIMIT 1",', 1)

old2 = """            if (vc.rows[0]) {"""
new2 = """            if (vc.rows[0] && vc.rows[0].is_tv) {
              /* RL_TV_NO_CREDS: a television is bypassed at the router and can never sign in, so
                 credentials are meaningless for it. Returning them made the portal auto-login the
                 BUYER'S PHONE on the TV's voucher — two devices on one purchase, and the phone's
                 own session invisible in the dashboard. Flag it instead so the page says the TV is
                 connected. This guard is gateway-agnostic and holds for any portal version. */
              is_tv_purchase = true;
              if (!voucher_code) voucher_code = vc.rows[0].code;
            } else if (vc.rows[0]) {"""
if old2 not in s:
    print("   ERROR: creds branch not found — unchanged"); sys.exit(1)
s = s.replace(old2, new2, 1)

# declare and return the flag
old3 = "        let radius_username = null, radius_password = null;"
new3 = "        let radius_username = null, radius_password = null, is_tv_purchase = false;"
s = s.replace(old3, new3, 1)
old4 = """          voucher_code,
            radius_username,
            radius_password
          });"""
if old4 in s:
    s = s.replace(old4, """          voucher_code,
            radius_username,
            radius_password,
            is_tv: is_tv_purchase
          });""", 1)
else:
    s = s.replace("""            radius_username,
            radius_password
          });""", """            radius_username,
            radius_password,
            is_tv: is_tv_purchase
          });""", 1)
open(p,'w').write(s); print("   TV vouchers no longer return login credentials")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js syntax OK"

say "D) Portal: say the TV is connected instead of trying to log the phone in"
sudo python3 - "$CP/classic.html" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_TV_NO_AUTOLOGIN' in s:
    print("   already patched"); sys.exit(0)
old = "            var _ru = json.radius_username, _rp = json.radius_password;"
if old not in s:
    print("   anchor not found — unchanged (the server guard alone is sufficient)"); sys.exit(0)
new = ("""            /* RL_TV_NO_AUTOLOGIN: a TV purchase must not connect this phone. The server no longer
               returns credentials for a TV voucher, so the check below already fails safely; this
               makes the message right instead of showing a generic voucher notice. */
            if (json.is_tv) {
              showMsg('\\u2705 Payment received! Your TV is now connected. It comes online automatically \\u2014 no login needed.', 'success');
              document.getElementById('pay-section').style.display = 'none';
              setLoading(false);
              return;
            }
            var _ru = json.radius_username, _rp = json.radius_password;""")
s = s.replace(old, new, 1)
open(p,'w').write(s); print("   portal shows the TV confirmation")
PY
sudo chown www-data:www-data "$CP/classic.html"
echo "   div balance: $(( $(grep -o '<div' "$CP/classic.html" | wc -l) - $(grep -o '</div>' "$CP/classic.html" | wc -l) ))"

say "E) Restart + verify"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 20 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"
q -c "SELECT code, is_tv, tv_mac, used_by_mac, status FROM hotspot_vouchers ORDER BY created_at DESC LIMIT 4;"
PID=$(q -tAc "SELECT payment_id FROM hotspot_vouchers WHERE is_tv=true ORDER BY created_at DESC LIMIT 1;")
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
if [ -n "$PID" ]; then
  echo "   status for the last TV payment (must have NO radius creds, is_tv true):"
  curl -s "http://127.0.0.1:5000/api/captive/$ISP/payment-status/$PID" | head -c 320 | sed 's/^/     /'; echo
fi

say "F) Test"
cat <<'EOS'
   Buy a TV package on Daraja from the phone. Expect:
     - the portal says "Your TV is now connected" and does NOT log the phone in
     - the router gains an ip-binding for the TV MAC and an rl-tv-<mac> queue
     - the phone has no hotspot session from that purchase
     - the SMS uses the TV wording
   Then buy a PHONE package and confirm autologin still works.
EOS

say "G) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "TV purchases: shared binding for both gateways; never return login creds for a TV voucher" 2>&1 | head -2 | sed 's/^/   /'
