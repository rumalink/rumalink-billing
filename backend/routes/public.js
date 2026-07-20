// routes/public.js — unauthenticated public endpoints (safe, read-only marketing/pricing data).
const express = require('express');
const { query } = require('../config/database');
const router = express.Router();

// GET /api/public/rates — live platform commission defaults for the landing page.
router.get('/rates', async (req, res) => {
  let hotspot = 0.03, pppoe = 32.25;
  try {
    const r = await query("SELECT key, value FROM platform_settings WHERE key IN ('hotspot_commission_rate','pppoe_per_user_fee')");
    for (const row of r.rows) {
      if (row.key === 'hotspot_commission_rate' && row.value != null) hotspot = parseFloat(row.value);
      if (row.key === 'pppoe_per_user_fee' && row.value != null) pppoe = parseFloat(row.value);
    }
  } catch (e) { /* defaults */ }
  res.json({
    hotspot_commission_rate: hotspot,
    hotspot_commission_percent: Math.round(hotspot * 100 * 100) / 100,
    pppoe_per_user_fee: pppoe
  });
});

// POST /api/public/sms-topup-callback/:paymentId — Safaricom STK callback for ISP SMS topups (public, idempotent)
router.post('/sms-topup-callback/:paymentId', async (req, res) => {
  const paymentId = req.params.paymentId;
  try {
    const cb = req.body && req.body.Body && req.body.Body.stkCallback;
    if (cb && cb.ResultCode === 0) {
      const items = (cb.CallbackMetadata && cb.CallbackMetadata.Item) || [];
      const g = n => { const f = items.find(x => x.Name === n); return f ? f.Value : null; };
      const receipt = g('MpesaReceiptNumber');
      const payerPhone = g('PhoneNumber');
      const payerAmount = g('Amount');
      const cbCheckoutId = cb.CheckoutRequestID || null;
      const txn = await query("SELECT id, isp_id, sms_count, status FROM sms_credit_transactions WHERE payment_id=$1::uuid LIMIT 1", [paymentId]);
      const t = txn.rows[0];
      // SECURITY: verify the callback matches our STK request (checkout id + amount), not a forgery.
      const mt = await query("SELECT checkout_request_id, amount FROM mpesa_transactions WHERE payment_id=$1::uuid LIMIT 1", [paymentId]);
      const m = mt.rows[0];
      const idOk = m && m.checkout_request_id && cbCheckoutId && String(m.checkout_request_id) === String(cbCheckoutId);
      const amtOk = m && payerAmount != null && Math.abs(Number(payerAmount) - Number(m.amount)) < 0.5;
      if (t && t.status === 'pending' && !(idOk && amtOk)) {
        try { require('../utils/logger').warn(`sms topup callback REJECTED (payment ${paymentId}): idOk=${idOk} amtOk=${amtOk}`); } catch(_){}
        return res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
      }
      if (t && t.status === 'pending') {
        await query("UPDATE payments SET status='paid', transaction_id=$1, paid_at=NOW(), mpesa_phone=$2::varchar, mpesa_amount=$3::decimal WHERE id=$4::uuid",
          [receipt, payerPhone ? String(payerPhone) : null, payerAmount || null, paymentId]).catch(()=>{});
        await query("UPDATE mpesa_transactions SET status='completed', mpesa_receipt=$1, transaction_date=NOW() WHERE payment_id=$2::uuid",[receipt,paymentId]).catch(()=>{});
        const upd = await query("UPDATE isps SET sms_balance = sms_balance + $1 WHERE id=$2::uuid RETURNING sms_balance", [t.sms_count, t.isp_id]);
        const balAfter = upd.rows[0] ? parseFloat(upd.rows[0].sms_balance) : null;
        await query("UPDATE sms_credit_transactions SET status='completed', isp_balance_after=$1 WHERE id=$2::uuid", [balAfter, t.id]).catch(()=>{});
        await query("INSERT INTO notifications (isp_id, type, title, message) VALUES ($1::uuid,'success','SMS Credited',$2)",
          [t.isp_id, t.sms_count + ' SMS added. New balance: ' + (balAfter!=null?balAfter:'-') + ' SMS.']).catch(()=>{});
      }
    } else if (cb) {
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid", [(cb.ResultDesc||'Cancelled').substring(0,240), paymentId]).catch(()=>{});
      await query("UPDATE sms_credit_transactions SET status='failed' WHERE payment_id=$1::uuid AND status='pending'", [paymentId]).catch(()=>{});
    }
  } catch (e) { try { require('../utils/logger').error('sms topup cb: ' + e.message); } catch(_){} }
  res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
});

module.exports = router;
