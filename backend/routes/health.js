const express = require('express');
const router = express.Router();
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const { query } = require('../config/database');
const hm = require('../utils/health-monitor');
router.use(authenticateToken, requireAdmin);
router.get('/', async (req, res, next) => {
  try {
    const cur = await hm.sample();
    const alerts = await query('SELECT metric, severity, value, threshold, message, opened_at FROM system_health_alerts WHERE closed_at IS NULL ORDER BY opened_at DESC');
    const hist = await query(`SELECT sampled_at, load1, cpu_steal, mem_avail_mb, swap_used_mb, disk_pct, freeradius_mb, node_mb, pg_conns, routers_down, status
      FROM system_health WHERE sampled_at > now() - interval '24 hours' ORDER BY sampled_at ASC`);
    const status = alerts.rows.some(a=>a.severity==='critical') ? 'critical' : (alerts.rows.length ? 'warning' : 'ok');
    res.json({ status, current: cur, thresholds: hm.THRESHOLDS, alerts: alerts.rows, history: hist.rows });
  } catch (err) { next(err); }
});
module.exports = router;
