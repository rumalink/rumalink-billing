// routes/adminEmail.js — RL_EMAIL_CONFIG_API
// SMTP settings managed from the admin dashboard, matching how the SMS gateway already works.
// Kept in its own file rather than appended to admin.js: the inline patch needed four levels of
// quote escaping and silently produced invalid JS, which is exactly the class of failure that
// costs hours to find later.
const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const { authenticateToken, requireAdmin } = require('../middleware/auth');

router.use(authenticateToken, requireAdmin);

// The password is deliberately never returned — the client only learns whether one is set.
// An admin session should not be a way to read the credential back out.
router.get('/', async (req, res) => {
  try {
    const r = await query(
      "SELECT id, provider, smtp_host, smtp_port, smtp_secure, smtp_user, from_email, from_name, logo_url, logo_bg, " +
      "is_active, updated_at, (smtp_pass IS NOT NULL AND smtp_pass <> '') AS has_password " +
      "FROM email_provider_config ORDER BY id LIMIT 1");
    res.json({ ok: true, config: r.rows[0] || null });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/', async (req, res) => {
  try {
    const b = req.body || {};
    const port = parseInt(b.smtp_port) || 587;
    const cur = await query('SELECT id FROM email_provider_config ORDER BY id LIMIT 1');
    if (!cur.rows[0]) {
      await query(
        "INSERT INTO email_provider_config (provider, smtp_host, smtp_port, smtp_secure, smtp_user, smtp_pass, from_email, from_name, is_active) " +
        "VALUES ($1,$2,$3,$4,$5,$6,$7,$8,true)",
        [b.provider || 'resend', b.smtp_host || null, port, !!b.smtp_secure, b.smtp_user || null,
         b.smtp_pass || null, b.from_email || null, b.from_name || 'RumaLink Enterprise']);
    } else {
      // NULLIF keeps the stored password when the field is left blank, so an admin can edit the
      // host or sender without having to re-enter (or expose) the API key.
      await query(
        "UPDATE email_provider_config SET provider=$1, smtp_host=$2, smtp_port=$3, smtp_secure=$4, " +
        "smtp_user=$5, smtp_pass=COALESCE(NULLIF($6,''), smtp_pass), from_email=$7, from_name=$8, updated_at=NOW() WHERE id=$9",
        [b.provider || 'resend', b.smtp_host || null, port, !!b.smtp_secure, b.smtp_user || null,
         b.smtp_pass || '', b.from_email || null, b.from_name || 'RumaLink Enterprise', cur.rows[0].id]);
    }
    if (b.logo_url !== undefined || b.logo_bg !== undefined) {
      await query("UPDATE email_provider_config SET logo_url=COALESCE(NULLIF($1,''), logo_url), logo_bg=COALESCE(NULLIF($2,''), logo_bg) WHERE id=(SELECT id FROM email_provider_config ORDER BY id LIMIT 1)", [b.logo_url || '', b.logo_bg || '']);
    }
    try { require('../utils/email').invalidate(); } catch (e) {}
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Verifies SMTP auth without sending; optionally sends a real test message.
router.post('/test', async (req, res) => {
  try {
    const em = require('../utils/email');
    em.invalidate();
    await em.verifyConnection();
    const to = (req.body && req.body.to) || null;
    if (to) {
      /* RL_TEST_BRANDED: this used to send bare HTML, so it proved SMTP worked but showed none of
         the branding — the one thing you actually want to eyeball before going live. Render the
         real template so the test is a true preview of what an ISP receives. */
      const tpl = require('../utils/emailTemplate');
      const html = await tpl.shell({
        title: 'Email is configured',
        body: '<p style="margin:0 0 6px;font-size:14px;line-height:1.65;color:#c9d4ee">Your RumaLink email configuration is working. This is exactly how verification and billing emails will look to your ISPs.</p>' +
              tpl.button('https://rumalinkenterprise.online', 'Open RumaLink') +
              '<p style="margin:0;font-size:12px;line-height:1.6;color:#8899bb">Sent from Admin → Settings → Email.</p>',
        footer: 'Test message from the RumaLink Enterprise admin dashboard.'
      });
      await em.sendEmail({
        to: to,
        subject: 'RumaLink email test',
        text: 'Your RumaLink email configuration is working.',
        html: html
      });
      return res.json({ ok: true, sent_to: to });
    }
    res.json({ ok: true, connection: 'verified' });
  } catch (e) { res.status(400).json({ ok: false, error: e.message }); }
});

module.exports = router;
