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
  // Validate UUID format to prevent SQL errors
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(req.params.ispId)) {
    return res.status(400).json({ error: 'Invalid ISP ID format' });
  }
  try {
    const isp = await query(
      "SELECT id, company_name, logo_url, support_number FROM isps WHERE id=$1::uuid AND status='active'",
      [req.params.ispId]
    );
    if (!isp.rows[0]) return res.status(404).json({ error: 'Portal not found' });

    let portal = { rows: [] };
    let payMethods = { rows: [] };
    try { portal = await query('SELECT * FROM isp_captive_portal WHERE isp_id=$1::uuid', [req.params.ispId]); } catch(e) {}
    const packages = await query(
      'SELECT id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb FROM hotspot_packages WHERE isp_id=$1::uuid AND is_active=true ORDER BY price ASC',
      [req.params.ispId]
    );
    try {
      payMethods = await query(
        "SELECT id, method_type, label, till_number, paybill_number, account_reference, bank_name, account_name, account_number FROM isp_payment_methods WHERE isp_id=$1::uuid AND is_active=true",
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
      WHERE hv.code=$1 AND hv.isp_id=$2::uuid AND hv.status IN ('unused','active')
    `, [code, req.params.ispId]);

    if (!voucher.rows[0]) return res.status(404).json({ error: 'Invalid or expired voucher code.' });

    const v = voucher.rows[0];
    let expiresAt = v.expires_at;

    if (v.status === 'unused') {
      expiresAt = v.duration_hours ? new Date(Date.now() + v.duration_hours * 3600000) : null;
      await query(
        `UPDATE hotspot_vouchers SET status='active', used_by_mac=$1, used_at=NOW(), expires_at=$2,
         buyer_phone=COALESCE($3,buyer_phone), updated_at=NOW() WHERE id=$4::uuid`,
        [mac, expiresAt, phone, v.id]
      );
      await query(
        "INSERT INTO hotspot_sessions (isp_id,voucher_id,nas_id,mac_address,status) VALUES ($1::uuid,$2::uuid,$3,$4,'active')",
        [v.isp_id, v.id, v.nas_id, mac]
      );

      if (mac) {
        await registerMACAuth({
          macAddress: mac, ispId: v.isp_id,
          packageData: { id: v.pkg_id, duration_hours: v.duration_hours, bandwidth_down_mbps: v.bandwidth_down_mbps, bandwidth_up_mbps: v.bandwidth_up_mbps, mikrotik_profile: v.mikrotik_profile }
        }).catch(() => {});
      }
    }

    res.json({
      success: true,
      message: 'Connected! You may now browse.',
      voucher: { code: v.code, package: v.pkg_name, expires_at: expiresAt }
    });
  } catch (err) { next(err); }
});

// ── LOGIN with username + password (vouchers re-used) ────────
// Allows a customer who was disconnected to reconnect using their voucher code
router.post('/:ispId/login', async (req, res, next) => {
  const { username, password, mac } = req.body;
  if (!username) return res.status(400).json({ error: 'Username (voucher code) required' });

  try {
    // For RumaLink, the "username" is the voucher code
    // The "password" can be the same code, or the phone number used to purchase it
    const code = username.trim().toUpperCase();
    const voucher = await query(`
      SELECT hv.*, hp.name as pkg_name, hp.duration_hours, hp.bandwidth_down_mbps,
             hp.bandwidth_up_mbps, hp.data_limit_mb, hp.mikrotik_profile, hp.id as pkg_id
      FROM hotspot_vouchers hv
      JOIN hotspot_packages hp ON hp.id = hv.package_id
      WHERE hv.code=$1 AND hv.isp_id=$2::uuid AND hv.status IN ('unused','active')
    `, [code, req.params.ispId]);

    if (!voucher.rows[0]) {
      return res.status(404).json({ error: 'Invalid voucher code. Check spelling or buy a new package.' });
    }

    const v = voucher.rows[0];

    // Check expiry
    if (v.expires_at && new Date(v.expires_at) < new Date()) {
      return res.status(410).json({ error: 'This voucher has expired. Please purchase a new one.' });
    }

    // If password provided, validate it matches either the code or buyer_phone
    if (password) {
      const passClean = password.replace(/\D/g, '');
      const buyerClean = (v.buyer_phone || '').replace(/\D/g, '');
      const matchesCode = password.trim().toUpperCase() === v.code;
      const matchesPhone = buyerClean && (
        passClean === buyerClean ||
        passClean === buyerClean.replace(/^254/, '0') ||
        ('254' + passClean.replace(/^0/, '')) === buyerClean
      );
      if (!matchesCode && !matchesPhone && password.trim() !== '') {
        // Allow login anyway with just the code as username — password optional
        // Don't reject if password is wrong, just log it
        logger.info(`Login: password mismatch for voucher ${code}, allowing by code-only`);
      }
    }

    let expiresAt = v.expires_at;
    if (v.status === 'unused') {
      expiresAt = v.duration_hours ? new Date(Date.now() + v.duration_hours * 3600000) : null;
      await query(
        `UPDATE hotspot_vouchers SET status='active', used_by_mac=COALESCE($1, used_by_mac),
         used_at=NOW(), expires_at=$2, updated_at=NOW() WHERE id=$3::uuid`,
        [mac, expiresAt, v.id]
      );
    } else if (mac && v.used_by_mac && v.used_by_mac !== mac) {
      // Already in use by another MAC — update to allow reconnection from new device
      await query(
        "UPDATE hotspot_vouchers SET used_by_mac=$1, updated_at=NOW() WHERE id=$2::uuid",
        [mac, v.id]
      );
    }

    // Register MAC for hotspot auto-login
    if (mac) {
      await registerMACAuth({
        macAddress: mac, ispId: v.isp_id,
        packageData: { id: v.pkg_id, duration_hours: v.duration_hours, bandwidth_down_mbps: v.bandwidth_down_mbps, bandwidth_up_mbps: v.bandwidth_up_mbps, mikrotik_profile: v.mikrotik_profile }
      }).catch(e => logger.warn('MAC register:', e.message));
    }

    // Trigger reconnect on MikroTik via CoA
    if (mac) {
      triggerMACReconnect({ macAddress: mac, ispId: v.isp_id }).catch(()=>{});
    }

    res.json({
      success: true,
      message: 'Reconnected successfully! You can now browse.',
      voucher: {
        code: v.code,
        package: v.pkg_name,
        expires_at: expiresAt,
        bandwidth_down: v.bandwidth_down_mbps,
        bandwidth_up: v.bandwidth_up_mbps
      }
    });
  } catch (err) {
    logger.error('Captive login error:', err.message);
    next(err);
  }
});

// ── PAY (initiate STK push) ───────────────────────────────────
router.post('/:ispId/pay', async (req, res) => {
  const { phone, package_id, mac } = req.body;
  if (!phone || !package_id) return res.status(400).json({ error: 'Phone and package required' });

  // Normalize phone
  const normalizedPhone = String(phone).replace(/\D/g, '').replace(/^0/, '254').replace(/^\+/, '');
  if (!/^254[17]\d{8}$/.test(normalizedPhone)) {
    return res.status(400).json({ error: `Invalid phone format. Use 0712345678 or 254712345678. Got: ${phone}` });
  }

  try {
    const pkg = await query(
      'SELECT * FROM hotspot_packages WHERE id=$1::uuid AND isp_id=$2::uuid',
      [package_id, req.params.ispId]
    );
    if (!pkg.rows[0]) return res.status(404).json({ error: 'Package not found' });

    const isp = await query('SELECT * FROM isps WHERE id=$1::uuid', [req.params.ispId]);
    if (!isp.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    const ispData = isp.rows[0];
    const amount = parseFloat(pkg.rows[0].price);

    // ── Load MPesa credentials (priority chain) ───────────────
    let mpesaCreds = null;
    let usedAdminCreds = false;

    // 1. ISP-specific mpesa_configs
    try {
      const ispMpesa = await query(
        "SELECT * FROM mpesa_configs WHERE isp_id=$1::uuid AND is_active=true AND COALESCE(is_admin_config,false)=false LIMIT 1",
        [req.params.ispId]
      );
      if (ispMpesa.rows[0] && ispMpesa.rows[0].consumer_key) {
        const m = ispMpesa.rows[0];
        mpesaCreds = {
          shortcode: m.shortcode, consumer_key: m.consumer_key,
          consumer_secret: m.consumer_secret, passkey: m.passkey, sandbox: m.is_sandbox
        };
      }
    } catch(e) {}

    // 2. Fall back to admin global Daraja
    if (!mpesaCreds) {
      try {
        const admin = await query(
          'SELECT * FROM mpesa_configs WHERE is_admin_config=true AND is_active=true LIMIT 1'
        );
        if (admin.rows[0] && admin.rows[0].consumer_key) {
          const m = admin.rows[0];
          mpesaCreds = {
            shortcode: m.shortcode, consumer_key: m.consumer_key,
            consumer_secret: m.consumer_secret, passkey: m.passkey, sandbox: m.is_sandbox
          };
          usedAdminCreds = true;
        }
      } catch(e) {}
    }

    // 3. Last resort: process.env
    if (!mpesaCreds) {
      mpesaCreds = {
        shortcode: process.env.MPESA_SHORTCODE,
        consumer_key: process.env.MPESA_CONSUMER_KEY,
        consumer_secret: process.env.MPESA_CONSUMER_SECRET,
        passkey: process.env.MPESA_PASSKEY,
        sandbox: process.env.MPESA_ENVIRONMENT !== 'production'
      };
      usedAdminCreds = true;
    }

    if (!mpesaCreds.consumer_key || !mpesaCreds.consumer_secret || !mpesaCreds.shortcode || !mpesaCreds.passkey) {
      return res.status(400).json({ error: 'M-Pesa not configured. Contact the ISP or platform admin.' });
    }

    const commRate = parseFloat(ispData.commission_rate) || 0.03;
    const commAmount = amount * commRate;
    const netAmount = amount - commAmount;

    // Create payment record
    const payment = await query(
      `INSERT INTO payments
         (isp_id, amount, payment_method, payment_gateway, phone_number,
          commission_rate, commission_amount, net_amount, description, status, used_admin_credentials)
       VALUES ($1::uuid, $2::decimal, 'mpesa', 'mpesa_stk', $3,
               $4::decimal, $5::decimal, $6::decimal, $7, 'pending', $8::boolean)
       RETURNING id`,
      [req.params.ispId, amount, normalizedPhone, commRate, commAmount, netAmount,
       `Hotspot - ${pkg.rows[0].name}`, usedAdminCreds]
    );
    const paymentId = payment.rows[0].id;

    // ── Send STK Push ─────────────────────────────────────────
    const baseUrl = mpesaCreds.sandbox ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';

    let accessToken;
    try {
      const tokRes = await axios.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, {
        headers: { Authorization: `Basic ${Buffer.from(`${mpesaCreds.consumer_key}:${mpesaCreds.consumer_secret}`).toString('base64')}` },
        timeout: 10000
      });
      accessToken = tokRes.data.access_token;
    } catch (tokenErr) {
      const errMsg = (tokenErr.response?.data?.errorMessage || tokenErr.message).substring(0, 240);
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid", [errMsg, paymentId]).catch(()=>{});
      return res.status(502).json({ error: 'M-Pesa auth failed: ' + errMsg });
    }

    const timestamp = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
    const password = Buffer.from(`${mpesaCreds.shortcode}${mpesaCreds.passkey}${timestamp}`).toString('base64');

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
        TransactionDesc: `WiFi - ${pkg.rows[0].name}`.substring(0, 13)
      }, { headers: { Authorization: `Bearer ${accessToken}` }, timeout: 15000 });
    } catch (stkErr) {
      const errMsg = (stkErr.response?.data?.errorMessage || stkErr.response?.data?.ResponseDescription || stkErr.message).substring(0, 240);
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid", [errMsg, paymentId]).catch(()=>{});
      logger.error('Captive STK push error:', errMsg);
      return res.status(502).json({ error: 'M-Pesa STK push failed: ' + errMsg });
    }

    // Track in mpesa_transactions
    await query(
      `INSERT INTO mpesa_transactions
         (isp_id, payment_id, checkout_request_id, merchant_request_id, amount, phone, status)
       VALUES ($1::uuid, $2::uuid, $3, $4, $5::decimal, $6, 'pending')`,
      [req.params.ispId, paymentId, stkRes.data.CheckoutRequestID, stkRes.data.MerchantRequestID, amount, normalizedPhone]
    ).catch(()=>{});

    // Reserve voucher for after-payment confirmation
    try {
      const code = generateCode();
      await query(
        `INSERT INTO hotspot_vouchers
           (isp_id, package_id, code, status, buyer_phone, payment_id)
         VALUES ($1::uuid, $2::uuid, $3, 'unused', $4, $5::uuid)`,
        [req.params.ispId, package_id, code, normalizedPhone, paymentId]
      );
    } catch (e) {
      // Try without payment_id column
      try {
        await query(
          `INSERT INTO hotspot_vouchers (isp_id, package_id, code, status, buyer_phone)
           VALUES ($1::uuid, $2::uuid, $3, 'unused', $4)`,
          [req.params.ispId, package_id, generateCode(), normalizedPhone]
        );
      } catch (e2) { logger.warn('Voucher pre-create:', e2.message); }
    }

    res.json({
      success: true,
      payment_id: paymentId,
      amount: amount,
      checkout_request_id: stkRes.data.CheckoutRequestID,
      message: `M-Pesa prompt sent to ${normalizedPhone}.`
    });

  } catch (err) {
    logger.error('Captive pay error:', err.message);
    logger.error(err.stack);
    res.status(500).json({ error: 'Internal error: ' + err.message });
  }
});

// ── PAYMENT STATUS POLL (for spinner) ─────────────────────────
router.get('/:ispId/payment-status/:paymentId', async (req, res) => {
  try {
    const r = await query(
      `SELECT id, status, transaction_id, amount, failure_reason
       FROM payments WHERE id=$1::uuid AND isp_id=$2::uuid`,
      [req.params.paymentId, req.params.ispId]
    );
    if (!r.rows[0]) return res.status(404).json({ status: 'not_found' });

    // If paid, fetch the voucher code
    let voucher_code = null;
    if (r.rows[0].status === 'paid') {
      try {
        const v = await query(
          `SELECT code FROM hotspot_vouchers
           WHERE payment_id = $2::uuid
           ORDER BY created_at DESC LIMIT 1`,
          [req.params.ispId, req.params.paymentId]
        );
        if (v.rows[0]) voucher_code = v.rows[0].code;
      } catch(e) {
        const v = await query(
          `SELECT code FROM hotspot_vouchers
           WHERE isp_id=$1::uuid ORDER BY created_at DESC LIMIT 1`,
          [req.params.ispId]
        );
        if (v.rows[0]) voucher_code = v.rows[0].code;
      }
    }

    res.json({
      payment_id: r.rows[0].id,
      status: r.rows[0].status,
      transaction_id: r.rows[0].transaction_id,
      amount: r.rows[0].amount,
      failure_reason: r.rows[0].failure_reason,
      voucher_code
    });
  } catch (err) {
    res.json({ status: 'pending' });
  }
});

// ── M-Pesa CALLBACK ───────────────────────────────────────────
router.post('/:ispId/callback/:paymentId', async (req, res) => {
  try {
    const cb = req.body?.Body?.stkCallback;
    if (cb && cb.ResultCode === 0) {
      const items = cb.CallbackMetadata?.Item || [];
      const g = n => items.find(x => x.Name === n)?.Value;
      const receipt = g('MpesaReceiptNumber');
      const amt = g('Amount');

      await query("UPDATE payments SET status='paid', transaction_id=$1, paid_at=NOW() WHERE id=$2::uuid",
        [receipt, req.params.paymentId]);
      await query("UPDATE mpesa_transactions SET status='completed', mpesa_receipt=$1, transaction_date=NOW() WHERE payment_id=$2::uuid",
        [receipt, req.params.paymentId]).catch(()=>{});

      // Activate the voucher (mark "ready to use")
      try {
        await query(`
          UPDATE hotspot_vouchers SET status='unused', updated_at=NOW()
          WHERE payment_id=$1::uuid AND status='unused'`,
          [req.params.paymentId]).catch(()=>{});
      } catch(e) {}

      // Send SMS with the voucher
      try {
        const v = await query(
          `SELECT hv.code, hv.buyer_phone, hp.name FROM hotspot_vouchers hv
           JOIN hotspot_packages hp ON hp.id=hv.package_id
           WHERE hv.isp_id=$1::uuid ORDER BY hv.created_at DESC LIMIT 1`,
          [req.params.ispId]);
        if (v.rows[0] && v.rows[0].buyer_phone) {
          const ispInfo = await query("SELECT * FROM isps WHERE id=$1::uuid", [req.params.ispId]);
          sendSMS({
            to: v.rows[0].buyer_phone,
            message: `Your ${v.rows[0].name} voucher: ${v.rows[0].code}. Receipt: ${receipt}`,
            isp: ispInfo.rows[0]
          }).catch(()=>{});
        }
      } catch(e){}
    } else if (cb) {
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid",
        [(cb.ResultDesc || 'Cancelled').substring(0, 240), req.params.paymentId]);
    }
  } catch (e) {
    logger.error('Captive callback:', e.message);
  }
  res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
});

module.exports = router;
