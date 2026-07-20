const express = require('express');
const { effectiveHotspotRate } = require('../utils/effectiveRate');
const axios = require('axios');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();

// ── License payment callback (PUBLIC; Daraja posts STK result here) ──
router.post('/license/callback/:paymentId', async (req, res) => {
  const log = require('../utils/logger');
  const { paymentId } = req.params;
  try {
    const body = req.body || {};
    const cb = body.Body && body.Body.stkCallback;
    const resultCode = cb ? cb.ResultCode : (body.ResultCode != null ? body.ResultCode : 1);
    const payRes = await query("SELECT * FROM payments WHERE id=$1::uuid", [paymentId]);
    const pay = payRes.rows[0];
    if (!pay) return res.json({ ok: true });

    if (String(resultCode) === '0') {
      let receipt = null;
      try { const items = cb.CallbackMetadata.Item; const r = items.find(i => i.Name === 'MpesaReceiptNumber'); receipt = r && r.Value; } catch (e) {}
      if (pay.status !== 'paid') {
        await query("UPDATE payments SET status='paid', paid_at=NOW(), transaction_id=COALESCE($2,transaction_id) WHERE id=$1::uuid", [paymentId, receipt]);
        const billing = require('../utils/billing');
        const ispRes = await query("SELECT id, license_expires_at FROM isps WHERE id=$1::uuid", [pay.isp_id]);
        const isp = ispRes.rows[0];
        if (isp) {
          const now = new Date();
          const newExp = billing.nextExpiry(isp.license_expires_at || now, now);
          await query("UPDATE isps SET license_expires_at=$1, billing_window_start=$2, license_status='active' WHERE id=$3::uuid",
            [newExp.toISOString(), now.toISOString(), pay.isp_id]);
          await query("UPDATE isp_platform_invoices SET status='paid', paid_at=NOW(), payment_id=$1 WHERE isp_id=$2::uuid AND status='pending'",
            [paymentId, pay.isp_id]).catch(() => {});
          await query("INSERT INTO notifications (isp_id,type,title,message) VALUES ($1::uuid,'success','License Renewed',$2)",
            [pay.isp_id, 'Your platform license is renewed until ' + newExp.toLocaleString() + '.']).catch(() => {});
          log.info('[BILLING] license renewed for ' + pay.isp_id + ' -> ' + newExp.toISOString());
        }
      }
    } else if (pay.status !== 'paid') {
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid",
        [String((cb && cb.ResultDesc) || 'Payment cancelled').slice(0, 200), paymentId]).catch(() => {});
    }
    res.json({ ok: true });
  } catch (e) {
    require('../utils/logger').error('[BILLING] license callback: ' + e.message);
    res.json({ ok: true });
  }
});


