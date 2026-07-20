const express = require('express');
const axios = require('axios');
const { query } = require('../config/database');
const { sendSMS } = require('../utils/sms');
const { generateCode } = require('../utils/vouchers');
const logger = require('../utils/logger');

const router = express.Router();

// ── GET portal config + packages (public) ──────────────────────
router.get('/:ispId', async (req, res, next) => {
  try {
    const isp = await query(
      `SELECT id, company_name, logo_url FROM isps WHERE id=$1 AND status='active'`,
      [req.params.ispId]
    );
    if (!isp.rows[0]) return res.status(404).json({ error: 'Portal not found' });

    const portal = await query(`SELECT * FROM isp_captive_portal WHERE isp_id=$1`, [req.params.ispId]);

    const packages = await query(`
      SELECT id, name, description, price, duration_hours,
             bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb
      FROM hotspot_packages
      WHERE isp_id=$1 AND is_active=true
      ORDER BY price ASC
    `, [req.params.ispId]);

    const payMethods = await query(`
      SELECT id, method_type, label, till_number, paybill_number,
             account_reference, bank_name, account_name, account_number,
             use_admin_credentials
      FROM isp_payment_methods
      WHERE isp_id=$1 AND is_active=true
    `, [req.params.ispId]);

    res.json({
      isp: isp.rows[0],
      portal: portal.rows[0] || {
        template: 'classic',
        primary_color: '#00d4aa',
        welcome_title: 'Welcome! Connect to WiFi',
        welcome_subtitle: 'Select a package and pay with MPesa',
        show_logo: true,
        show_powered_by: true,
        support_number: null,
        support_label: 'Call Support'
      },
      packages: packages.rows,
      payment_methods: payMethods.rows
    });
  } catch (err) { next(err); }
});

