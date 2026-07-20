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
  const { name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile, nas_id } = req.body;
  if (!name || !price) return res.status(400).json({ error: 'Name and price are required' });
  try {
    const result = await query(`
      INSERT INTO hotspot_packages (isp_id, nas_id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
      RETURNING *
    `, [req.user.ispId, nas_id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions || 1, mikrotik_profile]);
    res.status(201).json({ package: result.rows[0] });
  } catch (err) { next(err); }
});

router.put('/packages/:id', async (req, res, next) => {
  const { name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile, is_active } = req.body;
  try {
    const result = await query(`
      UPDATE hotspot_packages SET name=$1, description=$2, price=$3, duration_hours=$4,
        bandwidth_down_mbps=$5, bandwidth_up_mbps=$6, data_limit_mb=$7,
        simultaneous_sessions=$8, mikrotik_profile=$9, is_active=$10, updated_at=NOW()
      WHERE id=$11 AND isp_id=$12 RETURNING *
    `, [name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb, simultaneous_sessions, mikrotik_profile, is_active, req.params.id, req.user.ispId]);
    if (!result.rows[0]) return res.status(404).json({ error: 'Package not found' });
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
  const { status = 'active', page = 1, limit = 50 } = req.query;
  const offset = (page - 1) * limit;
  try {
    const result = await query(`
      SELECT hs.*, hv.code as voucher_code, hp.name as package_name, hp.price as package_price,
             n.name as device_name, n.mikrotik_identity
      FROM hotspot_sessions hs
      LEFT JOIN hotspot_vouchers hv ON hv.id = hs.voucher_id
      LEFT JOIN hotspot_packages hp ON hp.id = hv.package_id
      LEFT JOIN nas_devices n ON n.id = hs.nas_id
      WHERE hs.isp_id = $1 AND hs.status = $2
      ORDER BY hs.started_at DESC LIMIT $3 OFFSET $4
    `, [req.user.ispId, status, limit, offset]);
    res.json({ sessions: result.rows });
  } catch (err) { next(err); }
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
      `SELECT id, name, description, price, duration_hours, bandwidth_down_mbps, data_limit_mb
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
