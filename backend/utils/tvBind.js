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
