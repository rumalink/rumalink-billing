// RL_INTASEND_ACTIVATE: activate the voucher for a confirmed IntaSend payment.
// Mirrors the Daraja callback path exactly: extend expires_at by the package's
// duration_hours, then sync radcheck/radreply so the customer can actually get online.
const { query } = require('../config/database');
const logger = require('./logger');

// Same realmed username scheme as captive.js (code@ispShort).
async function syncRadius(voucherId) {
  try {
    const vr = await query(
      `SELECT v.id, v.code, v.password, v.isp_id, v.expires_at, v.package_id
       FROM hotspot_vouchers v WHERE v.id=$1::uuid`, [voucherId]);
    const v = vr.rows[0];
    if (!v) return;
    const pr = await query(
      `SELECT duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, mikrotik_profile
       FROM hotspot_packages WHERE id=$1::uuid`, [v.package_id]);
    const pkg = pr.rows[0] || {};

    const ispShort = String(v.isp_id).replace(/-/g, '').slice(0, 8).toLowerCase();
    const realmedUser = v.code + '@' + ispShort;
    const pw = v.password || v.code;

    await query("DELETE FROM radcheck WHERE username = $1 OR username = $2", [v.code, realmedUser]);
    await query("DELETE FROM radreply WHERE username = $1 OR username = $2", [v.code, realmedUser]);
    await query("INSERT INTO radcheck (username, attribute, op, value) VALUES ($1,'Cleartext-Password',':=',$2)",
      [realmedUser, pw]);

    if (pkg.bandwidth_down_mbps || pkg.bandwidth_up_mbps) {
      const up = pkg.bandwidth_up_mbps || pkg.bandwidth_down_mbps;
      const down = pkg.bandwidth_down_mbps || pkg.bandwidth_up_mbps;
      await query("INSERT INTO radreply (username, attribute, op, value) VALUES ($1,'Mikrotik-Rate-Limit','=',$2)",
        [realmedUser, up + 'M/' + down + 'M']);
    }
    let timeoutSeconds = null;
    if (v.expires_at) timeoutSeconds = Math.max(60, Math.floor((new Date(v.expires_at) - Date.now()) / 1000));
    else if (pkg.duration_hours) timeoutSeconds = pkg.duration_hours * 3600;
    if (timeoutSeconds && timeoutSeconds > 0) {
      await query("INSERT INTO radreply (username, attribute, op, value) VALUES ($1,'Session-Timeout','=',$2)",
        [realmedUser, String(timeoutSeconds)]);
    }
    if (pkg.data_limit_mb) {
      await query("INSERT INTO radreply (username, attribute, op, value) VALUES ($1,'Mikrotik-Total-Limit','=',$2)",
        [realmedUser, String(pkg.data_limit_mb * 1024 * 1024)]);
    }
    if (pkg.mikrotik_profile) {
      await query("INSERT INTO radreply (username, attribute, op, value) VALUES ($1,'Mikrotik-Group','=',$2)",
        [realmedUser, pkg.mikrotik_profile]);
    }
    logger.info('[intasend-activate] radius synced: ' + v.code + ' -> ' + realmedUser);
  } catch (e) {
    logger.error('[intasend-activate] radius sync failed: ' + e.message);
  }
}

