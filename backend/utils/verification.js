// utils/verification.js — RL_VERIFICATION
// Phone (SMS OTP) + email verification for ISP signup.
// Security notes, because an OTP without these is decorative:
//   - codes from crypto.randomInt, never Math.random
//   - salted SHA-256 at rest, constant-time comparison
//   - short TTL, capped attempts, per-target hourly send cap. That last one is commercial as
//     well as security: each SMS costs real credits, so an open resend endpoint would let anyone
//     drain the platform balance straight from the signup form.
const crypto = require('crypto');
const { query } = require('../config/database');
const logger = require('./logger');
const tpl = require('./emailTemplate');

const CODE_TTL_MIN = 10, MAX_ATTEMPTS = 5, MAX_SENDS_PER_HOUR = 3, RESEND_COOLDOWN_SEC = 60;

function genCode() { return String(crypto.randomInt(0, 1000000)).padStart(6, '0'); }
function hashCode(code, salt) { return crypto.createHash('sha256').update(String(salt) + ':' + String(code)).digest('hex'); }
function safeEqual(a, b) {
  const ba = Buffer.from(String(a)), bb = Buffer.from(String(b));
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
}
function normalizePhone(p) {
  let d = String(p || '').replace(/[^0-9]/g, '');
  if (d.indexOf('0') === 0) d = '254' + d.slice(1);
  else if (d.indexOf('254') !== 0 && (d.indexOf('7') === 0 || d.indexOf('1') === 0)) d = '254' + d;
  return d;
}
// The SMS helper's convention is detected from arity rather than assumed: a destructured
// options object gives length 1; positional (phone, message, ispId) gives >= 2.
async function sendSmsCompat(phone, message, ispId) {
  const fn = require('./sms').sendSMS;
  if (typeof fn !== 'function') throw new Error('sendSMS unavailable');
  /* RL_SMS_ISP_ROW: sendSMS takes ({ to, message, isp }) where isp is the ISP ROW — it reads
     isp.sms_gateway and isp.id. Passing an id instead left isp undefined, so the gateway fell
     through to a default with no credentials and threw. A brand-new signup also has an empty
     sms_gateway, so force the platform gateway for verification messages. */
  const r = await query("SELECT id, sms_gateway, sms_sender_id, sms_balance FROM isps WHERE id=$1::uuid", [ispId]);
  const isp = r.rows[0] || { id: ispId };
  if (!isp.sms_gateway) isp.sms_gateway = 'rumalink';
  return await fn({ to: phone, message: message, isp: isp });
}

async function issueCode(ispId, channel, rawTarget, ip) {
  if (channel !== 'phone' && channel !== 'email') throw new Error('invalid channel');
  const target = channel === 'phone' ? normalizePhone(rawTarget) : String(rawTarget || '').trim().toLowerCase();
  if (!target) throw new Error('missing target');

  const recent = await query(
    "SELECT COUNT(*)::int AS n, MAX(created_at) AS last FROM verification_codes WHERE target=$1 AND created_at > NOW() - interval '1 hour'", [target]);
  const n = recent.rows[0] ? recent.rows[0].n : 0;
  const last = recent.rows[0] ? recent.rows[0].last : null;
  if (n >= MAX_SENDS_PER_HOUR) return { ok: false, error: 'Too many codes requested. Please wait an hour and try again.' };
  if (last && (Date.now() - new Date(last).getTime()) < RESEND_COOLDOWN_SEC * 1000) {
    const wait = Math.ceil(RESEND_COOLDOWN_SEC - (Date.now() - new Date(last).getTime()) / 1000);
    return { ok: false, error: 'Please wait ' + wait + 's before requesting another code.', retry_after_sec: wait };
  }

  const code = genCode(), salt = crypto.randomBytes(8).toString('hex');
  await query(
    "INSERT INTO verification_codes (isp_id, channel, target, code_hash, expires_at, ip) VALUES ($1::uuid,$2,$3,$4, NOW() + interval '" + CODE_TTL_MIN + " minutes', $5)",
    [ispId, channel, target, salt + '.' + hashCode(code, salt), ip || null]);

  try {
    if (channel === 'phone') {
      await sendSmsCompat(target, 'Your RumaLink verification code is ' + code + '. It expires in ' + CODE_TTL_MIN + ' minutes. Do not share it.', ispId);
    } else {
      /* RL_OTP_EMAIL_BRANDED */
      const _h = await tpl.shell({ title: 'Your verification code',
        body: '<p style="margin:0;font-size:14px;line-height:1.65;color:#c9d4ee">Use this code to verify your email address:</p>' + tpl.codeBox(code) +
              '<p style="margin:0;font-size:12px;color:#8899bb">It expires in ' + CODE_TTL_MIN + ' minutes.</p>' });
      await require('./email').sendEmail({ to: target, subject: 'Your RumaLink verification code', text: 'Your RumaLink verification code is ' + code + '.', html: _h });
    }
  } catch (e) {
    logger.error('[verification] send failed (' + channel + '): ' + e.message);
    /* RL_SEND_ERR_DETAIL: a generic message here hid a real, actionable cause (bad SMTP password,
       empty SMS balance) for far too long. Surface what the caller can actually act on. */
    if (e.code === 'SMS_BALANCE_EMPTY') return { ok: false, error: 'SMS balance is empty. Contact support to top up.' };
    if (/Invalid login|BadCredentials|535/.test(String(e.message))) return { ok: false, error: 'Email is not configured on the server yet. Contact support.' };
    return { ok: false, error: 'Could not send the code right now. Please try again shortly.' };
  }
  logger.info('[verification] code issued isp=' + ispId + ' channel=' + channel);
  return { ok: true, expires_in_sec: CODE_TTL_MIN * 60 };
}

