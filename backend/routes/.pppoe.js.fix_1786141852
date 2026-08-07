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
      INSERT INTO pppoe_packages (isp_id, name, description, price, billing_cycle, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_gb, burst_limit_mbps, mikrotik_profile, address_pool, visible_in_portal)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11, $12) RETURNING *
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
      , visible_in_portal=COALESCE($11, visible_in_portal) /* RL_PPPOE_VIS_FIELD */ WHERE id=$11 AND isp_id=$12 RETURNING *
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
             (SELECT COUNT(*) FROM pppoe_sessions ses WHERE ses.subscriber_id = ps.id AND ses.status = 'active') as is_online, ps.is_test FROM pppoe_subscribers ps
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
  const { username, password, full_name, phone, email, id_number, package_id, nas_id, county, town, physical_address, static_ip, is_test } = req.body;
  if (!username || !password || !full_name || !package_id) {
    return res.status(400).json({ error: 'Username, password, full name and package are required' });
  }

  try {
    // Check username unique per ISP
    const existing = await query('SELECT id FROM pppoe_subscribers WHERE isp_id = $1 AND username = $2', [req.user.ispId, username]);
    if (existing.rows.length > 0) return res.status(409).json({ error: 'Username already exists' });

    const pkg = await query('SELECT * FROM pppoe_packages WHERE id = $1 AND isp_id = $2', [package_id, req.user.ispId]);
    if (!pkg.rows[0]) return res.status(404).json({ error: 'Package not found' });

    // Auto-assign nas_id if not provided by frontend
    let resolved_nas_id = nas_id || null;
    if (!resolved_nas_id) {
      try {
        const _nr = await query('SELECT id FROM nas_devices WHERE isp_id=$1::uuid AND wireguard_ip IS NOT NULL ORDER BY created_at ASC LIMIT 1', [req.user.ispId]);
        resolved_nas_id = (_nr.rows[0] || {}).id || null;
      } catch(e) {}
    }

    const password_hash = await bcrypt.hash(password, 10);
    const nextBilling = new Date();
    nextBilling.setMonth(nextBilling.getMonth() + 1);

    const result = await query(`
      INSERT INTO pppoe_subscribers (
        isp_id, package_id, nas_id, username, password_hash, full_name, phone, email,
        id_number, county, town, physical_address, static_ip, next_billing_date, is_test
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
      RETURNING id, username, full_name, phone, status, created_at, is_test
    `, [req.user.ispId, package_id, resolved_nas_id, username, password_hash, full_name, phone, email, id_number, county, town, physical_address, static_ip, nextBilling, !!is_test]);

    const subscriber = result.rows[0];

    // Add to RADIUS
    await query(`INSERT INTO radcheck (username, attribute, op, value) VALUES ($1, 'Cleartext-Password', ':=', $2)`, [username, password]);
    // v62.31b: also store NT-Password (MD4 of UTF-16-LE password) for MS-CHAPv2 auth
    try {
      const crypto = require('crypto');
      // Node's createHash doesn't have md4 in newer versions; try fallback
      let ntHash;
      try {
        ntHash = crypto.createHash('md4').update(Buffer.from(password, 'utf16le')).digest('hex').toUpperCase();
      } catch (e) {
        // Use openssl child_process fallback
        const { execSync } = require('child_process');
        ntHash = execSync(`printf '%s' "${password.replace(/"/g, '\\"')}" | iconv -t UTF-16LE | openssl dgst -provider legacy -provider default -md4 | awk '{print toupper($NF)}'`).toString().trim();
      }
      if (ntHash && ntHash.length === 32) {
        await query(`INSERT INTO radcheck (username, attribute, op, value) VALUES ($1, 'NT-Password', ':=', $2)`, [username, ntHash]);
      }
    } catch (e) { require('../utils/logger').warn('[pppoe nt-hash] ' + e.message); }
    
    // v62.34: insert radreply attributes for Mikrotik rate limiting + group
    try {
      const pkgInfo = pkg.rows[0];
      const downMbps = pkgInfo.bandwidth_down_mbps;
      const upMbps = pkgInfo.bandwidth_up_mbps;
      if (downMbps || upMbps) {
        const rate = (upMbps || downMbps) + 'M/' + (downMbps || upMbps) + 'M';
        await query(`INSERT INTO radreply (username, attribute, op, value) VALUES ($1, 'Mikrotik-Rate-Limit', '=', $2)`, [username, rate]);
      }
      if (pkgInfo.mikrotik_profile) {
        await query(`INSERT INTO radreply (username, attribute, op, value) VALUES ($1, 'Mikrotik-Group', '=', $2)`, [username, pkgInfo.mikrotik_profile]);
      }
      if (pkgInfo.address_pool) {
        await query(`INSERT INTO radreply (username, attribute, op, value) VALUES ($1, 'Framed-Pool', '=', $2)`, [username, pkgInfo.address_pool]);
      }
    } catch (rrErr) { require('../utils/logger').warn('[pppoe radreply] ' + rrErr.message); }
    if (pkg.rows[0].mikrotik_profile) {
      await query(`INSERT INTO radusergroup (username, groupname, priority) VALUES ($1, $2, 1)`, [username, pkg.rows[0].mikrotik_profile]);
    }

    // Welcome SMS
    if (phone) {
      const isp = await query('SELECT company_name, sms_gateway, sms_api_key, sms_sender_id FROM isps WHERE id = $1', [req.user.ispId]);
      /* RL_PPPOE_WELCOME_GATE: gated on the sms_gateway column, which is blank on the platform
         gateway — the welcome SMS never sent. sendSMS resolves the gateway itself. */
      if (isp.rows[0]) {
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
  // 'suspended'/'expired' => walled garden (online but only the pay page). 'active' => full restore.
  if (!['active', 'suspended', 'inactive', 'expired'].includes(status)) {
    return res.status(400).json({ error: 'Invalid status' });
  }
  try {
    // Load the subscriber (need nas_id, isp_id, package profile for the walled garden).
    const subRes = await query(
      `SELECT ps.id, ps.username, ps.full_name, ps.nas_id, ps.isp_id, pp.mikrotik_profile
         FROM pppoe_subscribers ps JOIN pppoe_packages pp ON pp.id=ps.package_id
        WHERE ps.id=$1 AND ps.isp_id=$2`,
      [req.params.id, req.user.ispId]
    );
    if (!subRes.rows[0]) return res.status(404).json({ error: 'Subscriber not found' });
    const sub = subRes.rows[0];

    // Clear any legacy hard-reject so we never leave a stale lock.
    await query(`DELETE FROM radcheck WHERE username=$1 AND attribute='Auth-Type' AND value='Reject'`, [sub.username]).catch(()=>{});

    const wg = require('../utils/walledGarden');
    if (status === 'active') {
      await query(`UPDATE pppoe_subscribers SET status='active', updated_at=NOW() WHERE id=$1`, [sub.id]);
      try { await wg.restore(sub, sub.mikrotik_profile || null); } catch (e) { require('../utils/logger').warn('[status] restore: ' + e.message); }
    } else if (status === 'suspended' || status === 'expired') {
      // restrict() sets status=expired + Mikrotik-Group=rl-expired + bounces the session.
      try { await wg.restrict(sub); } catch (e) { require('../utils/logger').warn('[status] restrict: ' + e.message); }
      // If the caller explicitly asked for 'suspended', reflect that label (still walled by the sync).
      if (status === 'suspended') await query(`UPDATE pppoe_subscribers SET status='suspended', updated_at=NOW() WHERE id=$1`, [sub.id]).catch(()=>{});
    } else {
      // 'inactive' — just set the status (sync leaves them as-is; no walled garden).
      await query(`UPDATE pppoe_subscribers SET status='inactive', updated_at=NOW() WHERE id=$1`, [sub.id]);
    }

    const out = await query(`SELECT username, full_name, status FROM pppoe_subscribers WHERE id=$1`, [sub.id]);
    res.json({ subscriber: out.rows[0] });
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


// v62.36c: Active PPPoE sessions endpoint — auto-resolves ispId from auth token
router.get('/active-sessions', async (req, res, next) => {
  try {
    const ispId = req.user && req.user.ispId;
    if (!ispId) return res.status(401).json({ ok: false, error: 'unauthenticated' });
    
    const nasRes = await query(
      `SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password
       FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL`,
      [ispId]
    );
    
    const axios = require('axios');
    const sessions = [];
    
    for (const nas of nasRes.rows) {
      try {
        const resp = await axios.get(
          'http://' + nas.wireguard_ip + '/rest/ppp/active',
          {
            auth: { username: nas.mikrotik_api_user, password: nas.mikrotik_api_password },
            timeout: 5000,
            validateStatus: () => true
          }
        );
        if (resp.status === 200 && Array.isArray(resp.data)) {
          for (const s of resp.data) {
            // Get traffic counters from PPP interface
            let bytesIn = 0, bytesOut = 0;
            try {
              const ifResp = await axios.get(
                'http://' + nas.wireguard_ip + '/rest/interface?name=<pppoe-' + s.name + '>',
                {
                  auth: { username: nas.mikrotik_api_user, password: nas.mikrotik_api_password },
                  timeout: 3000,
                  validateStatus: () => true
                }
              );
              if (ifResp.status === 200 && Array.isArray(ifResp.data) && ifResp.data.length > 0) {
                bytesIn = Number(ifResp.data[0]['rx-byte']) || 0;
                bytesOut = Number(ifResp.data[0]['tx-byte']) || 0;
              }
            } catch(_) {}
            
            // Enrich with subscriber info
            let meta = {};
            try {
              const r = await query(
                `SELECT ps.full_name, ps.phone, pp.name AS package_name, pp.price AS package_price
                 FROM pppoe_subscribers ps
                 JOIN pppoe_packages pp ON pp.id = ps.package_id
                 WHERE ps.isp_id = $1::uuid AND ps.username = $2
                 LIMIT 1`,
                [ispId, s.name]
              );
              meta = r.rows[0] || {};
            } catch(_) {}
            
            sessions.push({
              username: s.name,
              ip: s.address || '',
              mac: s['caller-id'] || '',
              uptime: s.uptime || '',
              bytes_in: bytesIn,
              bytes_out: bytesOut,
              session_id: s['.id'],
              nas_id: nas.id,
              nas_name: nas.name,
              service: s.service || 'pppoe',
              type: 'pppoe',
              currently_active: true,
              full_name: meta.full_name || '',
              phone: meta.phone || '',
              package_name: meta.package_name || '',
              package_price: meta.package_price || 0
            });
          }
        }
      } catch(e) { /* skip unreachable NAS */ }
    }
    
    res.json({ ok: true, sessions, count: sessions.length });
  } catch (err) { next(err); }
});



/* RL_PPPOE_VIS_ROUTES: which subscribers a package is hidden from. Absence of a row means the
   package is visible, so an empty list is the normal state and needs no configuration. */
router.get('/packages/:id/visibility', async (req, res, next) => {
  try {
    const own = await query('SELECT id FROM pppoe_packages WHERE id=$1::uuid AND isp_id=$2::uuid', [req.params.id, req.user.ispId]);
    if (!own.rows[0]) return res.status(404).json({ error: 'Package not found' });
    const r = await query(
      `SELECT s.id, s.username, s.full_name,
              COALESCE(v.hidden, false) AS hidden
         FROM pppoe_subscribers s
         LEFT JOIN pppoe_package_visibility v ON v.subscriber_id = s.id AND v.package_id = $1::uuid
        WHERE s.isp_id = $2::uuid AND s.deleted_at IS NULL
        ORDER BY s.username`,
      [req.params.id, req.user.ispId]);
    res.json({ subscribers: r.rows });
  } catch (err) { next(err); }
});

router.put('/packages/:id/visibility', async (req, res, next) => {
  try {
    const own = await query('SELECT id FROM pppoe_packages WHERE id=$1::uuid AND isp_id=$2::uuid', [req.params.id, req.user.ispId]);
    if (!own.rows[0]) return res.status(404).json({ error: 'Package not found' });
    const hiddenFor = Array.isArray(req.body.hidden_for) ? req.body.hidden_for : [];
    /* replace wholesale: the list sent IS the intended state, so a subscriber removed from it
       becomes visible again without needing a separate call */
    await query('DELETE FROM pppoe_package_visibility WHERE package_id = $1::uuid', [req.params.id]);
    for (const sid of hiddenFor) {
      await query(
        `INSERT INTO pppoe_package_visibility (package_id, subscriber_id, hidden)
         SELECT $1::uuid, s.id, true FROM pppoe_subscribers s
          WHERE s.id = $2::uuid AND s.isp_id = $3::uuid
         ON CONFLICT (package_id, subscriber_id) DO UPDATE SET hidden = true`,
        [req.params.id, sid, req.user.ispId]).catch(function(){});
    }
    require('../utils/logger').info('[pppoe-visibility] package ' + req.params.id + ' hidden from ' + hiddenFor.length + ' subscriber(s)');
    res.json({ ok: true, hidden_count: hiddenFor.length });
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