// ── Jenga (Equity / Finserve) IPN — PUBLIC endpoint Jenga POSTs payment results to ──
// Registered at JengaHQ as the IPN URL. Matches by gateway_reference (set when we
// initiate the STK), marks the payment paid idempotently, and always acks.
// ── RL_INTASEND_IPN: IntaSend collection webhook ──
// IntaSend funds land in the PLATFORM admin account, so unlike Jenga we must CREDIT the
// ISP's wallet here (net of the IntaSend fee + platform commission). The ISP withdraws it later.
router.post('/intasend/ipn', async (req, res) => {
  const log = require('../utils/logger');
  try {
    // RL_IPN_V2: IntaSend posts a FLAT payload: {invoice_id, state, api_ref, value,
    // net_amount, challenge, ...}. Accept both flat and nested shapes.
    const b = req.body || {};
    const inv = b.invoice || b;
    const apiRef = b.api_ref || inv.api_ref || null;
    const invoiceId = inv.invoice_id || b.invoice_id || null;
    const state = String(inv.state || b.state || '').toUpperCase();
    if (b.challenge) log.info('[INTASEND-IPN] challenge=' + b.challenge);
    // RL_IPN_V3: IntaSend's collection payload does NOT include a `challenge` field
    // (confirmed from a live delivery). Demanding one 401'd every webhook. So: if a
    // challenge IS present it must match; if it's absent we instead AUTHENTICATE the
    // event by re-querying IntaSend's status API below — a forger can't fake that.
    try {
      // RL_CHALLENGE_SOFT: the challenge is a convenience check, NOT the security boundary —
      // the event is authenticated below by re-querying IntaSend's own status API (a forger
      // cannot make IntaSend report COMPLETE). So a challenge mismatch must NOT 401 a real
      // payment. It once did exactly that: stored "Benrade@..." vs IntaSend's lowercased
      // "benrade@...", and a paying customer was left walled. Normalise the compare, and on a
      // mismatch WARN and fall through to the authenticated status check rather than rejecting.
      const _got = b.challenge || (inv && inv.challenge) || null;
      if (_got) {
        const _cr = await query("SELECT value FROM platform_secrets WHERE key='intasend_webhook_challenge' LIMIT 1");
        const _expected = _cr.rows[0] && _cr.rows[0].value;
        const _norm = x => String(x == null ? '' : x).trim().toLowerCase();
        if (_expected && _norm(_got) !== _norm(_expected)) {
          log.warn('[INTASEND-IPN] challenge mismatch (got=' + _got + ') — not rejecting; ' +
                   'the event is verified against IntaSend status API below');
        }
      }
    } catch (ce) { log.warn('[INTASEND-IPN] challenge check error: ' + ce.message); }
    const receipt = inv.mpesa_reference || b.mpesa_reference || inv.provider_reference || null;
    const success = state === 'COMPLETE' || state === 'COMPLETED' || state === 'PAID';
    log.info(`[INTASEND-IPN] ref=${apiRef} invoice=${invoiceId} state=${state} success=${success}`);

    if (!success) {
      if (state === 'FAILED') {
        await query("UPDATE payments SET status='failed', failure_reason=$1, updated_at=NOW() WHERE (gateway_reference=$2 OR transaction_id=$3) AND status='pending'",
          [('IntaSend: ' + state).slice(0,240), apiRef, String(invoiceId||'')]).catch(()=>{});
      }
      return res.json({ status: true, message: 'Received' });
    }

    // Find the pending payment (idempotent — only act if not already paid).
    const pr = await query(
      "SELECT * FROM payments WHERE (gateway_reference=$1 OR transaction_id=$2) AND payment_gateway='intasend' LIMIT 1",
      [apiRef, String(invoiceId||'')]
    );
    const p = pr.rows[0];
    if (!p) { log.warn('[INTASEND-IPN] no matching payment for ref=' + apiRef); return res.json({ status: true, message: 'Received' }); }
    if (p.status === 'paid') { return res.json({ status: true, message: 'Already processed' }); }

    // RL_IPN_V3: confirm with IntaSend before crediting — this is what authenticates the
    // event (a forged POST cannot make IntaSend's own status API say COMPLETE).
    try {
      const _isc = require('../utils/intasend-client');
      const _st = await _isc.collectionStatus(invoiceId || p.transaction_id);
      if (!_st.isPaid) {
        log.warn('[INTASEND-IPN] IntaSend does not confirm COMPLETE (state=' + _st.state + ') — ignoring');
        return res.json({ status: true, message: 'Not confirmed' });
      }
    } catch (ve) {
      log.warn('[INTASEND-IPN] verify failed, deferring to poller: ' + ve.message);
      return res.json({ status: true, message: 'Deferred' });
    }

    await query("UPDATE payments SET status='paid', paid_at=NOW(), transaction_id=COALESCE($2,transaction_id), updated_at=NOW() WHERE id=$1::uuid",
      [p.id, receipt || String(invoiceId||'')]);
    
    // RL_IPN_PPPOE: a PPPoE subscriber must be RECONNECTED, not merely marked paid.
    // This IPN was written for hotspot vouchers and knows nothing about subscribers — so an
    // ISP whose gateway is IntaSend would take the customer's money and leave them walled:
    // paid, confirmed, and still with no internet. The Daraja path avoids this only because
    // the PPPoE portal has its own callback that calls onPaid(). Run the SAME function here.
    try {
      const _pp = await query(
        "SELECT id, subscriber_id FROM payments WHERE (gateway_reference=$1 OR transaction_id=$2) AND subscriber_id IS NOT NULL LIMIT 1",
        [apiRef, String(invoiceId || '')]);
      if (_pp.rows[0] && _pp.rows[0].subscriber_id) {
        const _portal = require('./pppoePortal');
        if (typeof _portal.onPaid === 'function') {
          await _portal.onPaid(_pp.rows[0].id, receipt);
          log.info('[INTASEND-IPN] PPPoE subscriber reactivated for payment ' + _pp.rows[0].id +
                  ' — walled garden lifted');
        } else {
          log.error('[INTASEND-IPN] onPaid not exported — subscriber PAID BUT STILL BLOCKED: ' +
                    _pp.rows[0].id);
        }
      }
    } catch (pe) {
      // Loud, not silent: a customer has paid and may still be cut off.
      log.error('[INTASEND-IPN] PPPoE reactivation FAILED: ' + pe.message);
    }

    // RL_IPN_CREDIT_HELPER: single idempotent credit path (wallet+commission+ledger+notify).
    await require('../utils/wallet-credit').creditWalletOnce(p.id);

    // Mark the voucher paid so the portal can release access.
    await query("UPDATE hotspot_vouchers SET is_paid=true, amount_paid=$1 WHERE payment_id=$2::uuid", [p.amount, p.id]).catch(()=>{});
    // RL_IPN_V3: ACTIVATE the voucher + sync RADIUS — without this the customer pays and
    // never gets online (voucher stayed status=unused, expires_at=NULL).
    try { await require('../utils/intasend-activate').activateVoucher(p.id); }
    catch (ae) { log.error('[INTASEND-IPN] activation failed: ' + ae.message); }
    await query("UPDATE mpesa_transactions SET status='completed' WHERE payment_id=$1::uuid", [p.id]).catch(()=>{});

    log.info(`[INTASEND-IPN] credited ISP ${p.isp_id} net=${p.net_amount} payment=${p.id}`);
    res.json({ status: true, message: 'Received' });
  } catch (e) {
    require('../utils/logger').error('[INTASEND-IPN] ' + e.message);
    res.json({ status: true, message: 'Received' });
  }
});

