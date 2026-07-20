const express = require('express');
const { query } = require('../config/database');
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const logger = require('../utils/logger');
const axios = require('axios');

const router = express.Router();
router.use(authenticateToken, requireAdmin);

// ============================================================
// DASHBOARD STATS
// ============================================================
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

// ============================================================
// ISP MANAGEMENT
// ============================================================
router.get('/isps', async (req, res, next) => {
  try {
    const { page = 1, limit = 20, status, plan_type, search } = req.query;
    const offset = (page - 1) * limit;
    let whereClause = 'WHERE 1=1';
    const params = [];
    let p = 1;
    if (status)    { whereClause += ` AND i.status = $${p++}`;     params.push(status); }
    if (plan_type) { whereClause += ` AND i.plan_type = $${p++}`;  params.push(plan_type); }
    if (req.query.expired === '1') {
      whereClause += ` AND i.billing_exempt IS NOT TRUE AND i.license_expires_at IS NOT NULL AND i.license_expires_at <= NOW()`;
    } else if (req.query.exclude_expired === '1') {
      whereClause += ` AND NOT (i.billing_exempt IS NOT TRUE AND i.license_expires_at IS NOT NULL AND i.license_expires_at <= NOW())`;
    }
    if (search)    { whereClause += ` AND (i.company_name ILIKE $${p} OR i.email ILIKE $${p} OR i.owner_name ILIKE $${p})`; params.push(`%${search}%`); p++; }
    const result = await query(`SELECT i.id, i.company_name, i.owner_name, i.email, i.phone, i.plan_type, i.status, i.county, i.town, i.wallet_balance, i.total_earned, i.total_commission_paid, i.trial_ends_at, i.license_expires_at, i.license_status, i.last_login, i.created_at, COUNT(DISTINCT n.id) as device_count, COUNT(DISTINCT ps.id) FILTER (WHERE ps.status='active') as active_pppoe_users, COALESCE(SUM(p2.commission_amount) FILTER (WHERE p2.status='paid'),0) as total_commission FROM isps i LEFT JOIN nas_devices n ON n.isp_id=i.id LEFT JOIN pppoe_subscribers ps ON ps.isp_id=i.id LEFT JOIN payments p2 ON p2.isp_id=i.id ${whereClause} GROUP BY i.id ORDER BY i.created_at DESC LIMIT $${p} OFFSET $${p+1}`, [...params, limit, offset]);
    const countResult = await query(`SELECT COUNT(*) FROM isps i ${whereClause}`, params);
    res.json({ isps: result.rows, pagination: { total: parseInt(countResult.rows[0].count), page: parseInt(page), limit: parseInt(limit), pages: Math.ceil(countResult.rows[0].count / limit) } });
  } catch (err) { next(err); }
});

