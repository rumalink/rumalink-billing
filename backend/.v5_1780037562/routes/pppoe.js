const express = require('express');
const bcrypt = require('bcryptjs');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');
const { sendSMS } = require('../utils/sms');

const router = express.Router();
router.use(authenticateToken, requireISP);

// ============================================================
// PACKAGES
// ============================================================
router.get('/packages', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT pp.*, COUNT(ps.id) as subscriber_count
       FROM pppoe_packages pp
       LEFT JOIN pppoe_subscribers ps ON ps.package_id = pp.id AND ps.status = 'active'
       WHERE pp.isp_id = $1 GROUP BY pp.id ORDER BY pp.price ASC`,
      [req.user.ispId]
    );
    res.json({ packages: result.rows });
  } catch (err) { next(err); }
});

router.post('/packages', async (req, res, next) => {
  const { name, description, price, billing_cycle, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_gb, burst_limit_mbps, mikrotik_profile, address_pool } = req.body;
  if (!name || !price) return res.status(400).json({ error: 'Name and price are required' });
  try {
    const result = await query(`
      INSERT INTO pppoe_packages (isp_id, name, description, price, billing_cycle, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_gb, burst_limit_mbps, mikrotik_profile, address_pool)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *
    `, [req.user.ispId, name, description, price, billing_cycle || 'monthly', bandwidth_down_mbps, bandwidth_up_mbps, data_limit_gb, burst_limit_mbps, mikrotik_profile, address_pool]);
    res.status(201).json({ package: result.rows[0] });
  } catch (err) { next(err); }
});

router.put('/packages/:id', async (req, res, next) => {
  const { name, description, price, billing_cycle, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_gb, mikrotik_profile, address_pool, is_active } = req.body;
  try {
    const result = await query(`
      UPDATE pppoe_packages SET name=$1, description=$2, price=$3, billing_cycle=$4,
        bandwidth_down_mbps=$5, bandwidth_up_mbps=$6, data_limit_gb=$7,
        mikrotik_profile=$8, address_pool=$9, is_active=$10, updated_at=NOW()
      WHERE id=$11 AND isp_id=$12 RETURNING *
    `, [name, description, price, billing_cycle, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_gb, mikrotik_profile, address_pool, is_active, req.params.id, req.user.ispId]);
    if (!result.rows[0]) return res.status(404).json({ error: 'Package not found' });
    res.json({ package: result.rows[0] });
  } catch (err) { next(err); }
});

// ============================================================
// SUBSCRIBERS
// ============================================================
router.get('/subscribers', async (req, res, next) => {
  const { page = 1, limit = 20, status, search } = req.query;
  const offset = (page - 1) * limit;
  let where = 'WHERE ps.isp_id = $1';
  const params = [req.user.ispId];
  let idx = 2;

  if (status) { where += ` AND ps.status = $${idx++}`; params.push(status); }
  if (search) {
    where += ` AND (ps.username ILIKE $${idx} OR ps.full_name ILIKE $${idx} OR ps.phone ILIKE $${idx})`;
    params.push(`%${search}%`); idx++;
  }

  try {
    const result = await query(`
      SELECT ps.id, ps.username, ps.full_name, ps.phone, ps.email, ps.status,
             ps.balance, ps.next_billing_date, ps.last_payment_date, ps.county, ps.town, ps.created_at,
             pp.name as package_name, pp.price as package_price, pp.bandwidth_down_mbps, pp.bandwidth_up_mbps,
             (SELECT COUNT(*) FROM pppoe_sessions ses WHERE ses.subscriber_id = ps.id AND ses.status = 'active') as is_online
      FROM pppoe_subscribers ps
      JOIN pppoe_packages pp ON pp.id = ps.package_id
      ${where}
      ORDER BY ps.created_at DESC LIMIT $${idx} OFFSET $${idx + 1}
    `, [...params, limit, offset]);

    const count = await query(`SELECT COUNT(*) FROM pppoe_subscribers ps ${where}`, params);

    res.json({
      subscribers: result.rows,
      pagination: {
        total: parseInt(count.rows[0].count),
        page: parseInt(page),
        limit: parseInt(limit)
      }
    });
  } catch (err) { next(err); }
});

router.post('/subscribers', async (req, res, next) => {
  const { username, password, full_name, phone, email, id_number, package_id, nas_id, county, town, physical_address, static_ip } = req.body;
  if (!username || !password || !full_name || !package_id) {
    return res.status(400).json({ error: 'Username, password, full name and package are required' });
  }

  try {
    // Check username unique per ISP
    const existing = await query('SELECT id FROM pppoe_subscribers WHERE isp_id = $1 AND username = $2', [req.user.ispId, username]);
    if (existing.rows.length > 0) return res.status(409).json({ error: 'Username already exists' });

    const pkg = await query('SELECT * FROM pppoe_packages WHERE id = $1 AND isp_id = $2', [package_id, req.user.ispId]);
    if (!pkg.rows[0]) return res.status(404).json({ error: 'Package not found' });

    const password_hash = await bcrypt.hash(password, 10);
    const nextBilling = new Date();
    nextBilling.setMonth(nextBilling.getMonth() + 1);

    const result = await query(`
      INSERT INTO pppoe_subscribers (
        isp_id, package_id, nas_id, username, password_hash, full_name, phone, email,
        id_number, county, town, physical_address, static_ip, next_billing_date
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
      RETURNING id, username, full_name, phone, status, created_at
    `, [req.user.ispId, package_id, nas_id, username, password_hash, full_name, phone, email, id_number, county, town, physical_address, static_ip, nextBilling]);

    const subscriber = result.rows[0];

    // Add to RADIUS
    await query(`INSERT INTO radcheck (username, attribute, op, value) VALUES ($1, 'Cleartext-Password', ':=', $2)`, [username, password]);
    if (pkg.rows[0].mikrotik_profile) {
      await query(`INSERT INTO radusergroup (username, groupname, priority) VALUES ($1, $2, 1)`, [username, pkg.rows[0].mikrotik_profile]);
    }

    // Welcome SMS
    if (phone) {
      const isp = await query('SELECT company_name, sms_gateway, sms_api_key, sms_sender_id FROM isps WHERE id = $1', [req.user.ispId]);
      if (isp.rows[0]?.sms_gateway) {
        try {
          await sendSMS({
            to: phone,
            message: `Welcome to ${isp.rows[0].company_name}! Your PPPoE username: ${username}. Next billing: ${nextBilling.toLocaleDateString()}. Powered by RumaLink.`,
            isp: isp.rows[0]
          });
        } catch (smsErr) {}
      }
    }

    res.status(201).json({ subscriber });
  } catch (err) { next(err); }
});

router.get('/subscribers/:id', async (req, res, next) => {
  try {
    const sub = await query(`
      SELECT ps.*, pp.name as package_name, pp.price, pp.bandwidth_down_mbps, pp.bandwidth_up_mbps,
             n.name as device_name
      FROM pppoe_subscribers ps
      JOIN pppoe_packages pp ON pp.id = ps.package_id
      LEFT JOIN nas_devices n ON n.id = ps.nas_id
      WHERE ps.id = $1 AND ps.isp_id = $2
    `, [req.params.id, req.user.ispId]);

    if (!sub.rows[0]) return res.status(404).json({ error: 'Subscriber not found' });

    const [payments, sessions, invoices] = await Promise.all([
      query(`SELECT amount, payment_method, status, description, paid_at, created_at FROM payments WHERE subscriber_id = $1 ORDER BY created_at DESC LIMIT 20`, [req.params.id]),
      query(`SELECT framed_ip, bytes_downloaded, bytes_uploaded, session_time_seconds, started_at, ended_at, status FROM pppoe_sessions WHERE subscriber_id = $1 ORDER BY started_at DESC LIMIT 20`, [req.params.id]),
      query(`SELECT * FROM pppoe_invoices WHERE subscriber_id = $1 ORDER BY created_at DESC LIMIT 12`, [req.params.id])
    ]);

    res.json({ subscriber: sub.rows[0], payments: payments.rows, sessions: sessions.rows, invoices: invoices.rows });
  } catch (err) { next(err); }
});

router.put('/subscribers/:id', async (req, res, next) => {
  const { full_name, phone, email, id_number, package_id, county, town, physical_address, static_ip, status } = req.body;
  try {
    const result = await query(`
      UPDATE pppoe_subscribers SET full_name=$1, phone=$2, email=$3, id_number=$4,
        package_id=COALESCE($5, package_id), county=$6, town=$7, physical_address=$8,
        static_ip=$9, status=COALESCE($10, status), updated_at=NOW()
      WHERE id=$11 AND isp_id=$12 RETURNING *
    `, [full_name, phone, email, id_number, package_id, county, town, physical_address, static_ip, status, req.params.id, req.user.ispId]);
    if (!result.rows[0]) return res.status(404).json({ error: 'Subscriber not found' });
    res.json({ subscriber: result.rows[0] });
  } catch (err) { next(err); }
});

// Suspend/activate subscriber
router.patch('/subscribers/:id/status', async (req, res, next) => {
  const { status } = req.body;
  if (!['active', 'suspended', 'inactive'].includes(status)) {
    return res.status(400).json({ error: 'Invalid status' });
  }
  try {
    const result = await query(
      `UPDATE pppoe_subscribers SET status=$1, updated_at=NOW() WHERE id=$2 AND isp_id=$3 RETURNING username, full_name, status`,
      [status, req.params.id, req.user.ispId]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Subscriber not found' });

    // Update RADIUS - add/remove reject attribute
    if (status === 'suspended') {
      await query(`INSERT INTO radcheck (username, attribute, op, value) VALUES ($1, 'Auth-Type', ':=', 'Reject') ON CONFLICT DO NOTHING`, [result.rows[0].username]);
    } else {
      await query(`DELETE FROM radcheck WHERE username=$1 AND attribute='Auth-Type' AND value='Reject'`, [result.rows[0].username]);
    }

    res.json({ subscriber: result.rows[0] });
  } catch (err) { next(err); }
});

// Delete subscriber
router.delete('/subscribers/:id', async (req, res, next) => {
  try {
    const sub = await query('SELECT username FROM pppoe_subscribers WHERE id = $1 AND isp_id = $2', [req.params.id, req.user.ispId]);
    if (!sub.rows[0]) return res.status(404).json({ error: 'Subscriber not found' });
    
    // Remove from RADIUS
    await query('DELETE FROM radcheck WHERE username = $1', [sub.rows[0].username]);
    await query('DELETE FROM radreply WHERE username = $1', [sub.rows[0].username]);
    await query('DELETE FROM radusergroup WHERE username = $1', [sub.rows[0].username]);
    
    await query('DELETE FROM pppoe_subscribers WHERE id = $1', [req.params.id]);
    res.json({ message: 'Subscriber deleted' });
  } catch (err) { next(err); }
});

// PPPoE sessions
router.get('/sessions', async (req, res, next) => {
  const { status = 'active', page = 1, limit = 50 } = req.query;
  const offset = (page - 1) * limit;
  try {
    const result = await query(`
      SELECT ps.*, sub.username, sub.full_name, sub.phone,
             pp.name as package_name, n.name as device_name
      FROM pppoe_sessions ps
      JOIN pppoe_subscribers sub ON sub.id = ps.subscriber_id
      JOIN pppoe_packages pp ON pp.id = sub.package_id
      LEFT JOIN nas_devices n ON n.id = ps.nas_id
      WHERE ps.isp_id = $1 AND ps.status = $2
      ORDER BY ps.started_at DESC LIMIT $3 OFFSET $4
    `, [req.user.ispId, status, limit, offset]);
    res.json({ sessions: result.rows });
  } catch (err) { next(err); }
});

module.exports = router;

// ── Send payment details to subscriber ──
router.post('/subscribers/:id/send-payment-details', async (req, res, next) => {
  try {
    const sub = await query(`
      SELECT ps.*, pp.name as pkg_name, pp.price,
             i.company_name, i.sms_gateway, i.sms_api_key, i.sms_sender_id,
             pm.method_type, pm.till_number, pm.paybill_number, pm.account_number,
             pm.bank_name, pm.account_name, pm.account_reference
      FROM pppoe_subscribers ps
      JOIN pppoe_packages pp ON pp.id = ps.package_id
      JOIN isps i ON i.id = ps.isp_id
      LEFT JOIN isp_payment_methods pm ON pm.isp_id = i.id AND pm.is_default=true AND pm.is_active=true
      WHERE ps.id=$1 AND ps.isp_id=$2
    `, [req.params.id, req.user.ispId]);

    if (!sub.rows[0]) return res.status(404).json({ error: 'Subscriber not found' });
    const s = sub.rows[0];
    if (!s.phone) return res.status(400).json({ error: 'Subscriber has no phone number' });

    let payDetails = 'Contact your ISP for payment details.';
    if (s.method_type === 'till') payDetails = `Pay KES ${s.price} via MPesa:\nBuy Goods Till: ${s.till_number}`;
    else if (s.method_type === 'paybill') payDetails = `Pay KES ${s.price} via MPesa:\nPaybill: ${s.paybill_number}\nAccount: ${s.account_reference || s.username}`;
    else if (s.method_type === 'bank') payDetails = `Pay KES ${s.price} via Bank:\n${s.bank_name}\nAcc: ${s.account_number} (${s.account_name})`;
    else if (s.method_type === 'mpesa_stk') payDetails = `Pay KES ${s.price} via MPesa to ${s.paybill_number || s.shortcode}`;

    const { sendSMS } = require('../utils/sms');
    await sendSMS({
      to: s.phone,
      message: `Dear ${s.full_name}, your ${s.company_name} internet plan (${s.pkg_name}) costs KES ${s.price}/month. Due: ${new Date(s.next_billing_date).toLocaleDateString('en-KE')}.\n${payDetails}`,
      isp: s
    });

    await query('INSERT INTO sms_logs (isp_id, recipient, message, gateway) VALUES ($1,$2,$3,$4)',
      [req.user.ispId, s.phone, 'Payment details sent', s.sms_gateway || 'platform']);

    res.json({ message: `Payment details sent to ${s.phone}` });
  } catch (err) { next(err); }
});
