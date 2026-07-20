const express = require('express');
const bcrypt = require('bcryptjs');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');
const multer = require('multer');
const path = require('path');

const router = express.Router();
router.use(authenticateToken, requireISP);

const storage = multer.diskStorage({
  destination: './uploads/logos',
  filename: (req, file, cb) => {
    cb(null, `${req.user.ispId}-${Date.now()}${path.extname(file.originalname)}`);
  }
});
const upload = multer({ storage, limits: { fileSize: 2 * 1024 * 1024 } });

// ISP Dashboard stats
router.get('/stats', async (req, res, next) => {
  const ispId = req.user.ispId;
  try {
    const [devices, hotspot, pppoe, revenue, sessions] = await Promise.all([
      query(`SELECT COUNT(*) as total, COUNT(*) FILTER (WHERE is_online) as online, COUNT(*) FILTER (WHERE is_provisioned) as provisioned FROM nas_devices WHERE isp_id = $1`, [ispId]),
      query(`SELECT 
        COUNT(*) as total_vouchers,
        COUNT(*) FILTER (WHERE status = 'unused') as unused_vouchers,
        COUNT(*) FILTER (WHERE status = 'active') as active_vouchers,
        COUNT(*) FILTER (WHERE status = 'used') as used_vouchers
        FROM hotspot_vouchers WHERE isp_id = $1`, [ispId]),
      query(`SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status = 'active') as active,
        COUNT(*) FILTER (WHERE status = 'suspended') as suspended,
        COUNT(*) FILTER (WHERE next_billing_date <= NOW() + INTERVAL '3 days' AND status = 'active') as expiring_soon
        FROM pppoe_subscribers WHERE isp_id = $1`, [ispId]),
      query(`SELECT
        COALESCE(SUM(amount) FILTER (WHERE status = 'paid' AND paid_at >= DATE_TRUNC('month', NOW())), 0) as this_month,
        COALESCE(SUM(amount) FILTER (WHERE status = 'paid' AND paid_at >= NOW() - INTERVAL '24 hours'), 0) as today,
        COALESCE(SUM(amount) FILTER (WHERE status = 'paid'), 0) as total,
        COALESCE(SUM(commission_amount) FILTER (WHERE status = 'paid'), 0) as total_commission
        FROM payments WHERE isp_id = $1`, [ispId]),
      query(`SELECT
        (SELECT COUNT(*) FROM hotspot_sessions WHERE isp_id = $1 AND status = 'active') as active_hotspot,
        (SELECT COUNT(*) FROM pppoe_sessions WHERE isp_id = $1 AND status = 'active') as active_pppoe`, [ispId])
    ]);

    const isp = await query(`SELECT wallet_balance, plan_type, trial_ends_at FROM isps WHERE id = $1`, [ispId]);

    res.json({
      devices: devices.rows[0],
      hotspot: hotspot.rows[0],
      pppoe: pppoe.rows[0],
      revenue: revenue.rows[0],
      sessions: sessions.rows[0],
      wallet_balance: isp.rows[0]?.wallet_balance,
      plan_type: isp.rows[0]?.plan_type,
      trial_ends_at: isp.rows[0]?.trial_ends_at
    });
  } catch (err) { next(err); }
});

// Revenue chart
router.get('/revenue-chart', async (req, res, next) => {
  const ispId = req.user.ispId;
  const { days = 30 } = req.query;
  try {
    const result = await query(`
      SELECT DATE(paid_at) as date,
             COALESCE(SUM(amount), 0) as amount,
             payment_method
      FROM payments
      WHERE isp_id = $1 AND status = 'paid' AND paid_at >= NOW() - INTERVAL '${parseInt(days)} days'
      GROUP BY DATE(paid_at), payment_method
      ORDER BY date ASC
    `, [ispId]);
    res.json({ data: result.rows });
  } catch (err) { next(err); }
});

