const express = require('express');
const axios = require('axios');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();
router.use(authenticateToken, requireISP);

// Get all payment methods for ISP
router.get('/', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT id, method_type, label, shortcode, till_number, paybill_number,
              account_reference, bank_name, account_name, account_number, branch,
              forward_to_type, forward_to_number, forward_to_name,
              is_active, is_verified, is_default, use_admin_credentials, is_sandbox, created_at
       FROM isp_payment_methods WHERE isp_id = $1 ORDER BY is_default DESC, created_at ASC`,
      [req.user.ispId]
    );
    res.json({ methods: result.rows });
  } catch (err) { next(err); }
});

// Add / Update payment method
router.post('/', async (req, res, next) => {
  const {
    method_type, label,
    // MPesa STK (Daraja)
    shortcode, consumer_key, consumer_secret, passkey, is_sandbox, use_admin_credentials,
    // Till / Paybill (manual)
    till_number, paybill_number, account_reference,
    // Bank
    bank_name, account_name, account_number, branch,
    // Forwarding (when admin creds used)
    forward_to_type, forward_to_number, forward_to_name,
    is_default
  } = req.body;

  if (!method_type) return res.status(400).json({ error: 'method_type is required' });

  try {
    const result = await query(`
      INSERT INTO isp_payment_methods (
        isp_id, method_type, label,
        shortcode, consumer_key, consumer_secret, passkey, is_sandbox, use_admin_credentials,
        till_number, paybill_number, account_reference,
        bank_name, account_name, account_number, branch,
        forward_to_type, forward_to_number, forward_to_name,
        is_default, is_active, is_verified
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,true,false)
      ON CONFLICT DO NOTHING
      RETURNING id, method_type, label, is_default
    `, [req.user.ispId, method_type, label || method_type,
        shortcode, consumer_key, consumer_secret, passkey, is_sandbox || false, use_admin_credentials || false,
        till_number, paybill_number, account_reference,
        bank_name, account_name, account_number, branch,
        forward_to_type, forward_to_number, forward_to_name,
        is_default || false]);

    if (is_default) {
      await query(`UPDATE isp_payment_methods SET is_default=false WHERE isp_id=$1 AND id!=$2`,
        [req.user.ispId, result.rows[0]?.id]);
    }

    res.status(201).json({ method: result.rows[0] });
  } catch (err) { next(err); }
});

// Update payment method
router.put('/:id', async (req, res, next) => {
  const {
    label, shortcode, consumer_key, consumer_secret, passkey, is_sandbox, use_admin_credentials,
    till_number, paybill_number, account_reference,
    bank_name, account_name, account_number, branch,
    forward_to_type, forward_to_number, forward_to_name,
    is_default, is_active
  } = req.body;
  try {
    const result = await query(`
      UPDATE isp_payment_methods SET
        label=COALESCE($1,label), shortcode=COALESCE($2,shortcode),
        consumer_key=COALESCE($3,consumer_key), consumer_secret=COALESCE($4,consumer_secret),
        passkey=COALESCE($5,passkey), is_sandbox=COALESCE($6,is_sandbox),
        use_admin_credentials=COALESCE($7,use_admin_credentials),
        till_number=COALESCE($8,till_number), paybill_number=COALESCE($9,paybill_number),
        account_reference=COALESCE($10,account_reference),
        bank_name=COALESCE($11,bank_name), account_name=COALESCE($12,account_name),
        account_number=COALESCE($13,account_number), branch=COALESCE($14,branch),
        forward_to_type=COALESCE($15,forward_to_type), forward_to_number=COALESCE($16,forward_to_number),
        forward_to_name=COALESCE($17,forward_to_name),
        is_default=COALESCE($18,is_default), is_active=COALESCE($19,is_active),
        updated_at=NOW()
      WHERE id=$20 AND isp_id=$21 RETURNING *
    `, [label, shortcode, consumer_key, consumer_secret, passkey, is_sandbox, use_admin_credentials,
        till_number, paybill_number, account_reference, bank_name, account_name, account_number, branch,
        forward_to_type, forward_to_number, forward_to_name, is_default, is_active,
        req.params.id, req.user.ispId]);

    if (is_default && result.rows[0]) {
      await query(`UPDATE isp_payment_methods SET is_default=false WHERE isp_id=$1 AND id!=$2`,
        [req.user.ispId, req.params.id]);
    }
    if (!result.rows[0]) return res.status(404).json({ error: 'Method not found' });
    res.json({ method: result.rows[0] });
  } catch (err) { next(err); }
});

// Delete payment method
router.delete('/:id', async (req, res, next) => {
  try {
    await query('DELETE FROM isp_payment_methods WHERE id=$1 AND isp_id=$2', [req.params.id, req.user.ispId]);
    res.json({ message: 'Payment method removed' });
  } catch (err) { next(err); }
});

// ── TEST PAYMENT (simulate KES 2 STK push) ──
router.post('/:id/test', async (req, res, next) => {
  const { test_phone } = req.body;
  if (!test_phone) return res.status(400).json({ error: 'test_phone is required' });

  try {
    const pm = await query(
      'SELECT * FROM isp_payment_methods WHERE id=$1 AND isp_id=$2',
      [req.params.id, req.user.ispId]
    );
    if (!pm.rows[0]) return res.status(404).json({ error: 'Method not found' });
    const m = pm.rows[0];

    if (m.method_type !== 'mpesa_stk' && !m.use_admin_credentials) {
      // For non-API methods (till, paybill, bank), just mark as verified
      await query(`UPDATE isp_payment_methods SET is_verified=true WHERE id=$1`, [m.id]);
      return res.json({ success: true, message: 'Payment method saved. Manual methods do not require API testing.' });
    }

    // Use ISP credentials or admin fallback
    const consumerKey = m.use_admin_credentials ? process.env.MPESA_CONSUMER_KEY : m.consumer_key;
    const consumerSecret = m.use_admin_credentials ? process.env.MPESA_CONSUMER_SECRET : m.consumer_secret;
    const shortcode = m.use_admin_credentials ? process.env.MPESA_SHORTCODE : m.shortcode;
    const passkey = m.use_admin_credentials ? process.env.MPESA_PASSKEY : m.passkey;
    const sandbox = m.use_admin_credentials ? (process.env.MPESA_ENVIRONMENT === 'sandbox') : m.is_sandbox;
    const baseUrl = sandbox ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';

    // Get token
    const tokenRes = await axios.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, {
      headers: { Authorization: `Basic ${Buffer.from(`${consumerKey}:${consumerSecret}`).toString('base64')}` }
    });
    const token = tokenRes.data.access_token;

    const timestamp = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
    const password = Buffer.from(`${shortcode}${passkey}${timestamp}`).toString('base64');
    const normalizedPhone = test_phone.replace(/^0/, '254').replace(/^\+/, '');

    const stkRes = await axios.post(`${baseUrl}/mpesa/stkpush/v1/processrequest`, {
      BusinessShortCode: shortcode,
      Password: password,
      Timestamp: timestamp,
      TransactionType: 'CustomerPayBillOnline',
      Amount: 1, // KES 1 test
      PartyA: normalizedPhone,
      PartyB: shortcode,
      PhoneNumber: normalizedPhone,
      CallBackURL: `${process.env.BASE_URL}/api/payment-methods/test-callback`,
      AccountReference: 'TEST',
      TransactionDesc: 'RumaLink Payment Test'
    }, { headers: { Authorization: `Bearer ${token}` } });

    // Mark as verified after successful STK push initiation
    await query(`UPDATE isp_payment_methods SET is_verified=true WHERE id=$1`, [m.id]);

    res.json({
      success: true,
      message: `Test payment of KES 1 sent to ${test_phone}. If you receive the MPesa prompt, your payment method is working correctly!`,
      checkout_request_id: stkRes.data.CheckoutRequestID
    });
  } catch (err) {
    logger.error('Payment test failed:', err.message);
    res.status(400).json({
      success: false,
      error: 'Payment test failed. Check your credentials.',
      detail: err.response?.data?.errorMessage || err.message
    });
  }
});

// Test callback (swallow test payments)
router.post('/test-callback', (req, res) => {
  logger.info('Test payment callback received:', JSON.stringify(req.body));
  res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
});

module.exports = router;
