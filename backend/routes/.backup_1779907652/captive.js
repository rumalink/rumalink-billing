const express = require('express');
const axios = require('axios');
const { query } = require('../config/database');
const { sendSMS } = require('../utils/sms');
const { generateCode } = require('../utils/vouchers');
const { registerMACAuth, triggerMACReconnect } = require('../utils/macAuth');
const logger = require('../utils/logger');

const router = express.Router();

// ── GET portal data (public) ──────────────────────────────────
router.get('/:ispId', async (req, res, next) => {
  try {
    const isp = await query(
      `SELECT id, company_name, logo_url, support_number FROM isps WHERE id=$1 AND status='active'`,
      [req.params.ispId]
    );
    if (!isp.rows[0]) return res.status(404).json({ error: 'Portal not found' });

    let portal = { rows: [] };
    let payMethods = { rows: [] };
    try { portal = await query('SELECT * FROM isp_captive_portal WHERE isp_id=$1', [req.params.ispId]); } catch(e) {}
    const packages = await query(
      'SELECT id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb FROM hotspot_packages WHERE isp_id=$1 AND is_active=true ORDER BY price ASC',
      [req.params.ispId]
    );
    try {
      payMethods = await query(
        "SELECT id, method_type, label, till_number, paybill_number, account_reference, bank_name, account_name, account_number FROM isp_payment_methods WHERE isp_id=$1 AND is_active=true",
        [req.params.ispId]
      );
    } catch(e) {}

    const portalData = portal.rows[0] || {
      template: 'classic',
      primary_color: '#00d4aa',
      welcome_title: 'Welcome! Connect to WiFi',
      welcome_subtitle: 'Select a package below',
      show_powered_by: true,
      enable_tv_mode: true,
      support_number: null,
      support_label: 'Need Help? Call Us'
    };

    // Merge ISP support_number into portal settings
    if (!portalData.support_number && isp.rows[0].support_number) {
      portalData.support_number = isp.rows[0].support_number;
    }

    res.json({
      isp: isp.rows[0],
      portal: portalData,
      packages: packages.rows,
      payment_methods: payMethods.rows
    });
  } catch (err) { next(err); }
});

// ── REDEEM voucher code ───────────────────────────────────────
router.post('/:ispId/redeem', async (req, res, next) => {
  const { code, mac, phone } = req.body;
  if (!code) return res.status(400).json({ error: 'Voucher code required' });

  try {
    const voucher = await query(`
      SELECT hv.*, hp.name as pkg_name, hp.duration_hours, hp.bandwidth_down_mbps,
             hp.bandwidth_up_mbps, hp.data_limit_mb, hp.mikrotik_profile, hp.price, hp.id as pkg_id
      FROM hotspot_vouchers hv
      JOIN hotspot_packages hp ON hp.id = hv.package_id
      WHERE hv.code=$1 AND hv.isp_id=$2 AND hv.status IN ('unused','active')
    `, [code, req.params.ispId]);

    if (!voucher.rows[0]) return res.status(404).json({ error: 'Invalid or expired voucher code.' });

    const v = voucher.rows[0];
    let expiresAt = v.expires_at;

    if (v.status === 'unused') {
      expiresAt = v.duration_hours ? new Date(Date.now() + v.duration_hours * 3600000) : null;
      await query(
        `UPDATE hotspot_vouchers SET status='active', used_by_mac=$1, used_at=NOW(), expires_at=$2,
         buyer_phone=COALESCE($3,buyer_phone), updated_at=NOW() WHERE id=$4`,
        [mac, expiresAt, phone, v.id]
      );
      await query(
        `INSERT INTO hotspot_sessions (isp_id,voucher_id,nas_id,mac_address,status) VALUES ($1,$2,$3,$4,'active')`,
        [v.isp_id, v.id, v.nas_id, mac]
      );

      if (mac) {
        await registerMACAuth({
          macAddress: mac, ispId: v.isp_id,
          packageData: { id: v.pkg_id, duration_hours: v.duration_hours, bandwidth_down_mbps: v.bandwidth_down_mbps, bandwidth_up_mbps: v.bandwidth_up_mbps, mikrotik_profile: v.mikrotik_profile }
        });
      }

      const recipientPhone = phone || v.buyer_phone;
      if (recipientPhone) {
        try {
          const isp = await query(`SELECT company_name, sms_gateway, sms_api_key, sms_sender_id FROM isps WHERE id=$1`, [v.isp_id]);
          const expMsg = expiresAt ? `Expires: ${new Date(expiresAt).toLocaleString('en-KE', { timeZone: 'Africa/Nairobi' })}` : 'No expiry (unlimited)';
          await sendSMS({
            to: recipientPhone,
            message: `${isp.rows[0]?.company_name} WiFi\nUsername: ${v.code}\nPassword: ${v.code}\nPackage: ${v.pkg_name}\n${expMsg}\nEnjoy!`,
            isp: isp.rows[0]
          });
          await query(`UPDATE hotspot_vouchers SET sms_sent=true WHERE id=$1`, [v.id]);
        } catch (smsErr) { logger.error('Activation SMS failed:', smsErr.message); }
      }
    }

    res.json({
      success: true, username: v.code, password: v.code,
      profile: v.mikrotik_profile, expires_at: expiresAt,
      bandwidth_down: v.bandwidth_down_mbps, bandwidth_up: v.bandwidth_up_mbps,
      package_name: v.pkg_name
    });
  } catch (err) { next(err); }
});

