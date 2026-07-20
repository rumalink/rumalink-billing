const express = require('express');
const { query } = require('../config/database');
const { authenticateToken, requireAdmin } = require('../middleware/auth');

const router = express.Router();
router.use(authenticateToken, requireAdmin);

// Dashboard stats
router.get('/stats', async (req, res, next) => {
  try {
    const [isps, revenue, sessions, devices] = await Promise.all([
      query(`SELECT COUNT(*) as total, COUNT(*) FILTER (WHERE status='active') as active, COUNT(*) FILTER (WHERE status='pending') as pending, COUNT(*) FILTER (WHERE status='suspended') as suspended, COUNT(*) FILTER (WHERE plan_type='hotspot') as hotspot_isps, COUNT(*) FILTER (WHERE plan_type='pppoe') as pppoe_isps, COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days') as new_this_month FROM isps`),
      query(`SELECT COALESCE(SUM(commission_amount),0) as total_commission, COALESCE(SUM(commission_amount) FILTER (WHERE paid_at >= DATE_TRUNC('month',NOW())),0) as this_month_commission, COALESCE(SUM(amount),0) as total_processed, COUNT(*) as total_transactions, COUNT(*) FILTER (WHERE paid_at >= NOW() - INTERVAL '24 hours') as today_transactions FROM payments WHERE status='paid'`),
      query(`SELECT (SELECT COUNT(*) FROM hotspot_sessions WHERE status='active') as active_hotspot, (SELECT COUNT(*) FROM pppoe_sessions WHERE status='active') as active_pppoe`),
      query(`SELECT COUNT(*) as total, COUNT(*) FILTER (WHERE is_provisioned=true) as provisioned, COUNT(*) FILTER (WHERE is_online=true) as online FROM nas_devices`)
    ]);
    res.json({ isps: isps.rows[0], revenue: revenue.rows[0], sessions: sessions.rows[0], devices: devices.rows[0] });
  } catch (err) { next(err); }
});

// List all ISPs
router.get('/isps', async (req, res, next) => {
  try {
    const { page = 1, limit = 20, status, plan_type, search } = req.query;
    const offset = (page - 1) * limit;
    let whereClause = 'WHERE 1=1';
    const params = [];
    let paramIdx = 1;
    if (status) { whereClause += ` AND i.status = $${paramIdx++}`; params.push(status); }
    if (plan_type) { whereClause += ` AND i.plan_type = $${paramIdx++}`; params.push(plan_type); }
    if (search) { whereClause += ` AND (i.company_name ILIKE $${paramIdx} OR i.email ILIKE $${paramIdx} OR i.owner_name ILIKE $${paramIdx})`; params.push(`%${search}%`); paramIdx++; }
    const result = await query(`SELECT i.id, i.company_name, i.owner_name, i.email, i.phone, i.plan_type, i.status, i.county, i.town, i.wallet_balance, i.total_earned, i.total_commission_paid, i.trial_ends_at, i.last_login, i.created_at, COUNT(DISTINCT n.id) as device_count, COUNT(DISTINCT ps.id) FILTER (WHERE ps.status='active') as active_pppoe_users, COALESCE(SUM(p.commission_amount) FILTER (WHERE p.status='paid'),0) as total_commission FROM isps i LEFT JOIN nas_devices n ON n.isp_id=i.id LEFT JOIN pppoe_subscribers ps ON ps.isp_id=i.id LEFT JOIN payments p ON p.isp_id=i.id ${whereClause} GROUP BY i.id ORDER BY i.created_at DESC LIMIT $${paramIdx} OFFSET $${paramIdx+1}`, [...params, limit, offset]);
    const countResult = await query(`SELECT COUNT(*) FROM isps i ${whereClause}`, params);
    res.json({ isps: result.rows, pagination: { total: parseInt(countResult.rows[0].count), page: parseInt(page), limit: parseInt(limit), pages: Math.ceil(countResult.rows[0].count / limit) } });
  } catch (err) { next(err); }
});

