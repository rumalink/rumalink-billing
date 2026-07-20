// utils/intasend-selfheal.js
// RL_POLL_SELFHEAL: confirm a still-'pending' payment DIRECTLY with its gateway, so a dropped
// webhook/callback cannot strand a paying customer. Handles BOTH gateways behind one interface:
//   intasend  -> intasend.collectionStatus(invoice_id)
//   mpesa_stk -> mpesa.stkQuery(checkout_request_id)   [Daraja]
// Both return { ok, isPaid, isDead, ... }. On isPaid we mark the payment paid here; the CALLER
// runs the normal activation (onPaid for PPPoE, syncRadiusForVoucher for hotspot).
//
// Fail-soft by contract: any error or 'unknown' gateway state returns the status we already had.
// Read-only against the gateway — queries status, never initiates a charge.
const { query } = require('../config/database');

async function _confirmIntasend(pay) {
  let invId = null;
  try {
    const md = typeof pay.metadata === 'string' ? JSON.parse(pay.metadata) : (pay.metadata || {});
    invId = md.intasend_invoice || null;
  } catch (e) {}
  if (!invId) return null;
  const intasend = require('./intasend-client');
  const st = await intasend.collectionStatus(invId);
  if (!st || !st.ok) return null;
  return { isPaid: st.isPaid, isDead: st.isDead, receipt: st.receipt || null,
           failed: st.failedReason || st.state || 'failed' };
}

async function _confirmDaraja(pay) {
  // Need the CheckoutRequestID and the ISP's (or admin) Daraja creds.
  const tx = await query(
    "SELECT checkout_request_id FROM mpesa_transactions WHERE payment_id=$1::uuid AND checkout_request_id IS NOT NULL ORDER BY created_at DESC LIMIT 1",
    [pay.id]);
  const checkoutId = tx.rows[0] && tx.rows[0].checkout_request_id;
  if (!checkoutId) return null;  // nothing to query with -> cannot heal, leave as-is

  // Load creds: ISP-specific first, else admin. Mirrors captive.js resolution.
  let m = (await query(
    "SELECT * FROM mpesa_configs WHERE isp_id=$1::uuid AND is_active=true AND COALESCE(is_admin_config,false)=false LIMIT 1",
    [pay.isp_id])).rows[0];
  if (!m || !m.consumer_key) {
    m = (await query("SELECT * FROM mpesa_configs WHERE is_admin_config=true AND is_active=true LIMIT 1")).rows[0];
  }
  if (!m || !m.consumer_key) return null;

  const creds = { shortcode: m.shortcode, consumer_key: m.consumer_key,
                  consumer_secret: m.consumer_secret, passkey: m.passkey };
  const baseUrl = (m.is_sandbox || m.sandbox)
    ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';

  const mpesa = require('./mpesa');
  const st = await mpesa.stkQuery({ creds, baseUrl, checkoutRequestId: checkoutId });
  if (!st || !st.ok) return null;
  return { isPaid: st.isPaid, isDead: st.isDead, receipt: null, failed: 'M-Pesa result ' + st.resultCode };
}

async function rlConfirmWithGateway(pay) {
  try {
    if (!pay || pay.status !== 'pending') return pay ? pay.status : 'pending';

    let res = null;
    if (pay.payment_gateway === 'intasend')       res = await _confirmIntasend(pay);
    else if (pay.payment_gateway === 'mpesa_stk') res = await _confirmDaraja(pay);
    else return pay.status;                         // other gateways: unchanged

    if (!res) return pay.status;                    // could not confirm -> unchanged

    if (res.isPaid) {
      await query(
        "UPDATE payments SET status='paid', paid_at=NOW(), transaction_id=COALESCE($2,transaction_id), updated_at=NOW() WHERE id=$1::uuid AND status!='paid'",
        [pay.id, res.receipt]);
      return 'paid';
    }
    if (res.isDead) {
      await query(
        "UPDATE payments SET status='failed', failure_reason=$2, updated_at=NOW() WHERE id=$1::uuid AND status='pending'",
        [pay.id, String(res.failed).slice(0, 200)]);
      return 'failed';
    }
    return pay.status;
  } catch (e) {
    return pay ? pay.status : 'pending';
  }
}

// Backwards-compatible alias: the polls call rlConfirmWithIntasend today.
const rlConfirmWithIntasend = rlConfirmWithGateway;

module.exports = { rlConfirmWithGateway, rlConfirmWithIntasend };