router.get('/isps/:id', async (req, res, next) => {
  try {
    const isp = await query(`SELECT i.*, COUNT(DISTINCT n.id) as device_count, COUNT(DISTINCT ps.id) as total_pppoe_users, COUNT(DISTINCT ps.id) FILTER (WHERE ps.status='active') as active_pppoe_users, COUNT(DISTINCT hv.id) as total_vouchers, COALESCE(SUM(p.amount) FILTER (WHERE p.status='paid'),0) as total_revenue, COALESCE(SUM(p.commission_amount) FILTER (WHERE p.status='paid'),0) as total_commission FROM isps i LEFT JOIN nas_devices n ON n.isp_id=i.id LEFT JOIN pppoe_subscribers ps ON ps.isp_id=i.id LEFT JOIN hotspot_vouchers hv ON hv.isp_id=i.id LEFT JOIN payments p ON p.isp_id=i.id WHERE i.id=$1 GROUP BY i.id`, [req.params.id]);
    if (!isp.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    const recentPayments = await query(`SELECT amount, commission_amount, payment_method, status, created_at FROM payments WHERE isp_id=$1 ORDER BY created_at DESC LIMIT 10`, [req.params.id]);
    res.json({ isp: isp.rows[0], recent_payments: recentPayments.rows });
  } catch (err) { next(err); }
});

router.patch('/isps/:id/status', async (req, res, next) => {
  const { status } = req.body;
  if (!['active','suspended','cancelled'].includes(status)) return res.status(400).json({ error: 'Invalid status' });
  try {
    const result = await query('UPDATE isps SET status=$1, updated_at=NOW() WHERE id=$2 RETURNING id, company_name, status', [status, req.params.id]);
    if (!result.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    await query(`INSERT INTO notifications (isp_id,type,title,message) VALUES ($1,$2,'Account Status Update',$3)`, [req.params.id, status==='active'?'success':'warning', `Your account has been ${status}.`]);
    res.json({ isp: result.rows[0] });
  } catch (err) { next(err); }
});

router.get('/revenue-chart', async (req, res, next) => {
  const { period = '30', monthly } = req.query;
  try {
    if (monthly) {
      // 12 months of the CURRENT year (Jan..Dec); resets every January.
      const result = await query(`
        SELECT to_char(m.month, 'Mon') AS label,
               EXTRACT(MONTH FROM m.month)::int AS month_num,
               COALESCE(SUM(p.amount),0) AS total_revenue,
               COALESCE(SUM(p.commission_amount),0) AS commission
        FROM generate_series(date_trunc('year', NOW()), date_trunc('year', NOW()) + INTERVAL '11 months', INTERVAL '1 month') AS m(month)
        LEFT JOIN payments p
          ON p.status='paid'
         AND date_trunc('month', p.paid_at) = m.month
        GROUP BY m.month
        ORDER BY m.month ASC`);
      const ytd = result.rows.reduce((a, r) => a + parseFloat(r.total_revenue || 0), 0);
      return res.json({ data: result.rows, monthly: true, year: new Date().getFullYear(), ytd_total: ytd });
    }
    const result = await query(`SELECT DATE(paid_at) as date, COALESCE(SUM(amount),0) as total_revenue, COALESCE(SUM(commission_amount),0) as commission FROM payments WHERE status='paid' AND paid_at >= NOW() - INTERVAL '${parseInt(period)} days' GROUP BY DATE(paid_at) ORDER BY date ASC`);
    res.json({ data: result.rows });
  } catch (err) { next(err); }
});

router.get('/platform-invoices', async (req, res, next) => {
  try {
    const result = await query(`SELECT pi.*, i.company_name, i.email FROM isp_platform_invoices pi JOIN isps i ON i.id=pi.isp_id ORDER BY pi.created_at DESC LIMIT 50`);
    res.json({ invoices: result.rows });
  } catch (err) { next(err); }
});

router.get('/notifications', async (req, res, next) => {
  try {
    const result = await query(`SELECT * FROM notifications WHERE isp_id IS NULL ORDER BY created_at DESC LIMIT 50`);
    res.json({ notifications: result.rows });
  } catch (err) { next(err); }
});

router.get('/commissions', async (req, res, next) => {
  const { month, year } = req.query;
  try {
    // Platform earns via the monthly LICENSE INVOICE (isp_platform_invoices), not per-payment
    // commission. Report that as the platform's commission/revenue so the page tracks real money.
    const result = await query(`
      SELECT inv.id, inv.isp_id, i.company_name,
             inv.total_amount AS amount,
             inv.hotspot_rate AS rate,
             inv.hotspot_revenue AS payment_amount,
             ('PPPoE x' || inv.pppoe_user_count || ' + Hotspot') AS payment_method,
             (inv.status = 'paid') AS is_settled,
             COALESCE(inv.paid_at, inv.created_at) AS created_at,
             inv.status, inv.period_month, inv.period_year, inv.pppoe_user_count,
             inv.hotspot_fee, inv.pppoe_fee
        FROM isp_platform_invoices inv
        JOIN isps i ON i.id = inv.isp_id
       WHERE ($1::int IS NULL OR inv.period_month=$1)
         AND ($2::int IS NULL OR inv.period_year=$2)
       ORDER BY COALESCE(inv.paid_at, inv.created_at) DESC
       LIMIT 100`, [month||null, year||null]);
    const totals = await query(`
      SELECT COALESCE(SUM(total_amount),0) AS total,
             COALESCE(SUM(total_amount) FILTER (WHERE status='paid'),0) AS settled
        FROM isp_platform_invoices
       WHERE ($1::int IS NULL OR period_month=$1)
         AND ($2::int IS NULL OR period_year=$2)`, [month||null, year||null]);
    res.json({ commissions: result.rows, totals: totals.rows[0] });
  } catch (err) { next(err); }
});

router.get('/sessions', async (req, res, next) => {
  try {
    const hotspot = await query(`SELECT hs.*, hv.code as voucher_code, i.company_name FROM hotspot_sessions hs LEFT JOIN hotspot_vouchers hv ON hv.id=hs.voucher_id JOIN isps i ON i.id=hs.isp_id WHERE hs.status='active' ORDER BY hs.started_at DESC LIMIT 100`);
    const pppoe = await query(`SELECT ps.*, sub.username, sub.full_name, i.company_name FROM pppoe_sessions ps JOIN pppoe_subscribers sub ON sub.id=ps.subscriber_id JOIN isps i ON i.id=ps.isp_id WHERE ps.status='active' ORDER BY ps.started_at DESC LIMIT 100`);
    res.json({ hotspot: hotspot.rows, pppoe: pppoe.rows });
  } catch (err) { next(err); }
});

// ============================================================
// DARAJA API SETTINGS
// ============================================================
router.get('/settings/daraja', async (req, res, next) => {
  try {
    const r = await query('SELECT shortcode, consumer_key, consumer_secret, passkey, is_sandbox, is_active FROM mpesa_configs WHERE is_admin_config=true LIMIT 1');
    const row = r.rows[0] || {};
    res.json({
      shortcode:       row.shortcode || '',
      consumer_key:    row.consumer_key ? '***SET***' : '',
      consumer_secret: row.consumer_secret ? '***SET***' : '',
      passkey:         row.passkey ? '***SET***' : '',
      is_sandbox:      row.is_sandbox !== false,
      is_active:       !!row.is_active,
      is_configured:   !!(row.consumer_key && row.consumer_secret && row.shortcode && row.passkey)
    });
  } catch (err) { next(err); }
});

router.post('/settings/daraja', async (req, res, next) => {
  const { shortcode, consumer_key, consumer_secret, passkey, is_sandbox } = req.body;
  if (!shortcode || !consumer_key || !consumer_secret || !passkey) {
    return res.status(400).json({ error: 'All four fields are required.' });
  }
  try {
    const existing = await query('SELECT id FROM mpesa_configs WHERE is_admin_config=true LIMIT 1');
    if (existing.rows[0]) {
      await query('UPDATE mpesa_configs SET shortcode=$1, consumer_key=$2, consumer_secret=$3, passkey=$4, is_sandbox=$5, is_active=true, updated_at=NOW() WHERE is_admin_config=true',
        [shortcode, consumer_key, consumer_secret, passkey, is_sandbox !== false]);
    } else {
      await query('INSERT INTO mpesa_configs (isp_id, shortcode, consumer_key, consumer_secret, passkey, is_sandbox, is_active, is_admin_config) VALUES (NULL, $1, $2, $3, $4, $5, true, true)',
        [shortcode, consumer_key, consumer_secret, passkey, is_sandbox !== false]);
    }
    process.env.MPESA_SHORTCODE       = shortcode;
    process.env.MPESA_CONSUMER_KEY    = consumer_key;
    process.env.MPESA_CONSUMER_SECRET = consumer_secret;
    process.env.MPESA_PASSKEY         = passkey;
    process.env.MPESA_ENVIRONMENT     = is_sandbox !== false ? 'sandbox' : 'production';
    res.json({ success: true, message: 'Daraja credentials saved.' });
  } catch (err) { next(err); }
});

router.post('/settings/daraja/test', async (req, res, next) => {
  try {
    const r = await query('SELECT * FROM mpesa_configs WHERE is_admin_config=true LIMIT 1');
    const cfg = r.rows[0];
    if (!cfg || !cfg.consumer_key || !cfg.consumer_secret) {
      return res.status(400).json({ success: false, error: 'Save Daraja credentials first.' });
    }
    const baseUrl = cfg.is_sandbox ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';
    const tokRes = await axios.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, {
      headers: { Authorization: `Basic ${Buffer.from(`${cfg.consumer_key}:${cfg.consumer_secret}`).toString('base64')}` },
      timeout: 10000
    });
    if (tokRes.data.access_token) {
      res.json({ success: true, message: `Connected. Mode: ${cfg.is_sandbox ? 'Sandbox' : 'Production'} | Shortcode: ${cfg.shortcode}` });
    } else {
      res.status(400).json({ success: false, error: 'Empty token response.' });
    }
  } catch (err) {
    res.status(400).json({ success: false, error: `Failed: ${err.response?.data?.errorMessage || err.message}` });
  }
});

// ============================================================
// JENGA (EQUITY / FINSERVE) PROVIDER SETTINGS
// ============================================================
router.get('/settings/jenga', async (req, res, next) => {
  try {
    const r = await query("SELECT merchant_code, consumer_key, consumer_secret, api_key, private_key, base_url, is_sandbox, is_active FROM payment_provider_configs WHERE provider='jenga' LIMIT 1");
    const row = r.rows[0] || {};
    res.json({
      merchant_code:   row.merchant_code || '',
      consumer_key:    row.consumer_key ? '***SET***' : '',
      consumer_secret: row.consumer_secret ? '***SET***' : '',
      api_key:         row.api_key ? '***SET***' : '',
      private_key:     row.private_key ? '***SET***' : '',
      base_url:        row.base_url || 'https://api.finserve.africa',
      is_sandbox:      row.is_sandbox !== false,
      is_active:       !!row.is_active,
      is_configured:   !!(row.merchant_code && row.consumer_secret && row.api_key && row.private_key)
    });
  } catch (err) { next(err); }
});

router.post('/settings/jenga', async (req, res, next) => {
  const { merchant_code, consumer_key, consumer_secret, api_key, private_key, base_url, is_sandbox } = req.body;
  try {
    const ex = await query("SELECT * FROM payment_provider_configs WHERE provider='jenga' LIMIT 1");
    const cur = ex.rows[0] || {};
    const keep = (v, e) => (v === undefined || v === '' || v === '***SET***') ? (e || null) : v;
    const v = {
      merchant_code:   keep(merchant_code, cur.merchant_code),
      consumer_key:    keep(consumer_key, cur.consumer_key),
      consumer_secret: keep(consumer_secret, cur.consumer_secret),
      api_key:         keep(api_key, cur.api_key),
      private_key:     keep(private_key, cur.private_key),
      base_url:        (base_url && base_url.trim()) ? base_url.trim() : (cur.base_url || 'https://api.finserve.africa'),
      is_sandbox:      is_sandbox !== false
    };
    if (cur.id) {
      await query("UPDATE payment_provider_configs SET merchant_code=$1, consumer_key=$2, consumer_secret=$3, api_key=$4, private_key=$5, base_url=$6, is_sandbox=$7, is_active=true, updated_at=NOW() WHERE provider='jenga'",
        [v.merchant_code, v.consumer_key, v.consumer_secret, v.api_key, v.private_key, v.base_url, v.is_sandbox]);
    } else {
      await query("INSERT INTO payment_provider_configs (provider, merchant_code, consumer_key, consumer_secret, api_key, private_key, base_url, is_sandbox, is_active) VALUES ('jenga',$1,$2,$3,$4,$5,$6,$7,true)",
        [v.merchant_code, v.consumer_key, v.consumer_secret, v.api_key, v.private_key, v.base_url, v.is_sandbox]);
    }
    res.json({ success: true, message: 'Jenga (Equity) credentials saved.' });
  } catch (err) { next(err); }
});

router.post('/settings/jenga/test', async (req, res, next) => {
  try {
    const r = await query("SELECT * FROM payment_provider_configs WHERE provider='jenga' LIMIT 1");
    const cfg = r.rows[0];
    if (!cfg || !cfg.merchant_code || !cfg.consumer_secret || !cfg.api_key) {
      return res.status(400).json({ success: false, error: 'Save Jenga credentials first.' });
    }
    const jenga = require('../utils/jenga');
    const token = await jenga.getToken(cfg);
    if (token) res.json({ success: true, message: `Connected to Jenga. Mode: ${cfg.is_sandbox ? 'Sandbox' : 'Live'} | Merchant: ${cfg.merchant_code}` });
    else res.status(400).json({ success: false, error: 'No token returned from Jenga.' });
  } catch (err) {
    res.status(400).json({ success: false, error: `Failed: ${err.message}` });
  }
});

// ============================================================
// ADMIN IMPERSONATION + ISP EXPIRY MANAGEMENT
// ============================================================


// POST /admin/isps/:id/start-trial — put an ISP into trial mode (admin-only)
router.post('/isps/:id/start-trial', async (req, res, next) => {
  try {
    const r = await query('SELECT id, company_name FROM isps WHERE id=$1::uuid', [req.params.id]);
    if (!r.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    const billing = require('../utils/billing');
    const now = new Date();
    const trialEnd = new Date(now.getTime() + 30 * 86400000); // +30 days
    const firstExpiry = billing.addMonth(trialEnd); // license starts after trial
    await query(
      `UPDATE isps SET license_status='trial', trial_ends_at=$1, subscription_started_at=$2,
              billing_window_start=$1, license_expires_at=$3 WHERE id=$4::uuid`,
      [trialEnd.toISOString(), trialEnd.toISOString(), firstExpiry.toISOString(), req.params.id]
    );
    logger.info(`[ADMIN] ${req.user.email || req.user.adminId} started trial for ${r.rows[0].company_name} (ends ${trialEnd.toISOString()})`);
    res.json({ success: true, license_status: 'trial', trial_ends_at: trialEnd.toISOString(), license_expires_at: firstExpiry.toISOString() });
  } catch (err) { next(err); }
});

// POST /admin/isps/:id/end-trial — remove trial; license starts counting NOW (admin-only)
router.post('/isps/:id/end-trial', async (req, res, next) => {
  try {
    const r = await query('SELECT id, company_name FROM isps WHERE id=$1::uuid', [req.params.id]);
    if (!r.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    const billing = require('../utils/billing');
    const now = new Date();
    const newExpiry = billing.addMonth(now); // +1 month from this exact click
    await query(
      `UPDATE isps SET license_status='active', trial_ends_at=$1, subscription_started_at=$1,
              billing_window_start=$1, license_expires_at=$2 WHERE id=$3::uuid`,
      [now.toISOString(), newExpiry.toISOString(), req.params.id]
    );
    logger.info(`[ADMIN] ${req.user.email || req.user.adminId} ended trial for ${r.rows[0].company_name}; license now active until ${newExpiry.toISOString()}`);
    res.json({ success: true, license_status: 'active', subscription_started_at: now.toISOString(), license_expires_at: newExpiry.toISOString() });
  } catch (err) { next(err); }
});

// GET /admin/isps/:id/license — license state for the admin panel (admin-only)
router.get('/isps/:id/license', async (req, res, next) => {
  try {
    const r = await query(
      'SELECT license_status, billing_exempt, trial_ends_at, subscription_started_at, billing_window_start, license_expires_at FROM isps WHERE id=$1::uuid',
      [req.params.id]
    );
    if (!r.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    const row = r.rows[0];
    const exp = row.license_expires_at ? new Date(row.license_expires_at) : null;
    const expired = exp ? (Date.now() >= exp.getTime()) : false;
    res.json({ ...row, expired });
  } catch (err) { next(err); }
});

// POST /admin/isps/:id/impersonate — mint a short-lived ISP token (admin-only)
router.post('/isps/:id/impersonate', async (req, res, next) => {
  try {
    const r = await query('SELECT id, email, company_name, status FROM isps WHERE id=$1::uuid', [req.params.id]);
    const isp = r.rows[0];
    if (!isp) return res.status(404).json({ error: 'ISP not found' });

    const jwt = require('jsonwebtoken');
    const token = jwt.sign(
      { ispId: isp.id, email: isp.email, type: 'isp', impersonatedBy: req.user.adminId, imp: true },
      process.env.JWT_SECRET,
      { expiresIn: '30m' }
    );
    logger.warn(`[IMPERSONATE] admin ${req.user.email || req.user.adminId} -> ISP ${isp.company_name} (${isp.id})`);
    try {
      await query(
        "INSERT INTO notifications (type, title, message) VALUES ('warning', 'Admin Access', $1)",
        [`An administrator accessed the dashboard of ${isp.company_name}.`]
      );
    } catch (e) {}
    res.json({
      token,
      isp: { id: isp.id, email: isp.email, company_name: isp.company_name, companyName: isp.company_name },
      impersonated: true,
      expires_in: 1800
    });
  } catch (err) { next(err); }
});

// PUT /admin/isps/:id/expiry — set/edit an ISP's trial/expiry date (admin-only)
router.put('/isps/:id/expiry', async (req, res, next) => {
  const { expiry } = req.body; // ISO datetime string
  if (!expiry) return res.status(400).json({ error: 'expiry datetime is required' });
  const dt = new Date(expiry);
  if (isNaN(dt.getTime())) return res.status(400).json({ error: 'Invalid datetime format' });
  try {
    const r = await query('SELECT id, company_name FROM isps WHERE id=$1::uuid', [req.params.id]);
    if (!r.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    await query('UPDATE isps SET trial_ends_at=$1, license_expires_at=$1, license_status=\'active\' WHERE id=$2::uuid', [dt.toISOString(), req.params.id]);
    logger.info(`[ADMIN] ${req.user.email || req.user.adminId} set expiry of ${r.rows[0].company_name} to ${dt.toISOString()}`);
    res.json({ success: true, isp_id: req.params.id, trial_ends_at: dt.toISOString() });
  } catch (err) { next(err); }
});

// GET /admin/isps/:id/expiry — current expiry (admin-only)
router.get('/isps/:id/expiry', async (req, res, next) => {
  try {
    const r = await query('SELECT COALESCE(license_expires_at, trial_ends_at) AS trial_ends_at, status, plan_type, license_expires_at, license_status FROM isps WHERE id=$1::uuid', [req.params.id]);
    if (!r.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    res.json({ trial_ends_at: r.rows[0].trial_ends_at, status: r.rows[0].status, plan_type: r.rows[0].plan_type });
  } catch (err) { next(err); }
});


// ============================================================
// CROSS-ISP PAYMENT TRACKING
// ============================================================
// GET /admin/payments — all payments across every ISP, with filters
router.get('/payments', async (req, res, next) => {
  try {
    const { page = 1, limit = 25, isp_id, status, gateway, phone, date_from, date_to } = req.query;
    const lim = Math.min(parseInt(limit) || 25, 200);
    const offset = (Math.max(parseInt(page) || 1, 1) - 1) * lim;
    const params = [];
    let w = 'WHERE 1=1';
    let p = 1;
    if (isp_id)   { w += ` AND p.isp_id = $${p++}::uuid`; params.push(isp_id); }
    if (status)   { w += ` AND p.status = $${p++}`; params.push(status); }
    if (gateway)  { w += ` AND p.payment_gateway = $${p++}`; params.push(gateway); }
    if (phone)    { w += ` AND p.phone_number ILIKE $${p++}`; params.push('%' + String(phone).replace(/\D/g, '') + '%'); }
    if (date_from){ w += ` AND p.created_at >= $${p++}`; params.push(date_from); }
    if (date_to)  { w += ` AND p.created_at <= $${p++}`; params.push(date_to); }

    const rows = await query(
      `SELECT p.id, p.amount, p.commission_amount, p.net_amount, p.payment_method, p.payment_gateway,
              p.phone_number, p.status, p.description, p.gateway_reference, p.transaction_id,
              p.created_at, p.paid_at, i.company_name, i.id AS isp_id
       FROM payments p
       LEFT JOIN isps i ON i.id = p.isp_id
       ${w}
       ORDER BY p.created_at DESC
       LIMIT $${p++} OFFSET $${p}`,
      [...params, lim, offset]
    );
    const cnt = await query(`SELECT COUNT(*) FROM payments p ${w}`, params);
    const agg = await query(
      `SELECT COALESCE(SUM(amount),0) total, COALESCE(SUM(amount) FILTER (WHERE status='paid'),0) paid_total,
              COALESCE(SUM(commission_amount) FILTER (WHERE status='paid'),0) commission_total,
              COUNT(*) FILTER (WHERE status='paid') paid_count
       FROM payments p ${w}`,
      params
    );
    res.json({
      payments: rows.rows,
      totals: agg.rows[0],
      pagination: {
        total: parseInt(cnt.rows[0].count),
        page: parseInt(page),
        limit: lim,
        pages: Math.ceil(parseInt(cnt.rows[0].count) / lim)
      }
    });
  } catch (err) { next(err); }
});

// ============================================================
// BILLING — Charge ISPs via M-Pesa STK Push
// ============================================================

// POST /admin/billing/charge — send STK Push to an ISP
router.post('/billing/charge', async (req, res) => {
  const { isp_id, amount, phone, charge_type, description } = req.body;
  if (!isp_id) return res.status(400).json({ error: 'isp_id is required' });
  if (!amount || isNaN(amount) || amount < 1) return res.status(400).json({ error: 'Valid amount is required' });
  if (!phone) return res.status(400).json({ error: 'Phone is required' });

  try {
    const ispRes = await query('SELECT id, company_name FROM isps WHERE id=$1::uuid', [isp_id]);
    if (!ispRes.rows[0]) return res.status(404).json({ error: 'ISP not found' });

    const cfgRes = await query('SELECT * FROM mpesa_configs WHERE is_admin_config=true AND is_active=true LIMIT 1');
    if (!cfgRes.rows[0] || !cfgRes.rows[0].consumer_key) {
      return res.status(400).json({ error: 'Daraja not configured. Go to Admin → Daraja API.' });
    }
    const cfg = cfgRes.rows[0];

    const normPhone = String(phone).replace(/\D/g, '').replace(/^0/, '254').replace(/^\+/, '');
    if (!/^254[17]\d{8}$/.test(normPhone)) {
      return res.status(400).json({ error: `Invalid phone format. Got: ${phone}` });
    }

    const desc = (description || (charge_type ? `Platform: ${charge_type}` : 'Platform charge')).substring(0, 250);

    // Create payment record
    const paymentRes = await query(
      `INSERT INTO payments (isp_id, amount, payment_method, payment_gateway, phone_number, description, status, commission_rate, commission_amount, net_amount)
       VALUES ($1::uuid, $2::decimal, 'mpesa', 'mpesa_stk', $3, $4, 'pending', 0, 0, $2::decimal)
       RETURNING id`,
      [isp_id, amount, normPhone, desc]
    );
    const paymentId = paymentRes.rows[0].id;

    const baseUrl = cfg.is_sandbox ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';

    // OAuth token
    let token;
    try {
      const tokRes = await axios.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, {
        headers: { Authorization: `Basic ${Buffer.from(`${cfg.consumer_key}:${cfg.consumer_secret}`).toString('base64')}` },
        timeout: 10000
      });
      token = tokRes.data.access_token;
      if (!token) throw new Error('No access_token returned');
    } catch (e) {
      const msg = (e.response?.data?.errorMessage || e.message || 'OAuth failed').substring(0, 240);
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid", [msg, paymentId]).catch(()=>{});
      return res.status(400).json({ error: 'Daraja auth failed: ' + msg });
    }

    // STK Push
    const ts = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
    const pwd = Buffer.from(`${cfg.shortcode}${cfg.passkey}${ts}`).toString('base64');

    let stkRes;
    try {
      stkRes = await axios.post(`${baseUrl}/mpesa/stkpush/v1/processrequest`, {
        BusinessShortCode: cfg.shortcode,
        Password: pwd,
        Timestamp: ts,
        TransactionType: 'CustomerPayBillOnline',
        Amount: Math.ceil(amount),
        PartyA: normPhone,
        PartyB: cfg.shortcode,
        PhoneNumber: normPhone,
        CallBackURL: `${process.env.BASE_URL}/api/admin/billing/callback/${paymentId}`,
        AccountReference: paymentId.substring(0, 12),
        TransactionDesc: desc.substring(0, 13)
      }, {
        headers: { Authorization: `Bearer ${token}` },
        timeout: 15000
      });
    } catch (e) {
      const msg = (e.response?.data?.errorMessage || e.response?.data?.ResponseDescription || e.message).substring(0, 240);
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid", [msg, paymentId]).catch(()=>{});
      return res.status(400).json({ error: 'STK Push failed: ' + msg });
    }

    // Track in mpesa_transactions
    try {
      await query(
        `INSERT INTO mpesa_transactions (isp_id, payment_id, checkout_request_id, merchant_request_id, amount, phone, status)
         VALUES ($1::uuid, $2::uuid, $3, $4, $5::decimal, $6, 'pending')`,
        [isp_id, paymentId, stkRes.data.CheckoutRequestID, stkRes.data.MerchantRequestID, amount, normPhone]
      );
    } catch (e) { /* non-fatal */ }

    // Notify ISP
    try {
      await query(
        `INSERT INTO notifications (isp_id, type, title, message) VALUES ($1::uuid, 'warning', 'Payment Requested', $2)`,
        [isp_id, `RumaLink requests KES ${amount}: ${desc}. Enter M-Pesa PIN.`]
      );
    } catch (e) { /* non-fatal */ }

    res.json({
      success: true,
      payment_id: paymentId,
      checkout_request_id: stkRes.data.CheckoutRequestID,
      message: `STK Push sent to ${normPhone}.`
    });
  } catch (err) {
    logger.error('billing/charge unhandled:', err.message, err.stack);
    res.status(500).json({ error: 'Internal: ' + err.message });
  }
});

// POST callback from Safaricom
router.post('/billing/callback/:paymentId', async (req, res) => {
  try {
    const cb = req.body?.Body?.stkCallback;
    if (cb && cb.ResultCode === 0) {
      const items = cb.CallbackMetadata?.Item || [];
      const g = n => items.find(x => x.Name === n)?.Value;
      const receipt = g('MpesaReceiptNumber');
      const payerPhone = g('PhoneNumber');
      const payerAmount = g('Amount');
      await query("UPDATE payments SET status='paid', transaction_id=$1, paid_at=NOW(), mpesa_phone=$2::varchar, mpesa_amount=$3::decimal WHERE id=$4::uuid",
        [receipt, payerPhone ? String(payerPhone) : null, payerAmount || null, req.params.paymentId]);
      await query("UPDATE mpesa_transactions SET status='completed', mpesa_receipt=$1, transaction_date=NOW() WHERE payment_id=$2::uuid", [receipt, req.params.paymentId]).catch(()=>{});
    } else if (cb) {
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid",
        [(cb.ResultDesc || 'Cancelled').substring(0, 240), req.params.paymentId]);
    }
  } catch (e) { logger.error('billing callback:', e.message); }
  res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
});

// GET /admin/billing/charges — recent admin charges
router.get('/billing/charges', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 30, 100);
    const result = await query(
      `SELECT p.id, p.amount, p.description, p.description as charge_type, p.status, p.phone_number,
              p.transaction_id, p.created_at, p.paid_at,
              i.company_name, i.email
       FROM payments p
       JOIN isps i ON i.id = p.isp_id
       WHERE p.payment_gateway = 'mpesa_stk'
         AND (p.description ILIKE 'Platform%' OR p.description ILIKE 'admin%')
       ORDER BY p.created_at DESC
       LIMIT $1`,
      [limit]
    );
    res.json({ charges: result.rows });
  } catch (err) {
    logger.error('billing/charges:', err.message);
    res.json({ charges: [] });
  }
});

// GET /admin/billing/outstanding — unpaid ISP invoices
router.get('/billing/outstanding', async (req, res) => {
  try {
    const result = await query(
      `SELECT pi.id, pi.total_amount as outstanding_amount, pi.due_date, pi.period_month, pi.period_year,
              pi.status, pi.created_at,
              i.company_name, i.email, i.phone, i.plan_type,
              CASE WHEN pi.due_date IS NOT NULL AND pi.due_date < NOW()
                   THEN EXTRACT(DAY FROM NOW() - pi.due_date)::int ELSE 0 END as overdue_days
       FROM isp_platform_invoices pi
       JOIN isps i ON i.id = pi.isp_id
       WHERE pi.status IN ('pending', 'overdue')
       ORDER BY pi.due_date ASC NULLS LAST
       LIMIT 50`
    );
    res.json({ outstanding: result.rows });
  } catch (err) {
    logger.error('billing/outstanding:', err.message);
    res.json({ outstanding: [] });
  }
});

// POST /admin/billing/auto-bill-pppoe — generate monthly invoices
router.post('/billing/auto-bill-pppoe', async (req, res) => {
  const { month, year } = req.body;
  if (!month || !year) return res.status(400).json({ error: 'month and year required' });
  try {
    const ratePerUser = 32;
    const isps = await query(
      `SELECT i.id, i.company_name, COUNT(ps.id) FILTER (WHERE ps.status='active') as user_count
       FROM isps i
       LEFT JOIN pppoe_subscribers ps ON ps.isp_id = i.id
       WHERE i.status='active' AND i.plan_type IN ('pppoe', 'both')
       GROUP BY i.id
       HAVING COUNT(ps.id) FILTER (WHERE ps.status='active') > 0`
    );

    let count = 0;
    for (const isp of isps.rows) {
      const userCount = parseInt(isp.user_count) || 0;
      const existing = await query(
        'SELECT id FROM isp_platform_invoices WHERE isp_id=$1::uuid AND period_month=$2 AND period_year=$3',
        [isp.id, month, year]
      );
      if (existing.rows[0]) continue;
      const amount = userCount * ratePerUser;
      const dueDate = new Date(year, month - 1, 28);
      await query(
        `INSERT INTO isp_platform_invoices
           (isp_id, period_month, period_year, pppoe_user_count, amount_per_user, total_amount, status, due_date)
         VALUES ($1::uuid, $2::int, $3::int, $4::int, $5::decimal, $6::decimal, 'pending', $7)`,
        [isp.id, month, year, userCount, ratePerUser, amount, dueDate]
      ).catch(e => logger.warn(`Invoice ${isp.company_name}: ${e.message}`));
      count++;
    }

    res.json({ success: true, count, message: `Generated ${count} invoices for ${month}/${year}` });
  } catch (err) {
    logger.error('auto-bill:', err.message);
    res.status(500).json({ error: err.message });
  }
});



// GET /admin/payments/by-phone/:phone — cross-reference all payments from a phone number
router.get('/payments/by-phone/:phone', async (req, res) => {
  try {
    const phone = String(req.params.phone).replace(/\D/g, '').replace(/^0/, '254');
    const r = await query(
      `SELECT p.id, p.amount, p.mpesa_amount, p.mpesa_phone, p.phone_number,
              p.payment_method, p.status, p.transaction_id, p.paid_at, p.created_at,
              p.description, i.company_name, i.email
       FROM payments p
       JOIN isps i ON i.id = p.isp_id
       WHERE p.phone_number LIKE $1 OR p.mpesa_phone LIKE $1 OR p.phone_number LIKE $2 OR p.mpesa_phone LIKE $2
       ORDER BY p.created_at DESC LIMIT 100`,
      [`%${phone}%`, `%${phone.slice(-9)}%`]
    );
    res.json({ payments: r.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================
// PLATFORM COMMISSION DEFAULTS (single source of truth)
// ============================================================
router.get('/settings/commission', async (req, res, next) => {
  try {
    const r = await query("SELECT key, value FROM platform_settings WHERE key IN ('hotspot_commission_rate','pppoe_per_user_fee')");
    let hotspot = 0.03, pppoe = 32.25;
    for (const row of r.rows) {
      if (row.key === 'hotspot_commission_rate' && row.value != null) hotspot = parseFloat(row.value);
      if (row.key === 'pppoe_per_user_fee' && row.value != null) pppoe = parseFloat(row.value);
    }
    res.json({ hotspot_commission_rate: hotspot, pppoe_per_user_fee: pppoe });
  } catch (err) { next(err); }
});

router.post('/settings/commission', async (req, res, next) => {
  const { hotspot_commission_rate, pppoe_per_user_fee } = req.body || {};
  try {
    // hotspot rate accepted as a percent (e.g. 3) or fraction (e.g. 0.03); store as fraction.
    if (hotspot_commission_rate !== undefined && hotspot_commission_rate !== null && hotspot_commission_rate !== '') {
      let hr = parseFloat(hotspot_commission_rate);
      if (hr > 1) hr = hr / 100;            // user typed a percent
      if (!(hr >= 0 && hr <= 1)) return res.status(400).json({ error: 'hotspot rate out of range' });
      await query(`INSERT INTO platform_settings (key, value, updated_at) VALUES ('hotspot_commission_rate',$1,NOW())
                   ON CONFLICT (key) DO UPDATE SET value=$1, updated_at=NOW()`, [hr]);
    }
    if (pppoe_per_user_fee !== undefined && pppoe_per_user_fee !== null && pppoe_per_user_fee !== '') {
      const pf = parseFloat(pppoe_per_user_fee);
      if (!(pf >= 0)) return res.status(400).json({ error: 'pppoe fee out of range' });
      await query(`INSERT INTO platform_settings (key, value, updated_at) VALUES ('pppoe_per_user_fee',$1,NOW())
                   ON CONFLICT (key) DO UPDATE SET value=$1, updated_at=NOW()`, [pf]);
    }
    logger.info('[admin] commission defaults updated by ' + (req.user && req.user.email));
    res.json({ ok: true });
  } catch (err) { next(err); }
});

// ============================================================
// SMS RESELLER — admin config, balance, pricing, history, profit
// ============================================================

// GET /admin/settings/sms — TalkSasa creds (masked) + pricing
router.get('/settings/sms', async (req, res, next) => {
  try {
    const c = await query("SELECT provider, api_key, sender_id, base_url, is_active FROM sms_provider_config WHERE id=1");
    const cfg = c.rows[0] || {};
    const s = await query("SELECT key, value FROM platform_settings WHERE key IN ('sms_price_per_sms','sms_cost_per_sms','sms_signup_bonus')");
    let price=0.50, cost=0.35, bonus=50;
    for (const r of s.rows) {
      if (r.key==='sms_price_per_sms') price=parseFloat(r.value);
      if (r.key==='sms_cost_per_sms') cost=parseFloat(r.value);
      if (r.key==='sms_signup_bonus') bonus=parseFloat(r.value);
    }
    res.json({
      provider: cfg.provider || 'talksasa',
      api_key: cfg.api_key ? '***SET***' : '',
      sender_id: cfg.sender_id || '',
      base_url: cfg.base_url || 'https://bulksms.talksasa.com/api/v3',
      is_active: cfg.is_active !== false,
      is_configured: !!cfg.api_key,
      price_per_sms: price, cost_per_sms: cost, signup_bonus: bonus,
      profit_per_sms: Math.round((price - cost) * 10000) / 10000
    });
  } catch (err) { next(err); }
});

// POST /admin/settings/sms — save creds + pricing
router.post('/settings/sms', async (req, res, next) => {
  const { api_key, sender_id, base_url, price_per_sms, cost_per_sms, signup_bonus } = req.body || {};
  try {
    const cur = await query("SELECT api_key FROM sms_provider_config WHERE id=1");
    const keepKey = (api_key === undefined || api_key === '' || api_key === '***SET***') ? (cur.rows[0] ? cur.rows[0].api_key : null) : api_key;
    await query(`UPDATE sms_provider_config SET api_key=$1, sender_id=$2, base_url=COALESCE($3,base_url), updated_at=NOW() WHERE id=1`,
      [keepKey, sender_id || null, base_url || null]);
    const upd = async (k,v) => { if (v!==undefined && v!==null && v!=='') {
      const n=parseFloat(v); if(n>=0) await query(`INSERT INTO platform_settings (key,value,updated_at) VALUES ($1,$2,NOW()) ON CONFLICT (key) DO UPDATE SET value=$2, updated_at=NOW()`,[k,n]); } };
    await upd('sms_price_per_sms', price_per_sms);
    await upd('sms_cost_per_sms', cost_per_sms);
    await upd('sms_signup_bonus', signup_bonus);
    res.json({ ok: true });
  } catch (err) { next(err); }
});

// GET /admin/sms/balance — live balance from TalkSasa
router.get('/sms/balance', async (req, res, next) => {
  try {
    const c = await query("SELECT api_key, base_url FROM sms_provider_config WHERE id=1");
    const cfg = c.rows[0];
    if (!cfg || !cfg.api_key) return res.json({ ok:false, error:'TalkSasa not configured', balance:null });
    const base = (cfg.base_url || 'https://bulksms.talksasa.com/api/v3').replace(/\/$/,'');
    try {
      const r = await axios.get(base + '/balance', { headers:{ Authorization:'Bearer '+cfg.api_key, Accept:'application/json' }, timeout:12000 });
      // TalkSasa v3: { status:'success', data:{ remaining_balance:'Ksh285' } }
      const d = r.data || {};
      const raw = d.data && (d.data.remaining_balance ?? d.data.balance ?? d.data.credit);
      let bal = null, currency = 'KES';
      if (raw != null) {
        const m = String(raw).replace(/,/g,'').match(/([0-9]+(?:\.[0-9]+)?)/);
        if (m) bal = parseFloat(m[1]);
        const cm = String(raw).match(/[A-Za-z]+/);
        if (cm) currency = cm[0].toUpperCase().replace('KSH','KES');
      }
      res.json({ ok:true, balance: bal, balance_label: raw != null ? String(raw) : null, currency, raw: d });
    } catch (e) {
      res.json({ ok:false, error: (e.response && e.response.data && (e.response.data.message||JSON.stringify(e.response.data))) || e.message, balance:null });
    }
  } catch (err) { next(err); }
});

// GET /admin/sms/history — reseller transactions + profit summary
router.get('/sms/history', async (req, res, next) => {
  try {
    const rows = await query(`
      SELECT t.id, t.isp_id, i.company_name, t.txn_type, t.sms_count, t.unit_price, t.unit_cost,
             t.amount_paid, t.profit, t.status, t.created_at
        FROM sms_credit_transactions t
        LEFT JOIN isps i ON i.id = t.isp_id
       ORDER BY t.created_at DESC LIMIT 200`);
    const sums = await query(`
      SELECT
        COALESCE(SUM(CASE WHEN txn_type='purchase' AND status='completed' THEN amount_paid END),0) AS total_revenue,
        COALESCE(SUM(CASE WHEN txn_type='purchase' AND status='completed' THEN profit END),0) AS total_profit,
        COALESCE(SUM(CASE WHEN txn_type='purchase' AND status='completed' THEN sms_count END),0) AS sms_sold,
        COALESCE(SUM(CASE WHEN txn_type='signup_bonus' AND status='completed' THEN sms_count END),0) AS sms_gifted,
        -- total ever allocated to ISPs (purchases + signup bonuses + positive admin adjustments)
        COALESCE(SUM(CASE WHEN txn_type IN ('purchase','signup_bonus','admin_adjust') AND status='completed' AND sms_count>0 THEN sms_count END),0) AS total_allocated
        FROM sms_credit_transactions`);
    // R = sum of ISP remaining balances
    const rem = await query("SELECT COALESCE(SUM(sms_balance),0) AS remaining FROM isps");
    const remaining = parseFloat(rem.rows[0].remaining) || 0;
    const summary = sums.rows[0];
    summary.remaining_allocated = remaining;            // R (used in Allocated card numerator)
    res.json({ transactions: rows.rows, summary });
  } catch (err) { next(err); }
});


// ─── RL_INTASEND_ADMIN: IntaSend keys, fees, and payment tracking ───
router.get('/settings/intasend', async (req, res, next) => {
  try {
    const r = await query("SELECT api_key, private_key, base_url, is_sandbox, is_active FROM payment_provider_configs WHERE provider='intasend' LIMIT 1");
    const c = r.rows[0] || {};
    // mask keys for display
    const mask = v => v ? (String(v).slice(0,6) + '••••' + String(v).slice(-4)) : '';
    res.json({ configured: !!r.rows[0], api_key_masked: mask(c.api_key), private_key_masked: mask(c.private_key), base_url: c.base_url || 'https://payment.intasend.com', is_sandbox: c.is_sandbox !== false, is_active: !!c.is_active });
  } catch (e) { next(e); }
});

router.post('/settings/intasend', async (req, res, next) => {
  try {
    const { api_key, private_key, base_url, is_sandbox, is_active } = req.body || {};
    const ex = await query("SELECT id FROM payment_provider_configs WHERE provider='intasend' LIMIT 1");
    if (ex.rows[0]) {
      // Only overwrite keys if provided (non-empty), so admins can toggle active without re-entering.
      await query(
        `UPDATE payment_provider_configs SET
           api_key = COALESCE(NULLIF($1,''), api_key),
           private_key = COALESCE(NULLIF($2,''), private_key),
           base_url = COALESCE(NULLIF($3,''), base_url),
           is_sandbox = COALESCE($4, is_sandbox),
           is_active = COALESCE($5, is_active),
           updated_at = NOW()
         WHERE provider='intasend'`,
        [api_key||'', private_key||'', base_url||'', (typeof is_sandbox==='boolean'?is_sandbox:null), (typeof is_active==='boolean'?is_active:null)]);
    } else {
      await query(
        "INSERT INTO payment_provider_configs (provider, label, api_key, private_key, base_url, is_sandbox, is_active) VALUES ('intasend','IntaSend (Admin)',$1,$2,$3,$4,$5)",
        [api_key||'', private_key||'', base_url||'https://payment.intasend.com', is_sandbox!==false, !!is_active]);
    }
    res.json({ success: true });
  } catch (e) { next(e); }
});

router.get('/settings/intasend-fees', async (req, res, next) => {
  try {
    const r = await query("SELECT key, value FROM platform_settings WHERE key LIKE 'intasend_%' ORDER BY key");
    const m = {}; for (const row of r.rows) m[row.key] = parseFloat(row.value);
    res.json({ fees: m });
  } catch (e) { next(e); }
});

router.post('/settings/intasend-fees', async (req, res, next) => {
  try {
    const updates = req.body || {};
    const allowed = new Set(["intasend_collection_mpesa_pct","intasend_collection_mpesa_max","intasend_collection_card_pct","intasend_collection_cardintl_pct","intasend_payout_mpesa_pct","intasend_payout_mpesa_min","intasend_payout_mpesa_max","intasend_payout_bank_t1_max","intasend_payout_bank_t1_fee","intasend_payout_bank_t2_max","intasend_payout_bank_t2_fee","intasend_payout_bank_t3_max","intasend_payout_bank_t3_fee","intasend_payout_bank_t4_max","intasend_payout_bank_t4_fee","intasend_payout_bank_t5_max","intasend_payout_bank_t5_fee","intasend_payout_paybill_t1_max","intasend_payout_paybill_t1_fee","intasend_payout_paybill_t2_max","intasend_payout_paybill_t2_fee","intasend_payout_paybill_t3_max","intasend_payout_paybill_t3_fee","intasend_payout_paybill_t4_max","intasend_payout_paybill_t4_fee","intasend_payout_paybill_t5_max","intasend_payout_paybill_t5_fee","intasend_payout_paybill_t6_max","intasend_payout_paybill_t6_fee","intasend_payout_paybill_t7_max","intasend_payout_paybill_t7_fee","intasend_payout_till_threshold","intasend_payout_till_fee_low","intasend_payout_till_fee_high","intasend_max_fee_ratio","intasend_method_mpesa_enabled","intasend_method_bank_enabled","intasend_method_paybill_enabled","intasend_method_till_enabled"]);
    let n = 0;
    for (const [k,v] of Object.entries(updates)) {
      if (!allowed.has(k)) continue;
      const num = parseFloat(v); if (isNaN(num)) continue;
      await query("INSERT INTO platform_settings(key,value) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET value=$2, updated_at=NOW()", [k, num]);
      n++;
    }
    // bust the fee cache in the fee engine (best-effort)
    try { require('../utils/intasend-fees').invalidate(); } catch(_){}
    res.json({ success: true, updated: n });
  } catch (e) { next(e); }
});

// RL_TRACK_SEARCH: withdrawals with destination, server-side search & pagination.
router.get('/intasend/withdrawals', async (req, res, next) => {
  try {
    const q = String(req.query.q || '').trim();
    const page = Math.max(1, parseInt(req.query.page || '1', 10) || 1);
    const limit = Math.min(100, Math.max(10, parseInt(req.query.limit || '25', 10) || 25));
    const offset = (page - 1) * limit;

    const params = [];
    let where = '1=1';
    if (q) {
      params.push('%' + q + '%');
      const i = params.length;
      where += ` AND (
        i.company_name ILIKE $${i}
        OR w.intasend_ref ILIKE $${i}
        OR w.method ILIKE $${i}
        OR w.status ILIKE $${i}
        OR w.gross_amount::text ILIKE $${i}
        OR w.destination::text ILIKE $${i}
      )`;
    }

    const countRes = await query(
      `SELECT COUNT(*) AS total FROM intasend_withdrawals w LEFT JOIN isps i ON i.id = w.isp_id WHERE ${where}`, params);
    const total = parseInt(countRes.rows[0].total, 10) || 0;

    const rows = await query(
      `SELECT w.id, w.isp_id, i.company_name, w.method, w.destination, w.gross_amount, w.fee_amount,
              w.net_amount, w.below_threshold, w.status, w.intasend_ref, w.intasend_state,
              w.failure_reason, w.created_at
       FROM intasend_withdrawals w LEFT JOIN isps i ON i.id = w.isp_id
       WHERE ${where}
       ORDER BY w.created_at DESC
       LIMIT ${limit} OFFSET ${offset}`, params);

    res.json({
      withdrawals: rows.rows,
      page, limit, total,
      pages: Math.max(1, Math.ceil(total / limit)),
    });
  } catch (e) { next(e); }
});

// RL_TRACK_SEARCH: collections with phone + receipt, server-side search & pagination.
router.get('/intasend/collections', async (req, res, next) => {
  try {
    const q = String(req.query.q || '').trim();
    const page = Math.max(1, parseInt(req.query.page || '1', 10) || 1);
    const limit = Math.min(100, Math.max(10, parseInt(req.query.limit || '25', 10) || 25));
    const offset = (page - 1) * limit;

    const params = [];
    let where = "p.payment_gateway = 'intasend'";   // IntaSend rows ONLY
    if (q) {
      params.push('%' + q + '%');
      const i = params.length;
      // search: phone, M-Pesa receipt, our api_ref, ISP name, status, amount
      where += ` AND (
        p.phone_number ILIKE $${i}
        OR p.transaction_id ILIKE $${i}
        OR p.gateway_reference ILIKE $${i}
        OR i.company_name ILIKE $${i}
        OR p.status::text ILIKE $${i}
        OR p.amount::text ILIKE $${i}
      )`;
    }

    const countRes = await query(
      `SELECT COUNT(*) AS total FROM payments p LEFT JOIN isps i ON i.id = p.isp_id WHERE ${where}`, params);
    const total = parseInt(countRes.rows[0].total, 10) || 0;

    const rows = await query(
      `SELECT p.id, p.isp_id, i.company_name, p.amount, p.commission_amount, p.net_amount,
              p.payment_method, p.status, p.created_at,
              p.phone_number, p.transaction_id, p.gateway_reference, p.metadata
       FROM payments p LEFT JOIN isps i ON i.id = p.isp_id
       WHERE ${where}
       ORDER BY p.created_at DESC
       LIMIT ${limit} OFFSET ${offset}`, params);

    res.json({
      collections: rows.rows,
      page, limit, total,
      pages: Math.max(1, Math.ceil(total / limit)),
    });
  } catch (e) { next(e); }
});


// RL_INTASEND_STRICT: totals for the tracking page stat cards (IntaSend only).
router.get('/intasend/summary', async (req, res, next) => {
  try {
    const c = await query(
      `SELECT COALESCE(SUM(amount),0) AS gross, COALESCE(SUM(commission_amount),0) AS fees,
              COALESCE(SUM(net_amount),0) AS net, COUNT(*) AS n
       FROM payments WHERE payment_gateway='intasend' AND status='paid'   -- RL_ENUM_FIX: payment_status enum has no 'completed'/'success'`);
    const w = await query(
      `SELECT COALESCE(SUM(gross_amount),0) AS gross, COALESCE(SUM(fee_amount),0) AS fees,
              COALESCE(SUM(net_amount),0) AS net, COUNT(*) AS n,
              COUNT(*) FILTER (WHERE status='pending' OR status='processing') AS pending,
              COUNT(*) FILTER (WHERE status='failed') AS failed
       FROM intasend_withdrawals`);
    res.json({
      collections: c.rows[0] || { gross:0, fees:0, net:0, n:0 },
      withdrawals: w.rows[0] || { gross:0, fees:0, net:0, n:0, pending:0, failed:0 },
    });
  } catch (e) { next(e); }
});

// RL_RESTORE_ROUTES: list backups + restore one (snapshots current first).
router.get('/system/backups', async (req, res) => {
  try { res.json({ ok:true, backups: require('../utils/system-restore').listBackups() }); }
  catch (e) { res.status(500).json({ error: e.message }); }
});
router.post('/system/restore', async (req, res) => {
  try {
    const phrase = String((req.body && req.body.confirm) || '');
    if (phrase !== 'RESTORE DATABASE') return res.status(400).json({ error: 'Type: RESTORE DATABASE' });
    const file = String((req.body && req.body.file) || '');
    if (!file) return res.status(400).json({ error: 'No backup selected' });
    const admin = req.user && (req.user.email || req.user.id);
    logger.warn('[system-restore] INITIATED by admin=' + admin + ' file=' + file);
    const result = await require('../utils/system-restore').restore(file);
    logger.warn('[system-restore] DONE by admin=' + admin);
    res.json({ ok:true, message:'Restore complete. A snapshot of the previous state was saved first.', ...result });
  } catch (e) { logger.error('[system-restore] FAILED: ' + e.message); res.status(500).json({ error: e.message }); }
});

// RL_BACKUP_ONLY_ROUTE: create a backup WITHOUT wiping — lets the admin verify backups work first.
router.post('/system/backup', async (req, res) => {
  try {
    const { exec } = require('child_process');
    const fsx = require('fs'); const path = require('path');
    const dir = '/var/www/rumalink/backups'; fsx.mkdirSync(dir, { recursive: true });
    const stamp = new Date().toISOString().replace(/[:.]/g,'-');
    const file = path.join(dir, 'manual-' + stamp + '.sql');
    const db = process.env.DB_NAME || 'rumalink_db';
    exec('sudo -u postgres pg_dump ' + db + ' > "' + file + '"', { maxBuffer: 1024*1024*512 }, (err) => {
      if (err) return res.status(500).json({ error: 'backup failed: ' + err.message });
      const sz = fsx.existsSync(file) ? fsx.statSync(file).size : 0;
      res.json({ ok: true, file, size: sz, human: (sz/1024).toFixed(1) + ' KB' });
    });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// RL_SYSTEM_RESET_ROUTE: wipe test data, keep config. Requires admin auth + exact confirm phrase.
router.post('/system/reset', async (req, res, next) => {
  try {
    const phrase = String((req.body && req.body.confirm) || '');
    if (phrase !== 'RESET TO PRODUCTION') {
      return res.status(400).json({ error: 'Confirmation phrase incorrect. Type: RESET TO PRODUCTION' });
    }
    const admin = req.user && (req.user.email || req.user.id);
    logger.warn('[system-reset] INITIATED by admin=' + admin);
    const { resetToProduction } = require('../utils/system-reset');
    const result = await resetToProduction();
    logger.warn('[system-reset] DONE by admin=' + admin + ' backup=' + result.backup);
    res.json({ ok: true, message: 'System reset complete. Test data wiped; config preserved.', ...result });
  } catch (e) {
    logger.error('[system-reset] FAILED: ' + e.message);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