router.post('/jenga/ipn', async (req, res) => {
  const log = require('../utils/logger');
  try {
    const b = req.body || {};
    const tx = b.transaction || {};
    const ref = b.transactionReference || tx.reference || b.reference || (b.payment && b.payment.ref) || null;
    const codeOk = (b.code === 3) || (b.code === '3');
    const statusStr = String(tx.status || b.message || (codeOk ? 'SUCCESS' : '')).toUpperCase();
    const success = (b.status === true && codeOk) || statusStr.includes('SUCCESS') || statusStr.includes('SETTLED');
    const receipt = b.telcoReference || tx.reference || null;
    const amount = b.requestAmount || b.debitedAmount || tx.amount || null;
    log.info(`[JENGA-IPN] ref=${ref} success=${success} receipt=${receipt} amount=${amount}`);
    if (ref && success) {
      await query(
        "UPDATE payments SET status='paid', paid_at=NOW(), transaction_id=COALESCE($2,transaction_id), updated_at=NOW() WHERE gateway_reference=$1 AND status<>'paid'",
        [ref, receipt]
      ).catch(e => log.warn('[JENGA-IPN] update failed: ' + e.message));
    }
    res.json({ status: true, message: 'Received' });
  } catch (e) {
    require('../utils/logger').error('[JENGA-IPN] ' + e.message);
    res.json({ status: true, message: 'Received' });
  }
});


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
    const commissionRate = await effectiveHotspotRate(isp.rows[0].commission_rate);
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
      ? await effectiveHotspotRate(isp.rows[0].commission_rate)
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
  // Customer payments only — exclude SMS credit topups, platform charges, and admin charges.
  let where = "WHERE p.isp_id = $1 AND (p.description IS NULL OR (p.description NOT LIKE 'SMS topup%' AND p.description NOT LIKE 'Platform charge%' AND p.description NOT LIKE 'License%')) AND COALESCE(p.payment_method,'') != 'admin_charge' AND COALESCE(p.payment_gateway,'') != 'platform' AND COALESCE(p.payment_method,'') != 'platform'";
  const params = [req.user.ispId];
  let idx = 2;
  if (status) { where += ` AND p.status = $${idx++}`; params.push(status); }
  if (method) { where += ` AND p.payment_method = $${idx++}`; params.push(method); }

  try {
    const result = await query(`
      SELECT p.*,
             sub.username as subscriber_username, sub.full_name as subscriber_name,
             COALESCE(hv1.code, hv2.code) as voucher_code,
             COALESCE(p.mpesa_phone, p.phone_number, sub.phone) as payer_phone,
             COALESCE(NULLIF(p.payment_method,''), p.payment_gateway, 'mpesa_stk') as method_display,
             hp.name as package_name
      FROM payments p
      LEFT JOIN pppoe_subscribers sub ON sub.id = p.subscriber_id
      LEFT JOIN hotspot_vouchers hv1 ON hv1.id = p.voucher_id
      LEFT JOIN hotspot_vouchers hv2 ON hv2.payment_id = p.id
      LEFT JOIN hotspot_packages hp ON hp.id = COALESCE(hv1.package_id, hv2.package_id)
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
async function stkQueryAndUpdate(paymentId) {
  // When a payment is still pending, actively ask Safaricom if it completed.
  try {
    const tx = await query(
      "SELECT mt.checkout_request_id, mt.isp_id FROM mpesa_transactions mt WHERE mt.payment_id=$1::uuid ORDER BY mt.created_at DESC LIMIT 1",
      [paymentId]
    );
    if (!tx.rows[0] || !tx.rows[0].checkout_request_id) return;
    const checkoutId = tx.rows[0].checkout_request_id;

    // Get credentials (admin global, used for most STK)
    const cfgRes = await query("SELECT * FROM mpesa_configs WHERE is_admin_config=true AND is_active=true LIMIT 1");
    const cfg = cfgRes.rows[0];
    if (!cfg || !cfg.consumer_key) return;

    const baseUrl = cfg.is_sandbox ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';
    const tok = await axios.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, {
      headers: { Authorization: `Basic ${Buffer.from(`${cfg.consumer_key}:${cfg.consumer_secret}`).toString('base64')}` },
      timeout: 10000
    });
    const ts = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
    const pwd = Buffer.from(`${cfg.shortcode}${cfg.passkey}${ts}`).toString('base64');

    const q = await axios.post(`${baseUrl}/mpesa/stkpushquery/v1/query`, {
      BusinessShortCode: cfg.shortcode, Password: pwd, Timestamp: ts, CheckoutRequestID: checkoutId
    }, { headers: { Authorization: `Bearer ${tok.data.access_token}` }, timeout: 12000 });

    // ResultCode 0 = success; others = failed/pending
    if (q.data.ResultCode === '0' || q.data.ResultCode === 0) {
      await query("UPDATE payments SET status='paid', paid_at=NOW() WHERE id=$1::uuid AND status='pending'", [paymentId]);
      await query("UPDATE mpesa_transactions SET status='completed' WHERE payment_id=$1::uuid", [paymentId]).catch(()=>{});
    } else {
      // Only mark FAILED on KNOWN user-cancel/decline codes.
      // Everything else (still processing, timeout, etc.) stays pending — spinner will keep polling.
      const code = String(q.data.ResultCode || '');
      // 1032 = cancelled by user, 1031 = request cancelled
      const userCancelCodes = ['1032', '1031'];
      const desc = String(q.data.ResultDesc || '').toLowerCase();
      const isUserCancel = userCancelCodes.includes(code) || desc.includes('cancelled') || desc.includes('canceled');
      if (isUserCancel) {
        await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid AND status='pending'",
          [String(q.data.ResultDesc || 'Cancelled').substring(0,200), paymentId]).catch(()=>{});
      }
      // Other codes (500.001.1001 "processing", 1037 "timeout", etc) — leave as pending, spinner re-polls
    }
  } catch (e) {
    // STK query throws while transaction still processing — that's fine, stay pending
  }
}

router.get('/public-status/:paymentId', async (req, res) => {
  try {
    let r = await query(
      'SELECT id, status, transaction_id, amount, failure_reason FROM payments WHERE id=$1::uuid',
      [req.params.paymentId]
    );
    if (!r.rows[0]) return res.status(404).json({ status: 'not_found' });

    // Self-heal: if still pending, actively query Safaricom (callback may have missed)
    if (r.rows[0].status === 'pending') {
      await stkQueryAndUpdate(req.params.paymentId);
      r = await query('SELECT id, status, transaction_id, amount, failure_reason, isp_id FROM payments WHERE id=$1::uuid', [req.params.paymentId]);
    }
    // If marked paid but voucher not yet activated (callback never fired), activate now
    if (r.rows[0].status === 'paid') {
      try {
        const vCheck = await query("SELECT id, expires_at FROM hotspot_vouchers WHERE payment_id = $1::uuid LIMIT 1", [req.params.paymentId]);
        if (vCheck.rows[0] && !vCheck.rows[0].expires_at) {
          // Voucher exists but never activated -> trigger activation
          const pRow = await query("SELECT isp_id FROM payments WHERE id = $1::uuid", [req.params.paymentId]);
          if (pRow.rows[0]) {
            const ispId = pRow.rows[0].isp_id;
            require('../utils/logger').warn(`[SELF-HEAL] Payment ${req.params.paymentId} paid but voucher not activated. Triggering manual activation.`);
            // Fire-and-forget: call our own activate endpoint
            const axios = require('axios');
            const PORT = process.env.PORT || 5000;
            axios.post(`http://localhost:${PORT}/api/captive/${ispId}/activate-payment/${req.params.paymentId}`, {}, { timeout: 12000 })
              .then(()=>require('../utils/logger').info(`[SELF-HEAL] Manual activation completed for ${req.params.paymentId}`))
              .catch(e=>require('../utils/logger').error(`[SELF-HEAL] Manual activation failed: ${e.message}`));
          }
        }
      } catch(e) {
        require('../utils/logger').error(`[SELF-HEAL] check failed: ${e.message}`);
      }
    }
    // Look up voucher code (for captive auto-login after payment)
    let voucher_code = null;
    try {
      const v = await query("SELECT code, password, isp_id FROM hotspot_vouchers WHERE payment_id = $1::uuid LIMIT 1", [req.params.paymentId]); /* RL_PAY_AUTHZ */
      if (v.rows[0]) {
        voucher_code = v.rows[0].code;
        var _rlShort = String(v.rows[0].isp_id).replace(/-/g,'').slice(0,8).toLowerCase();
        var _rlUser = v.rows[0].code + '@' + _rlShort;
        var _rlPass = v.rows[0].password || v.rows[0].code;
        req._rlRadius = { username: _rlUser, password: _rlPass };
      }
    } catch(e) {}
    res.json({
      payment_id: r.rows[0].id,
      status: r.rows[0].status,
      transaction_id: r.rows[0].transaction_id,
      amount: r.rows[0].amount,
      failure_reason: r.rows[0].failure_reason,
      voucher_code: voucher_code,
      radius_username: (req._rlRadius ? req._rlRadius.username : null),
      radius_password: (req._rlRadius ? req._rlRadius.password : null)
    });
  } catch (err) {
    res.json({ status: 'pending' });
  }
});

module.exports = router;
