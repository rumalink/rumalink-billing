const express = require('express');
const bcrypt = require('bcryptjs');
const coa = require('../utils/coa');
const { query } = require('../config/database');
const { authenticateToken, requireISP, requireActiveLicense } = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
const axios = require('axios');

const router = express.Router();
router.use(authenticateToken, requireISP, requireActiveLicense);

// ── Pay Now: charge the ISP's platform license via admin Daraja STK ──
router.post('/billing/pay', async (req, res, next) => {
  const ispId = req.user.ispId;
  const { phone } = req.body;
  if (!phone) return res.status(400).json({ error: 'Phone number is required' });
  try {
    const axios = require('axios');
    const billing = require('../utils/billing');
    const isp = await billing.getIspBilling(ispId);
    if (!isp) return res.status(404).json({ error: 'ISP not found' });

    const ws = isp.billing_window_start || isp.subscription_started_at || isp.trial_ends_at;
    const owed = await billing.computeOwed(ispId, ws, new Date());
    if (owed.total <= 0) return res.status(400).json({ error: 'Nothing is due right now.' });
    const amount = Math.max(Math.ceil(owed.total), 1);

    const cfgRes = await query("SELECT * FROM mpesa_configs WHERE is_admin_config=true AND is_active=true LIMIT 1");
    if (!cfgRes.rows[0] || !cfgRes.rows[0].consumer_key) {
      return res.status(400).json({ error: 'Platform M-Pesa is not configured. Please contact support.' });
    }
    const cfg = cfgRes.rows[0];
    const normPhone = String(phone).replace(/\D/g, '').replace(/^0/, '254').replace(/^\+/, '');
    if (!/^254[17]\d{8}$/.test(normPhone)) return res.status(400).json({ error: 'Invalid phone format.' });

    const invRes = await query("SELECT id FROM isp_platform_invoices WHERE isp_id=$1::uuid AND status='pending' ORDER BY created_at DESC LIMIT 1", [ispId]);
    const invoiceId = invRes.rows[0] ? invRes.rows[0].id : null;

    const payRes = await query(
      `INSERT INTO payments (isp_id, amount, payment_method, payment_gateway, phone_number, description, status, commission_rate, commission_amount, net_amount)
       VALUES ($1::uuid,$2::decimal,'platform','mpesa_stk',$3,'License renewal','pending',0,0,$2::decimal) RETURNING id`,
      [ispId, owed.total, normPhone]
    );
    const paymentId = payRes.rows[0].id;
    if (invoiceId) await query("UPDATE isp_platform_invoices SET payment_id=$1 WHERE id=$2", [paymentId, invoiceId]).catch(() => {});

    const baseUrl = cfg.is_sandbox ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';
    let token;
    try {
      const tokRes = await axios.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, {
        headers: { Authorization: `Basic ${Buffer.from(`${cfg.consumer_key}:${cfg.consumer_secret}`).toString('base64')}` }, timeout: 10000
      });
      token = tokRes.data.access_token;
      if (!token) throw new Error('no token');
    } catch (e) {
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid", ['Daraja auth failed', paymentId]).catch(() => {});
      return res.status(400).json({ error: 'M-Pesa auth failed. Please try again.' });
    }
    const ts = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
    const pwd = Buffer.from(`${cfg.shortcode}${cfg.passkey}${ts}`).toString('base64');
    try {
      await axios.post(`${baseUrl}/mpesa/stkpush/v1/processrequest`, {
        BusinessShortCode: cfg.shortcode, Password: pwd, Timestamp: ts, TransactionType: 'CustomerPayBillOnline',
        Amount: amount, PartyA: normPhone, PartyB: cfg.shortcode, PhoneNumber: normPhone,
        CallBackURL: `${process.env.BASE_URL}/api/payments/license/callback/${paymentId}`,
        AccountReference: String(paymentId).substring(0, 12), TransactionDesc: 'License'
      }, { headers: { Authorization: `Bearer ${token}` }, timeout: 15000 });
    } catch (e) {
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid", [String(e.response && e.response.data && e.response.data.errorMessage || e.message).slice(0, 200), paymentId]).catch(() => {});
      return res.status(400).json({ error: 'Could not send the M-Pesa prompt. Please try again.' });
    }
    res.json({ success: true, payment_id: paymentId, amount: owed.total, message: `M-Pesa prompt sent to ${normPhone}.` });
  } catch (err) { next(err); }
});


// ── Platform billing: license state, owed breakdown, open invoice, history ──
router.get('/billing', async (req, res, next) => {
  const ispId = req.user.ispId;
  try {
    const billing = require('../utils/billing');
    const isp = await billing.getIspBilling(ispId);
    if (!isp) return res.status(404).json({ error: 'ISP not found' });

    const now = new Date();
    const expiresAt = isp.license_expires_at ? new Date(isp.license_expires_at) : null;
    const windowStart = isp.billing_window_start || isp.subscription_started_at || isp.trial_ends_at;
    const trialEnds = isp.trial_ends_at ? new Date(isp.trial_ends_at) : null;
    const inTrial = (isp.license_status === 'trial') && trialEnds && trialEnds > now;

    // Live owed for the current window (up to now).
    const owed = await billing.computeOwed(ispId, windowStart, now);

    // Any open (pending) invoice already generated by the cron.
    const inv = await query(
      `SELECT * FROM isp_platform_invoices WHERE isp_id=$1::uuid AND status='pending' ORDER BY created_at DESC LIMIT 1`,
      [ispId]
    );
    const openInvoice = inv.rows[0] || null;

    const msLeft = expiresAt ? (expiresAt.getTime() - now.getTime()) : null;
    const daysLeft = msLeft != null ? Math.ceil(msLeft / 86400000) : null;
    const expired = expiresAt ? (now.getTime() >= expiresAt.getTime()) : false;

    // Platform payment history (ISP paying us): payment_method 'platform' or description 'License%'.
    const history = await query(
      `SELECT id, amount, status, payment_method, payment_gateway, description, created_at, paid_at
         FROM payments
        WHERE isp_id=$1::uuid
          AND (payment_method='platform' OR payment_method='admin_charge'
               OR description ILIKE 'Platform%' OR description ILIKE 'License%')
        ORDER BY created_at DESC LIMIT 50`,
      [ispId]
    );

    res.json({
      company_name: isp.company_name,
      plan_type: isp.plan_type,
      license_status: isp.license_status,
      billing_exempt: !!isp.billing_exempt,
      in_trial: !!inTrial,
      trial_ends_at: isp.trial_ends_at,
      subscription_started_at: isp.subscription_started_at,
      license_expires_at: isp.license_expires_at,
      billing_window_start: windowStart,
      days_left: daysLeft,
      expired,
      owed,
      open_invoice: openInvoice,
      history: history.rows
    });
  } catch (err) { next(err); }
});


const storage = multer.diskStorage({
  destination: './uploads/logos',
  filename: (req, file, cb) => {
    cb(null, `${req.user.ispId}-${Date.now()}${path.extname(file.originalname)}`);
  }
});
const upload = multer({ storage, limits: { fileSize: 2 * 1024 * 1024 } });
/* RL_MEDIA_BANNER: separate multer for portal media (images/video), larger limit. */
const mediaStorage = multer.diskStorage({
  destination: './uploads/media',
  filename: (req, file, cb) => {
    cb(null, `${req.user.ispId}-${Date.now()}${path.extname(file.originalname)}`);
  }
});
const mediaUpload = multer({
  storage: mediaStorage,
  limits: { fileSize: 100 * 1024 * 1024 }, // RL_VIDEO_COMPRESS: 100MB source; compressed server-side
  fileFilter: (req, file, cb) => {
    if (/^(image\/(png|jpe?g|gif|webp)|video\/(mp4|webm))$/.test(file.mimetype)) cb(null, true);
    else cb(new Error('Only PNG/JPG/GIF/WEBP images or MP4/WEBM video are allowed'));
  }
});

// ISP Dashboard stats

// v62.23: PPPoE subscriber lookup by phone
async function lookupPppoeByPhone(ispId, phone) {
  try {
    const r = await query(
      `SELECT ps.id, ps.username, ps.full_name, ps.phone, ps.email, ps.status,
              ps.balance, ps.next_billing_date, ps.last_payment_date,
              ps.county, ps.town, ps.physical_address, ps.static_ip, ps.mac_address,
              ps.created_at,
              pp.name as package_name, pp.price as package_price,
              pp.bandwidth_down_mbps, pp.bandwidth_up_mbps, pp.data_limit_gb,
              pp.billing_cycle, pp.mikrotik_profile
       FROM pppoe_subscribers ps
       JOIN pppoe_packages pp ON pp.id = ps.package_id
       WHERE ps.isp_id = $1::uuid AND ps.phone = $2
       ORDER BY ps.created_at DESC`,
      [ispId, phone]
    );
    return r.rows;
  } catch (e) { return []; }
}

// v62.23: PPPoE subscriber lookup by id
async function lookupPppoeById(ispId, subscriberId) {
  try {
    const r = await query(
      `SELECT ps.*, pp.name as package_name, pp.price as package_price,
              pp.bandwidth_down_mbps, pp.bandwidth_up_mbps, pp.data_limit_gb,
              pp.billing_cycle, pp.mikrotik_profile
       FROM pppoe_subscribers ps
       JOIN pppoe_packages pp ON pp.id = ps.package_id
       WHERE ps.isp_id = $1::uuid AND ps.id = $2::uuid`,
      [ispId, subscriberId]
    );
    return r.rows;
  } catch (e) { return []; }
}

// v62.23: PPPoE session history for a subscriber
async function fetchPppoeSessions(subscriberId) {
  try {
    const r = await query(
      `
        SELECT 
          radacctid as id,
          framedipaddress::text as framed_ip,
          acctinputoctets as bytes_downloaded,
          acctoutputoctets as bytes_uploaded,
          acctsessiontime as session_time_seconds,
          acctstarttime as started_at,
          acctstoptime as ended_at,
          CASE WHEN acctstoptime IS NULL THEN 'active' ELSE 'closed' END as status,
          (acctstoptime IS NULL) as currently_active
        FROM radacct
        WHERE username = (SELECT username FROM pppoe_subscribers WHERE id = $1::uuid)
        ORDER BY acctstarttime DESC
        LIMIT 50
      `,
      [subscriberId]
    );
    return r.rows || [];
  } catch (e) { return []; }
}

// v62.23: PPPoE data totals (cumulative across all sessions)
async function fetchPppoeDataTotals(subscriberId) {
  try {
    const r = await query(`
        SELECT
          COALESCE(SUM(acctinputoctets) FILTER (WHERE acctstarttime >= ((date_trunc('month', NOW() AT TIME ZONE 'Africa/Nairobi') - INTERVAL '2 months')) AT TIME ZONE 'Africa/Nairobi'), 0)::bigint AS total_input,
          COALESCE(SUM(acctoutputoctets) FILTER (WHERE acctstarttime >= ((date_trunc('month', NOW() AT TIME ZONE 'Africa/Nairobi') - INTERVAL '2 months')) AT TIME ZONE 'Africa/Nairobi'), 0)::bigint AS total_output,
          COALESCE(SUM(acctsessiontime) FILTER (WHERE acctstarttime >= ((date_trunc('month', NOW() AT TIME ZONE 'Africa/Nairobi') - INTERVAL '2 months')) AT TIME ZONE 'Africa/Nairobi'), 0)::bigint AS total_seconds,
          COUNT(*) FILTER (WHERE acctstarttime >= ((date_trunc('month', NOW() AT TIME ZONE 'Africa/Nairobi') - INTERVAL '2 months')) AT TIME ZONE 'Africa/Nairobi') AS total_sessions,
          COALESCE(SUM(acctinputoctets) FILTER (WHERE acctstarttime >= (date_trunc('day', NOW() AT TIME ZONE 'Africa/Nairobi')) AT TIME ZONE 'Africa/Nairobi'), 0)::bigint AS day_input,
          COALESCE(SUM(acctoutputoctets) FILTER (WHERE acctstarttime >= (date_trunc('day', NOW() AT TIME ZONE 'Africa/Nairobi')) AT TIME ZONE 'Africa/Nairobi'), 0)::bigint AS day_output,
          COALESCE(SUM(acctinputoctets) FILTER (WHERE acctstarttime >= (date_trunc('month', NOW() AT TIME ZONE 'Africa/Nairobi')) AT TIME ZONE 'Africa/Nairobi'), 0)::bigint AS month_input,
          COALESCE(SUM(acctoutputoctets) FILTER (WHERE acctstarttime >= (date_trunc('month', NOW() AT TIME ZONE 'Africa/Nairobi')) AT TIME ZONE 'Africa/Nairobi'), 0)::bigint AS month_output,
          COUNT(*) FILTER (WHERE acctstarttime >= (date_trunc('month', NOW() AT TIME ZONE 'Africa/Nairobi')) AT TIME ZONE 'Africa/Nairobi') AS month_sessions
        FROM radacct WHERE username = (SELECT username FROM pppoe_subscribers WHERE id = $1::uuid)
      `, [subscriberId]);
    return r.rows[0] || {};
  } catch (e) { return {}; }
}


// v62.35: Fetch live PPPoE sessions from Mikrotik /ppp/active
async function fetchLivePppoeSessions(ispId, filterUsername) {
  const results = [];
  try {
    const nasRes = await query(
      `SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password
       FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL`,
      [ispId]
    );
    const axios = require('axios');
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
            if (filterUsername && s.name !== filterUsername) continue;
            // Get traffic counters
            let bytesIn = 0, bytesOut = 0;
            try {
              const iface = s.name;  // PPP interface name e.g. <pppoe-esther>
              // Fetch interface details for byte counts (Mikrotik creates a virtual interface per session)
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
            results.push({
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
              currently_active: true
            });
          }
        }
      } catch (e) { /* skip unreachable NAS */ }
    }
  } catch (e) { /* db error */ }
  return results;
}