// ISP Profile
router.get('/profile', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT id, company_name, owner_name, email, phone, county, town, address,
              plan_type, status, api_key, logo_url, sms_gateway, sms_sender_id,
              support_number,
              wallet_balance, total_earned, total_commission_paid, trial_ends_at,
              currency, timezone, created_at
       FROM isps WHERE id = $1`,
      [req.user.ispId]
    );
    res.json({ profile: result.rows[0] });
  } catch (err) { next(err); }
});

// Update profile
router.put('/profile', async (req, res, next) => {
  const { company_name, owner_name, phone, county, town, address, sms_gateway, sms_api_key, sms_sender_id, webhook_url, support_number } = req.body;
  try {
    const result = await query(`
      UPDATE isps SET 
      company_name = COALESCE($1, company_name), 
      owner_name = COALESCE($2, owner_name), 
      phone = COALESCE($3, phone), 
      county = COALESCE($4, county), 
      town = COALESCE($5, town),
      address = COALESCE($6, address), 
      sms_gateway = COALESCE($7, sms_gateway), 
      sms_api_key = COALESCE($8, sms_api_key), 
      sms_sender_id = COALESCE($9, sms_sender_id),
      webhook_url = COALESCE($10, webhook_url),
      support_number = COALESCE($11, support_number),
      updated_at = NOW()
    WHERE id = $12
      RETURNING id, company_name, owner_name, email, phone, support_number
    `, [company_name, owner_name, phone, county, town, address, sms_gateway, sms_api_key, sms_sender_id, webhook_url, support_number || null, req.user.ispId]);
    res.json({ profile: result.rows[0] });
  } catch (err) { next(err); }
});

// Upload logo
router.post('/logo', upload.single('logo'), async (req, res, next) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  try {
    const logoUrl = `/uploads/logos/${req.file.filename}`;
    await query('UPDATE isps SET logo_url = $1 WHERE id = $2', [logoUrl, req.user.ispId]);
    res.json({ logo_url: logoUrl });
  } catch (err) { next(err); }
});

// Change password
router.post('/change-password', async (req, res, next) => {
  const { current_password, new_password } = req.body;
  if (!current_password || !new_password || new_password.length < 8) {
    return res.status(400).json({ error: 'Invalid password data' });
  }
  try {
    const isp = await query('SELECT password_hash FROM isps WHERE id = $1', [req.user.ispId]);
    if (!await bcrypt.compare(current_password, isp.rows[0].password_hash)) {
      return res.status(401).json({ error: 'Current password incorrect' });
    }
    const hash = await bcrypt.hash(new_password, 12);
    await query('UPDATE isps SET password_hash = $1 WHERE id = $2', [hash, req.user.ispId]);
    res.json({ message: 'Password updated successfully' });
  } catch (err) { next(err); }
});

// Regenerate API key
router.post('/regenerate-api-key', async (req, res, next) => {
  try {
    const result = await query(
      `UPDATE isps SET api_key = uuid_generate_v4(), api_secret = encode(gen_random_bytes(32), 'hex') WHERE id = $1 RETURNING api_key, api_secret`,
      [req.user.ispId]
    );
    res.json({ api_key: result.rows[0].api_key, api_secret: result.rows[0].api_secret });
  } catch (err) { next(err); }
});

// ISP recent activity
router.get('/activity', async (req, res, next) => {
  const ispId = req.user.ispId;
  try {
    const [payments, sessions] = await Promise.all([
      query(`SELECT amount, payment_method, status, description, created_at FROM payments WHERE isp_id = $1 ORDER BY created_at DESC LIMIT 20`, [ispId]),
      query(`SELECT 'hotspot' as type, ip_address as identifier, started_at, ended_at, bytes_downloaded FROM hotspot_sessions WHERE isp_id = $1 ORDER BY started_at DESC LIMIT 10
             UNION ALL
             SELECT 'pppoe', framed_ip, started_at, ended_at, bytes_downloaded FROM pppoe_sessions WHERE isp_id = $1 ORDER BY started_at DESC LIMIT 10`, [ispId])
    ]);
    res.json({ payments: payments.rows, sessions: sessions.rows });
  } catch (err) { next(err); }
});

// ISP transactions (wallet)
router.get('/transactions', async (req, res, next) => {
  const { page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;
  try {
    const result = await query(
      `SELECT * FROM isp_transactions WHERE isp_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
      [req.user.ispId, limit, offset]
    );
    const count = await query('SELECT COUNT(*) FROM isp_transactions WHERE isp_id = $1', [req.user.ispId]);
    res.json({ transactions: result.rows, total: parseInt(count.rows[0].count) });
  } catch (err) { next(err); }
});

module.exports = router;
