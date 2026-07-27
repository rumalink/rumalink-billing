// routes/verification.js — RL_VERIFICATION endpoints (ISP email link + phone OTP)
// Mounted BEFORE /api/isp so it does not inherit requireISP — otherwise the verification gate
// would block the very endpoints an unverified ISP needs in order to become verified.
const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const { authenticateToken } = require('../middleware/auth');
const v = require('../utils/verification');
const logger = require('../utils/logger');

/* ── PUBLIC ────────────────────────────────────────────────────────────────
   Declared ABOVE router.use(authenticateToken) on purpose: Express applies middleware only to
   routes defined after it. People routinely open the verification email on a different device
   from the one they signed up on, where no session exists — requiring a token here would make
   the link fail exactly when it is most likely to be clicked. The link itself is the credential:
   single use, 24h, and 128 bits of verifier that is only ever stored hashed. */
router.post('/email-link', async (req, res) => {
  try {
    const t = (req.body && req.body.token) || '';
    if (!t) return res.status(400).json({ ok: false, error: 'Missing token' });
    const out = await v.confirmEmailLink(t);
    if (!out.ok) return res.status(400).json(out);
    res.json(out);
  } catch (e) { logger.error('[verification] email-link: ' + e.message); res.status(500).json({ ok: false, error: 'Server error' }); }
});

/* ── AUTHENTICATED BELOW ─────────────────────────────────────────────────── */
router.use(authenticateToken);
router.use(function (req, res, next) {
  if (!req.user || req.user.type !== 'isp') return res.status(403).json({ error: 'ISP access required' });
  next();
});
function ispIdOf(req) { return (req.user && (req.user.ispId || req.user.isp_id)) || null; }

router.get('/status', async (req, res) => {
  try {
    const st = await v.getStatus(ispIdOf(req));
    if (!st) return res.status(404).json({ error: 'ISP not found' });
    res.json({ ok: true, ...st });
  } catch (e) { logger.error('[verification] status: ' + e.message); res.status(500).json({ error: 'Server error' }); }
});

router.post('/send', async (req, res) => {
  try {
    const id = ispIdOf(req);
    const channel = String((req.body && req.body.channel) || '').toLowerCase();
    if (channel !== 'phone' && channel !== 'email') return res.status(400).json({ error: 'channel must be phone or email' });
    const r = await query('SELECT email, phone, COALESCE(email_verified,false) AS ev, COALESCE(phone_verified,false) AS pv FROM isps WHERE id=$1::uuid', [id]);
    const isp = r.rows[0];
    if (!isp) return res.status(404).json({ error: 'ISP not found' });
    if ((channel === 'phone' && isp.pv) || (channel === 'email' && isp.ev)) return res.json({ ok: true, already_verified: true });
    // Email is verified by link; phone by a 6-digit code.
    const out = channel === 'email'
      ? await v.issueEmailLink(id, isp.email, req.ip)
      : await v.issueCode(id, 'phone', isp.phone, req.ip);
    if (!out.ok) return res.status(429).json(out);
    res.json(out);
  } catch (e) { logger.error('[verification] send: ' + e.message); res.status(500).json({ error: 'Server error' }); }
});

router.post('/confirm', async (req, res) => {
  try {
    const id = ispIdOf(req);
    const channel = String((req.body && req.body.channel) || '').toLowerCase();
    const code = String((req.body && req.body.code) || '').trim();
    if (!code) return res.status(400).json({ error: 'code required' });
    const out = await v.confirmCode(id, channel, code);
    if (!out.ok) return res.status(400).json(out);
    res.json({ ok: true, ...(await v.getStatus(id)) });
  } catch (e) { logger.error('[verification] confirm: ' + e.message); res.status(500).json({ error: 'Server error' }); }
});

/* A typo'd address or number at signup would otherwise be a permanently dead account — every one
   of them landing in support. Correcting an UNVERIFIED channel keeps the same uniqueness rules. */
router.patch('/contact', async (req, res) => {
  try {
    const id = ispIdOf(req);
    const channel = String((req.body && req.body.channel) || '').toLowerCase();
    const value = String((req.body && req.body.value) || '').trim();
    if (channel !== 'phone' && channel !== 'email') return res.status(400).json({ error: 'channel must be phone or email' });
    if (!value) return res.status(400).json({ error: 'value required' });
    const cur = await query('SELECT COALESCE(email_verified,false) AS ev, COALESCE(phone_verified,false) AS pv FROM isps WHERE id=$1::uuid', [id]);
    if (!cur.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    if (channel === 'phone' && cur.rows[0].pv) return res.status(400).json({ error: 'Phone is already verified and cannot be changed here.' });
    if (channel === 'email' && cur.rows[0].ev) return res.status(400).json({ error: 'Email is already verified and cannot be changed here.' });
    if (channel === 'email') {
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value)) return res.status(400).json({ error: 'Enter a valid email address.' });
      const d = await query('SELECT 1 FROM isps WHERE LOWER(email)=LOWER($1) AND id<>$2::uuid LIMIT 1', [value, id]);
      if (d.rows[0]) return res.status(409).json({ error: 'That email is already registered.' });
      await query('UPDATE isps SET email=$1, updated_at=NOW() WHERE id=$2::uuid', [value.toLowerCase(), id]);
    } else {
      const norm = v.normalizePhone(value);
      if (norm.length < 12) return res.status(400).json({ error: 'Enter a valid phone number, e.g. 0712345678.' });
      const d = await query("SELECT 1 FROM isps WHERE regexp_replace(phone,'\\D','','g') = $1 AND id<>$2::uuid LIMIT 1", [norm, id]);
      if (d.rows[0]) return res.status(409).json({ error: 'That phone number is already registered.' });
      await query('UPDATE isps SET phone=$1, updated_at=NOW() WHERE id=$2::uuid', [norm, id]);
    }
    res.json({ ok: true, ...(await v.getStatus(id)) });
  } catch (e) { logger.error('[verification] contact: ' + e.message); res.status(500).json({ error: 'Server error' }); }
});

module.exports = router;