router.get('/stats', async (req, res, next) => {
  const ispId = req.user.ispId;
  try {
    res.set('Cache-Control','no-store, no-cache, must-revalidate'); /* RUMALINK_USAGE_CACHEFIX */
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
        COUNT(*) FILTER (WHERE next_billing_date <= NOW() + INTERVAL '5 days' AND (is_test IS NULL OR is_test = false)) as expiring_soon
        FROM pppoe_subscribers WHERE isp_id = $1`, [ispId]),
      query(`SELECT
        COALESCE(SUM(amount) FILTER (WHERE status = 'paid' AND paid_at >= (date_trunc('month', NOW() AT TIME ZONE 'Africa/Nairobi')) AT TIME ZONE 'Africa/Nairobi'), 0) as this_month,
        COALESCE(SUM(amount) FILTER (WHERE status = 'paid' AND paid_at >= (date_trunc('day', NOW() AT TIME ZONE 'Africa/Nairobi')) AT TIME ZONE 'Africa/Nairobi'), 0) as today,
        COALESCE(SUM(amount) FILTER (WHERE status = 'paid'), 0) as total,
        COALESCE(SUM(commission_amount) FILTER (WHERE status = 'paid'), 0) as total_commission
        FROM payments WHERE isp_id = $1 AND (description IS NULL OR (description NOT LIKE 'Platform charge%%' AND description NOT LIKE 'SMS topup%%')) AND payment_method != 'admin_charge'`, [ispId]),
      query(`SELECT
        0 as active_hotspot,
        (SELECT COUNT(DISTINCT ra.username) FROM radacct ra JOIN pppoe_subscribers ps ON ps.username = ra.username WHERE ps.isp_id = $1::uuid AND ra.acctstoptime IS NULL) as active_pppoe`, [ispId])
    ]);

    // Count live hotspot sessions from routers via REST (truth source)
    try {
      const mt = require('../utils/mikrotik');
      const nasList = await query(
        `SELECT id FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL`,
        [ispId]
      );
      let totalHotspot = 0;
      for (const nas of nasList.rows) {
        try {
          const s = await mt.liveHotspotSessions(nas.id);
          totalHotspot += (s || []).length;
        } catch(e) { /* router unreachable - skip */ }
      }
      if (sessions.rows[0]) sessions.rows[0].active_hotspot = totalHotspot;
    } catch(e) {
      require('../utils/logger').warn(`/stats live hotspot count: ${e.message}`);
    }


    // ── RUMALINK_USAGE_CARD: today's data consumed, per MikroTik ──────────
    // Joins radacct (accounting) to nas_devices on the WireGuard tunnel IP,
    // scoped to this ISP, excluding loopback. "Today" = Africa/Nairobi day.
    let usage = { total_bytes: 0, device_count: 0, devices: [] };
    try {
      const usageRes = await query(`
        /* RUMALINK_USAGE_DAILY: exact per-day usage from the snapshot collector.
           Every device for this ISP, LEFT JOINed to today's usage_daily so
           devices with no traffic still appear with 0. Resets at Nairobi midnight. */
        SELECT
          d.id::text   AS device_id,
          d.name       AS device_name,
          d.is_online  AS is_online,
          COALESCE(SUM(u.bytes_in + u.bytes_out), 0)::bigint AS bytes_today,
          COALESCE(COUNT(DISTINCT u.username) FILTER (WHERE u.username IS NOT NULL), 0) AS sessions
        FROM nas_devices d
        LEFT JOIN usage_daily u
          ON u.device_id = d.id
         AND u.usage_day = (now() AT TIME ZONE 'Africa/Nairobi')::date
        WHERE d.isp_id = $1::uuid
        GROUP BY d.id, d.name, d.is_online
        ORDER BY bytes_today DESC`, [ispId]);

      const devs = usageRes.rows.map(row => ({
        id: row.device_id,
        name: row.device_name,
        is_online: row.is_online,
        sessions: parseInt(row.sessions) || 0,
        bytes: parseInt(row.bytes_today) || 0
      }));
      usage = {
        total_bytes: devs.reduce((a, x) => a + x.bytes, 0),
        device_count: devs.length,
        devices: devs
      };
    } catch (e) {
      try { require('../utils/logger').warn(`/stats usage query: ${e.message}`); } catch(_) {}
    }
    // ── end RUMALINK_USAGE_CARD ──────────────────────────────────────────

        const isp = await query(`SELECT wallet_balance, plan_type, trial_ends_at FROM isps WHERE id = $1`, [ispId]);

    res.json({
      devices: devices.rows[0],
      hotspot: hotspot.rows[0],
      pppoe: pppoe.rows[0],
      revenue: revenue.rows[0],
      sessions: sessions.rows[0],
      wallet_balance: isp.rows[0]?.wallet_balance,
      plan_type: isp.rows[0]?.plan_type,
      trial_ends_at: isp.rows[0]?.trial_ends_at,
      usage /* RUMALINK_USAGE_CARD */
    });
  } catch (err) { next(err); }
});

// Revenue chart
router.get('/revenue-chart', async (req, res, next) => {
  const ispId = req.user.ispId;
  const { days = 30, monthly } = req.query;
  try {
    if (monthly) {
      // 12 months of the CURRENT year (Jan..Dec) for this ISP; resets each January.
      const result = await query(`
        SELECT to_char(m.month, 'Mon') AS label,
               EXTRACT(MONTH FROM m.month)::int AS month_num,
               COALESCE(SUM(p.amount), 0) AS amount
        FROM generate_series(date_trunc('year', NOW()), date_trunc('year', NOW()) + INTERVAL '11 months', INTERVAL '1 month') AS m(month)
        LEFT JOIN payments p
          ON p.isp_id = $1 AND p.status='paid'
         AND date_trunc('month', p.paid_at) = m.month
        GROUP BY m.month
        ORDER BY m.month ASC
      `, [ispId]);
      return res.json({ data: result.rows, monthly: true, year: new Date().getFullYear() });
    }
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

// RL_MEDIA_BANNER + RL_VIDEO_COMPRESS: upload media; compress video server-side so it
// plays on the captive portal pre-login (self-hosted, small, faststart).
router.post('/media', (req, res, next) => {
  mediaUpload.single('media')(req, res, async (err) => {
    if (err) return res.status(400).json({ error: err.message });
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });

    const isVideo = /^video\//.test(req.file.mimetype);
    if (!isVideo) {
      return res.json({ url: `/uploads/media/${req.file.filename}`, kind: 'image' });
    }

    // Compress the video with ffmpeg -> 720p, H.264, no audio, faststart.
    const { execFile } = require('child_process');
    const path = require('path');
    const fs = require('fs');
    const srcPath = req.file.path; // ./uploads/media/<name>.<ext>
    const outName = path.basename(req.file.filename, path.extname(req.file.filename)) + '-opt.mp4';
    const outPath = path.join('./uploads/media', outName);

    const args = [
      '-y', '-i', srcPath,
      '-vf', "scale='min(1280,iw)':-2",           // cap width 1280, keep aspect, even height
      '-c:v', 'libx264', '-profile:v', 'high', '-preset', 'veryfast', '-crf', '28',
      '-pix_fmt', 'yuv420p',
      '-an',                                        // strip audio (banner is muted)
      '-movflags', '+faststart',
      '-max_muxing_queue_size', '1024',
      outPath
    ];

    execFile('ffmpeg', args, { timeout: 5 * 60 * 1000 }, (fferr) => {
      // Always remove the large source.
      fs.unlink(srcPath, () => {});
      if (fferr) {
        _logger.error('[MEDIA] ffmpeg failed: ' + fferr.message);
        // Fallback: if compression failed, we already deleted src; report error.
        return res.status(500).json({ error: 'Video processing failed. Try a shorter/smaller clip or a different format.' });
      }
      // Success — return the optimized file.
      let sizeMB = 0;
      try { sizeMB = +(fs.statSync(outPath).size / (1024*1024)).toFixed(1); } catch(e){}
      res.json({ url: `/uploads/media/${outName}`, kind: 'video', optimized: true, size_mb: sizeMB });
    });
  });
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
      query(`SELECT id, amount, payment_method, payment_gateway, status, description,
              phone_number, mpesa_phone, mpesa_amount, mpesa_name,
              transaction_id, commission_rate, commission_amount, net_amount,
              created_at, paid_at, failure_reason
         FROM payments WHERE isp_id = $1::uuid AND (description IS NULL OR (description NOT LIKE 'Platform charge%%' AND description NOT LIKE 'SMS topup%%')) AND payment_method != 'admin_charge' ORDER BY created_at DESC LIMIT 50`, [ispId]),
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


// ============================================================
// GET /api/isp/users - all users with tabs (hotspot|pppoe|all)
// ============================================================
// ============================================================
// GET /api/isp/sessions/active - currently online users
// ============================================================
router.get('/sessions/active', async (req, res) => {
  const _logger = require('../utils/logger');
  try {
    /* RL_TYPE_NORMALISE: a repeated ?type= arrives as an array; take the last value. */
    const _rawT = req.query.type;
    const type = (Array.isArray(_rawT) ? _rawT[_rawT.length - 1] : _rawT) || 'all';
    let sessions = [];
    _logger.info(`[ACTIVE-SESS] start ispId=${req.user.ispId} type=${type}`);

    // Get all NAS devices with WG tunnel for this ISP
    const nasList = await query(
      `SELECT id, name, wireguard_ip FROM nas_devices
       WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL
         AND (last_seen IS NULL OR last_seen > NOW() - INTERVAL '10 minutes') /* RL_ACTIVESESS_PERF: skip stale routers */`,
      [req.user.ispId]
    );
    _logger.info(`[ACTIVE-SESS] found ${nasList.rows.length} NAS device(s) with WG`);

    // For each router, query its live hotspot sessions
    if (type === 'all' || type === 'hotspot') {
      const mt = require('../utils/mikrotik');
      /* RL_ACTIVESESS_PERF: query all routers in parallel; one slow/dead router
         can't block the others (each already has an 8s client timeout). */
      await Promise.allSettled(nasList.rows.map(async (nas) => {
        _logger.info(`[ACTIVE-SESS] querying NAS ${nas.name} (${nas.id}) at ${nas.wireguard_ip}`);
        try {
          const routerSessions = await mt.liveHotspotSessions(nas.id);
          _logger.info(`[ACTIVE-SESS] NAS ${nas.name} returned ${routerSessions.length} session(s)`);
          for (const s of routerSessions) {
            let voucherInfo = {};
            let displayCode = String(s.user || '').split('@')[0];
            const _isMac = /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/i.test(String(s.user || ''));
            try {
              if (_isMac) {
                // RL_MAC_SESSION_DISPLAY: MAC-auth session -> resolve voucher by used_by_mac (prefer active)
                const vRes = await query(
                  `SELECT v.code, v.buyer_phone, v.expires_at, hp.name as package_name
                   FROM hotspot_vouchers v
                   LEFT JOIN hotspot_packages hp ON hp.id = v.package_id
                   WHERE v.isp_id = $1::uuid AND UPPER(v.used_by_mac) = UPPER($2) AND (v.is_tv IS NOT TRUE OR v.is_tv IS NULL) /* RL_TV_EXCLUDE_SESS */
                   ORDER BY (v.status='active') DESC, v.expires_at DESC NULLS LAST LIMIT 1`,
                  [req.user.ispId, String(s.user || '')]
                );
                if (vRes.rows[0]) { voucherInfo = vRes.rows[0]; displayCode = vRes.rows[0].code || displayCode; }
              } else {
                const vRes = await query(
                  `SELECT v.buyer_phone, v.expires_at, hp.name as package_name
                   FROM hotspot_vouchers v
                   LEFT JOIN hotspot_packages hp ON hp.id = v.package_id
                   WHERE v.isp_id = $1::uuid AND UPPER(v.code) = UPPER($2) LIMIT 1`,
                  [req.user.ispId, String(s.user || '').split('@')[0]] /* RL_REALM_DISPLAY */
                );
                if (vRes.rows[0]) voucherInfo = vRes.rows[0];
              }
            } catch(e) {
              _logger.warn(`[ACTIVE-SESS] voucher lookup failed for ${s.user}: ${e.message}`);
            }
            sessions.push({
              type: 'hotspot',
              id: s.id,
              username: displayCode, /* RL_MAC_SESSION_DISPLAY: show voucher code for MAC sessions */
              phone: voucherInfo.buyer_phone || null,
              mac_address: s.mac_address,
              ip_address: s.address,
              start_time: null,
              uptime: s.uptime,
              bytes_in: s.bytes_in,
              bytes_out: s.bytes_out,
              package_name: voucherInfo.package_name || null,
              expires_at: voucherInfo.expires_at || null,
              source: 'router',
              router_name: nas.name
            });
          }
        } catch (e) {
          _logger.error(`[ACTIVE-SESS] NAS ${nas.name} REST failed: ${e.message} (stack: ${e.stack?.split('\n')[0]})`);
        }
      })); /* RL_ACTIVESESS_PERF: end parallel map */
    }

    if (type === 'all' || type === 'pppoe') {
      try {
        const r = await query(`
          SELECT 'pppoe' as type, ps.id, ps.username, sub.phone,
                 ps.caller_id as mac_address, ps.ip_address, ps.start_time,
                 ps.bytes_in, ps.bytes_out, pkg.name as package_name
          FROM pppoe_sessions ps
          LEFT JOIN pppoe_subscribers sub ON sub.username = ps.username AND sub.isp_id = $1::uuid
          LEFT JOIN pppoe_packages pkg ON pkg.id = sub.package_id
          WHERE ps.isp_id = $1::uuid AND ps.status = 'active'
          ORDER BY ps.start_time DESC LIMIT 100`, [req.user.ispId]);
        sessions = sessions.concat(r.rows);
      } catch(e) {
        _logger.warn(`[ACTIVE-SESS] pppoe query failed: ${e.message}`);
      }
    }

    _logger.info(`[ACTIVE-SESS] DONE returning ${sessions.length} session(s)`);
    // v62.38b: Also fetch live PPPoE sessions from Mikrotik /ppp/active
    if (type === 'all' || type === 'pppoe') {
      const axios = require('axios');
      for (const nas of nasList.rows) {
        try {
          const nasCredRes = await query(
            `SELECT mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE id = $1::uuid LIMIT 1`,
            [nas.id]
          );
          if (nasCredRes.rows.length === 0) continue;
          const cred = nasCredRes.rows[0];
          const baseURL = 'http://' + nas.wireguard_ip + '/rest';
          const auth = { username: cred.mikrotik_api_user, password: cred.mikrotik_api_password };
          
          const pppActive = await axios.get(baseURL + '/ppp/active', { auth, timeout: 5000, validateStatus: () => true });
          if (pppActive.status !== 200 || !Array.isArray(pppActive.data)) continue;
          
          for (const s of pppActive.data) {
            let bytesIn = 0, bytesOut = 0;
            try {
              const ifResp = await axios.get(baseURL + '/interface?name=<pppoe-' + s.name + '>', { auth, timeout: 3000, validateStatus: () => true });
              if (ifResp.status === 200 && Array.isArray(ifResp.data) && ifResp.data.length > 0) {
                bytesIn = Number(ifResp.data[0]['rx-byte']) || 0;
                bytesOut = Number(ifResp.data[0]['tx-byte']) || 0;
              }
            } catch(_) {}
            
            let subInfo = { full_name: '', phone: '', package_name: '', next_billing_date: null };
            try {
              const sr = await query(
                `SELECT ps.full_name, ps.phone, ps.next_billing_date, pp.name as package_name
                 FROM pppoe_subscribers ps
                 JOIN pppoe_packages pp ON pp.id = ps.package_id
                 WHERE ps.isp_id = $1::uuid AND ps.username = $2
                 LIMIT 1`,
                [req.user.ispId, s.name]
              );
              if (sr.rows.length > 0) subInfo = sr.rows[0];
            } catch(_) {}
            
            sessions.push({
              type: 'pppoe',
              username: s.name,
              phone: subInfo.phone || '',
              full_name: subInfo.full_name || '',
              ip_address: s.address || '',
              mac_address: s['caller-id'] || '',
              package_name: subInfo.package_name || '',
              uptime: s.uptime || '',
              start_time: null,
              expires_at: subInfo.next_billing_date,
              bytes_in: bytesIn,
              bytes_out: bytesOut,
              voucher_code: null,
              nas_id: nas.id,
              nas_name: nas.name,
              session_id: s['.id']
            });
          }
        } catch(e) { /* skip unreachable NAS */ }
      }
    }
    

    // RL_TV_ACTIVE_SESSIONS: bound TVs use bypass binding (no hotspot session), so add them here.
    // Also de-dupe: if a TV MAC already appeared as a router session, tag it tv_hotspot instead.
    try {
      const tvRows = (await query(
        "SELECT bd.name, bd.mac_address, bd.bound_ip, bd.expires_at, hp.name AS package_name," + /* RL_TV_SESS_PHONE */
        " COALESCE(bd.buyer_phone, v.buyer_phone, p.phone_number) AS purchase_phone, v.code AS voucher_code" +
        " FROM hotspot_bound_devices bd LEFT JOIN hotspot_packages hp ON hp.id=bd.package_id" +
        " LEFT JOIN hotspot_vouchers v ON v.id=bd.active_voucher_id LEFT JOIN payments p ON p.id=v.payment_id" +
        " WHERE bd.isp_id=$1::uuid AND bd.is_bound=true AND (bd.expires_at IS NULL OR bd.expires_at > NOW())",
        [req.user.ispId])).rows;
      const macSet = new Set(tvRows.map(t => String(t.mac_address||'').toUpperCase()));
      // retag any existing router session that is actually a bound TV
      sessions = sessions.map(s => {
        if (s.mac_address && macSet.has(String(s.mac_address).toUpperCase())) {
          const tv = tvRows.find(t => String(t.mac_address).toUpperCase() === String(s.mac_address).toUpperCase());
          return Object.assign({}, s, { type: 'tv_hotspot', username: tv ? tv.name : s.username, is_tv: true });
        }
        return s;
      });
      const seen = new Set(sessions.filter(s => s.mac_address).map(s => String(s.mac_address).toUpperCase()));
      for (const tv of tvRows) {
        const mac = String(tv.mac_address||'').toUpperCase();
        if (seen.has(mac)) continue;  // already shown (retagged above)
        sessions.push({
          type: 'tv_hotspot',
          id: 'tv-' + mac.replace(/:/g,''),
          username: tv.name,
          phone: tv.purchase_phone || null,
          voucher_code: tv.voucher_code || null,
          mac_address: tv.mac_address,
          ip_address: tv.bound_ip,
          start_time: null,
          uptime: null,
          bytes_in: 0, /* RL_TV_SESS_ROUTER: live usage shown in lifecycle */
          bytes_out: 0,
          package_name: tv.package_name || null,
          expires_at: tv.expires_at || null,
          source: 'tv-binding',
          router_name: null,
          is_tv: true
        });
      }
    } catch (e) { _logger.warn('[ACTIVE-SESS] TV inject: ' + e.message); }

    // v62.38b: Ensure every session has a type field
    sessions = sessions.map(s => ({ ...s, type: s.type || 'hotspot' }));

    // RL_AS_TODAY_TOTALS: today's data by service from radacct (matches user pages).
    let today_totals = { hotspot: 0, pppoe: 0, total: 0 };
    try {
      /* RL_TOTALS_FROM_USAGE_DAILY: read the SAME source the user pages read.
         Raw radacct is wrong here: interim updates lag (an open session can report 22 MB
         while the router shows 9 GB), and `acctstarttime >= today` silently drops sessions
         that started yesterday and are still running. usage_daily is collector-fed, ISP-
         scoped and keyed to the Nairobi day — it is what /usage/today-split and the user
         pages (RUMALINK_UD_FINAL) use, so the cards now agree with them by construction. */
      const ttRes = await query(`
        SELECT
          COALESCE(SUM(u.bytes_in + u.bytes_out) FILTER (WHERE ps.username IS NOT NULL), 0)::bigint AS pppoe_bytes,
          COALESCE(SUM(u.bytes_in + u.bytes_out) FILTER (WHERE ps.username IS NULL), 0)::bigint     AS hotspot_bytes
        FROM usage_daily u
        LEFT JOIN pppoe_subscribers ps
          ON ps.username = u.username AND ps.isp_id = $1::uuid
        WHERE u.isp_id = $1::uuid
          AND u.usage_day = (now() AT TIME ZONE 'Africa/Nairobi')::date
      `, [req.user.ispId]);
      const hb = Number(ttRes.rows[0]?.hotspot_bytes || 0);
      const pb = Number(ttRes.rows[0]?.pppoe_bytes || 0);
      today_totals = { hotspot: hb, pppoe: pb, total: hb + pb };
      /* RL_TV_USAGE_ROUTER_TOTAL: bypass TVs have no radacct; sum their QUEUE byte counters. */
      try {
        const tvu = require('../utils/tv-usage');
        const tvs = (await query("SELECT mac_address FROM hotspot_bound_devices WHERE isp_id=$1::uuid AND is_bound=true", [req.user.ispId])).rows;
        let tvBytes = 0;
        for (const t of tvs) { const rs = await tvu.tvRouterStats(req.user.ispId, t.mac_address); tvBytes += (rs.bytes_in + rs.bytes_out); }
        if (tvBytes > 0) { today_totals.hotspot += tvBytes; today_totals.total += tvBytes; }
      } catch (e) { _logger.warn('[ACTIVE-SESS] TV usage: ' + e.message); }
    } catch (e) { _logger.warn('[ACTIVE-SESS] today_totals: ' + e.message); }

    res.json({ sessions, today_totals /* RL_AS_TODAY_TOTALS */ });
  } catch (err) {
    _logger.error(`[ACTIVE-SESS] route error: ${err.message}`);
    res.status(500).json({ error: err.message });
  }
});


// ─── Recent payments with linked voucher + package + payer info ───
router.get('/recent', async (req, res) => {
  try {
    const r = await query(`
      SELECT p.id, p.created_at, p.amount, p.status, p.transaction_id,
             p.phone_number, p.mpesa_phone, p.mpesa_amount, p.mpesa_name,
             p.failure_reason, p.commission_amount, p.net_amount,
             v.code as voucher_code, v.used_by_mac, v.used_at, v.expires_at,
             hp.name as package_name, hp.duration_hours, hp.data_limit_mb,
             hp.bandwidth_down_mbps, hp.bandwidth_up_mbps
      FROM payments p
      LEFT JOIN hotspot_vouchers v ON v.payment_id = p.id
      LEFT JOIN hotspot_packages hp ON hp.id = v.package_id
      WHERE p.isp_id = $1::uuid
        AND (p.description IS NULL OR p.description NOT LIKE 'Platform charge%%')
        AND p.payment_method != 'admin_charge'
      ORDER BY p.created_at DESC LIMIT 50`, [req.user.ispId]);
    res.json({ payments: r.rows });
  } catch (err) {
    require('../utils/logger').error('isp/recent:', err.message);
    res.status(500).json({ error: err.message });
  }
});
// ─── RADIUS health: confirm FreeRADIUS reachable + show NAS registration ───
router.get('/radius-status', async (req, res) => {
  try {
    const nas = await query(
      `SELECT name, wireguard_ip, radius_secret IS NOT NULL as has_secret, last_seen
       FROM nas_devices WHERE isp_id = $1::uuid`, [req.user.ispId]);

    // Read accounting recent entries
    const accounting = await query(
      `SELECT COUNT(*) as total, COUNT(CASE WHEN acctstoptime IS NULL THEN 1 END) as active
       FROM radacct WHERE acctstarttime > NOW() - interval '24 hours'`).catch(()=>({rows:[{total:0,active:0}]}));

    // Test FreeRADIUS by trying to read /var/log/freeradius/radius.log mtime
    let radius_running = false;
    try {
      const { execSync } = require('child_process');
      const out = execSync('systemctl is-active freeradius 2>/dev/null', { stdio: ['pipe','pipe','ignore'] }).toString().trim();
      radius_running = out === 'active';
    } catch(e) { radius_running = false; }

    res.json({
      radius_running,
      nas_devices: nas.rows,
      accounting_24h: accounting.rows[0]
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// ─── ALL USERS: unified hotspot + pppoe view, optionally enriched with live router state ───
router.get('/users', async (req, res) => {
  try {
    /* RL_TYPE_NORMALISE: the page requests '?type=all' and the filter appends '&type=pppoe',
       so Express hands us an ARRAY ['all','pppoe']. Every branch below compares with === to a
       string, so all of them failed and the list came back empty — which read as 'there are no
       PPPoE users'. Take the last value, which is the one the filter meant. */
    const _rawType = req.query.type;
    const type = (Array.isArray(_rawType) ? _rawType[_rawType.length - 1] : _rawType) || 'all';
    const search = (req.query.search || '').trim().toLowerCase();
    const limit = Math.min(parseInt(req.query.limit) || 50, 500);
    const offset = Math.max(parseInt(req.query.offset) || 0, 0); /* RL_USERS_PAGINATE */
    /* RL_USERS_FETCH_ALL: each source query used LIMIT = the PAGE size, then the handler sliced
       offset..offset+limit from the combined array. Only the first page of each source was ever
       fetched, so page 2 re-sliced the same rows and anyone past row 50 of a source could not be
       reached at all — and the counts were wrong for the same reason. Fetch the ISP's whole set
       and let the slice below do the paging. */
    const FETCH_CAP = 5000;
    let users = [];

    // Hotspot vouchers (only those tied to a payment - the real "users")
    if (type === 'all' || type === 'hotspot') {
      const rows = await query(`
        SELECT v.id, v.code as username, v.buyer_phone as phone, v.expires_at,
               v.created_at, v.used_by_mac as last_mac, hp.name as package_name,
               hp.price as package_price, p.amount as last_amount,
               p.created_at as last_payment_at, p.status as last_payment_status,
               CASE
                 WHEN v.expires_at IS NULL THEN 'pending'
                 WHEN v.expires_at < NOW() THEN 'expired'
                 ELSE 'active'
               END as derived_status
        FROM hotspot_vouchers v
        LEFT JOIN hotspot_packages hp ON hp.id = v.package_id
        LEFT JOIN payments p ON p.id = v.payment_id
        WHERE v.isp_id = $1::uuid
          AND (v.payment_id IS NOT NULL OR v.created_by_isp = true OR v.expires_at IS NOT NULL) /* RL_SHOW_ISP_CREATED: show paid OR ISP-created(import/test) OR dated vouchers */
          AND (v.is_tv IS NOT TRUE OR v.is_tv IS NULL) /* RL_TV_EXCLUDE_USERS */
        ORDER BY v.created_at DESC LIMIT $2
      `, [req.user.ispId, FETCH_CAP]);

      for (const r of rows.rows) {
        users.push({
          id: r.id,
          type: 'hotspot',
          username: r.username,
          phone: r.phone,
          package_name: r.package_name,
          package_price: r.package_price,
          last_amount: r.last_amount,
          last_payment_at: r.last_payment_at,
          last_payment_status: r.last_payment_status,
          last_mac: r.last_mac,
          expires_at: r.expires_at,
          status: r.derived_status,
          created_at: r.created_at,
          online: false   // populated below from router REST
        });
      }
    }


    // RL_TV_USERS: show bound/saved TVs as users with type tv_hotspot + saved name.
    if (type === 'all' || type === 'hotspot' || type === 'tv') {
      try {
        const tvRows = await query(
          "SELECT bd.id, bd.name, bd.mac_address, bd.buyer_phone, bd.expires_at, bd.created_at, bd.is_bound," +
          " hp.name AS package_name, hp.price AS package_price," +
          " COALESCE(bd.buyer_phone, v.buyer_phone, p.phone_number) AS purchase_phone, v.code AS voucher_code," + /* RL_TV_PHONE */
          " p.amount AS last_amount, p.created_at AS last_payment_at, p.status AS last_payment_status," +
          " CASE WHEN bd.expires_at IS NULL THEN 'pending' WHEN bd.expires_at < NOW() THEN 'expired' ELSE 'active' END AS derived_status" +
          " FROM hotspot_bound_devices bd LEFT JOIN hotspot_packages hp ON hp.id=bd.package_id" +
          " LEFT JOIN hotspot_vouchers v ON v.id=bd.active_voucher_id" +
          " LEFT JOIN payments p ON p.id=v.payment_id" +
          " WHERE bd.isp_id=$1::uuid ORDER BY bd.created_at DESC LIMIT $2",
          [req.user.ispId, FETCH_CAP]);
        for (const r of tvRows.rows) {
          users.push({
            id: r.id,
            type: 'tv_hotspot',
            username: r.name,
            phone: r.purchase_phone,
            voucher_code: r.voucher_code,
            package_name: r.package_name,
            package_price: r.package_price,
            last_amount: r.last_amount,
            last_payment_at: r.last_payment_at,
            last_payment_status: r.last_payment_status,
            last_mac: r.mac_address,
            expires_at: r.expires_at,
            status: r.derived_status,
            created_at: r.created_at,
            online: !!r.is_bound && (r.expires_at && new Date(r.expires_at) > new Date()),
            is_tv: true
          });
        }
      } catch (e) { require('../utils/logger').warn('[isp/users] TV inject: ' + e.message); }
    }

    if (type === 'all' || type === 'pppoe') {
      try {
        const r = await query(`
          SELECT s.id, s.username, s.phone, s.full_name, s.next_billing_date AS expires_at, s.status,
                 s.created_at, pkg.name as package_name, pkg.price as package_price, rc.value as password /* RL_PPPOE_COL_FIX */
          FROM pppoe_subscribers s
          LEFT JOIN pppoe_packages pkg ON pkg.id = s.package_id
          LEFT JOIN radcheck rc ON rc.username = s.username AND rc.attribute = 'Cleartext-Password'
          WHERE s.isp_id = $1::uuid
          ORDER BY s.created_at DESC LIMIT $2
        `, [req.user.ispId, FETCH_CAP]);
        for (const row of r.rows) {
          users.push({
            id: row.id, type: 'pppoe',
            username: row.username, phone: row.phone, full_name: row.full_name,
            package_name: row.package_name, package_price: row.package_price,
            expires_at: row.expires_at, status: row.status, created_at: row.created_at, password: row.password,
            online: false
          });
        }
      } catch(e) { require('../utils/logger').warn('pppoe users query:', e.message); }
    }

    // Enrich with live router state (mark online users)
    try {
      const mt = require('../utils/mikrotik');
      const nasList = await query(
        `SELECT id FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL`,
        [req.user.ispId]
      );
      const liveSet = new Set();
      for (const nas of nasList.rows) {
        try {
          const live = await mt.liveHotspotSessions(nas.id);
          for (const s of live) liveSet.add(String(s.user || '').split('@')[0].toUpperCase()); /* RL_REALM_DISPLAY: match bare code */
        } catch(e) { /* skip unreachable router */ }
      }
      users.forEach(u => {
        // RL_MAC_ONLINE_USAGE: online if the live set has the code OR the device MAC
        if (liveSet.has(String(u.username || '').toUpperCase())
            || (u.last_mac && liveSet.has(String(u.last_mac).toUpperCase()))) u.online = true;
      });
    } catch(e) { require('../utils/logger').warn('user live-enrich:', e.message); }

    // Search filter
    let filtered = users;
    if (search) {
      filtered = users.filter(u => {
        return (String(u.username||'').toLowerCase().includes(search)
             || String(u.phone||'').toLowerCase().includes(search)
             || String(u.full_name||'').toLowerCase().includes(search)
             || String(u.last_mac||'').toLowerCase().includes(search));
      });
    }

    /* RL_COUNTS_UNFILTERED: these badges describe the account, not the current view. They used
       to be derived from the array just returned, which was fine while every type was always
       fetched — but now that the handler fetches only the requested type, the other tabs read 0
       and it looks as though those users have disappeared. Count them separately, always. */
    let _rlCounts = { all: 0, hotspot: 0, pppoe: 0, online: 0 };
    try {
      const _c = await query(
        `SELECT
           (SELECT count(*) FROM hotspot_vouchers v
             WHERE v.isp_id = $1::uuid
               AND (v.payment_id IS NOT NULL OR v.created_by_isp = true OR v.expires_at IS NOT NULL)
               AND (v.is_tv IS NOT TRUE OR v.is_tv IS NULL))::int AS hotspot,
           (SELECT count(*) FROM hotspot_bound_devices bd WHERE bd.isp_id = $1::uuid)::int AS tvs,
           (SELECT count(*) FROM pppoe_subscribers s WHERE s.isp_id = $1::uuid)::int AS pppoe`,
        [req.user.ispId]);
      const _r = _c.rows[0] || { hotspot: 0, tvs: 0, pppoe: 0 };
      /* the Hotspot tab shows TVs too — the server groups them there — so the badge must match */
      _rlCounts.hotspot = (_r.hotspot || 0) + (_r.tvs || 0);
      _rlCounts.pppoe = _r.pppoe || 0;
      _rlCounts.all = _rlCounts.hotspot + _rlCounts.pppoe;
      _rlCounts.online = users.filter(u => u.online).length;
    } catch (e) {
      require('../utils/logger').warn('[isp/users] counts: ' + e.message);
      _rlCounts = { all: users.length,
                    hotspot: users.filter(u => u.type === 'hotspot' || u.type === 'tv_hotspot').length,
                    pppoe: users.filter(u => u.type === 'pppoe').length,
                    online: users.filter(u => u.online).length };
    }

    const total = filtered.length;
    const paged = filtered.slice(offset, offset + limit); /* RL_USERS_PAGINATE */
    res.json({
      users: paged,
      total: total,
      offset: offset,
      limit: limit,
      counts: _rlCounts
    });
  } catch (err) {
    require('../utils/logger').error('isp/users:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Edit one user (update expires_at, status, etc.)
router.put('/users/:id', async (req, res) => {
  try {
    let { type, expires_at, status, mac, package_id } = req.body; /* RL_EDIT_SANITIZE RL_HS_PKG_EDIT */
    if (status === '' || status === null) status = undefined;
    if (expires_at === '' || expires_at === null) expires_at = undefined;
    if (mac === '') mac = undefined;
    if (type === 'hotspot') {
      const updates = [];
      const params = [req.params.id, req.user.ispId];
      let idx = 3;
      if (expires_at !== undefined) { updates.push(`expires_at = $${idx++}`); params.push(expires_at || null); }
      if (status !== undefined) { updates.push(`status = $${idx++}`); params.push(status); }
      if (mac !== undefined) { updates.push(`used_by_mac = ${idx++}`); params.push(mac); }
      if (package_id !== undefined && package_id) { updates.push(`package_id = ${idx++}::uuid`.replace('${D}', String.fromCharCode(36))); params.push(package_id); } /* RL_HS_PKG_EDIT */
      updates.push('updated_at = NOW()');
      await query(
        `UPDATE hotspot_vouchers SET ${updates.join(', ')} WHERE id = $1::uuid AND isp_id = $2::uuid`,
        params
      );
      try { const cap = require('./captive'); if (package_id && cap.syncRadiusForVoucher) await cap.syncRadiusForVoucher(req.params.id); } catch(e){} /* RL_HS_PKG_EDIT: re-sync rate */

      // v52: if status was set to 'expired', clean up router-side: kick session + remove queue
      if (status === 'expired' || expires_at && new Date(expires_at) < new Date()) {
        try {
          const axios = require('axios');
          const vRow = await query(
            `SELECT v.code, n.wireguard_ip, n.mikrotik_api_user, n.mikrotik_api_password
             FROM hotspot_vouchers v
             JOIN nas_devices n ON n.isp_id = v.isp_id AND n.wireguard_ip IS NOT NULL
             WHERE v.id = $1::uuid LIMIT 1`,
            [req.params.id]
          );
          if (vRow.rows[0]) {
            const { code, wireguard_ip, mikrotik_api_user, mikrotik_api_password } = vRow.rows[0];
            const baseURL = `http://${wireguard_ip}/rest`;
            const auth = { username: mikrotik_api_user, password: mikrotik_api_password };
            
            // Kick active session
            try {
              const active = await axios.get(baseURL + '/ip/hotspot/active', { auth, timeout: 5000 });
              for (const s of (active.data || [])) {
                if (s.user === code) {
                  (async ()=>{
                try {
                  const cr = await coa.sendDisconnect(vRow.rows[0].id ? null : null, s.user || code);
                  // CoA needs deviceId - look up
                  const ndRow = await query(`SELECT id FROM nas_devices WHERE wireguard_ip = $1 LIMIT 1`, [wireguard_ip]);
                  if (ndRow.rows[0]) {
                    const r = await coa.sendDisconnect(ndRow.rows[0].id, s.user || code);
                    if (r.ok) { require('../utils/logger').info(`[EXPIRE-COA] ${s.user||code} kicked via CoA`); return; }
                  }
                } catch(e) {}
                try { await axios.post(baseURL + '/ip/hotspot/active/remove', { '.id': s['.id'] }, { auth, timeout: 5000 }); } catch(e) {}
              // v62.35: also try PPPoE disconnect
              try {
                const pppResp = await axios.get(baseURL + '/ppp/active', { auth, timeout: 5000, validateStatus: () => true });
                if (pppResp.status === 200 && Array.isArray(pppResp.data)) {
                  for (const pp of pppResp.data) {
                    if (pp.name === code) {
                      try { await axios.delete(baseURL + '/ppp/active/' + encodeURIComponent(pp['.id']), { auth, timeout: 5000 }); kicked = true; } catch(e) {}
                    }
                  }
                }
              } catch(e) {}
              })();
                  require('../utils/logger').info(`[EXPIRE-CLEANUP] kicked session ${code} on ${wireguard_ip}`);
                }
              }
            } catch(e) {}
            
            // Remove queue
            try {
              const queues = await axios.get(baseURL + '/queue/simple', { auth, timeout: 5000 });
              for (const q of (queues.data || [])) {
                if (q.name === 'rl-' + code) {
                  await axios.delete(`${baseURL}/queue/simple/${q['.id']}`, { auth, timeout: 5000 });
                  require('../utils/logger').info(`[EXPIRE-CLEANUP] removed queue rl-${code} on ${wireguard_ip}`);
                }
              }
            } catch(e) {}
            
            // Clear RADIUS entries
            try {
              await query(`DELETE FROM radcheck WHERE username = $1`, [code]);
              await query(`DELETE FROM radreply WHERE username = $1`, [code]);
              require('../utils/logger').info(`[EXPIRE-CLEANUP] cleared radcheck/radreply for ${code}`);
            } catch(e) {}
          }
        } catch(e) { require('../utils/logger').warn(`[EXPIRE-CLEANUP] failed: ${e.message}`); }
      }
    } else if (type === 'pppoe') {
      const updates = [];
      const params = [req.params.id, req.user.ispId];
      let idx = 3;
      if (expires_at !== undefined) { updates.push(`expires_at = $${idx++}`); params.push(expires_at || null); }
      if (status !== undefined) { updates.push(`status = $${idx++}`); params.push(status); }
      await query(
        `UPDATE pppoe_subscribers SET ${updates.join(', ')} WHERE id = $1::uuid AND isp_id = $2::uuid`,
        params
      );
    } else {
      return res.status(400).json({ error: 'type must be hotspot or pppoe' });
    }
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete one user
router.delete('/users/:id', async (req, res) => {
  try {
    const { type } = req.query;
    if (type === 'hotspot') {
      // Get code first for router removal
      const v = await query(
        `SELECT v.code, n.id as nas_id FROM hotspot_vouchers v, nas_devices n
         WHERE v.id = $1::uuid AND v.isp_id = $2::uuid AND n.isp_id = $2::uuid AND n.wireguard_ip IS NOT NULL
         LIMIT 1`, [req.params.id, req.user.ispId]
      );
      if (v.rows[0]) {
        try {
          const mt = require('../utils/mikrotik');
          await mt.removeHotspotUser(v.rows[0].nas_id, v.rows[0].code);
        } catch(e) {}
      }
      await query(`DELETE FROM hotspot_vouchers WHERE id = $1::uuid AND isp_id = $2::uuid`, [req.params.id, req.user.ispId]);
    } else if (type === 'pppoe') {
      await query(`DELETE FROM pppoe_subscribers WHERE id = $1::uuid AND isp_id = $2::uuid`, [req.params.id, req.user.ispId]);
    } else {
      return res.status(400).json({ error: 'type must be hotspot or pppoe' });
    }
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// ─── v58: RADIUS Accounting / Usage Reports endpoint ───
router.get('/:ispId/usage-reports', authenticateToken, async (req, res) => {
  try {
    const ispId = req.params.ispId;

    // Aggregate per-voucher usage
    const perVoucher = await query(`
      SELECT 
        ra.username,
        COUNT(*) as session_count,
        COALESCE(SUM(ra.acctsessiontime), 0)::bigint as total_seconds,
        COALESCE(SUM(ra.acctinputoctets), 0)::bigint as total_input_bytes,
        COALESCE(SUM(ra.acctoutputoctets), 0)::bigint as total_output_bytes,
        MAX(ra.acctstarttime) as last_seen,
        COUNT(*) FILTER (WHERE ra.acctstoptime IS NULL) as currently_active,
        hv.package_id,
        hp.name as package_name
      FROM radacct ra
      LEFT JOIN hotspot_vouchers hv ON hv.code = SPLIT_PART(ra.username, '@', 1) AND hv.isp_id = $1::uuid
      LEFT JOIN hotspot_packages hp ON hp.id = hv.package_id
      WHERE hv.isp_id = $1::uuid
        AND ra.acctstarttime > NOW() - INTERVAL '30 days'
      GROUP BY ra.username, hv.package_id, hp.name
      ORDER BY total_input_bytes + total_output_bytes DESC
      LIMIT 100
    `, [ispId]);

    // Aggregate per-day totals
    const perDay = await query(`
      SELECT 
        DATE_TRUNC('day', ra.acctstarttime) as day,
        COUNT(DISTINCT ra.username) as unique_users,
        COUNT(*) as sessions,
        COALESCE(SUM(ra.acctinputoctets), 0)::bigint as input_bytes,
        COALESCE(SUM(ra.acctoutputoctets), 0)::bigint as output_bytes,
        COALESCE(SUM(ra.acctsessiontime), 0)::bigint as session_seconds
      FROM radacct ra
      JOIN hotspot_vouchers hv ON hv.code = SPLIT_PART(ra.username, '@', 1) AND hv.isp_id = $1::uuid
      WHERE ra.acctstarttime > NOW() - INTERVAL '30 days'
      GROUP BY day
      ORDER BY day DESC
    `, [ispId]);

    // Current active sessions
    const activeSessions = await query(`
      SELECT 
        ra.username,
        ra.framedipaddress::text as ip,
        ra.callingstationid as mac,
        ra.acctstarttime,
        EXTRACT(EPOCH FROM (NOW() - ra.acctstarttime))::int as uptime_seconds,
        ra.acctinputoctets,
        ra.acctoutputoctets
      FROM radacct ra
      JOIN hotspot_vouchers hv ON hv.code = SPLIT_PART(ra.username, '@', 1) AND hv.isp_id = $1::uuid
      WHERE ra.acctstoptime IS NULL
      ORDER BY ra.acctstarttime DESC
    `, [ispId]);

    // Summary stats
    const summary = await query(`
      SELECT 
        COUNT(*) FILTER (WHERE ra.acctstarttime > NOW() - INTERVAL '24 hours') as sessions_24h,
        COUNT(*) FILTER (WHERE ra.acctstarttime > NOW() - INTERVAL '7 days') as sessions_7d,
        COUNT(DISTINCT ra.username) FILTER (WHERE ra.acctstarttime > NOW() - INTERVAL '24 hours') as unique_users_24h,
        COALESCE(SUM(ra.acctinputoctets + ra.acctoutputoctets) FILTER (WHERE ra.acctstarttime > NOW() - INTERVAL '24 hours'), 0)::bigint as bytes_24h,
        COALESCE(SUM(ra.acctinputoctets + ra.acctoutputoctets) FILTER (WHERE ra.acctstarttime > NOW() - INTERVAL '7 days'), 0)::bigint as bytes_7d
      FROM radacct ra
      JOIN hotspot_vouchers hv ON hv.code = SPLIT_PART(ra.username, '@', 1) AND hv.isp_id = $1::uuid
    `, [ispId]);

    res.json({
      ok: true,
      summary: summary.rows[0] || {},
      active_sessions: activeSessions.rows,
      per_voucher: perVoucher.rows,
      per_day: perDay.rows
    });
  } catch (err) {
    require('../utils/logger').error(`[usage-reports] ${err.message}`);
    res.status(500).json({ ok: false, error: err.message });
  }
});



// RL_TV_LIFECYCLE: dedicated TV lifecycle, scoped to the TV's MAC (NOT the buyer's phone, which may
// have many prior purchases). Returns the same shape user.html expects, with tv name + badge.
router.get('/:ispId/tv-user/:identifier', async (req, res) => {
  try {
    const { ispId, identifier } = req.params;
    const ident = String(identifier).trim();
    // resolve the TV by id (uuid) or MAC
    const isUuid = /^[0-9a-f-]{36}$/i.test(ident);
    const tvRes = await query(
      "SELECT bd.*, hp.name AS package_name, hp.price AS package_price, hp.duration_hours," +
      " hp.bandwidth_up_mbps, hp.bandwidth_down_mbps, hp.data_limit_mb," +
      " v.code AS voucher_code, v.buyer_phone AS voucher_phone, v.expires_at AS voucher_expires," +
      " p.phone_number AS payment_phone" +
      " FROM hotspot_bound_devices bd" +
      " LEFT JOIN hotspot_packages hp ON hp.id=bd.package_id" +
      " LEFT JOIN hotspot_vouchers v ON v.id=bd.active_voucher_id" +
      " LEFT JOIN payments p ON p.id=v.payment_id" +
      " WHERE bd.isp_id=$1::uuid AND (" + (isUuid ? "bd.id=$2::uuid" : "UPPER(REPLACE(bd.mac_address,':',''))=UPPER(REPLACE($2,':',''))") + ") LIMIT 1", /* RL_TV_COLONFREE */
      [ispId, ident]);
    const tv = tvRes.rows[0];
    if (!tv) return res.json({ ok:true, found:false, identifier: ident });

    const tvMac = String(tv.mac_address||'').toUpperCase();
    const phone = tv.voucher_phone || tv.payment_phone || tv.buyer_phone || null;

    // Payments made FOR THIS TV (metadata.tv_mac matches), not all of the buyer's payments.
    const paymentsRes = await query(
      "SELECT p.*, p.metadata->>'tv_mac' AS tv_mac_meta" +
      " FROM payments p" +
      " WHERE p.isp_id=$1::uuid AND UPPER(COALESCE(p.metadata->>'tv_mac','')) = $2" +
      " ORDER BY p.created_at DESC LIMIT 50",
      [ispId, tvMac]);

    // radacct sessions BY THIS TV's MAC
    let sessions = { rows: [] };
    try {
      sessions = await query(
        "SELECT username, framedipaddress::text AS ip, callingstationid AS mac, acctstarttime," +
        " acctstoptime, acctsessiontime, acctinputoctets, acctoutputoctets, acctterminatecause," +
        " (acctstoptime IS NULL) AS currently_active" +
        " FROM radacct WHERE UPPER(callingstationid)=$1 ORDER BY acctstarttime DESC LIMIT 50",
        [tvMac]);
    } catch (e) { require('../utils/logger').warn('[tv-lifecycle] sessions: ' + e.message); }

    // usage/bytes for this TV (radacct by MAC)
    let usedBytes = 0;
    try {
      const ub = await query(
        "SELECT COALESCE(SUM(acctinputoctets+acctoutputoctets),0)::bigint AS b FROM radacct WHERE UPPER(callingstationid)=$1",
        [tvMac]);
      usedBytes = Number(ub.rows[0]?.b || 0);
    } catch (e) {}

    // today bytes (Nairobi)
    let todayBytes = 0;
    try {
      const tb = await query(
        "SELECT COALESCE(SUM(acctinputoctets+acctoutputoctets),0)::bigint AS b FROM radacct" +
        " WHERE UPPER(callingstationid)=$1 AND (acctstarttime AT TIME ZONE 'Africa/Nairobi')::date = (now() AT TIME ZONE 'Africa/Nairobi')::date",
        [tvMac]);
      todayBytes = Number(tb.rows[0]?.b || 0);
    } catch (e) {}

    // live session from router by MAC
    let liveSessions = [];
    try {
      const nasRes = await query("SELECT id, wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE isp_id=$1::uuid AND wireguard_ip IS NOT NULL", [ispId]);
      const axios = require('axios');
      for (const nas of (nasRes.rows||[])) {
        if (!nas.wireguard_ip || !nas.mikrotik_api_user) continue;
        try {
          const api = axios.create({ baseURL:'http://'+nas.wireguard_ip+'/rest', timeout:3500, auth:{username:nas.mikrotik_api_user,password:nas.mikrotik_api_password}, validateStatus:()=>true });
          const resp = await api.get('/ip/hotspot/active');
          if (resp && resp.status===200 && Array.isArray(resp.data)) {
            for (const sn of resp.data) {
              if (String(sn['mac-address']||'').toUpperCase() === tvMac) {
                liveSessions.push({ username: tv.name, ip: sn.address||'', mac: sn['mac-address']||'', uptime: sn.uptime||'', bytes_in:Number(sn['bytes-in'])||0, bytes_out:Number(sn['bytes-out'])||0, currently_active:true, source:'mikrotik' });
              }
            }
          }
        } catch(_) {}
      }
    } catch (e) { require('../utils/logger').warn('[tv-lifecycle] live: ' + e.message); }

    const revenue = paymentsRes.rows.filter(p => p.status==='paid'||p.status==='success'||p.status==='completed').reduce((s,p)=>s+Number(p.amount||0),0);
    const isActive = tv.is_bound && tv.expires_at && new Date(tv.expires_at) > new Date();
    let isOnline = liveSessions.length > 0;
    /* RL_TV_ROUTER_USAGE: bypass TVs have no radacct — read usage + live status from the router
       (queue byte counters + hotspot host idle-time). */
    try {
      const tvu = require('../utils/tv-usage');
      const rs = await tvu.tvRouterStats(ispId, tv.mac_address);
      /* RL_TV_ORDER_FIX: set online/ip/bytes here; do NOT touch tvVoucher (declared later — const,
         not hoisted, would throw and abort this block). tvVoucher.used_bytes is set after declare. */
      var tvVoucherBytesIn = 0, tvVoucherBytesOut = 0;
      if (rs.bytes_in || rs.bytes_out) {
        /* RL_TV_DURABLE: total = banked baseline (survives expiry + router re-provision) + live counters */
        tvVoucherBytesIn = Number(rs.bytes_in||0) + Number(tv.usage_base_in||0);
        tvVoucherBytesOut = Number(rs.bytes_out||0) + Number(tv.usage_base_out||0);
        usedBytes = tvVoucherBytesIn + tvVoucherBytesOut;
        todayBytes = usedBytes;
      }
      if (rs.online) isOnline = true;
      if (rs.ip) tv.bound_ip = rs.ip;
      if (isOnline && !liveSessions.length) {
        liveSessions.push({ username: tv.name, ip: rs.ip||tv.bound_ip||'', mac: tv.mac_address, uptime:'—', bytes_in: rs.bytes_in, bytes_out: rs.bytes_out, currently_active:true, source:'tv-queue' }); /* RL_TV_LIVE_PUSH */
      }
    } catch(e) { require('../utils/logger').warn('[tv-lifecycle] router stats: ' + e.message); }

    // a single "voucher"-like row so user.html's K-code table shows the TV's package/expiry
    const tvVoucher = {
      id: tv.active_voucher_id || null, /* RL_TV_VID: real voucher id so Edit/Delete work */
      code: tv.voucher_code || tv.name,
      password: null,
      package_name: tv.package_name,
      package_price: tv.package_price,
      bandwidth_down_mbps: tv.bandwidth_down_mbps,
      bandwidth_up_mbps: tv.bandwidth_up_mbps,
      status: isActive ? 'active' : (tv.expires_at && new Date(tv.expires_at) <= new Date() ? 'expired' : 'pending'),
      expires_at: tv.expires_at,
      used_by_mac: tv.mac_address,
      used_bytes: usedBytes
    };
    if (usedBytes) tvVoucher.used_bytes = usedBytes; /* RL_TV_ORDER_FIX */

    res.json({
      ok: true,
      found: true,
      source: 'tv',
      is_tv: true,
      /* RL_TV_SHAPE: fields user.html reads (is_online, dt{}, total_payments). */
      is_online: isOnline,
      /* RL_TV_SUMMARY: user.html reads usage from summary.data_totals and revenue from summary. */
      summary: {
        total_revenue_kes: revenue,
        total_payments: paymentsRes.rows.length,
        data_totals: {
          day_input: (tvVoucherBytesIn||0), day_output: (tvVoucherBytesOut||0),
          month_input: (tvVoucherBytesIn||0), month_output: (tvVoucherBytesOut||0),
          total_input_bytes: (tvVoucherBytesIn||0), total_output_bytes: (tvVoucherBytesOut||0),
          month_sessions: (tvVoucherBytesIn||tvVoucherBytesOut) ? 1 : 0,
          total_seconds: 0,
          voucher_cumulative: { seconds: 0 }
        }
      },
      total_payments: paymentsRes.rows.length,
      tv_name: tv.name,
      identifier: ident,
      phone,
      username: tv.name,
      mac_address: tv.mac_address,
      online: isOnline,
      is_online: isOnline,
      package_name: tv.package_name,
      expires_at: tv.expires_at,
      revenue,
      total_revenue: revenue,
      used_bytes: usedBytes,
      today_bytes: todayBytes,
      month_bytes: usedBytes, /* RL_TV_ROUTER_USAGE applied above */
      vouchers: [tvVoucher],
      payments: paymentsRes.rows,
      sessions: sessions.rows,
      live_sessions: liveSessions,
      active_session: liveSessions[0] || sessions.rows.find(s=>s.currently_active) || null
    });
  } catch (err) {
    require('../utils/logger').error('[tv-lifecycle] ' + err.message);
    res.status(500).json({ ok:false, error: err.message });
  }
});

router.get('/:ispId/user/:identifier', async (req, res) => {
  try {
    const { ispId, identifier } = req.params;
    const ident = String(identifier).trim();
    
    // Normalize phone (strip spaces, leading +, leading 0 → 254)
    let normPhone = ident.replace(/[\s+]/g, '');
    if (normPhone.startsWith('0')) normPhone = '254' + normPhone.slice(1);
    
    // Find all vouchers for this phone OR matching this code
    const vouchersRes = await query(`
      SELECT v.*,
             p.name as package_name, p.price as package_price,
             p.duration_hours, p.bandwidth_up_mbps, p.bandwidth_down_mbps,
             p.data_limit_mb
      FROM hotspot_vouchers v
      LEFT JOIN hotspot_packages p ON p.id = v.package_id
      WHERE v.isp_id = $1::uuid
        AND (v.buyer_phone = $2 OR v.buyer_phone = $3 OR v.code = $4)
      ORDER BY (v.payment_id IS NOT NULL) DESC, v.updated_at DESC NULLS LAST, v.created_at DESC /* RL_CURRENT_FIRST: the customer's LIVING voucher leads (has a payment, most recently renewed) */
      LIMIT 100
    `, [ispId, normPhone, ident, ident]);
    
    const vouchers = vouchersRes.rows;
    
    if (vouchers.length === 0) {
      return res.json({ ok: true, found: false, identifier: ident });
    }
    
    // Get the phone (use first voucher's phone)
    const phone = vouchers[0].buyer_phone;
    const codes = vouchers.map(v => v.code);
    
    // Payments for this phone
    const paymentsRes = await query(`
      SELECT p.*, hv.code as voucher_code, pkg.name as package_name
      FROM payments p
      LEFT JOIN hotspot_vouchers hv ON hv.payment_id = p.id
      LEFT JOIN hotspot_vouchers vj ON vj.id = p.voucher_id
            LEFT JOIN hotspot_packages pkg ON pkg.id = vj.package_id
      WHERE p.isp_id = $1::uuid AND p.phone_number = $2
        AND (p.description IS NULL OR p.description NOT LIKE 'Platform charge%%')
        AND p.payment_method != 'admin_charge'
      ORDER BY p.created_at DESC
      LIMIT 50
    `, [ispId, phone]);
    
    // Sessions from radacct (realmed K-codes)
    const ispShort = String(ispId).replace(/-/g,'').slice(0,8).toLowerCase();
    // RL_MAC_ONLINE_USAGE: include each voucher's device MAC (both cases) so MAC-auth
    // sessions/usage recorded under the MAC roll into the voucher.
    const _macForms = [];
    for (const v of vouchers) {
      if (v.used_by_mac) { _macForms.push(String(v.used_by_mac).toLowerCase(), String(v.used_by_mac).toUpperCase()); }
    }
    const realmedCodes = codes.map(c => `${c}@${ispShort}`).concat(_macForms);
    
    let sessions = { rows: [] };
    try {
      sessions = await query(`
        SELECT 
          username,
          framedipaddress::text as ip,
          callingstationid as mac,
          acctstarttime,
          acctstoptime,
          acctsessiontime,
          acctinputoctets,
          acctoutputoctets,
          acctterminatecause,
          (acctstoptime IS NULL) as currently_active
        FROM radacct
        WHERE username = ANY($1::text[])
        ORDER BY acctstarttime DESC
        LIMIT 100
      `, [realmedCodes]);
    } catch (e) {
      sessions = { rows: [], error: e.message };
    }
    
    // Aggregate data totals (lifetime, this month, last 24h)
    let totals = { rows: [{}] };
    try {
      totals = await query(`
        SELECT 
          COALESCE(SUM(acctinputoctets), 0)::bigint as total_input_bytes,
          COALESCE(SUM(acctoutputoctets), 0)::bigint as total_output_bytes,
          COALESCE(SUM(acctsessiontime), 0)::bigint as total_seconds,
          COUNT(*) as total_sessions,
          COALESCE(SUM(acctinputoctets) FILTER (WHERE acctstarttime >= (date_trunc('month', NOW() AT TIME ZONE 'Africa/Nairobi')) AT TIME ZONE 'Africa/Nairobi'), 0)::bigint as month_input,
            COALESCE(SUM(acctoutputoctets) FILTER (WHERE acctstarttime >= (date_trunc('month', NOW() AT TIME ZONE 'Africa/Nairobi')) AT TIME ZONE 'Africa/Nairobi'), 0)::bigint as month_output,
            COUNT(*) FILTER (WHERE acctstarttime >= (date_trunc('month', NOW() AT TIME ZONE 'Africa/Nairobi')) AT TIME ZONE 'Africa/Nairobi') as month_sessions,
            COALESCE(SUM(acctinputoctets) FILTER (WHERE acctstarttime >= (date_trunc('day', NOW() AT TIME ZONE 'Africa/Nairobi')) AT TIME ZONE 'Africa/Nairobi'), 0)::bigint as day_input,
            COALESCE(SUM(acctoutputoctets) FILTER (WHERE acctstarttime >= (date_trunc('day', NOW() AT TIME ZONE 'Africa/Nairobi')) AT TIME ZONE 'Africa/Nairobi'), 0)::bigint as day_output
        FROM radacct WHERE username = ANY($1::text[])
      `, [realmedCodes]);
    } catch (e) {}

    /* RL_LIVE_HANDLER_UD: 'Today' MUST come from usage_daily, not radacct.
       The radacct query above filters `acctstarttime >= today`, so a session that started
       YESTERDAY and is still running contributes NOTHING — which is why an actively
       downloading hotspot user showed 0 B. usage_daily is the collector-fed per-day truth,
       keyed on the realmed username (K18@3d71deb2). The identical override already existed
       at ~line 1796, but that handler is SHADOWED by this one and never executes. */
    try {
      const _ud = await query(
        "SELECT COALESCE(SUM(bytes_in),0)::bigint AS day_input, " +
        "COALESCE(SUM(bytes_out),0)::bigint AS day_output " +
        "FROM usage_daily WHERE username = ANY($1::text[]) " +
        "AND usage_day = (now() AT TIME ZONE 'Africa/Nairobi')::date",
        [realmedCodes]
      );
      if (totals.rows && totals.rows[0] && _ud.rows && _ud.rows[0]) {
        totals.rows[0].day_input  = _ud.rows[0].day_input;
        totals.rows[0].day_output = _ud.rows[0].day_output;
      }
    } catch (e) { require('../utils/logger').warn('[user-lifecycle] usage_daily: ' + e.message); }

    /* RL_LIVE_HANDLER_UD: per-voucher lifetime bytes for the 'Used Bytes' column, which
       also read 0 B. Each voucher's realmed code (and its MAC, for MAC-auth sessions). */
    try {
      for (const v of vouchers) {
        const forms = [String(v.code) + '@' + ispShort];
        if (v.used_by_mac) { forms.push(String(v.used_by_mac).toLowerCase(), String(v.used_by_mac).toUpperCase()); }
        const _vb = await query(
          "SELECT COALESCE(SUM(acctinputoctets),0)::bigint AS b_in, " +
          "COALESCE(SUM(acctoutputoctets),0)::bigint AS b_out " +
          "FROM radacct WHERE username = ANY($1::text[])",
          [forms]
        );
        const r0 = _vb.rows && _vb.rows[0];
        v.used_bytes = r0 ? (Number(r0.b_in) + Number(r0.b_out)) : 0;
      }
    } catch (e) { require('../utils/logger').warn('[user-lifecycle] voucher bytes: ' + e.message); }
    
    // Current active session (if any)
    const activeSession = sessions.rows.find(s => s.currently_active) || null;
    
    // Total revenue from this phone
    const revenue = paymentsRes.rows
      .filter(p => p.status === 'success' || p.status === 'completed')
      .reduce((sum, p) => sum + Number(p.amount || 0), 0);
    
    // v62.20+v62.21: fetch live Mikrotik hotspot sessions (HARDENED — never crashes)
    let liveSessions = [];
    try {
      const axios = require('axios');
      let nasRes;
      try {
        nasRes = await query("SELECT id, wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL", [ispId]);
      } catch(qe) {
        require('../utils/logger').warn('[user-lifecycle] nas query: ' + qe.message);
        nasRes = { rows: [] };
      }
      
      for (const nas of (nasRes.rows || [])) {
        if (!nas.wireguard_ip || !nas.mikrotik_api_user || !nas.mikrotik_api_password) continue;
        try {
          const api = axios.create({
            baseURL: 'http://' + nas.wireguard_ip + '/rest',
            timeout: 3500,
            auth: { username: nas.mikrotik_api_user, password: nas.mikrotik_api_password },
            validateStatus: () => true
          });
          const resp = await api.get('/ip/hotspot/active');
          if (resp && resp.status === 200 && Array.isArray(resp.data)) {
            const codeSet = new Set(codes || []);
            const realmedSet = new Set(realmedCodes || []);
            for (const s of resp.data) {
              try {
                const u = s.user || '';
                const uBase = u.split('@')[0];
                if (codeSet.has(u) || codeSet.has(uBase) || realmedSet.has(u)) {
                  liveSessions.push({
                    username: u,
                    ip: s.address || '',
                    mac: s['mac-address'] || '',
                    uptime: s.uptime || '',
                    bytes_in: Number(s['bytes-in']) || 0,
                    bytes_out: Number(s['bytes-out']) || 0,
                    packets_in: Number(s['packets-in']) || 0,
                    packets_out: Number(s['packets-out']) || 0,
                    session_time_left: s['session-time-left'] || '',
                    idle_timeout: s['idle-timeout'] || '',
                    currently_active: true,
                    source: 'mikrotik'
                  });
                }
              } catch(_) { /* skip bad session */ }
            }
          }
        } catch (e) { /* skip this NAS — never fail the whole request */ }
      }
    } catch (e) {
      require('../utils/logger').warn('[user-lifecycle] live mikrotik fetch outer: ' + e.message);
      liveSessions = [];
    }
    
    //  (username) — most-recent active voucher's code, or first voucher
    const mostRecentActive = vouchers.filter(v => v.expires_at && new Date(v.expires_at) > new Date())
      .sort((a, b) => new Date(b.expires_at) - new Date(a.expires_at))[0];
    const primaryCode = (mostRecentActive && mostRecentActive.code) 
      || (liveSessions[0] && (liveSessions[0].username||'').split('@')[0])
      || (vouchers[0] && vouchers[0].code) 
      || '';
    
    // Online if there's a live Mikrotik session OR a radacct active session
    // v62.22c: defensive — radSessions may be out of scope here
    let isOnline = liveSessions.length > 0;
    try {
      if (!isOnline && typeof radSessions !== 'undefined' && radSessions && radSessions.rows && Array.isArray(radSessions.rows)) {
        isOnline = !!radSessions.rows.find(function(s) { return s.currently_active; });
      }
    } catch(_) {}
    
    res.json({
      ok: true,
      found: true,
      identifier: ident,
      phone,
      username: primaryCode,
      is_online: isOnline,
      live_sessions: liveSessions,
      summary: {
        total_vouchers: vouchers.length,
        active_vouchers: vouchers.filter(v => v.expires_at && new Date(v.expires_at) > new Date()).length,
        total_payments: paymentsRes.rows.length,
        total_revenue_kes: revenue,
        total_sessions: sessions.rows.length,
        active_session: activeSession,
        data_totals: totals.rows[0] || {}
      },
      vouchers,
      payments: paymentsRes.rows,
      sessions: sessions.rows
    });
  } catch (err) {
    require('../utils/logger').error(`[user-lifecycle] ${err.message}`);
    res.status(500).json({ ok: false, error: err.message });
  }
});


// --- v62.15b: Voucher edit/delete endpoints ---
// PATCH /api/isp/:ispId/voucher/:voucherId — update expires_at, status
router.patch('/:ispId/voucher/:voucherId', async (req, res) => {
  try {
    const { ispId, voucherId } = req.params;
    const { expires_at, status } = req.body || {};
    
    // Validate status if provided
    const validStatuses = ['unused', 'used', 'expired'];
    if (status && !validStatuses.includes(String(status).toLowerCase())) {
      return res.status(400).json({ ok: false, error: 'Invalid status' });
    }
    
    // Build dynamic SET clause
    const sets = [];
    const vals = [];
    let i = 1;
    /* RL_EXPIRE_FORCE_TIME: status and expiry must never contradict. Marking a voucher expired
       while its timestamp still sits in the future produced one screen saying 'expired' and
       another saying '23h 43m left' — and the session sweep, which reads the status, cut off a
       customer whose paid time had not run out. The status the operator picked decides the
       timestamp, not the other way round. */
    const _wantExpired = String(status || '').toLowerCase() === 'expired';
    const _wantActive  = String(status || '').toLowerCase() === 'active';
    if (_wantExpired) {
      // never leave a future timestamp on an expired voucher
      if (expires_at !== undefined && expires_at) {
        sets.push('expires_at = LEAST($' + i++ + '::timestamptz, NOW())');
        vals.push(expires_at);
      } else {
        sets.push('expires_at = NOW()');
      }
    } else if (expires_at !== undefined && expires_at) {
      sets.push('expires_at = $' + i++);
      vals.push(expires_at);
    } else if (_wantActive) {
      // reactivating something already past its time needs a future expiry, or it is both at once
      sets.push("expires_at = GREATEST(COALESCE(expires_at, NOW()), NOW() + interval '1 hour')");
    }
    if (status !== undefined) {
      sets.push('status = $' + i++);
      vals.push(String(status).toLowerCase());
    }
    sets.push('updated_at = NOW()');
    
    if (sets.length === 1) {
      return res.status(400).json({ ok: false, error: 'No changes' });
    }
    
    vals.push(ispId);
    vals.push(voucherId);
    
    const result = await query(
      'UPDATE hotspot_vouchers SET ' + sets.join(', ') +
      ' WHERE isp_id = $' + i++ + '::uuid AND id = $' + i + '::uuid RETURNING *',
      vals
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ ok: false, error: 'Voucher not found' });
    }
    
    // Also update radcheck if status changes (so RADIUS reflects this)
    try {
      const v = result.rows[0];
      const ispShort = String(ispId).replace(/-/g, '').slice(0, 8).toLowerCase();
      const realmedUser = v.code + '@' + ispShort;
      if (String(status).toLowerCase() === 'expired') {
        await query("DELETE FROM radcheck WHERE username = $1 OR username = $2", [v.code, realmedUser]);
        await query("DELETE FROM radreply WHERE username = $1 OR username = $2", [v.code, realmedUser]);
      } else if (String(status).toLowerCase() === 'unused' || String(status).toLowerCase() === 'used') {
        // Ensure radcheck entries exist
        const exists = await query("SELECT 1 FROM radcheck WHERE username = $1", [realmedUser]);
        if (exists.rows.length === 0) {
          await query("INSERT INTO radcheck (username, attribute, op, value) VALUES ($1, 'Cleartext-Password', ':=', $2) ON CONFLICT DO NOTHING", [realmedUser, v.code]);
        }
      }
    } catch (e) {
      require('../utils/logger').warn('[voucher-patch] radcheck sync: ' + e.message);
    }
    
    res.json({ ok: true, voucher: result.rows[0] });
  } catch (err) {
    require('../utils/logger').error('[voucher-patch] ' + err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// DELETE /api/isp/:ispId/voucher/:voucherId
router.delete('/:ispId/voucher/:voucherId', async (req, res) => {
  try {
    const { ispId, voucherId } = req.params;
    
    // Get voucher first so we can clean radcheck/radreply too
    const vRes = await query("SELECT * FROM hotspot_vouchers WHERE isp_id = $1::uuid AND id = $2::uuid", [ispId, voucherId]);
    if (vRes.rows.length === 0) {
      return res.status(404).json({ ok: false, error: 'Voucher not found' });
    }
    const v = vRes.rows[0];
    
    // Clean RADIUS tables for this code
    try {
      const ispShort = String(ispId).replace(/-/g, '').slice(0, 8).toLowerCase();
      const realmedUser = v.code + '@' + ispShort;
      await query("DELETE FROM radcheck WHERE username = $1 OR username = $2", [v.code, realmedUser]);
      await query("DELETE FROM radreply WHERE username = $1 OR username = $2", [v.code, realmedUser]);
    } catch (e) {
      require('../utils/logger').warn('[voucher-delete] radcheck cleanup: ' + e.message);
    }
    
    // Delete sessions tied to this voucher first (FK)
    try { await query("DELETE FROM hotspot_sessions WHERE voucher_id = $1::uuid", [voucherId]); } catch (e) {}
    
    // Note: payments.voucher_id references this voucher - set to NULL to keep payment records
    try { await query("UPDATE payments SET voucher_id = NULL WHERE voucher_id = $1::uuid", [voucherId]); } catch (e) {}
    
    await query("DELETE FROM hotspot_vouchers WHERE id = $1::uuid", [voucherId]);
    
    res.json({ ok: true, deleted: v });
  } catch (err) {
    require('../utils/logger').error('[voucher-delete] ' + err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});


// --- v62.20: Disconnect a hotspot session by K-code (via Mikrotik REST API) ---
// Resend the purchase SMS (code + password) for a voucher — RUMALINK resend-sms
router.post('/:ispId/user/:code/resend-sms', async (req, res) => {
  try {
    const { ispId, code } = req.params;
    const bareCode = String(code).split('@')[0].trim().toUpperCase();
    const vr = await query(
      `SELECT hv.code, hv.buyer_phone, hv.password, hp.name AS package_name
       FROM hotspot_vouchers hv
       LEFT JOIN hotspot_packages hp ON hp.id = hv.package_id
       WHERE hv.isp_id = $1::uuid AND UPPER(hv.code) = $2 LIMIT 1`,
      [ispId, bareCode]
    );
    if (!vr.rows[0]) return res.status(404).json({ ok: false, error: 'Voucher not found' });
    const v = vr.rows[0];
    if (!v.buyer_phone) return res.status(400).json({ ok: false, error: 'No phone number on this voucher' });

    const ispInfo = await query("SELECT * FROM isps WHERE id = $1::uuid", [ispId]);
    const pass = v.password || v.code;
    const message = `Your ${v.package_name || 'WiFi'} voucher: ${v.code}.\nReconnect if dropped: user ${v.code} pass ${pass}`;

    const { sendSMS } = require('../utils/sms');
    await sendSMS({ to: v.buyer_phone, message, isp: ispInfo.rows[0] });
    return res.json({ ok: true, sent_to: v.buyer_phone });
  } catch (err) {
    require('../utils/logger').error('[resend-sms] ' + err.message);
    return res.status(500).json({ ok: false, error: err.message });
  }
});

/* RL_MESSAGE_HISTORY: everything the SYSTEM has sent this customer — purchase confirmations,
   expiry notices, OTPs, and anything typed by hand. Matched on the last nine digits of the number
   so a message logged as +254…, 254… or 07… all belong to the same person; storing one format and
   querying another is exactly how a history silently comes back empty. */
router.get('/:ispId/user/:identifier/messages', async (req, res) => {
  try {
    const { ispId, identifier } = req.params;
    const ident = String(identifier || '').split('@')[0].trim();
    const digits = ident.replace(/[^0-9]/g, '');
    let phone = null;

    const v = await query(
      "SELECT hv.buyer_phone FROM hotspot_vouchers hv WHERE hv.isp_id = $1::uuid " +
      "AND (UPPER(hv.code) = UPPER($2) OR (LENGTH($3) >= 9 AND RIGHT(regexp_replace(hv.buyer_phone,'[^0-9]','','g'),9) = RIGHT($3,9))) " +
      "ORDER BY hv.updated_at DESC NULLS LAST LIMIT 1", [ispId, ident, digits]);
    if (v.rows[0]) phone = v.rows[0].buyer_phone;

    if (!phone) {
      const p = await query(
        "SELECT phone FROM pppoe_subscribers WHERE isp_id = $1::uuid " +
        "AND (LOWER(username) = LOWER($2) OR (LENGTH($3) >= 9 AND RIGHT(regexp_replace(COALESCE(phone,''),'[^0-9]','','g'),9) = RIGHT($3,9))) LIMIT 1",
        [ispId, ident, digits]);
      if (p.rows[0]) phone = p.rows[0].phone;
    }
    if (!phone) {
      const t = await query(
        "SELECT hv.buyer_phone FROM hotspot_bound_devices bd JOIN hotspot_vouchers hv ON hv.id = bd.active_voucher_id " +
        "WHERE bd.isp_id = $1::uuid AND UPPER(bd.mac_address) = UPPER($2) LIMIT 1", [ispId, ident]);
      if (t.rows[0]) phone = t.rows[0].buyer_phone;
    }
    if (!phone && digits.length >= 9) phone = digits;
    if (!phone) return res.json({ ok: true, phone: null, messages: [], note: 'No phone on record' });

    const pd = String(phone).replace(/[^0-9]/g, '');
    /* RL_HISTORY_PAGING: return a page plus the true total, so the UI can say "1-20 of 143"
       rather than silently truncating at a hundred. */
    const limit = Math.min(Math.max(parseInt(req.query.limit) || 20, 1), 100);
    const offset = Math.max(parseInt(req.query.offset) || 0, 0);
    const tot = await query(
      "SELECT COUNT(*)::int AS n FROM sms_logs WHERE isp_id = $1::uuid " +
      "AND RIGHT(regexp_replace(recipient,'[^0-9]','','g'),9) = RIGHT($2,9)", [ispId, pd]);
    const r = await query(
      "SELECT id, recipient, message, status, gateway, cost, sent_at FROM sms_logs " +
      "WHERE isp_id = $1::uuid AND RIGHT(regexp_replace(recipient,'[^0-9]','','g'),9) = RIGHT($2,9) " +
      "ORDER BY sent_at DESC NULLS LAST LIMIT $3 OFFSET $4", [ispId, pd, limit, offset]);

    return res.json({ ok: true, phone: phone, count: tot.rows[0].n, shown: r.rows.length,
                      limit: limit, offset: offset, messages: r.rows });
  } catch (err) {
    require('../utils/logger').error('[message-history] ' + err.message);
    return res.status(500).json({ ok: false, error: err.message });
  }
});

/* RL_CUSTOM_MESSAGE: free-text SMS to one customer from their lifecycle page.
   Separate from resend-sms on purpose — that one re-sends the fixed voucher credentials and is
   left exactly as it was. The recipient is resolved on the SERVER from the identifier rather than
   taken from the request, so a tampered payload cannot make one ISP text another ISP's customer. */
router.post('/:ispId/user/:identifier/message', async (req, res) => {
  try {
    const { ispId, identifier } = req.params;
    const message = String((req.body && req.body.message) || '').trim();
    if (!message) return res.status(400).json({ ok: false, error: 'Message is empty' });
    if (message.length > 480) return res.status(400).json({ ok: false, error: 'Message is too long (max 480 characters, 3 SMS)' });

    const ident = String(identifier || '').split('@')[0].trim();
    const digits = ident.replace(/[^0-9]/g, '');
    let phone = null, who = null;

    // hotspot voucher: by code, or by the buyer's number in any format
    const v = await query(
      "SELECT hv.code, hv.buyer_phone FROM hotspot_vouchers hv " +
      "WHERE hv.isp_id = $1::uuid AND (UPPER(hv.code) = UPPER($2) " +
      "  OR (LENGTH($3) >= 9 AND RIGHT(regexp_replace(hv.buyer_phone,'[^0-9]','','g'),9) = RIGHT($3,9))) " +
      "ORDER BY hv.updated_at DESC NULLS LAST LIMIT 1", [ispId, ident, digits]);
    if (v.rows[0] && v.rows[0].buyer_phone) { phone = v.rows[0].buyer_phone; who = 'voucher ' + v.rows[0].code; }

    // PPPoE subscriber: by username or number
    if (!phone) {
      const p = await query(
        "SELECT username, phone FROM pppoe_subscribers " +
        "WHERE isp_id = $1::uuid AND (LOWER(username) = LOWER($2) " +
        "  OR (LENGTH($3) >= 9 AND RIGHT(regexp_replace(COALESCE(phone,''),'[^0-9]','','g'),9) = RIGHT($3,9))) LIMIT 1",
        [ispId, ident, digits]);
      if (p.rows[0] && p.rows[0].phone) { phone = p.rows[0].phone; who = 'subscriber ' + p.rows[0].username; }
    }

    // TV: the bound device carries no number, so fall back to the voucher that owns it
    if (!phone) {
      const t = await query(
        "SELECT hv.code, hv.buyer_phone FROM hotspot_bound_devices bd " +
        "JOIN hotspot_vouchers hv ON hv.id = bd.active_voucher_id " +
        "WHERE bd.isp_id = $1::uuid AND UPPER(bd.mac_address) = UPPER($2) LIMIT 1", [ispId, ident]);
      if (t.rows[0] && t.rows[0].buyer_phone) { phone = t.rows[0].buyer_phone; who = 'TV owner (' + t.rows[0].code + ')'; }
    }

    if (!phone) return res.status(404).json({ ok: false, error: 'No phone number on record for this customer' });

    const ispInfo = await query('SELECT * FROM isps WHERE id = $1::uuid', [ispId]);
    if (!ispInfo.rows[0]) return res.status(404).json({ ok: false, error: 'ISP not found' });

    const { sendSMS } = require('../utils/sms');
    try {
      await sendSMS({ to: phone, message, isp: ispInfo.rows[0] });
    } catch (se) {
      // Surface the real reason. A silent failure here looks identical to success in the UI,
      // which is how an empty SMS balance goes unnoticed for days.
      const msg = se && se.code === 'SMS_BALANCE_EMPTY'
        ? 'SMS balance is empty. Top up to send messages.'
        : (se.message || 'Send failed');
      require('../utils/logger').warn('[custom-message] ' + msg);
      return res.status(400).json({ ok: false, error: msg });
    }
    require('../utils/logger').info('[custom-message] sent to ' + phone + ' (' + who + ') by isp ' + ispId);
    return res.json({ ok: true, sent_to: phone, matched: who, segments: Math.ceil(message.length / 160) });
  } catch (err) {
    require('../utils/logger').error('[custom-message] ' + err.message);
    return res.status(500).json({ ok: false, error: err.message });
  }
});

router.post('/:ispId/disconnect/:code', async (req, res) => {
  try {
    const { ispId, code } = req.params;
    const axios = require('axios');
    const ispShort = String(ispId).replace(/-/g, '').slice(0, 8).toLowerCase();
    const realmedCode = code + '@' + ispShort;
    
    // Find all NAS for this ISP
    const nasRes = await query("SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password, radius_secret FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL", [ispId]);
    
    let disconnected = 0;
    const details = [];
    
    for (const nas of nasRes.rows) {
      try {
        const api = axios.create({
          baseURL: 'http://' + nas.wireguard_ip + '/rest',
          timeout: 5000,
          auth: { username: nas.mikrotik_api_user, password: nas.mikrotik_api_password },
          validateStatus: () => true
        });
        
        // Get active hotspot sessions
        const active = await api.get('/ip/hotspot/active');
        if (active.status === 200 && Array.isArray(active.data)) {
          for (const s of active.data) {
            const u = s.user || '';
            if (u === code || u === realmedCode || u.split('@')[0] === code) {
              // Disconnect this session
              try {
                const del = await api.delete('/ip/hotspot/active/' + encodeURIComponent(s['.id']));
                if (del.status >= 200 && del.status < 300) {
                  disconnected++;
                  details.push({ nas: nas.name, user: u, mac: s['mac-address'], status: 'disconnected' });
                }
              } catch (e) { details.push({ nas: nas.name, user: u, error: e.message }); }
            }
          }
        }
      } catch (e) {
        details.push({ nas: nas.name, error: e.message });
      }
    }
    
    res.json({ ok: true, disconnected, details });
  } catch (err) {
    require('../utils/logger').error('[disconnect] ' + err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// --- v62.20 helper: disconnect a voucher's active session (called from DELETE/PATCH) ---
async function disconnectVoucherSession(ispId, code) {
  try {
    const axios = require('axios');
    const ispShort = String(ispId).replace(/-/g, '').slice(0, 8).toLowerCase();
    const realmedCode = code + '@' + ispShort;
    
    const nasRes = await query("SELECT id, wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL", [ispId]);
    
    for (const nas of nasRes.rows) {
      try {
        const api = axios.create({
          baseURL: 'http://' + nas.wireguard_ip + '/rest',
          timeout: 4000,
          auth: { username: nas.mikrotik_api_user, password: nas.mikrotik_api_password },
          validateStatus: () => true
        });
        const active = await api.get('/ip/hotspot/active');
        if (active.status === 200 && Array.isArray(active.data)) {
          for (const s of active.data) {
            const u = s.user || '';
            if (u === code || u === realmedCode || u.split('@')[0] === code) {
              try {
                await api.delete('/ip/hotspot/active/' + encodeURIComponent(s['.id']));
              } catch(_){}
            }
          }
        }
      } catch (e) { /* skip NAS */ }
    }
  } catch (e) {
    require('../utils/logger').warn('[disconnectVoucherSession] ' + e.message);
  }
}


// =====================================================================
// v62.23: PPPoE user lifecycle endpoint
// GET /api/isp/:ispId/pppoe-user/:identifier  (identifier = phone or username)
// Returns the same shape as /user/:identifier but populated from PPPoE tables
// =====================================================================
router.get('/:ispId/pppoe-user/:identifier', async (req, res) => {
  try {
    const { ispId, identifier: ident } = req.params;
    if (!ispId || !ident) return res.status(400).json({ ok: false, error: 'missing params' });
    
    // Look up subscribers — by phone first, then by username
    let subs = await lookupPppoeByPhone(ispId, ident);
    if (subs.length === 0) {
      // Try by username
      try {
        const r = await query(
          `SELECT ps.*, pp.name as package_name, pp.price as package_price,
                  pp.bandwidth_down_mbps, pp.bandwidth_up_mbps, pp.data_limit_gb,
                  pp.billing_cycle, pp.mikrotik_profile
           FROM pppoe_subscribers ps
           JOIN pppoe_packages pp ON pp.id = ps.package_id
           WHERE ps.isp_id = $1::uuid AND ps.username = $2
           LIMIT 1`,
          [ispId, ident]
        );
        subs = r.rows || [];
      } catch (e) {}
    }
    
    if (subs.length === 0) {
      return res.json({ ok: true, found: false, identifier: ident });
    }
    
    // For now, use the most recent subscriber (or active)
    const sub = subs.find(s => s.status === 'active') || subs[0];
    
    // v62.27: Fetch password from radcheck (Cleartext-Password)
    let subPassword = '';
    try {
      const pwRes = await query("SELECT value FROM radcheck WHERE username = $1 AND attribute = 'Cleartext-Password' LIMIT 1", [sub.username]);
      if (pwRes.rows.length > 0) subPassword = pwRes.rows[0].value;
    } catch (e) { /* no password retrievable */ }
    
    // Fetch data totals + sessions + payments for this subscriber
    const [dataTotals, sessions, payments] = await Promise.all([
      fetchPppoeDataTotals(sub.id),
      fetchPppoeSessions(sub.id),
      query(`SELECT id, amount, payment_method, status, description, paid_at, created_at, transaction_id, gateway_reference, phone_number
             FROM payments
             WHERE subscriber_id = $1::uuid OR (phone_number = $2 AND description ILIKE '%pppoe%')
             ORDER BY created_at DESC LIMIT 50`, [sub.id, sub.phone || ident]).then(r => r.rows || []).catch(() => [])
    ]);
    
    // Compute revenue from paid payments
    const paidPayments = payments.filter(p => {
      const st = String(p.status || '').toLowerCase().trim();
      return st === 'paid' || st === 'success' || st === 'completed';
    });
    const totalRevenue = paidPayments.reduce((s, p) => s + Number(p.amount || 0), 0);
    
    // Active session
    // Active session (from DB)
      const activeSession = sessions.find(s => s.currently_active);

      // v62.35/v62.36b: Live data from Mikrotik /ppp/active (define BEFORE use)
      let liveSessions = [];
      try {
        liveSessions = await fetchLivePppoeSessions(ispId, sub.username);
      } catch (e) { liveSessions = []; }

      const isOnline = liveSessions.length > 0 || !!activeSession;

      /* RUMALINK_UD_FINAL: exact today usage from usage_daily for this PPPoE user. */
      try {
        const _ud = await query(
          "SELECT COALESCE(SUM(bytes_in),0)::bigint AS day_input, " +
          "COALESCE(SUM(bytes_out),0)::bigint AS day_output " +
          "FROM usage_daily WHERE username = $1 " +
          "AND usage_day = (now() AT TIME ZONE 'Africa/Nairobi')::date",
          [sub.username]
        );
        if (_ud.rows && _ud.rows[0]) {
          dataTotals.day_input  = _ud.rows[0].day_input;
          dataTotals.day_output = _ud.rows[0].day_output;
        }
      } catch (e) { /* keep existing values on error */ }
    
    res.json({
      ok: true,
      found: true,
      source: 'pppoe',
      identifier: ident,
      phone: sub.phone || ident,
      username: sub.username,
      is_online: isOnline,
      live_sessions: liveSessions,
      pppoe_subscriber: {
        id: sub.id,
        username: sub.username,
        password: subPassword,
        full_name: sub.full_name,
        phone: sub.phone,
        email: sub.email,
        status: sub.status,
        balance: sub.balance,
        next_billing_date: sub.next_billing_date,
        last_payment_date: sub.last_payment_date,
        county: sub.county,
        town: sub.town,
        physical_address: sub.physical_address,
        static_ip: sub.static_ip,
        mac_address: sub.mac_address,
        package_name: sub.package_name,
        package_price: sub.package_price,
        bandwidth_down_mbps: sub.bandwidth_down_mbps,
        bandwidth_up_mbps: sub.bandwidth_up_mbps,
        data_limit_gb: sub.data_limit_gb,
        billing_cycle: sub.billing_cycle,
        mikrotik_profile: sub.mikrotik_profile,
        created_at: sub.created_at
      },
      summary: {
        total_revenue_kes: totalRevenue,
        total_payments: payments.length,
        paid_payments: paidPayments.length,
        total_vouchers: 0,
        active_vouchers: 0,
        data_totals: {
          total_input: Number(dataTotals.total_input) || 0,
          total_output: Number(dataTotals.total_output) || 0,
          total_seconds: Number(dataTotals.total_seconds) || 0,
          total_sessions: Number(dataTotals.total_sessions) || 0,
          day_input: Number(dataTotals.day_input) || 0,
          day_output: Number(dataTotals.day_output) || 0,
          month_input: Number(dataTotals.month_input) || 0,
          month_output: Number(dataTotals.month_output) || 0,
          month_sessions: Number(dataTotals.month_sessions) || 0,
          voucher_cumulative: { bytes_in: 0, bytes_out: 0, seconds: 0 }
        }
      },
      vouchers: [],  // PPPoE has subscribers not vouchers
      payments: payments,
      sessions: sessions
    });
  } catch (err) {
    require('../utils/logger').error('[pppoe-user] ' + err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// v62.23: Update PPPoE subscriber (phone, etc.) via ISP route
router.patch('/:ispId/pppoe-subscriber/:subscriberId', async (req, res) => {
  if (req.body) { req.body.password = req.body.password || req.body.pppoe_password || req.body.pppoePassword || req.body.new_password || req.body.secret; }

  try {
    const { ispId, subscriberId } = req.params;
    let { phone, full_name, email, status, next_billing_date, password, package_id, pppoe_password } = req.body || {};
    if (!password && pppoe_password) password = pppoe_password; /* RL_PPPOE_PKG_EDIT */
    
    // Build dynamic update
    const fields = [];
    const params = [];
    let idx = 1;
    if (phone !== undefined) { fields.push(`phone = $${idx++}`); params.push(phone); }
    if (full_name !== undefined) { fields.push(`full_name = $${idx++}`); params.push(full_name); }
    if (email !== undefined) { fields.push(`email = $${idx++}`); params.push(email); }
    if (status !== undefined) { fields.push(`status = $${idx++}`); params.push(status); }
    if (next_billing_date !== undefined) { fields.push(`next_billing_date = $${idx++}::timestamptz`); params.push(next_billing_date); }
    if (fields.length === 0 && !password && !package_id) return res.status(400).json({ ok: false, error: 'no fields to update' });
    
    fields.push('updated_at = NOW()');
    params.push(subscriberId, ispId);
    
    const sql = `UPDATE pppoe_subscribers SET ${fields.join(', ')} WHERE id = $${idx++}::uuid AND isp_id = $${idx++}::uuid RETURNING id, username, phone, full_name, email, status`;
    
    const r = await query(sql, params);
    if (r.rows.length === 0) return res.status(404).json({ ok: false, error: 'subscriber not found' });
    
    // v62.27: also update radcheck if password changed
    if (password !== undefined && password !== '') {
      try {
        await query("UPDATE radcheck SET value = $1 WHERE username = $2 AND attribute = 'Cleartext-Password'", [password, r.rows[0].username]);
        // bcrypt-update password_hash too for backwards compat
        const bcrypt = require('bcryptjs');
        const hash = await bcrypt.hash(password, 10);
        await query("UPDATE pppoe_subscribers SET password_hash = $1 WHERE id = $2::uuid", [hash, subscriberId]);
        
        // v62.31b: also update NT-Password for MS-CHAPv2 (required by PPPoE clients)
        try {
          const crypto = require('crypto');
          let ntHash;
          try {
            ntHash = crypto.createHash('md4').update(Buffer.from(password, 'utf16le')).digest('hex').toUpperCase();
          } catch (e) {
            const { execSync } = require('child_process');
            ntHash = execSync(`printf '%s' "${password.replace(/"/g, '\\"')}" | iconv -t UTF-16LE | openssl dgst -provider legacy -provider default -md4 | awk '{print toupper($NF)}'`).toString().trim();
          }
          if (ntHash && ntHash.length === 32) {
            await query("DELETE FROM radcheck WHERE username = $1 AND attribute = 'NT-Password'", [r.rows[0].username]);
            await query("INSERT INTO radcheck (username, attribute, op, value) VALUES ($1, 'NT-Password', ':=', $2)", [r.rows[0].username, ntHash]);
          }
        } catch (ntErr) { require('../utils/logger').warn('[pppoe nt-hash] ' + ntErr.message); }
      } catch (pwErr) { require('../utils/logger').warn('[pppoe-pw-update] ' + pwErr.message); }
    }
    
    // RL_PPPOE_PKG_EDIT: change plan/speed — update package_id + rewrite RADIUS reply attributes
    if (package_id !== undefined && package_id) {
      try {
        const uname = r.rows[0].username;
        const np = (await query("SELECT id, name, bandwidth_down_mbps, bandwidth_up_mbps, mikrotik_profile, address_pool FROM pppoe_packages WHERE id="+String.fromCharCode(36)+"1::uuid AND isp_id="+String.fromCharCode(36)+"2::uuid AND is_active=true LIMIT 1", [package_id, ispId])).rows[0];
        if (np) {
          await query("UPDATE pppoe_subscribers SET package_id="+String.fromCharCode(36)+"1::uuid, updated_at=NOW() WHERE id="+String.fromCharCode(36)+"2::uuid", [np.id, subscriberId]);
          await query("DELETE FROM radreply WHERE username="+String.fromCharCode(36)+"1 AND attribute IN ('Mikrotik-Rate-Limit','Mikrotik-Group','Framed-Pool')", [uname]).catch(function(){});
          const down = np.bandwidth_down_mbps, up = np.bandwidth_up_mbps;
          if (down || up) { const rate = (up||down)+'M/'+(down||up)+'M'; await query("INSERT INTO radreply (username, attribute, op, value) VALUES ("+String.fromCharCode(36)+"1,'Mikrotik-Rate-Limit','=',"+String.fromCharCode(36)+"2)", [uname, rate]).catch(function(){}); }
          if (np.mikrotik_profile) { await query("INSERT INTO radreply (username, attribute, op, value) VALUES ("+String.fromCharCode(36)+"1,'Mikrotik-Group','=',"+String.fromCharCode(36)+"2)", [uname, np.mikrotik_profile]).catch(function(){}); }
          if (np.address_pool) { await query("INSERT INTO radreply (username, attribute, op, value) VALUES ("+String.fromCharCode(36)+"1,'Framed-Pool','=',"+String.fromCharCode(36)+"2)", [uname, np.address_pool]).catch(function(){}); }
          require('../utils/logger').info('[pppoe-edit] '+uname+' plan -> '+np.name+' (reconnect to apply)');
        }
      } catch (e) { require('../utils/logger').warn('[pppoe-pkg-edit] '+e.message); }
    }

    // v62.49: expiry-driven walled garden — if the expiry date is set in the past, wall the
    // subscriber immediately (don't wait for the overdue cron). If pushed to the future and they
    // were expired, restore them. Only acts when next_billing_date is explicitly provided.
    if (next_billing_date !== undefined) {
      try {
        const wg = require('../utils/walledGarden');
        const full = await query(
          `SELECT ps.id, ps.username, ps.nas_id, ps.isp_id, ps.status, ps.next_billing_date, pp.mikrotik_profile
             FROM pppoe_subscribers ps JOIN pppoe_packages pp ON pp.id=ps.package_id
            WHERE ps.id=$1::uuid`, [subscriberId]
        );
        const s = full.rows[0];
        if (s) {
          const isPast = s.next_billing_date && new Date(s.next_billing_date) < new Date();
          if (isPast && s.status !== 'expired') {
            await wg.restrict(s);
            require('../utils/logger').info('[expiry] ' + s.username + ' set to past date -> restricted (walled)');
          } else if (!isPast && s.status === 'expired') {
            await query("UPDATE pppoe_subscribers SET status='active', updated_at=NOW() WHERE id=$1::uuid", [s.id]);
            await wg.restore(s, s.mikrotik_profile || null);
            require('../utils/logger').info('[expiry] ' + s.username + ' future date on expired -> restored');
          }
        }
      } catch (wgErr) { require('../utils/logger').warn('[expiry walled-garden] ' + wgErr.message); }
    }

        res.json({ ok: true, subscriber: r.rows[0] });
  } catch (err) {
    require('../utils/logger').error('[pppoe-subscriber update] ' + err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});


// v62.27: DELETE PPPoE subscriber + cleanup radcheck
router.delete('/:ispId/pppoe-subscriber/:subscriberId', async (req, res) => {
  try {
    const { ispId, subscriberId } = req.params;
    
    // Get username first
    const subRes = await query("SELECT username FROM pppoe_subscribers WHERE id = $1::uuid AND isp_id = $2::uuid", [subscriberId, ispId]);
    if (subRes.rows.length === 0) {
      return res.status(404).json({ ok: false, error: 'Subscriber not found' });
    }
    const username = subRes.rows[0].username;
    
    // Delete radcheck rows
    try {
      await query("DELETE FROM radcheck WHERE username = $1", [username]);
      await query("DELETE FROM radreply WHERE username = $1", [username]);
    } catch (e) { /* ignore */ }
    
    // Delete from PPPoE active sessions if any (let radius accounting handle the cleanup)
    try {
      await query("UPDATE pppoe_sessions SET status = 'closed', ended_at = NOW() WHERE subscriber_id = $1::uuid AND status = 'active'", [subscriberId]);
    } catch (e) {}
    
    // Delete subscriber
    await query("DELETE FROM pppoe_subscribers WHERE id = $1::uuid AND isp_id = $2::uuid", [subscriberId, ispId]);
    
    res.json({ ok: true, deleted: true, username });
  } catch (err) {
    require('../utils/logger').error('[pppoe-subscriber delete] ' + err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// v62.72: Return next available auto K-code for this ISP (helps the UI pre-fill)
router.get('/hotspot/next-code', async (req, res, next) => {
  try {
    const existing = await query(`SELECT code FROM hotspot_vouchers WHERE isp_id = $1::uuid AND code ~ '^K[0-9]+$' ORDER BY LENGTH(code) DESC, code DESC LIMIT 1`, [req.user.ispId]);
    let nextNum = 1;
    if (existing.rows[0]) {
      const n = parseInt(existing.rows[0].code.replace(/^K/, ''), 10);
      if (!isNaN(n)) nextNum = n + 1;
    }
    res.json({ ok: true, next_code: `K${nextNum}` });
  } catch (err) { next(err); }
});

// v62.72: Create a single hotspot voucher manually (test or paid)
// Accepts: code (optional), package_id (required), buyer_phone, mac_address, nas_id, is_test
router.post('/hotspot/manual-voucher', async (req, res, next) => {
  try {
    const { code: rawCode, package_id, buyer_phone, mac_address, nas_id, is_test } = req.body;
    if (!package_id) return res.status(400).json({ error: 'package_id is required' });

    const pkg = await query(`SELECT id, name, duration_hours, isp_id, price FROM hotspot_packages WHERE id = $1 AND isp_id = $2`, [package_id, req.user.ispId]);
    if (!pkg.rows[0]) return res.status(404).json({ error: 'Package not found' });

    // Resolve the code: use provided OR auto-generate next K-number
    let code = (rawCode || '').trim().toUpperCase();
    if (!code) {
      const existing = await query(`SELECT code FROM hotspot_vouchers WHERE isp_id = $1::uuid AND code ~ '^K[0-9]+$' ORDER BY LENGTH(code) DESC, code DESC LIMIT 1`, [req.user.ispId]);
      let nextNum = 1;
      if (existing.rows[0]) {
        const n = parseInt(existing.rows[0].code.replace(/^K/, ''), 10);
        if (!isNaN(n)) nextNum = n + 1;
      }
      code = `K${nextNum}`;
    }

    // Validate code (alphanumeric only, 2-20 chars)
    if (!/^[A-Z0-9_-]{2,20}$/.test(code)) {
      return res.status(400).json({ error: 'Code must be 2-20 chars, alphanumeric (A-Z, 0-9, _ or -)' });
    }

    // Uniqueness check per ISP
    const dup = await query(`SELECT id FROM hotspot_vouchers WHERE isp_id = $1::uuid AND code = $2`, [req.user.ispId, code]);
    if (dup.rows[0]) return res.status(409).json({ error: `Code ${code} already exists for this ISP. Choose a different one or leave blank to auto-generate.` });

    // Expiry: from now + package.duration_hours (default 1h)
    const durHrs = pkg.rows[0].duration_hours || 1;
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + durHrs);

    const testFlag = !!is_test;
    // Test accounts: free, marked is_paid=true so usable immediately
    // Manual non-test: not paid yet (waits for cash record), but voucher exists
    const isPaid = testFlag ? true : false;
    const amountPaid = testFlag ? 0 : null;
    const paymentMethod = testFlag ? 'test' : null;

    const result = await query(`
      INSERT INTO hotspot_vouchers (
        isp_id, package_id, nas_id, code, status, is_paid, is_test, amount_paid, payment_method, buyer_phone, used_by_mac, expires_at
      ) VALUES ($1::uuid, $2::uuid, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING id, code, expires_at, is_test, is_paid, buyer_phone
    `, [req.user.ispId, package_id, nas_id || null, code, 'active', isPaid, testFlag, amountPaid, paymentMethod, buyer_phone || null, mac_address || null, expiresAt]);

    res.json({
      ok: true,
      voucher: result.rows[0],
      note: testFlag
        ? 'Test voucher created — usable immediately, no payment required, excluded from revenue.'
        : 'Manual voucher created — record cash payment separately to mark it paid.'
    });
  } catch (err) {
    require('../utils/logger').error('[manual-voucher] ' + err.message);
    next(err);
  }
});

// v62.71: Create a test hotspot voucher (no M-Pesa, no charge)
router.post('/hotspot/test-voucher', async (req, res, next) => {
  try {
    const { package_id, nas_id } = req.body;
    if (!package_id) return res.status(400).json({ error: 'package_id required' });

    // Look up package
    const pkg = await query(`SELECT id, name, duration_hours, isp_id, bandwidth_down_mbps, bandwidth_up_mbps FROM hotspot_packages WHERE id = $1 AND isp_id = $2`, [package_id, req.user.ispId]);
    if (!pkg.rows[0]) return res.status(404).json({ error: 'Package not found' });

    // Compute next K-code (highest K-number for this ISP + 1)
    const existing = await query(`SELECT code FROM hotspot_vouchers WHERE isp_id = $1::uuid AND code ~ '^K[0-9]+$' ORDER BY LENGTH(code) DESC, code DESC LIMIT 1`, [req.user.ispId]);
    let nextNum = 1;
    if (existing.rows[0]) {
      const n = parseInt(existing.rows[0].code.replace(/^K/, ''), 10);
      if (!isNaN(n)) nextNum = n + 1;
    }
    const code = `K${nextNum}`;

    // Compute expires_at from package duration
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + (pkg.rows[0].duration_hours || 1));

    const result = await query(`
      INSERT INTO hotspot_vouchers (isp_id, package_id, nas_id, code, status, is_paid, is_test, amount_paid, payment_method, expires_at)
      VALUES ($1::uuid, $2::uuid, $3, $4, 'active', true, true, 0, 'test', $5)
      RETURNING id, code, expires_at, is_test
    `, [req.user.ispId, package_id, nas_id || null, code, expiresAt]);

    res.json({ ok: true, voucher: result.rows[0], note: 'Test voucher created — usable immediately, no payment required, excluded from revenue.' });
  } catch (err) {
    require('../utils/logger').error('[test-voucher] ' + err.message);
    next(err);
  }
});


// v62.75: Lists for dashboard "Expiring Soon" + "PPPoE Online" tables
router.get('/dashboard-lists', async (req, res, next) => {
  try {
    const ispId = req.user.ispId;

    // Expiring Soon PPPoE: due within 5 days OR already past due; exclude test accounts
    const expiring = await query(`
      SELECT ps.id, ps.username, ps.full_name, ps.phone, ps.status, ps.next_billing_date,
             pp.name as package_name,
             CASE WHEN ps.next_billing_date < NOW() THEN 'expired'
                  WHEN ps.next_billing_date <= NOW() + INTERVAL '5 days' THEN 'expiring'
                  ELSE 'ok' END as expiry_state
      FROM pppoe_subscribers ps
      LEFT JOIN pppoe_packages pp ON pp.id = ps.package_id
      WHERE ps.isp_id = $1::uuid
        AND (ps.is_test IS NULL OR ps.is_test = false)
        AND ps.next_billing_date IS NOT NULL
        AND ps.next_billing_date <= NOW() + INTERVAL '5 days'
      ORDER BY ps.next_billing_date ASC
      LIMIT 20
    `, [ispId]);

    // PPPoE Online: active sessions for this ISP's subscribers (live from radacct)
    const online = await query(`
      SELECT ps.id, ra.username, ra.framedipaddress::text as ip, ra.callingstationid as mac,
             ra.acctstarttime, ra.acctsessiontime,
             ps.full_name, ps.phone, ps.is_test
      FROM radacct ra
      JOIN pppoe_subscribers ps ON ps.username = ra.username
      WHERE ps.isp_id = $1::uuid AND ra.acctstoptime IS NULL
      ORDER BY ra.acctstarttime DESC
      LIMIT 20
    `, [ispId]);

    res.json({
      ok: true,
      expiring_pppoe: expiring.rows,
      pppoe_online: online.rows
    });
  } catch (err) {
    require('../utils/logger').error('[dashboard-lists] ' + err.message);
    next(err);
  }
});


// ============================================================
// SMS CREDITS — balance, topup (STK to admin paybill), callback
// ============================================================

// GET /api/isp/sms/balance — ISP credit balance + live price + gateway flag
router.get('/sms/balance', async (req, res, next) => {
  try {
    const ispId = req.user.ispId;
    const r = await query("SELECT sms_balance, sms_gateway FROM isps WHERE id=$1::uuid", [ispId]);
    const row = r.rows[0] || {};
    const s = await query("SELECT value FROM platform_settings WHERE key='sms_price_per_sms' LIMIT 1");
    const price = (s.rows[0] && s.rows[0].value != null) ? parseFloat(s.rows[0].value) : 0.50;
    res.json({
      balance: parseFloat(row.sms_balance || 0),
      price_per_sms: price,
      is_rumalink_sms: (row.sms_gateway || '').toLowerCase() === 'rumalink'
    });
  } catch (err) { next(err); }
});

// POST /api/isp/sms/topup — STK push to admin paybill to buy SMS credits
router.post('/sms/topup', async (req, res, next) => {
  const ispId = req.user.ispId;
  const { phone, amount } = req.body || {};
  if (!phone) return res.status(400).json({ error: 'Phone is required' });
  const amt = parseFloat(amount);
  if (!amt || isNaN(amt) || amt < 1) return res.status(400).json({ error: 'Enter a valid amount (min KES 1)' });
  try {
    // live pricing
    const ps = await query("SELECT key, value FROM platform_settings WHERE key IN ('sms_price_per_sms','sms_cost_per_sms')");
    let price = 0.50, cost = 0.35;
    for (const r of ps.rows) { if (r.key==='sms_price_per_sms') price=parseFloat(r.value); if (r.key==='sms_cost_per_sms') cost=parseFloat(r.value); }
    if (!(price > 0)) return res.status(400).json({ error: 'SMS price not configured' });
    const smsCount = Math.round((amt / price) * 100) / 100;   // 2dp
    const profit = Math.round((price - cost) * smsCount * 10000) / 10000;

    // admin Daraja config
    const cfgRes = await query("SELECT * FROM mpesa_configs WHERE is_admin_config=true AND is_active=true LIMIT 1");
    if (!cfgRes.rows[0] || !cfgRes.rows[0].consumer_key) return res.status(400).json({ error: 'SMS payments are not available right now (platform M-Pesa not configured).' });
    const cfg = cfgRes.rows[0];

    const normPhone = String(phone).replace(/\D/g,'').replace(/^0/,'254').replace(/^\+/,'');
    if (!/^254[17]\d{8}$/.test(normPhone)) return res.status(400).json({ error: 'Invalid phone format. Use 07XXXXXXXX.' });

    const desc = ('SMS topup ' + smsCount + ' sms').substring(0,250);
    // payment row
    const payRes = await query(
      `INSERT INTO payments (isp_id, amount, payment_method, payment_gateway, phone_number, description, status, commission_rate, commission_amount, net_amount)
       VALUES ($1::uuid, $2::decimal, 'mpesa', 'mpesa_stk', $3, $4, 'pending', 0, 0, $2::decimal) RETURNING id`,
      [ispId, amt, normPhone, desc]
    );
    const paymentId = payRes.rows[0].id;

    // sms credit txn (pending)
    await query(
      `INSERT INTO sms_credit_transactions (isp_id, txn_type, sms_count, unit_price, unit_cost, amount_paid, profit, payment_id, status, note)
       VALUES ($1::uuid, 'purchase', $2, $3, $4, $5, $6, $7::uuid, 'pending', $8)`,
      [ispId, smsCount, price, cost, amt, profit, paymentId, 'STK topup']
    );

    // OAuth + STK (mirror admin flow)
    const baseUrl = cfg.is_sandbox ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';
    let token;
    try {
      const tokRes = await axios.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, { headers:{ Authorization:`Basic ${Buffer.from(`${cfg.consumer_key}:${cfg.consumer_secret}`).toString('base64')}` }, timeout:10000 });
      token = tokRes.data.access_token;
      if (!token) throw new Error('No access_token');
    } catch (e) {
      const msg = (e.response?.data?.errorMessage || e.message || 'OAuth failed').substring(0,240);
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid",[msg,paymentId]).catch(()=>{});
      await query("UPDATE sms_credit_transactions SET status='failed' WHERE payment_id=$1::uuid",[paymentId]).catch(()=>{});
      return res.status(400).json({ error: 'M-Pesa auth failed: ' + msg });
    }
    const ts = new Date().toISOString().replace(/[-:T.Z]/g,'').slice(0,14);
    const pwd = Buffer.from(`${cfg.shortcode}${cfg.passkey}${ts}`).toString('base64');
    let stkRes;
    try {
      stkRes = await axios.post(`${baseUrl}/mpesa/stkpush/v1/processrequest`, {
        BusinessShortCode: cfg.shortcode, Password: pwd, Timestamp: ts, TransactionType:'CustomerPayBillOnline',
        Amount: Math.ceil(amt), PartyA: normPhone, PartyB: cfg.shortcode, PhoneNumber: normPhone,
        CallBackURL: `${process.env.BASE_URL}/api/public/sms-topup-callback/${paymentId}`,
        AccountReference: 'SMS'+paymentId.substring(0,9), TransactionDesc: 'SMS topup'
      }, { headers:{ Authorization:`Bearer ${token}` }, timeout:15000 });
    } catch (e) {
      const msg = (e.response?.data?.errorMessage || e.response?.data?.ResponseDescription || e.message).substring(0,240);
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid",[msg,paymentId]).catch(()=>{});
      await query("UPDATE sms_credit_transactions SET status='failed' WHERE payment_id=$1::uuid",[paymentId]).catch(()=>{});
      return res.status(400).json({ error: 'STK push failed: ' + msg });
    }
    try {
      await query(`INSERT INTO mpesa_transactions (isp_id, payment_id, checkout_request_id, merchant_request_id, amount, phone, status) VALUES ($1::uuid,$2::uuid,$3,$4,$5::decimal,$6,'pending')`,
        [ispId, paymentId, stkRes.data.CheckoutRequestID, stkRes.data.MerchantRequestID, amt, normPhone]);
    } catch (e) {}
    res.json({ success:true, payment_id: paymentId, sms_count: smsCount, amount: amt, message: `M-Pesa prompt sent to ${normPhone}.` });
  } catch (err) { next(err); }
});

// POST /api/isp/sms/topup/callback/:paymentId — Safaricom callback (idempotent credit)
router.post('/sms/topup/callback/:paymentId', async (req, res) => {
  const paymentId = req.params.paymentId;
  try {
    const cb = req.body?.Body?.stkCallback;
    if (cb && cb.ResultCode === 0) {
      const items = cb.CallbackMetadata?.Item || [];
      const g = n => items.find(x => x.Name === n)?.Value;
      const receipt = g('MpesaReceiptNumber');
      const payerPhone = g('PhoneNumber');
      const payerAmount = g('Amount');
      // idempotency: only act if the credit txn is still pending
      const txn = await query("SELECT id, isp_id, sms_count, status FROM sms_credit_transactions WHERE payment_id=$1::uuid LIMIT 1", [paymentId]);
      const t = txn.rows[0];
      if (t && t.status === 'pending') {
        await query("UPDATE payments SET status='paid', transaction_id=$1, paid_at=NOW(), mpesa_phone=$2::varchar, mpesa_amount=$3::decimal WHERE id=$4::uuid",
          [receipt, payerPhone ? String(payerPhone) : null, payerAmount || null, paymentId]).catch(()=>{});
        await query("UPDATE mpesa_transactions SET status='completed', mpesa_receipt=$1, transaction_date=NOW() WHERE payment_id=$2::uuid",[receipt,paymentId]).catch(()=>{});
        // credit the ISP + record balance after
        const upd = await query("UPDATE isps SET sms_balance = sms_balance + $1 WHERE id=$2::uuid RETURNING sms_balance", [t.sms_count, t.isp_id]);
        const balAfter = upd.rows[0] ? parseFloat(upd.rows[0].sms_balance) : null;
        await query("UPDATE sms_credit_transactions SET status='completed', isp_balance_after=$1 WHERE id=$2::uuid", [balAfter, t.id]).catch(()=>{});
        await query(`INSERT INTO notifications (isp_id, type, title, message) VALUES ($1::uuid,'success','SMS Credited',$2)`,
          [t.isp_id, t.sms_count + ' SMS added to your balance. New balance: ' + (balAfter!=null?balAfter:'-') + ' SMS.']).catch(()=>{});
      }
    } else if (cb) {
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid", [(cb.ResultDesc||'Cancelled').substring(0,240), paymentId]).catch(()=>{});
      await query("UPDATE sms_credit_transactions SET status='failed' WHERE payment_id=$1::uuid AND status='pending'", [paymentId]).catch(()=>{});
    }
  } catch (e) { require('../utils/logger').error('sms topup callback: ' + e.message); }
  res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
});

// GET /api/isp/sms/topup/status/:paymentId — poll for the modal
router.get('/sms/topup/status/:paymentId', async (req, res, next) => {
  try {
    const r = await query("SELECT p.status, t.sms_count, t.isp_balance_after FROM payments p LEFT JOIN sms_credit_transactions t ON t.payment_id=p.id WHERE p.id=$1::uuid AND p.isp_id=$2::uuid", [req.params.paymentId, req.user.ispId]);
    if (!r.rows[0]) return res.status(404).json({ error: 'not found' });
    res.json(r.rows[0]);
  } catch (err) { next(err); }
});

// GET /api/isp/sms/purchases — the ISP's SMS purchase/expense + consumption ledger
router.get('/sms/purchases', async (req, res, next) => {
  try {
    const ispId = req.user.ispId;
    const rows = await query(`
      SELECT id, txn_type, sms_count, unit_price, amount_paid, isp_balance_after, status, note, created_at
        FROM sms_credit_transactions
       WHERE isp_id = $1::uuid
       ORDER BY created_at DESC LIMIT 200`, [ispId]);
    const sums = await query(`
      SELECT
        COALESCE(SUM(CASE WHEN txn_type='purchase' AND status='completed' THEN sms_count END),0) AS total_purchased,
        COALESCE(SUM(CASE WHEN txn_type='purchase' AND status='completed' THEN amount_paid END),0) AS total_spent,
        COALESCE(SUM(CASE WHEN txn_type='signup_bonus' AND status='completed' THEN sms_count END),0) AS total_bonus,
        COALESCE(-SUM(CASE WHEN txn_type='consumption' THEN sms_count END),0) AS total_consumed
        FROM sms_credit_transactions WHERE isp_id=$1::uuid`, [ispId]);
    const bal = await query("SELECT sms_balance FROM isps WHERE id=$1::uuid", [ispId]);
    res.json({
      transactions: rows.rows,
      summary: sums.rows[0],
      balance: bal.rows[0] ? parseFloat(bal.rows[0].sms_balance) : 0
    });
  } catch (err) { next(err); }
});

// ============================================================
// SMS RECIPIENTS — groups, list resolution, search (for the composer)
// ============================================================

// GET /api/isp/sms/recipients/groups — recipient groups with counts
router.get('/sms/recipients/groups', async (req, res, next) => {
  try {
    const ispId = req.user.ispId;
    const q = async (sql) => { const r = await query(sql, [ispId]); return parseInt(r.rows[0].c) || 0; };
    const [pppoeAll, pppoeActive, voucherBuyers, pppoeActiveSess, hsActiveSess] = await Promise.all([
      q("SELECT COUNT(*) c FROM pppoe_subscribers WHERE isp_id=$1::uuid AND phone IS NOT NULL AND phone<>''"),
      q("SELECT COUNT(*) c FROM pppoe_subscribers WHERE isp_id=$1::uuid AND status='active' AND phone IS NOT NULL AND phone<>''"),
      q("SELECT COUNT(DISTINCT buyer_phone) c FROM hotspot_vouchers WHERE isp_id=$1::uuid AND buyer_phone IS NOT NULL AND buyer_phone<>''"),
      q("SELECT COUNT(DISTINCT s.subscriber_id) c FROM pppoe_sessions s JOIN pppoe_subscribers p ON p.id=s.subscriber_id WHERE s.isp_id=$1::uuid AND s.status='active' AND p.phone IS NOT NULL AND p.phone<>''"),
      q("SELECT COUNT(DISTINCT v.buyer_phone) c FROM hotspot_sessions hs JOIN hotspot_vouchers v ON v.id=hs.voucher_id WHERE hs.isp_id=$1::uuid AND hs.status='active' AND v.buyer_phone IS NOT NULL AND v.buyer_phone<>''")
    ]);
    const groups = [
      { key:'pppoe_active',   label:'Active PPPoE subscribers',    count: pppoeActive },
      { key:'pppoe_all',      label:'All PPPoE subscribers',       count: pppoeAll },
      { key:'voucher_buyers', label:'Hotspot voucher buyers',      count: voucherBuyers },
      { key:'pppoe_sessions', label:'Active PPPoE sessions (online)', count: pppoeActiveSess },
      { key:'hotspot_sessions', label:'Active hotspot sessions (online)', count: hsActiveSess },
      { key:'all',            label:'Everyone (PPPoE + voucher buyers)', count: 0 }
    ];
    res.json({ groups });
  } catch (err) { next(err); }
});

// GET /api/isp/sms/recipients/list?group=KEY — resolve a group to phone numbers
router.get('/sms/recipients/list', async (req, res, next) => {
  try {
    const ispId = req.user.ispId;
    const group = String(req.query.group || '');
    let sql;
    switch (group) {
      case 'pppoe_active':
        sql = "SELECT DISTINCT phone, username AS label FROM pppoe_subscribers WHERE isp_id=$1::uuid AND status='active' AND phone IS NOT NULL AND phone<>''"; break;
      case 'pppoe_all':
        sql = "SELECT DISTINCT phone, username AS label FROM pppoe_subscribers WHERE isp_id=$1::uuid AND phone IS NOT NULL AND phone<>''"; break;
      case 'voucher_buyers':
        sql = "SELECT DISTINCT buyer_phone AS phone, code AS label FROM hotspot_vouchers WHERE isp_id=$1::uuid AND buyer_phone IS NOT NULL AND buyer_phone<>''"; break;
      case 'pppoe_sessions':
        sql = "SELECT DISTINCT p.phone, p.username AS label FROM pppoe_sessions s JOIN pppoe_subscribers p ON p.id=s.subscriber_id WHERE s.isp_id=$1::uuid AND s.status='active' AND p.phone IS NOT NULL AND p.phone<>''"; break;
      case 'hotspot_sessions':
        sql = "SELECT DISTINCT v.buyer_phone AS phone, v.code AS label FROM hotspot_sessions hs JOIN hotspot_vouchers v ON v.id=hs.voucher_id WHERE hs.isp_id=$1::uuid AND hs.status='active' AND v.buyer_phone IS NOT NULL AND v.buyer_phone<>''"; break;
      case 'all':
        sql = `SELECT phone, label FROM (
                 SELECT phone, username AS label FROM pppoe_subscribers WHERE isp_id=$1::uuid AND phone IS NOT NULL AND phone<>''
                 UNION
                 SELECT buyer_phone AS phone, code AS label FROM hotspot_vouchers WHERE isp_id=$1::uuid AND buyer_phone IS NOT NULL AND buyer_phone<>''
               ) u`; break;
      default:
        return res.status(400).json({ error: 'Unknown group' });
    }
    const r = await query(sql, [ispId]);
    res.json({ recipients: r.rows, count: r.rows.length });
  } catch (err) { next(err); }
});

// GET /api/isp/sms/recipients/search?q=... — search by phone, username, or name
router.get('/sms/recipients/search', async (req, res, next) => {
  try {
    const ispId = req.user.ispId;
    const qstr = String(req.query.q || '').trim();
    if (qstr.length < 2) return res.json({ results: [] });
    const like = '%' + qstr + '%';
    const r = await query(`
      SELECT phone, label, kind FROM (
        SELECT phone, username AS label, 'PPPoE' AS kind
          FROM pppoe_subscribers
         WHERE isp_id=$1::uuid AND phone IS NOT NULL AND phone<>''
           AND (phone ILIKE $2 OR username ILIKE $2 OR full_name ILIKE $2)
        UNION
        SELECT buyer_phone AS phone, code AS label, 'Voucher' AS kind
          FROM hotspot_vouchers
         WHERE isp_id=$1::uuid AND buyer_phone IS NOT NULL AND buyer_phone<>''
           AND (buyer_phone ILIKE $2 OR code ILIKE $2)
      ) u LIMIT 15`, [ispId, like]);
    res.json({ results: r.rows });
  } catch (err) { next(err); }
});


// RUMALINK_AS_USAGE_CARDS: today's data usage split by service type (hotspot vs pppoe).
// Exact, from usage_daily (Africa/Nairobi day). pppoe = usernames in pppoe_subscribers.
router.get('/usage/today-split', async (req, res, next) => {
  const ispId = req.user.ispId;
  try {
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate');
    const r = await query(`
      SELECT
        COALESCE(SUM(u.bytes_in + u.bytes_out) FILTER (WHERE ps.username IS NOT NULL), 0)::bigint AS pppoe_bytes,
        COALESCE(SUM(u.bytes_in + u.bytes_out) FILTER (WHERE ps.username IS NULL), 0)::bigint     AS hotspot_bytes,
        COALESCE(SUM(u.bytes_in + u.bytes_out), 0)::bigint                                        AS total_bytes
      FROM usage_daily u
      LEFT JOIN pppoe_subscribers ps
        ON ps.username = u.username AND ps.isp_id = $1::uuid
      WHERE u.isp_id = $1::uuid
        AND u.usage_day = (now() AT TIME ZONE 'Africa/Nairobi')::date`, [ispId]);
    const row = r.rows[0] || {};
    res.json({
      hotspot_bytes: parseInt(row.hotspot_bytes) || 0,
      pppoe_bytes:   parseInt(row.pppoe_bytes)   || 0,
      total_bytes:   parseInt(row.total_bytes)   || 0
    });
  } catch (err) { next(err); }
});



// RL_USER_EXPORT: CSV of users. scope=all|active|pppoe|hotspot
router.get('/:ispId/users/export', async (req, res) => {
  try {
    const { ispId } = req.params;
    const scope = String(req.query.scope || 'all');
    const rows = [];
    if (scope !== 'pppoe') {
      const act = (scope === 'active') ? " AND v.status='active' AND v.expires_at > NOW()" : "";
      const r = await query(
        "SELECT v.code, v.buyer_phone, hp.name AS pkg, v.expires_at, v.status FROM hotspot_vouchers v " +
        "LEFT JOIN hotspot_packages hp ON hp.id=v.package_id WHERE v.isp_id=$1::uuid AND (v.is_tv IS NOT TRUE OR v.is_tv IS NULL)" + act + " ORDER BY v.created_at", [ispId]);
      for (const x of r.rows) rows.push(['hotspot', x.code, x.buyer_phone||'', '', x.pkg||'', x.expires_at?new Date(x.expires_at).toISOString():'', x.status||'']);
    }
    if (scope === 'pppoe' || scope === 'all' || scope === 'active') {
      const act = (scope === 'active') ? " AND status='active' AND next_billing_date > NOW()" : "";
      const r = await query("SELECT username, phone, full_name, next_billing_date, status FROM pppoe_subscribers WHERE isp_id=$1::uuid" + act + " ORDER BY created_at", [ispId]).catch(()=>({rows:[]}));
      for (const x of r.rows) rows.push(['pppoe', x.username, x.phone||'', x.full_name||'', '', x.next_billing_date?new Date(x.next_billing_date).toISOString():'', x.status||'']);
    }
    const csv = 'type,identifier,phone,name,package_name,expires_at,status\n' +
      rows.map(r => r.map(c => '"' + String(c).replace(/"/g,'""') + '"').join(',')).join('\n');
    res.setHeader('Content-Type','text/csv');
    res.setHeader('Content-Disposition','attachment; filename="rumalink-users-' + scope + '.csv"');
    res.send(csv);
  } catch (e) { res.status(500).json({ ok:false, error: e.message }); }
});

// RL_USER_IMPORT: robust to legacy data. Unmatched/empty package -> default package (never null).
router.post('/:ispId/users/import', async (req, res) => {
  try {
    const { ispId } = req.params;
    const rows = Array.isArray(req.body.rows) ? req.body.rows : [];
    /* RL_IMPORT_PREFIX: was hardcoded 'K'. Codes must carry the ISP's own initial
       (Rumalink -> R1, R2...). The max-number lookup below also searched the ^K[0-9]+$ series,
       so for any ISP not starting with K it counted from an unrelated sequence. */
    const _pfxRow = await query("SELECT company_name FROM isps WHERE id=$1::uuid", [ispId]);
    const _pfx = (String((_pfxRow.rows[0] && _pfxRow.rows[0].company_name) || 'X').trim().match(/[A-Za-z]/) || ['X'])[0].toUpperCase();
    const kre = '^' + _pfx + '[0-9]+' + String.fromCharCode(36);
    const mk = await query("SELECT COALESCE(MAX((substring(code from 2))::int),0) AS m FROM hotspot_vouchers WHERE isp_id=$1::uuid AND code ~ '" + kre + "'", [ispId]);
    let nextK = Number(mk.rows[0].m || 0) + 1;
    const importBatch = 'imp_' + Date.now(); /* RL_IMPORT_BATCH */
    // package matcher: exact -> normalized -> default(cheapest)
    const pkgs = (await query("SELECT id, name, price FROM hotspot_packages WHERE isp_id=$1::uuid ORDER BY price ASC", [ispId])).rows;
    if (!pkgs.length) return res.status(400).json({ ok:false, error:'No hotspot packages defined for this ISP — create at least one before importing.' });
    const norm = (x) => String(x||'').toLowerCase().replace(/[^a-z0-9]/g,'');
    const byNorm = {}; pkgs.forEach(p => { byNorm[norm(p.name)] = p.id; });
    const _find=(arr,rx)=>{ const m=arr.find(p=>rx.test(String(p.name||''))); return m?m.id:null; };
    const defaultPkg = _find(pkgs,/1\s*hour/i) || pkgs[0].id; /* RL_DEFAULT_BYNAME: hotspot -> 1 Hour */
    const ppkgs = (await query("SELECT id, name FROM pppoe_packages WHERE isp_id=$1::uuid ORDER BY created_at ASC", [ispId]).catch(()=>({rows:[]}))).rows;
    const ppByNorm = {}; ppkgs.forEach(p => { ppByNorm[norm(p.name)] = p.id; });
    const defaultPppoe = ppkgs.length ? ((ppkgs.find(p=>/5\s*mbps/i.test(String(p.name||'')))||ppkgs[0]).id) : null; /* RL_DEFAULT_BYNAME: pppoe -> 5Mbps */
    const matchPkg = (name) => { const n = norm(name); return byNorm[n] || defaultPkg; };
    const out = { hotspot: 0, pppoe: 0, skipped: 0, errors: [] };
    let syncFn = null;
    try { syncFn = require('./captive').syncRadiusForVoucher; } catch(e){ try { syncFn = require('../routes/captive').syncRadiusForVoucher; } catch(e2){} }
    for (const r of rows.slice(0, 3000)) {
      try {
        const t = String(r.type||'hotspot').toLowerCase();
        if (t === 'hotspot') {
          const pkgId = matchPkg(r.package_name);
          const code = _pfx + nextK; /* RL_IMPORT_PREFIX */
          const pass = Math.random().toString(16).slice(2, 8);
          const st = (String(r.status||'').toLowerCase().indexOf('activ')===0) ? 'active' : 'unused';
          const ins = await query(
            "INSERT INTO hotspot_vouchers (isp_id, package_id, code, status, buyer_phone, expires_at, is_tv, created_by_isp, import_batch) " +
            "VALUES ($1::uuid,$2::uuid,$3,$4::voucher_status,$5,$6::timestamptz,false,true,$7) RETURNING id", /* RL_IMPORT_FLAG RL_IMPORT_BATCH */
            [ispId, pkgId, code, st, String(r.phone||'').replace(/[^0-9]/g,'') || null, (r.expires_at && String(r.expires_at).trim()) ? String(r.expires_at).trim() : null, importBatch]);
          out.hotspot++; nextK++;
          if (syncFn && ins.rows[0]) { try { await syncFn(ins.rows[0].id); } catch(e){} }
        } else if (t === 'pppoe') {
          if (!defaultPppoe) { out.errors.push((r.identifier||'?') + ': no PPPoE package defined to assign'); continue; }
          const ppkgId = ppByNorm[norm(r.package_name)] || defaultPppoe;
          const uname = String(r.identifier||'').trim();
          if (!uname) { out.skipped++; continue; }
          await query(
            "INSERT INTO pppoe_subscribers (isp_id, package_id, username, password_hash, full_name, phone, status, next_billing_date, import_batch) " +
            "VALUES ($1::uuid,$2::uuid,$3,$4,$5,$6,$7,$8,$9) ON CONFLICT DO NOTHING",
            [ispId, ppkgId, uname, 'CHANGE_ME_' + Math.random().toString(16).slice(2,8), (r.name||uname), String(r.phone||'')||null, (String(r.status||'').toLowerCase().indexOf('activ')===0?'active':'inactive'), r.expires_at||null, importBatch]);
          out.pppoe++;
        } else out.skipped++;
      } catch (e) { out.errors.push((r.identifier||'?') + ': ' + e.message); }
    }
    res.json({ ok: true, ...out, next_code: _pfx + nextK /* RL_IMPORT_PREFIX */, import_batch: importBatch }); /* RL_IMPORT_BATCH */
  } catch (e) { res.status(500).json({ ok:false, error: e.message }); }
});

// RL_IMPORT_BATCH: undo an import batch (defaults to the most recent).
router.post('/:ispId/users/import/undo', async (req, res) => {
  try {
    const { ispId } = req.params;
    let batch = req.body && req.body.batch;
    if (!batch) {
      const b = await query("SELECT import_batch FROM (SELECT import_batch, MAX(created_at) mc FROM hotspot_vouchers WHERE isp_id=$1::uuid AND import_batch IS NOT NULL GROUP BY import_batch UNION ALL SELECT import_batch, MAX(created_at) mc FROM pppoe_subscribers WHERE isp_id=$1::uuid AND import_batch IS NOT NULL GROUP BY import_batch) x ORDER BY mc DESC LIMIT 1", [ispId]);
      batch = b.rows[0] && b.rows[0].import_batch;
    }
    if (!batch) return res.json({ ok:false, error:'No import batch to undo.' });
    const h = await query("DELETE FROM hotspot_vouchers WHERE isp_id=$1::uuid AND import_batch=$2", [ispId, batch]);
    const p = await query("DELETE FROM pppoe_subscribers WHERE isp_id=$1::uuid AND import_batch=$2", [ispId, batch]);
    res.json({ ok:true, batch, hotspot_removed: h.rowCount||0, pppoe_removed: p.rowCount||0 });
  } catch (e) { res.status(500).json({ ok:false, error: e.message }); }
});

module.exports = router;
