const express = require('express');
const axios = require('axios');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();

// ============================================================
// MPESA STK PUSH (ISP initiates payment for subscriber)
// ============================================================
const getMpesaToken = async (consumerKey, consumerSecret, sandbox = false) => {
  const url = sandbox
    ? 'https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials'
    : 'https://api.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials';

  const credentials = Buffer.from(`${consumerKey}:${consumerSecret}`).toString('base64');
  const response = await axios.get(url, {
    headers: { Authorization: `Basic ${credentials}` }
  });
  return response.data.access_token;
};

const stkPush = async ({ shortcode, passkey, token, phone, amount, callbackUrl, accountRef, sandbox }) => {
  const timestamp = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
  const password = Buffer.from(`${shortcode}${passkey}${timestamp}`).toString('base64');

  const url = sandbox
    ? 'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest'
    : 'https://api.safaricom.co.ke/mpesa/stkpush/v1/processrequest';

  const response = await axios.post(url, {
    BusinessShortCode: shortcode,
    Password: password,
    Timestamp: timestamp,
    TransactionType: 'CustomerPayBillOnline',
    Amount: Math.ceil(amount),
    PartyA: phone,
    PartyB: shortcode,
    PhoneNumber: phone,
    CallBackURL: callbackUrl,
    AccountReference: accountRef,
    TransactionDesc: `Payment for ${accountRef}`
  }, { headers: { Authorization: `Bearer ${token}` } });

  return response.data;
};

// Initiate MPesa payment
router.post('/mpesa/initiate', authenticateToken, requireISP, async (req, res, next) => {
  const { phone, amount, subscriber_id, voucher_id, description } = req.body;
  if (!phone || !amount) return res.status(400).json({ error: 'Phone and amount required' });

  try {
    const mpesa = await query('SELECT * FROM mpesa_configs WHERE isp_id = $1 AND is_active = true', [req.user.ispId]);
    if (!mpesa.rows[0]) return res.status(400).json({ error: 'MPesa not configured. Go to Settings > Payment Methods.' });

    const m = mpesa.rows[0];
    const isp = await query('SELECT commission_rate FROM isps WHERE id = $1', [req.user.ispId]);
    const commissionRate = parseFloat(isp.rows[0].commission_rate) || 0.03;
    const commissionAmount = parseFloat(amount) * commissionRate;

    // Create pending payment
    const payment = await query(`
      INSERT INTO payments (isp_id, subscriber_id, voucher_id, amount, payment_method,
                            payment_gateway, phone_number, commission_rate, commission_amount,
                            net_amount, description, status)
      VALUES ($1,$2,$3,$4,'mpesa','mpesa',$5,$6,$7,$8,$9,'pending')
      RETURNING id
    `, [req.user.ispId, subscriber_id, voucher_id, amount, phone,
        commissionRate, commissionAmount, amount - commissionAmount, description]);

    const paymentId = payment.rows[0].id;

    const token = await getMpesaToken(m.consumer_key, m.consumer_secret, m.is_sandbox);
    const callbackUrl = m.callback_url || `${process.env.BASE_URL}/api/payments/mpesa/callback/${req.user.ispId}`;

    const stkResult = await stkPush({
      shortcode: m.shortcode,
      passkey: m.passkey,
      token,
      phone: phone.replace(/^0/, '254').replace(/^\+/, ''),
      amount,
      callbackUrl,
      accountRef: paymentId.substring(0, 12),
      sandbox: m.is_sandbox
    });

    // Save MPesa transaction
    await query(`
      INSERT INTO mpesa_transactions (isp_id, payment_id, checkout_request_id, merchant_request_id, amount, phone, status)
      VALUES ($1,$2,$3,$4,$5,$6,'pending')
    `, [req.user.ispId, paymentId, stkResult.CheckoutRequestID, stkResult.MerchantRequestID, amount, phone]);

    res.json({
      payment_id: paymentId,
      checkout_request_id: stkResult.CheckoutRequestID,
      message: 'STK push sent. Customer should enter their PIN.'
    });
  } catch (err) { next(err); }
});