async function confirmCode(ispId, channel, code) {
  if (channel !== 'phone' && channel !== 'email') return { ok: false, error: 'invalid channel' };
  const r = await query(
    "SELECT id, code_hash, expires_at, attempts FROM verification_codes WHERE isp_id=$1::uuid AND channel=$2 AND consumed_at IS NULL ORDER BY created_at DESC LIMIT 1",
    [ispId, channel]);
  const row = r.rows[0];
  if (!row) return { ok: false, error: 'No active code. Request a new one.' };
  if (new Date(row.expires_at) <= new Date()) return { ok: false, error: 'That code has expired. Request a new one.' };
  if (row.attempts >= MAX_ATTEMPTS) return { ok: false, error: 'Too many incorrect attempts. Request a new code.' };

  const parts = String(row.code_hash).split('.');
  if (!safeEqual(hashCode(String(code || '').trim(), parts[0]), parts[1])) {
    await query("UPDATE verification_codes SET attempts = attempts + 1 WHERE id=$1", [row.id]);
    const left = MAX_ATTEMPTS - (row.attempts + 1);
    return { ok: false, error: left > 0 ? 'Incorrect code. ' + left + ' attempt(s) left.' : 'Too many incorrect attempts. Request a new code.' };
  }
  await query("UPDATE verification_codes SET consumed_at = NOW() WHERE id=$1", [row.id]);
  if (channel === 'phone') await query("UPDATE isps SET phone_verified=true, phone_verified_at=NOW(), updated_at=NOW() WHERE id=$1::uuid", [ispId]);
  else await query("UPDATE isps SET email_verified=true, email_verified_at=NOW(), email_verify_token=NULL, updated_at=NOW() WHERE id=$1::uuid", [ispId]);
  logger.info('[verification] ' + channel + ' verified isp=' + ispId);
  return { ok: true };
}

/* RL_EMAIL_LINK: email is verified by clicking a link, not typing a code — fewer steps and it
   works when the mail is read on a different device. The token is selector.verifier: the
   selector is stored in clear so it can be looked up by index, the verifier is stored only as a
   salted hash. That way a leaked database still cannot be used to forge a working link, while a
   plain single-column token would have to be stored in clear to be searchable. */
const LINK_TTL_HOURS = 24;

