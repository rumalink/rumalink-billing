const express = require('express');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');
const router = express.Router();
router.use(authenticateToken, requireISP);

router.get('/', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT * FROM notifications WHERE isp_id = $1 ORDER BY created_at DESC LIMIT 50`,
      [req.user.ispId]
    );
    res.json({ notifications: result.rows });
  } catch (err) { next(err); }
});

router.patch('/read-all', async (req, res, next) => {
  try {
    await query('UPDATE notifications SET is_read = true WHERE isp_id = $1', [req.user.ispId]);
    res.json({ message: 'All marked as read' });
  } catch (err) { next(err); }
});

router.patch('/:id/read', async (req, res, next) => {
  try {
    await query('UPDATE notifications SET is_read = true WHERE id = $1 AND isp_id = $2', [req.params.id, req.user.ispId]);
    res.json({ message: 'Marked as read' });
  } catch (err) { next(err); }
});

module.exports = router;