// Activate the voucher tied to a paid payment. Idempotent-safe to re-run.
async function activateVoucher(paymentId) {
  try {
    // Identical expiry logic to the Daraja callback (RL_STATUS_NO_DOWNGRADE).
    // RL_ACTIVATE_GUARD: idempotency — skip if this payment already activated a voucher.
    const _chk = await query("SELECT voucher_activated_at FROM payments WHERE id=$1::uuid", [paymentId]);
    if (_chk.rows[0] && _chk.rows[0].voucher_activated_at) {
      logger.info('[intasend-activate] payment ' + paymentId + ' already activated — skipping');
      return null;
    }
    const r = await query(`
      UPDATE hotspot_vouchers v
      SET status = 'active'::voucher_status,  /* RL_PURCHASE_EXPIRY: paid => active immediately */
          is_paid = true,
          /* RL_ACTIVATE_IDEMPOTENT: expiry = the PAYMENT's paid_at + duration. Deterministic, so a
             re-scan of the same payment computes the SAME expiry (no stacking, no NOW() drift). */
          expires_at = COALESCE((SELECT paid_at FROM payments WHERE id = v.payment_id), NOW())
                       + COALESCE((SELECT (duration_hours || ' hours')::interval
                           FROM hotspot_packages WHERE id = v.package_id), interval '24 hours'),
          updated_at = NOW()
      WHERE payment_id=$1::uuid
      RETURNING id, code, isp_id, expires_at, package_id, used_by_mac`, [paymentId]);
    const v = r.rows[0];
    if (!v) { logger.warn('[intasend-activate] no voucher for payment ' + paymentId); return null; }
    logger.info(`[intasend-activate] voucher ${v.code} activated, expires ${v.expires_at}`);
    await query("UPDATE payments SET voucher_activated_at=NOW() WHERE id=$1::uuid", [paymentId]).catch(function(){});  // RL_ACTIVATE_GUARD marker
    // RL_ACTIVATE_CREDIT: credit the ISP wallet for this hotspot payment (idempotent — the
    // commissions(payment_id) unique index means a payment already credited by IPN/poll is a no-op).
    try { await require('./wallet-credit').creditWalletOnce(paymentId); }
    catch(e){ logger.error('[intasend-activate] wallet credit: ' + e.message); }
    // RL_TV_BIND: if this payment is a TV purchase, bind the TV MAC (bypass) + cap it with a queue.
    try {
      const pm = (await query("SELECT metadata, isp_id FROM payments WHERE id=$1::uuid", [paymentId])).rows[0];
      const meta = pm && pm.metadata || {};
      if (meta.is_tv && meta.tv_mac) {
        const mt = require('./mikrotik');
        const tvMac = String(meta.tv_mac).toUpperCase();
        const dev = (await query("SELECT id FROM nas_devices WHERE isp_id=$1::uuid AND wireguard_ip IS NOT NULL ORDER BY last_seen DESC NULLS LAST LIMIT 1", [pm.isp_id])).rows[0];
        const pkg = (await query("SELECT hp.bandwidth_down_mbps, hp.bandwidth_up_mbps FROM hotspot_packages hp JOIN hotspot_vouchers hv ON hv.package_id=hp.id WHERE hv.payment_id=$1::uuid LIMIT 1", [paymentId])).rows[0];
        if (dev) {
          await mt.addIpBindingBypass(dev.id, { mac_address: tvMac, comment: 'RumaLink-TV ' + tvMac });
          const ip = await mt.findIpForMac(dev.id, tvMac).catch(()=>null);
          const maxLimit = pkg ? ((pkg.bandwidth_up_mbps||pkg.bandwidth_down_mbps||0)+'M/'+(pkg.bandwidth_down_mbps||0)+'M') : null;
          if (ip && maxLimit && maxLimit !== '0M/0M') {
            await mt.applyQueueRateLimit(dev.id, { username: 'tv-'+tvMac.replace(/:/g,''), ip, max_limit: maxLimit }).catch(()=>{});
          }
          await query("UPDATE hotspot_bound_devices SET is_bound=true, bound_ip=$1, active_voucher_id=(SELECT id FROM hotspot_vouchers WHERE payment_id=$2::uuid LIMIT 1), package_id=(SELECT package_id FROM hotspot_vouchers WHERE payment_id=$2::uuid LIMIT 1), expires_at=(SELECT expires_at FROM hotspot_vouchers WHERE payment_id=$2::uuid LIMIT 1), updated_at=NOW() WHERE isp_id=$3::uuid AND lower(mac_address)=lower($4)", [ip, paymentId, pm.isp_id, tvMac]).catch(()=>{});
          logger.info('[intasend-activate] TV bound: ' + tvMac + ' ip=' + (ip||'?') + ' cap=' + (maxLimit||'none'));
        }
      }
    } catch (e) { logger.error('[intasend-activate] TV bind: ' + e.message); }

    await syncRadius(v.id);
    /* RL_INTASEND_PURCHASE_SMS: the confirmation is sent from the Daraja callback for that
       gateway; on the IntaSend path nothing sent it, so those customers paid and heard
       nothing. sendPurchaseSms is idempotent via the payment's rl_purchase_sms flag, so a
       retry or a second activation pass cannot send a duplicate. */
    try { await require('./hotspotSms').sendPurchaseSms(paymentId); }
    catch (e) { logger.error('[intasend-activate] purchase sms: ' + e.message); }
    return v;
  } catch (e) {
    logger.error('[intasend-activate] ' + e.message);
    return null;
  }
}

module.exports = { activateVoucher, syncRadius };