// ── INITIATE MPesa STK Push payment ──────────────────────────
router.post('/:ispId/pay', async (req, res, next) => {
  const { phone, package_id, mac } = req.body;
  if (!phone || !package_id) return res.status(400).json({ error: 'Phone and package required' });

  try {
    const pkg = await query(`SELECT * FROM hotspot_packages WHERE id=$1 AND isp_id=$2`, [package_id, req.params.ispId]);
    if (!pkg.rows[0]) return res.status(404).json({ error: 'Package not found' });

    const isp = await query(`SELECT * FROM isps WHERE id=$1`, [req.params.ispId]);
    const ispData = isp.rows[0];
    const amount = pkg.rows[0].price;

    // ── Load MPesa credentials ──────────────────────────────────
    // Priority: ISP's own mpesa_configs → admin global mpesa_configs → .env
    let mpesaCreds = null;

    // 1. Check ISP-specific mpesa_configs
    const ispMpesa = await query(
      'SELECT * FROM mpesa_configs WHERE isp_id=$1 AND is_active=true LIMIT 1',
      [req.params.ispId]
    );
    if (ispMpesa.rows[0]?.consumer_key) {
      const m = ispMpesa.rows[0];
      mpesaCreds = { shortcode: m.shortcode, consumer_key: m.consumer_key, consumer_secret: m.consumer_secret, passkey: m.passkey, sandbox: m.is_sandbox };
    }

    // 2. Check isp_payment_methods mpesa_stk entry
    if (!mpesaCreds) {
      const pm = await query(
        "SELECT * FROM isp_payment_methods WHERE isp_id=$1 AND method_type='mpesa_stk' AND is_active=true LIMIT 1",
        [req.params.ispId]
      );
      if (pm.rows[0]?.consumer_key && !pm.rows[0].use_admin_credentials) {
        const m = pm.rows[0];
        mpesaCreds = { shortcode: m.shortcode, consumer_key: m.consumer_key, consumer_secret: m.consumer_secret, passkey: m.passkey, sandbox: m.is_sandbox };
      }
    }

    // 3. Fall back to admin global config (saved via Admin → Daraja API page)
    if (!mpesaCreds) {
      const adminMpesa = await query('SELECT * FROM mpesa_configs WHERE is_admin_config=true AND is_active=true LIMIT 1');
      if (adminMpesa.rows[0]?.consumer_key) {
        const m = adminMpesa.rows[0];
        mpesaCreds = { shortcode: m.shortcode, consumer_key: m.consumer_key, consumer_secret: m.consumer_secret, passkey: m.passkey, sandbox: m.is_sandbox };
      }
    }

    // 4. Last resort: process.env (from .env file)
    if (!mpesaCreds) {
      mpesaCreds = {
        shortcode: process.env.MPESA_SHORTCODE,
        consumer_key: process.env.MPESA_CONSUMER_KEY,
        consumer_secret: process.env.MPESA_CONSUMER_SECRET,
        passkey: process.env.MPESA_PASSKEY,
        sandbox: process.env.MPESA_ENVIRONMENT !== 'production'
      };
    }

    if (!mpesaCreds.consumer_key || !mpesaCreds.consumer_secret || !mpesaCreds.shortcode || !mpesaCreds.passkey) {
      return res.status(400).json({ error: 'M-Pesa not configured. The ISP needs to set up Daraja API credentials.' });
    }

    const commRate = parseFloat(ispData.commission_rate) || 0.03;
    // Detect whether the creds we ended up using were the admin global ones
    let usedAdminCreds = false;
    try {
      const adminCheck = await query('SELECT shortcode, consumer_key FROM mpesa_configs WHERE is_admin_config=true AND is_active=true LIMIT 1');
      if (adminCheck.rows[0] && adminCheck.rows[0].consumer_key === mpesaCreds.consumer_key) {
        usedAdminCreds = true;
      }
    } catch (e) { /* non-fatal */ }

    const payment = await query(`
      INSERT INTO payments (isp_id,amount,payment_method,payment_gateway,phone_number,commission_rate,
        commission_amount,net_amount,description,status,used_admin_credentials)
      VALUES ($1::uuid,$2::decimal,'mpesa','mpesa_stk',$3,$4::decimal,$5::decimal,$6::decimal,$7,'pending',$8::boolean) RETURNING id
    `, [req.params.ispId, amount, phone, commRate, amount * commRate, amount - (amount * commRate),
        `Hotspot - ${pkg.rows[0].name}`, usedAdminCreds]);

    const paymentId = payment.rows[0].id;

    // STK Push
    const baseUrl = mpesaCreds.sandbox ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';

    let accessToken;
    try {
      const tokenRes = await axios.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, {
        headers: { Authorization: `Basic ${Buffer.from(`${mpesaCreds.consumer_key}:${mpesaCreds.consumer_secret}`).toString('base64')}` },
        timeout: 10000
      });
      accessToken = tokenRes.data.access_token;
    } catch (tokenErr) {
      await query(`UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2`,
        ['M-Pesa token fetch failed: ' + tokenErr.message, paymentId]);
      return res.status(502).json({ error: 'Failed to reach M-Pesa. Please try again or pay via alternative method.' });
    }

    const timestamp = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
    const password = Buffer.from(`${mpesaCreds.shortcode}${mpesaCreds.passkey}${timestamp}`).toString('base64');
    const normalizedPhone = phone.replace(/^0/, '254').replace(/^\+/, '');

    let stkRes;
    try {
      stkRes = await axios.post(`${baseUrl}/mpesa/stkpush/v1/processrequest`, {
        BusinessShortCode: mpesaCreds.shortcode,
        Password: password,
        Timestamp: timestamp,
        TransactionType: 'CustomerPayBillOnline',
        Amount: Math.ceil(amount),
        PartyA: normalizedPhone,
        PartyB: mpesaCreds.shortcode,
        PhoneNumber: normalizedPhone,
        CallBackURL: `${process.env.BASE_URL}/api/captive/${req.params.ispId}/callback/${paymentId}`,
        AccountReference: paymentId.substring(0, 12),
        TransactionDesc: `WiFi - ${pkg.rows[0].name}`
      }, { headers: { Authorization: `Bearer ${accessToken}` }, timeout: 15000 });
    } catch (stkErr) {
      const errMsg = stkErr.response?.data?.errorMessage || stkErr.message;
      await query(`UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2`, [errMsg, paymentId]);
      return res.status(502).json({ error: `M-Pesa STK push failed: ${errMsg}` });
    }

    await query(
      `INSERT INTO mpesa_transactions (isp_id,payment_id,checkout_request_id,merchant_request_id,amount,phone,status)
       VALUES ($1,$2,$3,$4,$5,$6,'pending')`,
      [req.params.ispId, paymentId, stkRes.data.CheckoutRequestID, stkRes.data.MerchantRequestID, amount, phone]
    );

    if (mac) {
      await query(
        `UPDATE payments SET metadata=jsonb_build_object('mac',$1,'package_id',$2) WHERE id=$3`,
        [mac, package_id, paymentId]
      );
    }

    res.json({
      payment_id: paymentId,
      checkout_request_id: stkRes.data.CheckoutRequestID,
      message: `Check ${normalizedPhone} for M-Pesa prompt. Enter your PIN to complete. Your voucher will be sent via SMS.`
    });
  } catch (err) {
    logger.error('Captive pay error:', err.response?.data || err.message);
    next(err);
  }
});