// Get single ISP
router.get('/isps/:id', async (req, res, next) => {
  try {
    const isp = await query(`SELECT i.*, COUNT(DISTINCT n.id) as device_count, COUNT(DISTINCT ps.id) as total_pppoe_users, COUNT(DISTINCT ps.id) FILTER (WHERE ps.status='active') as active_pppoe_users, COUNT(DISTINCT hv.id) as total_vouchers, COALESCE(SUM(p.amount) FILTER (WHERE p.status='paid'),0) as total_revenue, COALESCE(SUM(p.commission_amount) FILTER (WHERE p.status='paid'),0) as total_commission FROM isps i LEFT JOIN nas_devices n ON n.isp_id=i.id LEFT JOIN pppoe_subscribers ps ON ps.isp_id=i.id LEFT JOIN hotspot_vouchers hv ON hv.isp_id=i.id LEFT JOIN payments p ON p.isp_id=i.id WHERE i.id=$1 GROUP BY i.id`, [req.params.id]);
    if (!isp.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    const recentPayments = await query(`SELECT amount, commission_amount, payment_method, status, created_at FROM payments WHERE isp_id=$1 ORDER BY created_at DESC LIMIT 10`, [req.params.id]);
    res.json({ isp: isp.rows[0], recent_payments: recentPayments.rows });
  } catch (err) { next(err); }
});

// Update ISP status
router.patch('/isps/:id/status', async (req, res, next) => {
  const { status } = req.body;
  if (!['active','suspended','cancelled'].includes(status)) return res.status(400).json({ error: 'Invalid status' });
  try {
    const result = await query('UPDATE isps SET status=$1, updated_at=NOW() WHERE id=$2 RETURNING id, company_name, status', [status, req.params.id]);
    if (!result.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    await query(`INSERT INTO notifications (isp_id,type,title,message) VALUES ($1,$2,'Account Status Update',$3)`, [req.params.id, status==='active'?'success':'warning', `Your account has been ${status}. Contact support@rumalink.co.ke for more info.`]);
    res.json({ isp: result.rows[0] });
  } catch (err) { next(err); }
});

// Revenue chart
router.get('/revenue-chart', async (req, res, next) => {
  const { period = '30' } = req.query;
  try {
    const result = await query(`SELECT DATE(paid_at) as date, COALESCE(SUM(amount),0) as total_revenue, COALESCE(SUM(commission_amount),0) as commission FROM payments WHERE status='paid' AND paid_at >= NOW() - INTERVAL '${parseInt(period)} days' GROUP BY DATE(paid_at) ORDER BY date ASC`);
    res.json({ data: result.rows });
  } catch (err) { next(err); }
});

// Platform invoices
router.get('/platform-invoices', async (req, res, next) => {
  try {
    const result = await query(`SELECT pi.*, i.company_name, i.email FROM isp_platform_invoices pi JOIN isps i ON i.id=pi.isp_id ORDER BY pi.created_at DESC LIMIT 50`);
    res.json({ invoices: result.rows });
  } catch (err) { next(err); }
});

// Admin notifications
router.get('/notifications', async (req, res, next) => {
  try {
    const result = await query(`SELECT * FROM notifications WHERE isp_id IS NULL ORDER BY created_at DESC LIMIT 50`);
    res.json({ notifications: result.rows });
  } catch (err) { next(err); }
});

// Commissions
router.get('/commissions', async (req, res, next) => {
  const { month, year } = req.query;
  try {
    const result = await query(`SELECT c.*, i.company_name, p.amount as payment_amount, p.payment_method FROM commissions c JOIN isps i ON i.id=c.isp_id JOIN payments p ON p.id=c.payment_id WHERE ($1::int IS NULL OR EXTRACT(MONTH FROM c.created_at)=$1) AND ($2::int IS NULL OR EXTRACT(YEAR FROM c.created_at)=$2) ORDER BY c.created_at DESC LIMIT 100`, [month||null, year||null]);
    const totals = await query(`SELECT COALESCE(SUM(amount),0) as total, COALESCE(SUM(amount) FILTER (WHERE is_settled),0) as settled FROM commissions`);
    res.json({ commissions: result.rows, totals: totals.rows[0] });
  } catch (err) { next(err); }
});

// Sessions
router.get('/sessions', async (req, res, next) => {
  try {
    const hotspot = await query(`SELECT hs.*, hv.code as voucher_code, i.company_name FROM hotspot_sessions hs LEFT JOIN hotspot_vouchers hv ON hv.id=hs.voucher_id JOIN isps i ON i.id=hs.isp_id WHERE hs.status='active' ORDER BY hs.started_at DESC LIMIT 100`);
    const pppoe = await query(`SELECT ps.*, sub.username, sub.full_name, i.company_name FROM pppoe_sessions ps JOIN pppoe_subscribers sub ON sub.id=ps.subscriber_id JOIN isps i ON i.id=ps.isp_id WHERE ps.status='active' ORDER BY ps.started_at DESC LIMIT 100`);
    res.json({ hotspot: hotspot.rows, pppoe: pppoe.rows });
  } catch (err) { next(err); }
});

// ================================================================
// DARAJA API SETTINGS
// Uses the existing mpesa_configs table with is_admin_config=true
// ================================================================
const axios = require('axios');

router.get('/settings/daraja', async (req, res, next) => {
  try {
    const r = await query('SELECT shortcode, consumer_key, consumer_secret, passkey, is_sandbox, is_active FROM mpesa_configs WHERE is_admin_config=true LIMIT 1');
    const row = r.rows[0] || {};
    res.json({
      shortcode:       row.shortcode       || '',
      consumer_key:    row.consumer_key    ? '***SET***' : '',
      consumer_secret: row.consumer_secret ? '***SET***' : '',
      passkey:         row.passkey         ? '***SET***' : '',
      is_sandbox:      row.is_sandbox !== false,
      is_active:       !!row.is_active,
      is_configured:   !!(row.consumer_key && row.consumer_secret && row.shortcode && row.passkey)
    });
  } catch (err) { next(err); }
});

router.post('/settings/daraja', async (req, res, next) => {
  const { shortcode, consumer_key, consumer_secret, passkey, is_sandbox } = req.body;
  if (!shortcode || !consumer_key || !consumer_secret || !passkey) {
    return res.status(400).json({ error: 'All four fields are required: shortcode, consumer_key, consumer_secret, passkey' });
  }
  try {
    const existing = await query('SELECT id FROM mpesa_configs WHERE is_admin_config=true LIMIT 1');
    if (existing.rows[0]) {
      await query(
        'UPDATE mpesa_configs SET shortcode=$1, consumer_key=$2, consumer_secret=$3, passkey=$4, is_sandbox=$5, is_active=true, updated_at=NOW() WHERE is_admin_config=true',
        [shortcode, consumer_key, consumer_secret, passkey, is_sandbox !== false]
      );
    } else {
      await query(
        'INSERT INTO mpesa_configs (isp_id, shortcode, consumer_key, consumer_secret, passkey, is_sandbox, is_active, is_admin_config) VALUES (NULL, $1, $2, $3, $4, $5, true, true)',
        [shortcode, consumer_key, consumer_secret, passkey, is_sandbox !== false]
      );
    }
    // Hot-load into process.env immediately — no restart needed
    process.env.MPESA_SHORTCODE       = shortcode;
    process.env.MPESA_CONSUMER_KEY    = consumer_key;
    process.env.MPESA_CONSUMER_SECRET = consumer_secret;
    process.env.MPESA_PASSKEY         = passkey;
    process.env.MPESA_ENVIRONMENT     = is_sandbox !== false ? 'sandbox' : 'production';
    res.json({ success: true, message: 'Daraja credentials saved and active.' });
  } catch (err) { next(err); }
});

router.post('/settings/daraja/test', async (req, res, next) => {
  try {
    const r = await query('SELECT * FROM mpesa_configs WHERE is_admin_config=true LIMIT 1');
    const cfg = r.rows[0];
    if (!cfg || !cfg.consumer_key || !cfg.consumer_secret) {
      return res.status(400).json({ success: false, error: 'No credentials saved yet. Fill in the form and click Save first.' });
    }
    const baseUrl = cfg.is_sandbox ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';
    const tokRes = await axios.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, {
      headers: { Authorization: `Basic ${Buffer.from(`${cfg.consumer_key}:${cfg.consumer_secret}`).toString('base64')}` },
      timeout: 10000
    });
    if (tokRes.data.access_token) {
      res.json({ success: true, message: `✅ Connected! Mode: ${cfg.is_sandbox ? 'Sandbox' : 'Production'} | Shortcode: ${cfg.shortcode}` });
    } else {
      res.status(400).json({ success: false, error: 'Empty token response — double-check your Consumer Key and Secret.' });
    }
  } catch (err) {
    const msg = err.response?.data?.errorMessage || err.message;
    res.status(400).json({ success: false, error: `Connection failed: ${msg}` });
  }
});

// Billing charge
router.post('/billing/charge', async (req, res, next) => {
  const { isp_id, amount, phone, charge_type, description } = req.body;
  if (!isp_id || !amount || !phone) return res.status(400).json({ error: 'isp_id, amount and phone required' });
  try {
    const cfg = await query('SELECT * FROM mpesa_configs WHERE is_admin_config=true AND is_active=true LIMIT 1');
    if (!cfg.rows[0]?.consumer_key) return res.status(400).json({ error: 'Daraja not configured. Go to Admin → Daraja API.' });
    const m = cfg.rows[0];
    const baseUrl = m.is_sandbox ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';
    const payment = await query(`INSERT INTO payments (isp_id,amount,payment_method,payment_gateway,phone_number,description,status,commission_rate,commission_amount,net_amount) VALUES ($1,$2,'admin_charge','mpesa_stk',$3,$4,'pending',0,0,$2) RETURNING id`, [isp_id, amount, phone, description || charge_type]);
    const paymentId = payment.rows[0].id;
    const tokRes = await axios.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, { headers: { Authorization: `Basic ${Buffer.from(`${m.consumer_key}:${m.consumer_secret}`).toString('base64')}` }, timeout: 10000 });
    const ts = new Date().toISOString().replace(/[-:T.Z]/g,'').slice(0,14);
    const pwd = Buffer.from(`${m.shortcode}${m.passkey}${ts}`).toString('base64');
    const normPhone = phone.replace(/^0/,'254').replace(/^\+/,'');
    const stkRes = await axios.post(`${baseUrl}/mpesa/stkpush/v1/processrequest`, { BusinessShortCode: m.shortcode, Password: pwd, Timestamp: ts, TransactionType: 'CustomerPayBillOnline', Amount: Math.ceil(amount), PartyA: normPhone, PartyB: m.shortcode, PhoneNumber: normPhone, CallBackURL: `${process.env.BASE_URL}/api/admin/billing/callback/${paymentId}`, AccountReference: paymentId.substring(0,12), TransactionDesc: description || 'Platform charge' }, { headers: { Authorization: `Bearer ${tokRes.data.access_token}` }, timeout: 15000 });
    await query(`INSERT INTO mpesa_transactions (isp_id,payment_id,checkout_request_id,merchant_request_id,amount,phone,status) VALUES ($1,$2,$3,$4,$5,$6,'pending')`, [isp_id, paymentId, stkRes.data.CheckoutRequestID, stkRes.data.MerchantRequestID, amount, phone]);
    res.json({ success: true, payment_id: paymentId, message: `STK Push sent to ${phone}` });
  } catch (err) { require('../utils/logger').error('Billing charge:', err.response?.data||err.message); next(err); }
});

router.post('/billing/callback/:paymentId', async (req, res) => {
  const { Body } = req.body;
  try {
    const cb = Body?.stkCallback;
    if (cb?.ResultCode === 0) {
      const g = n => (cb.CallbackMetadata?.Item||[]).find(i=>i.Name===n)?.Value;
      await query(`UPDATE payments SET status='paid',transaction_id=$1,paid_at=NOW() WHERE id=$2`, [g('MpesaReceiptNumber'), req.params.paymentId]);
      await query(`UPDATE mpesa_transactions SET status='completed',mpesa_receipt=$1,transaction_date=NOW() WHERE payment_id=$2`, [g('MpesaReceiptNumber'), req.params.paymentId]);
    } else {
      await query(`UPDATE payments SET status='failed',failure_reason=$1 WHERE id=$2`, [cb?.ResultDesc||'Cancelled', req.params.paymentId]);
    }
  } catch(e) { require('../utils/logger').error('Billing cb:', e.message); }
  res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
});

module.exports = router;