async function issueEmailLink(ispId, rawEmail, ip) {
  const email = String(rawEmail || '').trim().toLowerCase();
  if (!email) throw new Error('missing email');
  const recent = await query(
    "SELECT COUNT(*)::int AS n, MAX(created_at) AS last FROM verification_codes WHERE target=$1 AND created_at > NOW() - interval '1 hour'", [email]);
  const n = recent.rows[0] ? recent.rows[0].n : 0;
  const last = recent.rows[0] ? recent.rows[0].last : null;
  if (n >= MAX_SENDS_PER_HOUR) return { ok: false, error: 'Too many emails requested. Please wait an hour and try again.' };
  if (last && (Date.now() - new Date(last).getTime()) < RESEND_COOLDOWN_SEC * 1000) {
    const wait = Math.ceil(RESEND_COOLDOWN_SEC - (Date.now() - new Date(last).getTime()) / 1000);
    return { ok: false, error: 'Please wait ' + wait + 's before requesting another email.', retry_after_sec: wait };
  }

  const selector = crypto.randomBytes(6).toString('hex');
  const verifier = crypto.randomBytes(16).toString('hex');
  const salt = crypto.randomBytes(8).toString('hex');
  await query(
    "INSERT INTO verification_codes (isp_id, channel, target, code_hash, selector, expires_at, ip) VALUES ($1::uuid,'email',$2,$3,$4, NOW() + interval '" + LINK_TTL_HOURS + " hours', $5)",
    [ispId, email, salt + '.' + hashCode(verifier, salt), selector, ip || null]);

  const base = (process.env.FRONTEND_URL || process.env.BASE_URL || 'https://rumalinkenterprise.online').replace(/\/+$/, '');
  const link = base + '/isp/verify.html?t=' + selector + '.' + verifier;

  try {
    const html = await tpl.shell({
      title: 'Confirm your email address',
      body: '<p style="margin:0 0 6px;font-size:14px;line-height:1.65;color:#c9d4ee">Welcome to RumaLink Enterprise. Confirm this address to continue setting up your ISP account.</p>' +
            tpl.button(link, 'Verify my email') +
            '<p style="margin:0;font-size:12px;line-height:1.6;color:#8899bb">The link is valid for ' + LINK_TTL_HOURS + ' hours. If the button does not work, copy this address into your browser:<br><span style="color:#00d4aa;word-break:break-all">' + link + '</span></p>' +
            '<p style="margin:16px 0 0;font-size:12px;line-height:1.6;color:#8899bb">After this you will confirm your phone number by SMS, and your dashboard unlocks.</p>',
      footer: 'If you did not create a RumaLink account you can safely ignore this email — no account is active until it is verified.'
    });
    await require('./email').sendEmail({
      to: email,
      subject: 'Confirm your email — RumaLink Enterprise',
      text: 'Confirm your email address to continue: ' + link + ' (valid for ' + LINK_TTL_HOURS + ' hours)',
      html: html
    });
  } catch (e) {
    logger.error('[verification] email link send failed: ' + e.message);
    if (e.code === 'EMAIL_NOT_CONFIGURED' || /Invalid login|535/.test(String(e.message)))
      return { ok: false, error: 'Email is not configured on the server yet. Contact support.' };
    return { ok: false, error: 'Could not send the email right now. Please try again shortly.' };
  }
  logger.info('[verification] email link issued isp=' + ispId);
  return { ok: true, expires_in_hours: LINK_TTL_HOURS };
}

/* Public: no session required, because the link is often opened on a different device. */
async function confirmEmailLink(rawToken) {
  const parts = String(rawToken || '').split('.');
  if (parts.length !== 2) return { ok: false, error: 'That link is not valid.' };
  const r = await query(
    "SELECT id, isp_id, code_hash, expires_at, consumed_at FROM verification_codes WHERE selector=$1 AND channel='email' ORDER BY created_at DESC LIMIT 1", [parts[0]]);
  const row = r.rows[0];
  if (!row) return { ok: false, error: 'That link is not valid.' };
  if (row.consumed_at) return { ok: false, error: 'That link has already been used.', already_used: true };
  if (new Date(row.expires_at) <= new Date()) return { ok: false, error: 'That link has expired. Request a new one.' };
  const h = String(row.code_hash).split('.');
  if (!safeEqual(hashCode(parts[1], h[0]), h[1])) return { ok: false, error: 'That link is not valid.' };
  await query("UPDATE verification_codes SET consumed_at = NOW() WHERE id=$1", [row.id]);
  await query("UPDATE isps SET email_verified=true, email_verified_at=NOW(), email_verify_token=NULL, updated_at=NOW() WHERE id=$1::uuid", [row.isp_id]);
  logger.info('[verification] email verified by link isp=' + row.isp_id);
  const st = await getStatus(row.isp_id);
  return { ok: true, isp_id: row.isp_id, ...st };
}

async function getStatus(ispId) {
  const r = await query(
    "SELECT email, phone, COALESCE(email_verified,false) AS email_verified, COALESCE(phone_verified,false) AS phone_verified, email_verified_at, phone_verified_at FROM isps WHERE id=$1::uuid", [ispId]);
  const x = r.rows[0];
  if (!x) return null;
  return { email: x.email, phone: x.phone, email_verified: x.email_verified, phone_verified: x.phone_verified,
           email_verified_at: x.email_verified_at, phone_verified_at: x.phone_verified_at,
           fully_verified: !!(x.email_verified && x.phone_verified) };
}

module.exports = { issueCode, confirmCode, getStatus, normalizePhone, issueEmailLink, confirmEmailLink };
