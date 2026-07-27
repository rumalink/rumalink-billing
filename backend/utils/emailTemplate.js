// utils/emailTemplate.js — RL_EMAIL_TEMPLATE
// A single branded shell so every transactional email looks the same and only the body changes.
// Deliberately plain HTML with inline styles and a table wrapper: Gmail, Outlook and most mobile
// clients strip <style> blocks, flexbox and CSS variables, so anything cleverer renders broken.
const { query } = require('../config/database');

async function brand() {
  try {
    const r = await query('SELECT logo_url, from_name, logo_bg FROM email_provider_config ORDER BY id LIMIT 1');
    const c = r.rows[0] || {};
    return { logo: c.logo_url || '', name: c.from_name || 'RumaLink Enterprise', bg: c.logo_bg || '#0d1530' };
  } catch (e) { return { logo: '', name: 'RumaLink Enterprise', bg: '#0d1530' }; }
}

async function shell(opts) {
  const b = await brand();
  const title = opts.title || '';
  const body = opts.body || '';
  const footer = opts.footer || 'You are receiving this because an account was created with this address on RumaLink Enterprise.';
  // Images are blocked by default in many clients, so the wordmark is real text and the logo is
  // an enhancement — the email is fully readable with images off.
  /* RL_BRAND_BANNER: the brand asset already contains the wordmark, so rendering it beside a
     typed company name duplicated the name. Show the banner alone, and fall back to text when
     images are blocked — which is the default in Gmail and Outlook for a first-time sender. */
  const logoImg = b.logo
    ? '<img src="' + b.logo + '" alt="' + b.name + '" width="230" style="display:block;margin:0 auto;border:0;max-width:230px;height:auto">'
    : '<div style="font-family:Arial,Helvetica,sans-serif;font-size:19px;font-weight:bold;color:#00d4aa;letter-spacing:.3px">' + b.name + '</div>';
  return '' +
  '<!DOCTYPE html><html><body style="margin:0;padding:0;background:#0a0f1e">' +
  '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0a0f1e;padding:28px 12px">' +
  '<tr><td align="center">' +
  '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#111d3a;border:1px solid #1e2f52;border-radius:14px;overflow:hidden">' +
  /* RL_LOGO_BG: the artwork carries its own background, so a fixed header colour framed it as a
     visible rectangle. Adopt the logo's colour and the seam disappears. */
  '<tr><td style="background:' + (b.bg || '#0d1530') + ';padding:22px 24px;text-align:center">' + logoImg + '</td></tr>' +
  '<tr><td style="padding:28px 24px;font-family:Arial,Helvetica,sans-serif;color:#f0f4ff">' +
  (title ? '<div style="font-size:17px;font-weight:bold;margin-bottom:14px">' + title + '</div>' : '') +
  body +
  '</td></tr>' +
  '<tr><td style="padding:16px 24px 24px;font-family:Arial,Helvetica,sans-serif;font-size:11px;color:#8899bb;line-height:1.6;border-top:1px solid #1e2f52">' +
  footer +
  '</td></tr>' +
  '</table></td></tr></table></body></html>';
}

function button(href, label) {
  return '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:22px auto"><tr><td style="background:#00d4aa;border-radius:8px">' +
         '<a href="' + href + '" style="display:inline-block;padding:13px 30px;font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:bold;color:#07211c;text-decoration:none">' + label + '</a>' +
         '</td></tr></table>';
}

function codeBox(code) {
  return '<div style="font-family:Arial,Helvetica,sans-serif;font-size:30px;letter-spacing:9px;font-weight:bold;text-align:center;color:#00d4aa;background:#0d1530;border:1px solid #1e2f52;border-radius:10px;padding:16px;margin:20px 0">' + code + '</div>';
}

module.exports = { shell, button, codeBox };
