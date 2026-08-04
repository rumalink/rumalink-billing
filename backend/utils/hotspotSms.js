// utils/hotspotSms.js — RL_PURCHASE_SMS
// One place that tells a hotspot customer what they just bought.
//
// The previous version lived inside the Daraja callback in captive.js. Payments now activate
// through IntaSend, so that code still existed but never ran — the message simply stopped
// arriving with nothing failing anywhere. It also selected the ISP's newest voucher rather than
// the one attached to the payment, which would text one customer another customer's code the
// moment two people bought at once. Both are fixed here: the voucher is looked up BY PAYMENT,
// and every activation path calls this single function.
const { query } = require('../config/database');
const logger = require('./logger');

function fmt(dt) {
  if (!dt) return 'N/A';
  try {
    return new Date(dt).toLocaleString('en-KE', {
      timeZone: 'Africa/Nairobi', day: '2-digit', month: 'short',
      year: 'numeric', hour: '2-digit', minute: '2-digit'
    });
  } catch (e) { return String(dt); }
}

async function sendSmsCompat(phone, message, isp) {
  const fn = require('./sms').sendSMS;
  if (typeof fn !== 'function') throw new Error('sendSMS unavailable');
  const row = Object.assign({}, isp);
  if (!row.sms_gateway) row.sms_gateway = 'rumalink';
  return await fn({ to: phone, message: message, isp: row });
}

/* Send the purchase confirmation for a payment. Idempotent: the flag on the payment means a
   retry, a webhook replay and the strand healer cannot each send their own copy — which would
   be three charged messages for one purchase. */
async function sendPurchaseSms(paymentId, receipt) {
  try {
    const r = await query(
      "SELECT v.code, v.password, v.buyer_phone, v.expires_at, v.isp_id, v.is_tv, v.tv_mac, p.metadata AS pay_meta, " +
      "       (SELECT name FROM hotspot_bound_devices bd WHERE UPPER(bd.mac_address)=UPPER(v.tv_mac) LIMIT 1) AS tv_name, " +
      "       hp.name AS pkg_name, p.amount, p.transaction_id, " +
      "       COALESCE(p.metadata->>'rl_purchase_sms','') AS already " +
      "FROM payments p " +
      "JOIN hotspot_vouchers v ON v.payment_id = p.id " +
      "LEFT JOIN hotspot_packages hp ON hp.id = v.package_id " +
      "WHERE p.id = $1::uuid " +
          /* RL_SMS_PICK_REAL: if more than one voucher ever points at a payment, prefer the one
             that was actually activated — otherwise the customer is told a code that was never
             provisioned. */
          "ORDER BY (v.status = 'active') DESC, v.expires_at DESC NULLS LAST, v.updated_at DESC NULLS LAST LIMIT 1",
          [paymentId]);
    const v = r.rows[0];
    if (!v) return { ok: false, reason: 'no voucher for payment' };
    if (v.already === 'sent') return { ok: true, skipped: 'already sent' };
    if (!v.buyer_phone) return { ok: false, reason: 'no buyer phone' };

    const isp = (await query('SELECT * FROM isps WHERE id = $1::uuid', [v.isp_id])).rows[0];
    if (!isp) return { ok: false, reason: 'isp missing' };

    /* RL_TV_SMS: a television is bypassed at the router and never signs in, so sending it a
       username and password describes something the customer cannot do and invites them to try.
       Name the device instead and say plainly that nothing is required of them. */
    /* RL_TV_SMS_FAILSAFE: this decided purely on v.is_tv. When a voucher was left unmarked — the
       payment metadata was correct, the voucher flag was not — the PHONE template fired and sent a
       username and password for a television, which the buyer can then use on any device. The
       payment's own is_tv is an independent signal for the same fact, so honour both and let the
       safe answer win: if either says television, no credentials go out. */
    let _payMeta = v.pay_meta;
    try { if (typeof _payMeta === 'string') _payMeta = JSON.parse(_payMeta); } catch (e) { _payMeta = null; }
    const _isTv = !!(v.is_tv || (_payMeta && (_payMeta.is_tv === true || _payMeta.is_tv === 'true')));
    if (_isTv && !v.is_tv) {
      logger.warn('[purchase-sms] ' + v.code + ' was not marked as a TV but its payment is — sending TV wording and correcting the voucher');
      try {
        await query("UPDATE hotspot_vouchers SET is_tv=true, tv_mac=COALESCE(tv_mac,$1) WHERE id=$2::uuid",
          [(_payMeta && _payMeta.tv_mac) || null, v.id]);
      } catch (e) { logger.warn('[purchase-sms] tv correction: ' + e.message); }
    }
    const lines = _isTv
      ? [
          (isp.company_name || 'WiFi') + ': ' + (v.pkg_name || 'Package') + ' activated for ' + (v.tv_name || 'your TV') + '.',
          'It connects automatically — no login needed.',
          'Expires: ' + fmt(v.expires_at)
        ]
      : [
          (isp.company_name || 'WiFi') + ': ' + (v.pkg_name || 'Package') + ' activated.',
          'Username: ' + v.code,
          'Password: ' + (v.password || v.code),
          'Expires: ' + fmt(v.expires_at)
        ];
    const ref = receipt || v.transaction_id;
    if (ref) lines.push('Receipt: ' + ref);
    const message = lines.join('\n');

    await sendSmsCompat(v.buyer_phone, message, isp);
    await query(
      "UPDATE payments SET metadata = COALESCE(metadata,'{}'::jsonb) || jsonb_build_object('rl_purchase_sms','sent') WHERE id = $1::uuid",
      [paymentId]).catch(function () {});
    logger.info('[purchase-sms] sent to ' + v.buyer_phone + ' for ' + v.code);
    return { ok: true, to: v.buyer_phone, code: v.code };
  } catch (e) {
    logger.error('[purchase-sms] ' + e.message);
    return { ok: false, error: e.message };
  }
}

module.exports = { sendPurchaseSms, fmt };
