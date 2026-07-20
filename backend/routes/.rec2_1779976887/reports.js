// reports.js
const express = require('express');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');

const router = express.Router();
router.use(authenticateToken, requireISP);

router.get('/revenue', async (req, res, next) => {
  const { from, to, group_by = 'day' } = req.query;
  const dateFrom = from || new Date(Date.now() - 30 * 86400000).toISOString().split('T')[0];
  const dateTo = to || new Date().toISOString().split('T')[0];
  try {
    const result = await query(`
      SELECT 
        DATE_TRUNC($3, paid_at) as period,
        COUNT(*) as transactions,
        SUM(amount) as gross_revenue,
        SUM(commission_amount) as commission,
        SUM(net_amount) as net_revenue,
        payment_method
      FROM payments
      WHERE isp_id = $1 AND status = 'paid' AND paid_at BETWEEN $1 AND $2
      GROUP BY period, payment_method
      ORDER BY period ASC
    `, [req.user.ispId, dateFrom, dateTo, group_by]);
    res.json({ data: result.rows });
  } catch (err) { next(err); }
});

router.get('/subscribers', async (req, res, next) => {
  try {
    const result = await query(`
      SELECT 
        DATE_TRUNC('month', created_at) as month,
        COUNT(*) as new_subscribers,
        COUNT(*) FILTER (WHERE status = 'active') as active
      FROM pppoe_subscribers WHERE isp_id = $1
      GROUP BY month ORDER BY month DESC LIMIT 12
    `, [req.user.ispId]);
    res.json({ data: result.rows });
  } catch (err) { next(err); }
});

router.get('/bandwidth', async (req, res, next) => {
  try {
    const result = await query(`
      SELECT 
        DATE(started_at) as date,
        SUM(bytes_downloaded) as downloaded,
        SUM(bytes_uploaded) as uploaded,
        COUNT(*) as sessions
      FROM pppoe_sessions WHERE isp_id = $1 AND started_at >= NOW() - INTERVAL '30 days'
      GROUP BY date ORDER BY date ASC
    `, [req.user.ispId]);
    res.json({ data: result.rows });
  } catch (err) { next(err); }
});

module.exports = router;