// ── INITIATE MPESA PAYMENT (with STK push) ────────────────────
router.post('/:ispId/pay', async (req, res, next) => {
  const { phone, package_id, mac, ip } = req.body;
  if (!phone || !package_id) {
    return res.status(400).json({ error: 'Phone and package_id are required' });
  }

  try {
    const pkg = await query(
      `SELECT * FROM hotspot_packages WHERE id=$1 AND isp_id=$2 AND is_active=true`,
      [package_id, req.params.ispId]
    );
    if (!pkg.rows[0]) return res.status(404).json({ error: 'Package not found' });

    const isp = await query(`SELECT * FROM isps WHERE id=$1`, [req.params.ispId]);
    const ispData = isp.rows[0];
    const amount = parseFloat(pkg.rows[0].price);

    // Determine payment credentials (ISP own or admin fallback)
    const pm = await query(`
      SELECT * FROM isp_payment_methods
      WHERE isp_id=$1 AND method_type='mpesa_stk' AND is_active=true
      LIMIT 1
    `, [req.params.ispId]);

    const useAdmin = !pm.rows[0] || pm.rows[0].use_admin_credentials;
    const creds = useAdmin ? {
      consumer_key: process.env.MPESA_CONSUMER_KEY,
      consumer_secret: process.env.MPESA_CONSUMER_SECRET,
      shortcode: process.env.MPESA_SHORTCODE,
      passkey: process.env.MPESA_PASSKEY,
      sandbox: process.env.MPESA_ENVIRONMENT === 'sandbox'
    } : {
      consumer_key: pm.rows[0].consumer_key,
      consumer_secret: pm.rows[0].consumer_secret,
      shortcode: pm.rows[0].shortcode,
      passkey: pm.rows[0].passkey,
      sandbox: pm.rows[0].is_sandbox
    };

    if (!creds.consumer_key || !creds.shortcode) {
      return res.status(400).json({
        error: 'MPesa is not configured for this network. Please contact support.'
      });
    }

    // Record payment intent
    const commRate = parseFloat(ispData.commission_rate) || 0.03;
    const commAmt = amount * commRate;
    const payment = await query(`
      INSERT INTO payments (
        isp_id, amount, payment_method, payment_gateway,
        phone_number, commission_rate, commission_amount, net_amount,
        description, status, used_admin_credentials, metadata
      ) VALUES ($1,$2,'mpesa','mpesa_stk',$3,$4,$5,$6,$7,'pending',$8,$9)
      RETURNING id
    `, [
      req.params.ispId, amount, phone,
      commRate, commAmt, amount - commAmt,
      `Hotspot - ${pkg.rows[0].name}`,
      useAdmin,
      JSON.stringify({ mac, ip, package_id, package_name: pkg.rows[0].name })
    ]);

    const paymentId = payment.rows[0].id;

    // ── STK PUSH ─────────────────────────────────────────────
    const baseUrl = creds.sandbox
      ? 'https://sandbox.safaricom.co.ke'
      : 'https://api.safaricom.co.ke';

    // Get access token
    const tokenRes = await axios.get(
      `${baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
      {
        headers: {
          Authorization: `Basic ${Buffer.from(`${creds.consumer_key}:${creds.consumer_secret}`).toString('base64')}`
        },
        timeout: 10000
      }
    );
    const accessToken = tokenRes.data.access_token;

    const timestamp = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
    const password = Buffer.from(`${creds.shortcode}${creds.passkey}${timestamp}`).toString('base64');
    const normalizedPhone = phone.replace(/^0/, '254').replace(/^\+/, '');
    const callbackUrl = `${process.env.BASE_URL}/api/captive/${req.params.ispId}/callback/${paymentId}`;

    const stkRes = await axios.post(
      `${baseUrl}/mpesa/stkpush/v1/processrequest`,
      {
        BusinessShortCode: creds.shortcode,
        Password: password,
        Timestamp: timestamp,
        TransactionType: 'CustomerPayBillOnline',
        Amount: Math.ceil(amount),
        PartyA: normalizedPhone,
        PartyB: creds.shortcode,
        PhoneNumber: normalizedPhone,
        CallBackURL: callbackUrl,
        AccountReference: paymentId.substring(0, 12).toUpperCase(),
        TransactionDesc: `WiFi - ${pkg.rows[0].name}`
      },
      {
        headers: { Authorization: `Bearer ${accessToken}` },
        timeout: 15000
      }
    );

    if (stkRes.data.ResponseCode !== '0') {
      await query(`UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2`,
        [stkRes.data.ResponseDescription, paymentId]);
      return res.status(400).json({ error: 'MPesa request failed: ' + stkRes.data.ResponseDescription });
    }

    // Save MPesa transaction record
    await query(`
      INSERT INTO mpesa_transactions (
        isp_id, payment_id, checkout_request_id, merchant_request_id,
        amount, phone, status
      ) VALUES ($1,$2,$3,$4,$5,$6,'pending')
    `, [
      req.params.ispId, paymentId,
      stkRes.data.CheckoutRequestID,
      stkRes.data.MerchantRequestID,
      amount, phone
    ]);

    logger.info(`STK push sent: ${phone} KES ${amount} CheckoutID:${stkRes.data.CheckoutRequestID}`);

    res.json({
      payment_id: paymentId,
      checkout_request_id: stkRes.data.CheckoutRequestID,
      message: `MPesa prompt sent to ${phone}. Enter your PIN to complete payment.`,
      amount,
      package_name: pkg.rows[0].name
    });

  } catch (err) {
    logger.error('Captive pay error:', err.response?.data || err.message);
    if (err.code === 'ECONNREFUSED' || err.code === 'ECONNABORTED') {
      return res.status(503).json({ error: 'MPesa service temporarily unavailable. Please try again.' });
    }
    next(err);
  }
});

// ── PAYMENT STATUS POLLING (frontend polls every 5s) ──────────
router.get('/status/:paymentId', async (req, res, next) => {
  try {
    const payment = await query(`
      SELECT p.id, p.status, p.amount, p.phone_number, p.metadata,
             hv.code as voucher_code, hv.expires_at
      FROM payments p
      LEFT JOIN hotspot_vouchers hv ON hv.payment_reference = p.transaction_id
      WHERE p.id = $1
    `, [req.params.paymentId]);

    if (!payment.rows[0]) {
      return res.status(404).json({ error: 'Payment not found' });
    }

    const p = payment.rows[0];
    res.json({
      status: p.status,
      amount: p.amount,
      phone: p.phone_number,
      voucher_code: p.voucher_code,
      expires_at: p.expires_at
    });
  } catch (err) { next(err); }
});

// ── MPESA CALLBACK ─────────────────────────────────────────────
router.post('/:ispId/callback/:paymentId', async (req, res) => {
  const { Body } = req.body;
  const { ispId, paymentId } = req.params;
  logger.info(`MPesa callback received for payment ${paymentId}`);

  try {
    const cb = Body?.stkCallback;
    const resultCode = cb?.ResultCode;

    if (resultCode === 0) {
      // ── PAYMENT SUCCESSFUL ─────────────────────────────────
      const meta = cb.CallbackMetadata?.Item || [];
      const getMeta = n => meta.find(i => i.Name === n)?.Value;
      const mpesaCode = getMeta('MpesaReceiptNumber');
      const amount    = getMeta('Amount');
      const phone     = getMeta('PhoneNumber')?.toString();

      // Mark payment as paid
      await query(`
        UPDATE payments
        SET status='paid', transaction_id=$1, paid_at=NOW()
        WHERE id=$2
      `, [mpesaCode, paymentId]);

      // Get payment details + package info
      const payData = await query(`SELECT *, metadata->>'package_id' as pkg_id, metadata->>'mac' as mac_addr FROM payments WHERE id=$1`, [paymentId]);
      const p = payData.rows[0];

      if (p) {
        // Update ISP wallet
        await query(`
          UPDATE isps
          SET wallet_balance = wallet_balance + $1,
              total_earned   = total_earned + $2
          WHERE id = $3
        `, [p.net_amount, p.amount, ispId]);

        // Record commission
        await query(`
          INSERT INTO commissions (isp_id, payment_id, amount, rate)
          VALUES ($1,$2,$3,$4)
        `, [ispId, paymentId, p.commission_amount, p.commission_rate]);

        const isp = await query('SELECT * FROM isps WHERE id=$1', [ispId]);
        const ispData = isp.rows[0];

        // Forward payment to ISP if using admin credentials
        if (p.used_admin_credentials) {
          const fwMethod = await query(`
            SELECT * FROM isp_payment_methods
            WHERE isp_id=$1 AND is_active=true
            ORDER BY is_default DESC LIMIT 1
          `, [ispId]);
          if (fwMethod.rows[0]) {
            await query(`
              UPDATE payments
              SET forwarded_to=$1, forward_status='queued', forwarded_at=NOW()
              WHERE id=$2
            `, [
              `${fwMethod.rows[0].method_type}:${fwMethod.rows[0].till_number || fwMethod.rows[0].paybill_number || fwMethod.rows[0].account_number}`,
              paymentId
            ]);
            await query(`
              INSERT INTO notifications (type, title, message)
              VALUES ('warning', 'Forward Payment Required', $1)
            `, [`Forward KES ${p.net_amount} to ${ispData.company_name} via ${fwMethod.rows[0].method_type}. Receipt: ${mpesaCode}`]);
          }
        }

        // ── AUTO-GENERATE VOUCHER ───────────────────────────
        let pkgData = null;
        if (p.pkg_id) {
          const pkgRes = await query('SELECT * FROM hotspot_packages WHERE id=$1', [p.pkg_id]);
          pkgData = pkgRes.rows[0];
        } else {
          const pkgRes = await query('SELECT * FROM hotspot_packages WHERE isp_id=$1 AND is_active=true ORDER BY price ASC LIMIT 1', [ispId]);
          pkgData = pkgRes.rows[0];
        }

        if (pkgData) {
          const code = generateCode('HS', 8);
          const expiresAt = pkgData.duration_hours
            ? new Date(Date.now() + pkgData.duration_hours * 3600000)
            : null;
          const buyerPhone = phone ? `254${phone.toString().slice(-9)}` : null;

          await query(`
            INSERT INTO hotspot_vouchers (
              isp_id, package_id, code, status, is_paid,
              amount_paid, payment_method, payment_reference,
              buyer_phone, sms_sent, used_by_mac, expires_at
            ) VALUES ($1,$2,$3,'active',true,$4,'mpesa',$5,$6,false,$7,$8)
          `, [ispId, pkgData.id, code, amount, mpesaCode, buyerPhone, p.mac_addr || null, expiresAt]);

          // Update payment to link voucher by payment_reference
          // (already linked via mpesaCode)

          // Send SMS
          if (buyerPhone) {
            const expMsg = expiresAt
              ? `Expires: ${new Date(expiresAt).toLocaleString('en-KE', { timeZone: 'Africa/Nairobi' })}`
              : 'No time limit';
            try {
              await sendSMS({
                to: buyerPhone,
                message: `${ispData.company_name} WiFi\nUsername: ${code}\nPassword: ${code}\nPackage: ${pkgData.name}\n${expMsg}\nReceipt: ${mpesaCode}`,
                isp: ispData
              });
              await query(`UPDATE hotspot_vouchers SET sms_sent=true WHERE code=$1`, [code]);
            } catch (smsErr) {
              logger.error('Post-payment SMS failed:', smsErr.message);
            }
          }

          // CoA trigger — reconnect device if MAC known
          if (p.mac_addr) {
            try {
              const { triggerMACReconnect } = require('../utils/macAuth');
              await triggerMACReconnect({
                ispId,
                macAddress: p.mac_addr,
                packageData: {
                  id: pkgData.id,
                  duration_hours: pkgData.duration_hours,
                  bandwidth_down_mbps: pkgData.bandwidth_down_mbps,
                  bandwidth_up_mbps: pkgData.bandwidth_up_mbps,
                  mikrotik_profile: pkgData.mikrotik_profile
                }
              });
            } catch (coaErr) {
              logger.error('CoA trigger failed:', coaErr.message);
            }
          }
        }

        // Notify ISP
        await query(`
          INSERT INTO notifications (isp_id, type, title, message)
          VALUES ($1, 'success', 'Payment Received', $2)
        `, [ispId, `KES ${amount} received via MPesa (${mpesaCode})`]);

      }
    } else {
      // Payment failed/cancelled
      const reason = cb?.ResultDesc || 'Payment not completed';
      await query(`
        UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2
      `, [reason, paymentId]);
      logger.info(`Payment ${paymentId} failed: ${reason}`);
    }
  } catch (err) {
    logger.error('Captive callback error:', err.message);
  }

  // Always acknowledge callback to Safaricom
  res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
});

// ── REDEEM VOUCHER ─────────────────────────────────────────────
router.post('/:ispId/redeem', async (req, res, next) => {
  const { code, mac, phone } = req.body;
  if (!code) return res.status(400).json({ error: 'Voucher code is required' });

  try {
    const voucher = await query(`
      SELECT hv.*, hp.name as pkg_name, hp.duration_hours,
             hp.bandwidth_down_mbps, hp.bandwidth_up_mbps,
             hp.data_limit_mb, hp.mikrotik_profile, hp.price, hp.id as pkg_id
      FROM hotspot_vouchers hv
      JOIN hotspot_packages hp ON hp.id = hv.package_id
      WHERE hv.code = $1 AND hv.isp_id = $2 AND hv.status IN ('unused','active')
    `, [code.toUpperCase(), req.params.ispId]);

    if (!voucher.rows[0]) {
      return res.status(404).json({ error: 'Invalid or expired voucher code.' });
    }

    const v = voucher.rows[0];
    let expiresAt = v.expires_at;

    if (v.status === 'unused') {
      expiresAt = v.duration_hours
        ? new Date(Date.now() + v.duration_hours * 3600000)
        : null;

      await query(`
        UPDATE hotspot_vouchers
        SET status='active', used_by_mac=$1, used_at=NOW(),
            expires_at=$2, buyer_phone=COALESCE($3, buyer_phone), updated_at=NOW()
        WHERE id=$4
      `, [mac, expiresAt, phone, v.id]);

      await query(`
        INSERT INTO hotspot_sessions (isp_id, voucher_id, nas_id, mac_address, status)
        VALUES ($1,$2,$3,$4,'active')
      `, [v.isp_id, v.id, v.nas_id, mac]);

      // SMS on redemption
      const recipientPhone = phone || v.buyer_phone;
      if (recipientPhone) {
        try {
          const isp = await query(
            'SELECT company_name, sms_gateway, sms_api_key, sms_sender_id FROM isps WHERE id=$1',
            [v.isp_id]
          );
          const expMsg = expiresAt
            ? `Expires: ${new Date(expiresAt).toLocaleString('en-KE', { timeZone: 'Africa/Nairobi' })}`
            : 'No expiry';
          await sendSMS({
            to: recipientPhone,
            message: `${isp.rows[0]?.company_name} WiFi\nUsername: ${v.code}\nPassword: ${v.code}\nPackage: ${v.pkg_name}\n${expMsg}`,
            isp: isp.rows[0]
          });
          await query(`UPDATE hotspot_vouchers SET sms_sent=true WHERE id=$1`, [v.id]);
        } catch (smsErr) {
          logger.error('Redemption SMS failed:', smsErr.message);
        }
      }
    }

    res.json({
      success: true,
      username: v.code,
      password: v.code,
      profile: v.mikrotik_profile,
      expires_at: expiresAt,
      bandwidth_down: v.bandwidth_down_mbps,
      bandwidth_up: v.bandwidth_up_mbps,
      package_name: v.pkg_name
    });
  } catch (err) { next(err); }
});


// ── GET payment status (for spinner polling) ──────────────────
router.get('/:ispId/payment-status/:paymentId', async (req, res) => {
  try {
    const r = await query(
      `SELECT id, status, transaction_id, amount, failure_reason
       FROM payments WHERE id=$1::uuid AND isp_id=$2::uuid`,
      [req.params.paymentId, req.params.ispId]
    );
    if (!r.rows[0]) return res.status(404).json({ status: 'not_found' });

    // Look up associated voucher code if completed
    let voucher_code = null;
    if (r.rows[0].status === 'paid') {
      const v = await query(
        "SELECT code FROM hotspot_vouchers WHERE isp_id=$1::uuid AND buyer_phone IS NOT NULL ORDER BY created_at DESC LIMIT 1",
        [req.params.ispId]
      ).catch(() => ({ rows: [] }));
      if (v.rows[0]) voucher_code = v.rows[0].code;
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


module.exports = router;
