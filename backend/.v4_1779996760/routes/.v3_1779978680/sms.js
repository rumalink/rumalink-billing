// sms.js
const express = require('express');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');
const { sendSMS } = require('../utils/sms');
const router = express.Router();
router.use(authenticateToken, requireISP);

router.post('/send', async (req, res, next) => {
  const { recipients, message } = req.body;
  if (!recipients || !message) return res.status(400).json({ error: 'Recipients and message required' });
  try {
    const isp = await query('SELECT sms_gateway, sms_api_key, sms_sender_id FROM isps WHERE id = $1', [req.user.ispId]);
    const results = [];
    for (const phone of (Array.isArray(recipients) ? recipients : [recipients])) {
      try {
        await sendSMS({ to: phone, message, isp: isp.rows[0] });
        results.push({ phone, status: 'sent' });
        await query(`INSERT INTO sms_logs (isp_id, recipient, message, gateway) VALUES ($1,$2,$3,$4)`,
          [req.user.ispId, phone, message, isp.rows[0]?.sms_gateway]);
      } catch (e) {
        results.push({ phone, status: 'failed', error: e.message });
      }
    }
    res.json({ results });
  } catch (err) { next(err); }
});

router.get('/logs', async (req, res, next) => {
  try {
    const result = await query('SELECT * FROM sms_logs WHERE isp_id = $1 ORDER BY sent_at DESC LIMIT 100', [req.user.ispId]);
    res.json({ logs: result.rows });
  } catch (err) { next(err); }
});

module.exports = router;

// Get list of all supported Kenya SMS gateways
router.get('/gateways', async (req, res) => {
  const { GATEWAY_LIST } = require('../utils/sms');
  res.json({ gateways: GATEWAY_LIST });
});
