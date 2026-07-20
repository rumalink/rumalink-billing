const express = require('express');
const { v4: uuidv4 } = require('uuid');
const QRCode = require('qrcode');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');

const router = express.Router();
router.use(authenticateToken, requireISP);

function generateVoucherCode(prefix = '', length = 8) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = prefix;
  for (let i = 0; i < length; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code;
}

// List vouchers
router.get('/', async (req, res, next) => {
  const { page = 1, limit = 50, status, package_id, batch_id } = req.query;
  const offset = (page - 1) * limit;
  let where = 'WHERE hv.isp_id = $1';
  const params = [req.user.ispId];
  let idx = 2;

  if (status) { where += ` AND hv.status = $${idx++}`; params.push(status); }
  if (package_id) { where += ` AND hv.package_id = $${idx++}`; params.push(package_id); }
  if (batch_id) { where += ` AND hv.batch_id = $${idx++}`; params.push(batch_id); }

  try {
    const result = await query(`
      SELECT hv.id, hv.code, hv.status, hv.used_at, hv.expires_at,
             hv.used_by_mac, hv.is_paid, hv.amount_paid, hv.batch_id,
             hp.name as package_name, hp.price, hp.duration_hours,
             n.name as device_name
      FROM hotspot_vouchers hv
      JOIN hotspot_packages hp ON hp.id = hv.package_id
      LEFT JOIN nas_devices n ON n.id = hv.nas_id
      ${where}
      ORDER BY hv.created_at DESC LIMIT $${idx} OFFSET $${idx + 1}
    `, [...params, limit, offset]);

    const count = await query(`SELECT COUNT(*) FROM hotspot_vouchers hv ${where}`, params);
    res.json({ vouchers: result.rows, total: parseInt(count.rows[0].count) });
  } catch (err) { next(err); }
});

// Generate vouchers batch
router.post('/generate', async (req, res, next) => {
  const { package_id, quantity = 1, prefix, nas_id } = req.body;
  if (!package_id) return res.status(400).json({ error: 'Package ID required' });
  if (quantity < 1 || quantity > 500) return res.status(400).json({ error: 'Quantity must be between 1 and 500' });

  try {
    const pkg = await query('SELECT * FROM hotspot_packages WHERE id = $1 AND isp_id = $2', [package_id, req.user.ispId]);
    if (!pkg.rows[0]) return res.status(404).json({ error: 'Package not found' });

    const batchId = uuidv4();

    // Create batch record
    await query('INSERT INTO voucher_batches (id, isp_id, package_id, quantity, prefix) VALUES ($1,$2,$3,$4,$5)',
      [batchId, req.user.ispId, package_id, quantity, prefix]);

    // Generate unique codes
    const vouchers = [];
    const usedCodes = new Set();

    for (let i = 0; i < quantity; i++) {
      let code;
      do {
        code = generateVoucherCode(prefix, 8);
      } while (usedCodes.has(code));
      usedCodes.add(code);
      vouchers.push([req.user.ispId, package_id, nas_id || null, code, batchId]);
    }

    // Bulk insert
    const placeholders = vouchers.map((_, i) =>
      `($${i * 5 + 1},$${i * 5 + 2},$${i * 5 + 3},$${i * 5 + 4},$${i * 5 + 5})`
    ).join(',');

    await query(
      `INSERT INTO hotspot_vouchers (isp_id, package_id, nas_id, code, batch_id) VALUES ${placeholders}`,
      vouchers.flat()
    );

    res.status(201).json({
      message: `${quantity} vouchers generated successfully`,
      batch_id: batchId,
      package: pkg.rows[0].name,
      quantity
    });
  } catch (err) { next(err); }
});

// Get batch vouchers
router.get('/batch/:batchId', async (req, res, next) => {
  try {
    const result = await query(`
      SELECT hv.code, hv.status, hv.amount_paid, hp.name as package_name, hp.price, hp.duration_hours, hp.bandwidth_down_mbps
      FROM hotspot_vouchers hv
      JOIN hotspot_packages hp ON hp.id = hv.package_id
      WHERE hv.batch_id = $1 AND hv.isp_id = $2
      ORDER BY hv.created_at ASC
    `, [req.params.batchId, req.user.ispId]);
    res.json({ vouchers: result.rows });
  } catch (err) { next(err); }
});

// Delete unused voucher
router.delete('/:id', async (req, res, next) => {
  try {
    const result = await query(
      `DELETE FROM hotspot_vouchers WHERE id=$1 AND isp_id=$2 AND status='unused' RETURNING id`,
      [req.params.id, req.user.ispId]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Voucher not found or already used' });
    res.json({ message: 'Voucher deleted' });
  } catch (err) { next(err); }
});

// Get voucher QR code
router.get('/:code/qr', async (req, res, next) => {
  try {
    const qr = await QRCode.toDataURL(req.params.code);
    res.json({ qr_code: qr, code: req.params.code });
  } catch (err) { next(err); }
});

// Batch stats
router.get('/stats/summary', async (req, res, next) => {
  try {
    const result = await query(`
      SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status = 'unused') as unused,
        COUNT(*) FILTER (WHERE status = 'active') as active,
        COUNT(*) FILTER (WHERE status = 'used') as used,
        COUNT(*) FILTER (WHERE status = 'expired') as expired,
        COALESCE(SUM(amount_paid) FILTER (WHERE is_paid = true), 0) as total_revenue
      FROM hotspot_vouchers WHERE isp_id = $1
    `, [req.user.ispId]);
    res.json(result.rows[0]);
  } catch (err) { next(err); }
});

module.exports = router;
