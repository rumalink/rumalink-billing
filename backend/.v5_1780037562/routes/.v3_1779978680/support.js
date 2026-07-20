// support.js
const express = require('express');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');
const router = express.Router();
router.use(authenticateToken, requireISP);

router.get('/', async (req, res, next) => {
  try {
    const result = await query(
      'SELECT * FROM support_tickets WHERE isp_id = $1 ORDER BY created_at DESC',
      [req.user.ispId]
    );
    res.json({ tickets: result.rows });
  } catch (err) { next(err); }
});

router.post('/', async (req, res, next) => {
  const { subject, message, priority } = req.body;
  if (!subject || !message) return res.status(400).json({ error: 'Subject and message required' });
  try {
    const result = await query(
      `INSERT INTO support_tickets (isp_id, subject, message, priority) VALUES ($1,$2,$3,$4) RETURNING *`,
      [req.user.ispId, subject, message, priority || 'normal']
    );
    res.status(201).json({ ticket: result.rows[0] });
  } catch (err) { next(err); }
});

router.get('/:id', async (req, res, next) => {
  try {
    const ticket = await query('SELECT * FROM support_tickets WHERE id=$1 AND isp_id=$2', [req.params.id, req.user.ispId]);
    if (!ticket.rows[0]) return res.status(404).json({ error: 'Ticket not found' });
    const replies = await query('SELECT * FROM support_replies WHERE ticket_id=$1 ORDER BY created_at ASC', [req.params.id]);
    res.json({ ticket: ticket.rows[0], replies: replies.rows });
  } catch (err) { next(err); }
});

router.post('/:id/reply', async (req, res, next) => {
  const { message } = req.body;
  try {
    const result = await query(
      `INSERT INTO support_replies (ticket_id, author_type, author_id, message) VALUES ($1,'isp',$2,$3) RETURNING *`,
      [req.params.id, req.user.ispId, message]
    );
    res.status(201).json({ reply: result.rows[0] });
  } catch (err) { next(err); }
});

module.exports = router;
