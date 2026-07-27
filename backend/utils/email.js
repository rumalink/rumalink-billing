// utils/email.js — RL_EMAIL_DB_CONFIG
// SMTP settings now live in email_provider_config so they can be changed from the admin
// dashboard, matching how the SMS gateway is already managed. Previously they were .env-only,
// which meant a stale placeholder password sat there failing silently for weeks — every
// welcome email was being swallowed by a try/catch and nobody could see it.
const nodemailer = require('nodemailer');
const logger = require('./logger');
const { query } = require('../config/database');

let cached = null;
let cachedAt = 0;
let transporter = null;
const TTL_MS = 60 * 1000;

function fromEnv() {
  return {
    provider: 'env',
    smtp_host: process.env.SMTP_HOST,
    smtp_port: parseInt(process.env.SMTP_PORT) || 587,
    smtp_secure: String(process.env.SMTP_SECURE) === 'true',
    smtp_user: process.env.SMTP_USER,
    smtp_pass: process.env.SMTP_PASS,
    from_email: process.env.EMAIL_FROM || 'noreply@rumalink.co.ke',
    from_name: 'RumaLink Enterprise'
  };
}

async function loadConfig(force) {
  if (!force && cached && (Date.now() - cachedAt) < TTL_MS) return cached;
  try {
    const r = await query('SELECT * FROM email_provider_config WHERE is_active = true ORDER BY id LIMIT 1');
    cached = r.rows[0] || fromEnv();
  } catch (e) {
    logger.warn('[email] config load failed, using .env: ' + e.message);
    cached = fromEnv();
  }
  cachedAt = Date.now();
  transporter = null; // rebuild on next send
  return cached;
}

function invalidate() { cached = null; cachedAt = 0; transporter = null; }

async function getTransporter(force) {
  const c = await loadConfig(force);
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: c.smtp_host,
      port: parseInt(c.smtp_port) || 587,
      secure: !!c.smtp_secure,
      auth: { user: c.smtp_user, pass: c.smtp_pass }
    });
  }
  return { t: transporter, c: c };
}

const sendEmail = async ({ to, subject, html, text }) => {
  const { t, c } = await getTransporter();
  if (!c.smtp_host || !c.smtp_pass) {
    const e = new Error('Email is not configured. Set SMTP details in Admin → Settings → Email.');
    e.code = 'EMAIL_NOT_CONFIGURED';
    throw e;
  }
  const from = (c.from_name ? c.from_name + ' <' + c.from_email + '>' : c.from_email);
  try {
    const info = await t.sendMail({ from: from, to: to, subject: subject, html: html, text: text });
    logger.info('[email] sent to ' + to + ': ' + info.messageId);
    return info;
  } catch (err) {
    logger.error('[email] send failed to ' + to + ': ' + err.message);
    throw err;
  }
};

// Verify credentials without sending — used by the admin "Test connection" button.
const verifyConnection = async () => {
  const { t, c } = await getTransporter(true);
  if (!c.smtp_host) throw new Error('No SMTP host configured');
  await t.verify();
  return { ok: true, host: c.smtp_host, port: c.smtp_port, from: c.from_email };
};

module.exports = { sendEmail, verifyConnection, invalidate, loadConfig };