// MPesa callback
router.post('/mpesa/callback/:ispId', async (req, res) => {
  const { Body } = req.body;
  const ispId = req.params.ispId;

  try {
    const stkCallback = Body?.stkCallback;
    const checkoutId = stkCallback?.CheckoutRequestID;
    const resultCode = stkCallback?.ResultCode;

    const mpesaTx = await query('SELECT * FROM mpesa_transactions WHERE checkout_request_id = $1', [checkoutId]);
    if (!mpesaTx.rows[0]) return res.json({ ResultCode: 0, ResultDesc: 'Accepted' });

    const tx = mpesaTx.rows[0];

    if (resultCode === 0) {
      const meta = stkCallback.CallbackMetadata?.Item || [];
      const getMeta = (name) => meta.find(i => i.Name === name)?.Value;
      const mpesaCode = getMeta('MpesaReceiptNumber');
      const amount = getMeta('Amount');

      await query(`
        UPDATE mpesa_transactions SET result_code=$1, mpesa_receipt=$2, transaction_date=NOW(), status='completed', raw_callback=$3
        WHERE checkout_request_id=$4
      `, [resultCode, mpesaCode, JSON.stringify(Body), checkoutId]);

      // Update payment
      await query(`
        UPDATE payments SET status='paid', transaction_id=$1, gateway_reference=$2, paid_at=NOW()
        WHERE id=$3
      `, [mpesaCode, checkoutId, tx.payment_id]);

      // Update ISP wallet
      const payment = await query('SELECT * FROM payments WHERE id = $1', [tx.payment_id]);
      const p = payment.rows[0];
      if (p) {
        await query(`
          UPDATE isps SET wallet_balance = wallet_balance + $1, total_earned = total_earned + $2,
                          total_commission_paid = total_commission_paid + $3
          WHERE id = $4
        `, [p.net_amount, p.amount, p.commission_amount, ispId]);

        // Log commission
        await query(`INSERT INTO commissions (isp_id, payment_id, amount, rate) VALUES ($1,$2,$3,$4)`,
          [ispId, p.id, p.commission_amount, p.commission_rate]);

        // Log ISP transaction
        const isp = await query('SELECT wallet_balance FROM isps WHERE id = $1', [ispId]);
        await query(`INSERT INTO isp_transactions (isp_id, type, amount, balance_after, description, reference_id) VALUES ($1,'payment',$2,$3,$4,$5)`,
          [ispId, p.net_amount, isp.rows[0]?.wallet_balance, `Payment received - ${mpesaCode}`, p.id]);

        // Real-time notification
        // (io would be accessed here via app but this is a webhook route)
        await query(`INSERT INTO notifications (isp_id, type, title, message) VALUES ($1,'success','Payment Received',$2)`,
          [ispId, `KES ${amount?.toLocaleString()} received via MPesa (${mpesaCode})`]);

        // Activate voucher if payment linked
        if (p.voucher_id) {
          await query(`UPDATE hotspot_vouchers SET status='active', is_paid=true, amount_paid=$1, payment_method='mpesa', payment_reference=$2 WHERE id=$3`,
            [amount, mpesaCode, p.voucher_id]);
        }
        // Update subscriber balance if linked
        if (p.subscriber_id) {
          await query(`UPDATE pppoe_subscribers SET balance=balance+$1, last_payment_date=NOW() WHERE id=$2`, [amount, p.subscriber_id]);
          await query(`UPDATE pppoe_invoices SET status='paid', paid_at=NOW(), payment_id=$1 WHERE subscriber_id=$2 AND status='pending' ORDER BY created_at LIMIT 1`, [p.id, p.subscriber_id]);
        }
      }
    } else {
      await query(`UPDATE mpesa_transactions SET result_code=$1, status='failed', raw_callback=$2 WHERE checkout_request_id=$3`,
        [resultCode, JSON.stringify(Body), checkoutId]);
      await query(`UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2`,
        [stkCallback?.ResultDesc, tx.payment_id]);
    }
  } catch (err) {
    logger.error('MPesa callback error:', err);
  }

  res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
});

// ============================================================
// MANUAL PAYMENT (cash, bank)
// ============================================================
router.post('/manual', authenticateToken, requireISP, async (req, res, next) => {
  const { amount, payment_method, subscriber_id, voucher_id, description, reference } = req.body;
  if (!amount || !payment_method) return res.status(400).json({ error: 'Amount and payment method required' });

  try {
    const isp = await query('SELECT commission_rate, wallet_balance FROM isps WHERE id = $1', [req.user.ispId]);
    const commissionRate = isp.rows[0].plan_type === 'hotspot'
      ? parseFloat(isp.rows[0].commission_rate) || 0.03
      : 0;
    const commissionAmount = parseFloat(amount) * commissionRate;
    const netAmount = amount - commissionAmount;

    const payment = await query(`
      INSERT INTO payments (isp_id, subscriber_id, voucher_id, amount, payment_method,
                            transaction_id, commission_rate, commission_amount, net_amount,
                            description, status, paid_at)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'paid',NOW())
      RETURNING *
    `, [req.user.ispId, subscriber_id, voucher_id, amount, payment_method, reference,
        commissionRate, commissionAmount, netAmount, description]);

    const p = payment.rows[0];

    await query(`UPDATE isps SET wallet_balance=wallet_balance+$1, total_earned=total_earned+$2 WHERE id=$3`,
      [netAmount, amount, req.user.ispId]);

    if (subscriber_id) {
      await query(`UPDATE pppoe_subscribers SET balance=balance+$1, last_payment_date=NOW() WHERE id=$2`, [amount, subscriber_id]);
      await query(`UPDATE pppoe_invoices SET status='paid', paid_at=NOW(), payment_id=$1 WHERE subscriber_id=$2 AND status='pending' ORDER BY created_at LIMIT 1`, [p.id, subscriber_id]);
    }

    if (voucher_id) {
      await query(`UPDATE hotspot_vouchers SET is_paid=true, amount_paid=$1, payment_method=$2 WHERE id=$3`, [amount, payment_method, voucher_id]);
    }

    res.status(201).json({ payment: p });
  } catch (err) { next(err); }
});

