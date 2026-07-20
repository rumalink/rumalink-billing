// sms.js
const express = require('express');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');
const { sendSMS, GATEWAY_LIST } = require('../utils/sms');
const router = express.Router();
router.use(authenticateToken, requireISP);

router.post('/send', async (req, res, next) => {
  const { recipients, message } = req.body;
  if (!recipients || !message) return res.status(400).json({ error: 'Recipients and message required' });
  try {
    // Fetch ALL sms columns sendSMS needs (was only fetching 3)
    const isp = await query(
      `SELECT id, sms_balance, sms_gateway, sms_api_key, sms_api_secret, sms_username, sms_sender_id, sms_partner_id
       FROM isps WHERE id = $1`, [req.user.ispId]);
    const cfg = isp.rows[0] || {};
    const results = [];
    for (const phone of (Array.isArray(recipients) ? recipients : [recipients])) {
      try {
        await sendSMS({ to: phone, message, isp: cfg });
        results.push({ phone, status: 'sent' });
        await query(`INSERT INTO sms_logs (isp_id, recipient, message, gateway) VALUES ($1,$2,$3,$4)`,
          [req.user.ispId, phone, message, cfg.sms_gateway]).catch(()=>{});
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

router.get('/gateways', async (req, res) => {
  res.json({ gateways: GATEWAY_LIST || [] });
});

module.exports = router;