// ── CHECK payment status (polling from portal) ────────────────
router.get('/:ispId/payment-status/:paymentId', async (req, res, next) => {
  try {
    const p = await query(`SELECT status, transaction_id FROM payments WHERE id=$1 AND isp_id=$2`,
      [req.params.paymentId, req.params.ispId]);
    if (!p.rows[0]) return res.status(404).json({ error: 'Payment not found' });

    // Also check mpesa_transactions for receipt
    const mt = await query(`SELECT mpesa_receipt, status FROM mpesa_transactions WHERE payment_id=$1 ORDER BY created_at DESC LIMIT 1`,
      [req.params.paymentId]);

    res.json({
      status: p.rows[0].status,
      transaction_id: p.rows[0].transaction_id || mt.rows[0]?.mpesa_receipt,
      mpesa_receipt: mt.rows[0]?.mpesa_receipt
    });
  } catch (err) { next(err); }
});

// ── MPesa callback ────────────────────────────────────────────
router.post('/:ispId/callback/:paymentId', async (req, res) => {
  const { Body } = req.body;
  const { ispId, paymentId } = req.params;

  try {
    const cb = Body?.stkCallback;
    if (cb?.ResultCode === 0) {
      const meta = cb.CallbackMetadata?.Item || [];
      const getMeta = n => meta.find(i => i.Name === n)?.Value;
      const mpesaCode = getMeta('MpesaReceiptNumber');
      const amount = getMeta('Amount');
      const phone = getMeta('PhoneNumber')?.toString();

      await query(`UPDATE payments SET status='paid', transaction_id=$1, paid_at=NOW() WHERE id=$2`,
        [mpesaCode, paymentId]);
      await query(`UPDATE mpesa_transactions SET status='completed', mpesa_receipt=$1, result_code=0, result_desc='Success', transaction_date=NOW() WHERE payment_id=$2`,
        [mpesaCode, paymentId]);

      const paymentData = await query(
        `SELECT *, metadata->>'mac' as mac_addr, metadata->>'package_id' as pkg_id FROM payments WHERE id=$1`,
        [paymentId]
      );
      const p = paymentData.rows[0];
      if (!p) return res.json({ ResultCode: 0, ResultDesc: 'Accepted' });

      // Update ISP wallet
      await query(
        `UPDATE isps SET wallet_balance=wallet_balance+$1, total_earned=total_earned+$2 WHERE id=$3`,
        [p.net_amount, p.amount, ispId]
      );
      await query(
        `INSERT INTO commissions (isp_id,payment_id,amount,rate) VALUES ($1,$2,$3,$4)`,
        [ispId, paymentId, p.commission_amount, p.commission_rate]
      );

      const isp = await query(`SELECT * FROM isps WHERE id=$1`, [ispId]);
      const ispData = isp.rows[0];

      // Forward notification if admin creds were used
      if (p.used_admin_credentials) {
        const fwMethod = await query(
          `SELECT * FROM isp_payment_methods WHERE isp_id=$1 AND is_active=true ORDER BY is_default DESC LIMIT 1`,
          [ispId]
        );
        if (fwMethod.rows[0]) {
          const fwDest = `${fwMethod.rows[0].method_type}:${fwMethod.rows[0].till_number || fwMethod.rows[0].paybill_number || fwMethod.rows[0].account_number}`;
          await query(
            `UPDATE payments SET forwarded_to=$1, forward_status='queued', forwarded_at=NOW() WHERE id=$2`,
            [fwDest, paymentId]
          );
          await query(
            `INSERT INTO notifications (type,title,message) VALUES ('warning','Forward Payment',$1)`,
            [`Forward KES ${p.net_amount} to ${ispData.company_name} — ${fwMethod.rows[0].method_type}. Ref: ${mpesaCode}`]
          );
        }
      }

      // Auto-generate voucher
      const pkg = p.pkg_id
        ? await query(`SELECT * FROM hotspot_packages WHERE id=$1`, [p.pkg_id])
        : await query(`SELECT * FROM hotspot_packages WHERE isp_id=$1 AND is_active=true ORDER BY price ASC LIMIT 1`, [ispId]);

      if (pkg.rows[0]) {
        const pkgData = pkg.rows[0];
        const code = generateCode('HS', 8);
        const expiresAt = pkgData.duration_hours ? new Date(Date.now() + pkgData.duration_hours * 3600000) : null;
        const buyerPhone = phone ? `254${phone.toString().slice(-9)}` : null;

        await query(`
          INSERT INTO hotspot_vouchers (isp_id,package_id,code,status,is_paid,amount_paid,payment_method,payment_reference,buyer_phone,sms_sent)
          VALUES ($1,$2,$3,'active',true,$4,'mpesa',$5,$6,false)
        `, [ispId, pkgData.id, code, amount, mpesaCode, buyerPhone]);

        if (buyerPhone) {
          const expMsg = expiresAt ? `Expires: ${new Date(expiresAt).toLocaleString('en-KE', { timeZone: 'Africa/Nairobi' })}` : 'No expiry';
          try {
            await sendSMS({
              to: buyerPhone,
              message: `${ispData.company_name} WiFi\nUsername: ${code}\nPassword: ${code}\nPackage: ${pkgData.name}\n${expMsg}\nEnjoy!`,
              isp: ispData
            });
            await query(`UPDATE hotspot_vouchers SET sms_sent=true WHERE code=$1`, [code]);
          } catch (smsErr) { logger.error('Post-payment SMS failed:', smsErr.message); }
        }

        if (p.mac_addr) {
          await triggerMACReconnect({
            ispId, macAddress: p.mac_addr,
            packageData: { id: pkgData.id, duration_hours: pkgData.duration_hours, bandwidth_down_mbps: pkgData.bandwidth_down_mbps, bandwidth_up_mbps: pkgData.bandwidth_up_mbps, mikrotik_profile: pkgData.mikrotik_profile }
          });
        }
      }

      await query(
        `INSERT INTO notifications (isp_id,type,title,message) VALUES ($1,'success','Payment Received',$2)`,
        [ispId, `KES ${amount} received via M-Pesa (${mpesaCode})`]
      );
    } else {
      await query(
        `UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2`,
        [Body?.stkCallback?.ResultDesc || 'Payment cancelled', paymentId]
      );
      await query(
        `UPDATE mpesa_transactions SET status='failed', result_code=$1, result_desc=$2 WHERE payment_id=$3`,
        [cb?.ResultCode, cb?.ResultDesc, paymentId]
      );
    }
  } catch (err) { logger.error('Captive callback error:', err.message); }
  res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
});

module.exports = router;
