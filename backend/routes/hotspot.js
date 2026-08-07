/* RL_MANUAL_USER_FLAG: a voucher with no payment is refused at login unless
   created_by_isp is set (captive.js:1454). The import path set it; creating a single
   user did not, so hand-made accounts were told 'Voucher has no payment'. */
const express = require('express');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');

const router = express.Router();
router.use(authenticateToken, requireISP);

// Packages CRUD
router.get('/packages', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT hp.*, COUNT(hv.id) as voucher_count,
              COUNT(hv.id) FILTER (WHERE hv.status = 'unused') as available_vouchers
       FROM hotspot_packages hp
       LEFT JOIN hotspot_vouchers hv ON hv.package_id = hp.id
       WHERE hp.isp_id = $1 GROUP BY hp.id ORDER BY hp.price ASC`,
      [req.user.ispId]
    );
    res.json({ packages: result.rows });
  } catch (err) { next(err); }
});

router.post('/packages', async (req, res, next) => {
  const { name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile, nas_id, visible_in_portal } = req.body;
  if (!name || !price) return res.status(400).json({ error: 'Name and price are required' });
  try {
    const result = await query(`
      INSERT INTO hotspot_packages (isp_id, nas_id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile, visible_in_portal)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11, $12)
      RETURNING *
    `, [req.user.ispId, nas_id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions || 1, mikrotik_profile,
       /* RL_VISIBLE_PARAM: $12 had no value, so every save failed with a bind mismatch.
          Default true — a package is offered unless the ISP says otherwise. */
       (visible_in_portal === false ? false : true)]);
    res.status(201).json({ package: result.rows[0] });
  } catch (err) { next(err); }
});

router.put('/packages/:id', async (req, res, next) => {
  const { name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile, is_active, visible_in_portal } = req.body;
  try {
    const result = await query(`
      UPDATE hotspot_packages SET name=$1, description=$2, price=$3, duration_hours=$4,
        bandwidth_down_mbps=$5, bandwidth_up_mbps=$6, data_limit_mb=$7,
        simultaneous_sessions=$8, mikrotik_profile=$9, is_active=$10,
        /* RL_VISIBLE_EDIT: COALESCE so an edit that omits the flag leaves it as it was, rather
           than silently republishing a hidden package. */
        visible_in_portal=COALESCE($13, visible_in_portal), updated_at=NOW()
      WHERE id=$11 AND isp_id=$12 RETURNING *
    `, [name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile, is_active, req.params.id, req.user.ispId, (visible_in_portal === undefined ? null : !!visible_in_portal)]);
    if (!result.rows[0]) return res.status(404).json({ error: 'Package not found' });
    /* RL_PKG_LIMIT_PROPAGATE: changing a package's device count must reach the vouchers already
       issued from it. The limit lives in radcheck, so this is a database update — nothing is
       pushed to the router, which is the point of keeping shared-users permissive. */
    try {
      await query("UPDATE radcheck rc SET value = COALESCE(hp.simultaneous_sessions,1)::text " +
        "FROM hotspot_vouchers hv JOIN hotspot_packages hp ON hp.id = hv.package_id " +
        "WHERE rc.attribute='Simultaneous-Use' AND hv.status='active' AND hp.id = $1::uuid " +
        "AND rc.username = hv.code || '@' || lower(left(replace(hv.isp_id::text,'-',''),8))", [req.params.id]);
    } catch (e) { require('../utils/logger').warn('[packages] limit propagate: ' + e.message); }
    res.json({ package: result.rows[0] });
  } catch (err) { next(err); }
});

router.delete('/packages/:id', async (req, res, next) => {
  try {
    await query('DELETE FROM hotspot_packages WHERE id = $1 AND isp_id = $2', [req.params.id, req.user.ispId]);
    res.json({ message: 'Package deleted' });
  } catch (err) { next(err); }
});

// Active hotspot sessions
router.get('/sessions', async (req, res, next) => {
  try {
    // Query routers DIRECTLY via REST (no dependency on hotspot_sessions table)
    const nasList = await query(
      `SELECT id, name, wireguard_ip FROM nas_devices
       WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL`,
      [req.user.ispId]
    );

    const mt = require('../utils/mikrotik');
    let sessions = [];

    for (const nas of nasList.rows) {
      try {
        const routerSessions = await mt.liveHotspotSessions(nas.id);
        for (const s of routerSessions) {
          let voucherInfo = {};
          try {
            const vRes = await query(
              `SELECT v.id as voucher_id, v.buyer_phone, v.expires_at, hp.name as package_name, hp.price as package_price
               FROM hotspot_vouchers v
               LEFT JOIN hotspot_packages hp ON hp.id = v.package_id
               WHERE v.isp_id = $1::uuid AND UPPER(v.code) = UPPER($2) LIMIT 1`,
              [req.user.ispId, s.user]
            );
            if (vRes.rows[0]) voucherInfo = vRes.rows[0];
          } catch(e) {}
          sessions.push({
            id: s.id,
            mac_address: s.mac_address,
            ip_address: s.address,
            voucher_code: s.user,
            voucher_id: voucherInfo.voucher_id || null,
            buyer_phone: voucherInfo.buyer_phone || null,
            package_name: voucherInfo.package_name || null,
            package_price: voucherInfo.package_price || null,
            expires_at: voucherInfo.expires_at || null,
            device_name: nas.name,
            mikrotik_identity: nas.name,
            uptime: s.uptime,
            bytes_in: s.bytes_in,
            bytes_out: s.bytes_out,
            started_at: null,
            status: 'active',
            source: 'router'
          });
        }
      } catch (e) {
        require('../utils/logger').warn(`Live sessions fetch failed for ${nas.name}: ${e.message}`);
      }
    }

    require('../utils/logger').info(`[HS-SESSIONS] Returning ${sessions.length} session(s) for ISP ${req.user.ispId}`);
    res.json({ sessions });
  } catch (err) {
    require('../utils/logger').error(`[HS-SESSIONS] Route error: ${err.message}`);
    next(err);
  }
});

// Hotspot login page data (public - for captive portal)
router.get('/portal/:isp_id', async (req, res, next) => {
  try {
    const isp = await query(
      'SELECT company_name, logo_url FROM isps WHERE id = $1 AND status = $2',
      [req.params.isp_id, 'active']
    );
    if (!isp.rows[0]) return res.status(404).json({ error: 'ISP not found' });

    const packages = await query(
      `SELECT id, name, description, price, duration_hours, bandwidth_down_mbps, data_limit_mb, visible_in_portal /* RL_PKG_VISIBLE_FIELD: the ISP sees hidden packages; customers do not */
       FROM hotspot_packages WHERE isp_id = $1 AND is_active = true ORDER BY price ASC`,
      [req.params.isp_id]
    );

    res.json({ isp: isp.rows[0], packages: packages.rows });
  } catch (err) { next(err); }
});

// Validate voucher (for captive portal)
router.post('/portal/:isp_id/validate', async (req, res, next) => {
  const { code, mac } = req.body;
  try {
    const voucher = await query(`
      SELECT hv.*, hp.name as package_name, hp.duration_hours, hp.bandwidth_down_mbps, hp.bandwidth_up_mbps, hp.data_limit_mb, hp.mikrotik_profile
      FROM hotspot_vouchers hv
      JOIN hotspot_packages hp ON hp.id = hv.package_id
      WHERE hv.code = $1 AND hv.isp_id = $2 AND hv.status IN ('unused', 'active')
    `, [code, req.params.isp_id]);

    if (!voucher.rows[0]) {
      return res.status(404).json({ error: 'Invalid or expired voucher code' });
    }

    const v = voucher.rows[0];

    // Activate if unused
    if (v.status === 'unused') {
      const expiresAt = v.duration_hours
        ? new Date(Date.now() + v.duration_hours * 3600000)
        : null;

      await query(`
        UPDATE hotspot_vouchers SET status='active', used_by_mac=$1, used_at=NOW(), expires_at=$2 WHERE id=$3
      `, [mac, expiresAt, v.id]);

      // Create session
      await query(`
        INSERT INTO hotspot_sessions (isp_id, voucher_id, nas_id, mac_address, status)
        VALUES ($1, $2, $3, $4, 'active')
      `, [v.isp_id, v.id, v.nas_id, mac]);
    }

    res.json({
      valid: true,
      username: v.code,
      password: v.code,
      profile: v.mikrotik_profile,
      expires_at: v.expires_at,
      bandwidth_down: v.bandwidth_down_mbps,
      bandwidth_up: v.bandwidth_up_mbps
    });
  } catch (err) { next(err); }
});

module.exports = router;