// List payments
router.get('/', authenticateToken, requireISP, async (req, res, next) => {
  const { page = 1, limit = 20, status, method } = req.query;
  const offset = (page - 1) * limit;
  let where = 'WHERE p.isp_id = $1';
  const params = [req.user.ispId];
  let idx = 2;
  if (status) { where += ` AND p.status = $${idx++}`; params.push(status); }
  if (method) { where += ` AND p.payment_method = $${idx++}`; params.push(method); }

  try {
    const result = await query(`
      SELECT p.*, 
             sub.username as subscriber_username, sub.full_name as subscriber_name,
             hv.code as voucher_code
      FROM payments p
      LEFT JOIN pppoe_subscribers sub ON sub.id = p.subscriber_id
      LEFT JOIN hotspot_vouchers hv ON hv.id = p.voucher_id
      ${where} ORDER BY p.created_at DESC LIMIT $${idx} OFFSET $${idx + 1}
    `, [...params, limit, offset]);
    const count = await query(`SELECT COUNT(*) FROM payments p ${where}`, params);
    res.json({ payments: result.rows, total: parseInt(count.rows[0].count) });
  } catch (err) { next(err); }
});

// MPesa config
router.get('/mpesa/config', authenticateToken, requireISP, async (req, res, next) => {
  try {
    const result = await query('SELECT id, shortcode, callback_url, is_sandbox, is_active FROM mpesa_configs WHERE isp_id = $1', [req.user.ispId]);
    res.json({ config: result.rows[0] || null });
  } catch (err) { next(err); }
});

router.post('/mpesa/config', authenticateToken, requireISP, async (req, res, next) => {
  const { shortcode, consumer_key, consumer_secret, passkey, callback_url, is_sandbox } = req.body;
  try {
    const result = await query(`
      INSERT INTO mpesa_configs (isp_id, shortcode, consumer_key, consumer_secret, passkey, callback_url, is_sandbox, is_active)
      VALUES ($1,$2,$3,$4,$5,$6,$7,true)
      ON CONFLICT (isp_id) DO UPDATE SET shortcode=$2, consumer_key=$3, consumer_secret=$4, passkey=$5, callback_url=$6, is_sandbox=$7, is_active=true, updated_at=NOW()
      RETURNING id, shortcode, callback_url, is_sandbox, is_active
    `, [req.user.ispId, shortcode, consumer_key, consumer_secret, passkey, callback_url, is_sandbox || false]);
    res.json({ config: result.rows[0] });
  } catch (err) { next(err); }
});


// ── After payment confirmed, send PPPoE payment SMS ──
async function sendPPPoEPaymentSMS(subscriberId, amount, mpesaCode) {
  try {
    const { sendSMS } = require('../utils/sms');
    const sub = await require('../config/database').query(`
      SELECT ps.*, pp.name as pkg_name, i.company_name, i.sms_gateway, i.sms_api_key, i.sms_sender_id
      FROM pppoe_subscribers ps
      JOIN pppoe_packages pp ON pp.id = ps.package_id
      JOIN isps i ON i.id = ps.isp_id
      WHERE ps.id=$1
    `, [subscriberId]);

    if (!sub.rows[0]?.phone) return;
    const s = sub.rows[0];

    const nextDate = new Date();
    nextDate.setMonth(nextDate.getMonth() + 1);
    const expiry = s.next_billing_date
      ? new Date(s.next_billing_date).toLocaleDateString('en-KE')
      : nextDate.toLocaleDateString('en-KE');

    await sendSMS({
      to: s.phone,
      message: `${s.company_name}: Payment of KES ${amount} received (Ref: ${mpesaCode || 'N/A'}). Your ${s.pkg_name} plan is active until ${expiry}. Thank you!`,
      isp: s
    });

    await require('../config/database').query(
      `UPDATE pppoe_subscribers SET payment_sms_sent_at=NOW(), expiry_reminder_sent=false WHERE id=$1`,
      [subscriberId]
    );
  } catch (err) {
    require('../utils/logger').error('PPPoE payment SMS failed:', err.message);
  }
}



// PUBLIC payment status — no auth, only reveals status (for spinner polling)
router.get('/public-status/:paymentId', async (req, res) => {
  try {
    const r = await query(
      'SELECT id, status, transaction_id, amount, failure_reason FROM payments WHERE id=$1::uuid',
      [req.params.paymentId]
    );
    if (!r.rows[0]) return res.status(404).json({ status: 'not_found' });
    res.json({
      payment_id: r.rows[0].id,
      status: r.rows[0].status,
      transaction_id: r.rows[0].transaction_id,
      amount: r.rows[0].amount,
      failure_reason: r.rows[0].failure_reason
    });
  } catch (err) {
    res.json({ status: 'pending' });
  }
});

module.exports = router;
