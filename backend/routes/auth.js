const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { body, validationResult } = require('express-validator');
const { query } = require('../config/database');
const { sendEmail } = require('../utils/email');
const { authenticateToken } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();

const generateTokens = (payload) => {
  const token = jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '1h'
  });
  const refreshToken = jwt.sign(payload, process.env.JWT_REFRESH_SECRET, {
    expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d'
  });
  return { token, refreshToken };
};

// ============================================================
// ISP REGISTRATION
// ============================================================
router.post('/isp/register', [
  body('company_name').notEmpty().trim(),
  body('owner_name').notEmpty().trim(),
  body('email').isEmail().normalizeEmail(),
  body('phone').notEmpty().trim(),
  body('password').isLength({ min: 8 }),
  body('plan_type').isIn(['hotspot', 'pppoe', 'both']),
], async (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { company_name, owner_name, email, phone, password, plan_type, county, town } = req.body;

  try {
    // Check existing — email, phone, and company name must be unique.
    const dupe = await query(
      `SELECT
         BOOL_OR(LOWER(email) = LOWER($1)) AS email_dupe,
         BOOL_OR(regexp_replace(phone, '\\D', '', 'g') = regexp_replace($2, '\\D', '', 'g')) AS phone_dupe,
         BOOL_OR(LOWER(TRIM(company_name)) = LOWER(TRIM($3))) AS company_dupe
       FROM isps`,
      [email, phone, company_name]
    );
    const d = dupe.rows[0] || {};
    if (d.email_dupe)   return res.status(409).json({ error: 'This email is already registered. Please use a different email or sign in.' });
    if (d.phone_dupe)   return res.status(409).json({ error: 'This phone number is already registered. Please use a different number.' });
    if (d.company_dupe) return res.status(409).json({ error: 'A company with this name is already registered. Please choose a different name.' });

    const password_hash = await bcrypt.hash(password, parseInt(process.env.BCRYPT_ROUNDS) || 12);
    const verify_token = uuidv4();

    /* RL_TRIAL_DAYS: trial_ends_at was left to the column default of now() + '30 days', so every
       ISP got thirty days whatever the policy said — and the length could not be changed without
       a migration. Read it from platform_settings, the same way the signup bonus just below does,
       so there is one place it lives and the admin dashboard can set it. */
    let _trialDays = 3;
    try {
      const _td = await query("SELECT value FROM platform_settings WHERE key='trial_days' LIMIT 1");
      if (_td.rows[0] && _td.rows[0].value != null) {
        const _n = parseInt(_td.rows[0].value, 10);
        if (Number.isFinite(_n) && _n >= 0) _trialDays = _n;
      }
    } catch (e) { require('../utils/logger').warn('[signup] trial_days lookup: ' + e.message); }

    const result = await query(`
      INSERT INTO isps (
        company_name, owner_name, email, phone, password_hash, plan_type,
        county, town, email_verify_token, status, trial_ends_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'active', NOW() + ($10 || ' days')::interval)
      RETURNING id, company_name, owner_name, email, plan_type, status, api_key, created_at
    `, [company_name, owner_name, email, phone, password_hash, plan_type, county, town, verify_token, String(_trialDays)]);

    const isp = result.rows[0];

    // SMS signup bonus — credit the new ISP + record in ledger (admin Allocated total rises).
    try {
      const bRes = await query("SELECT value FROM platform_settings WHERE key='sms_signup_bonus' LIMIT 1");
      const smsBonus = (bRes.rows[0] && bRes.rows[0].value != null) ? parseFloat(bRes.rows[0].value) : 50;
      if (smsBonus > 0) {
        const updB = await query("UPDATE isps SET sms_balance = sms_balance + $1 WHERE id=$2::uuid RETURNING sms_balance", [smsBonus, isp.id]);
        const afterB = updB.rows[0] ? parseFloat(updB.rows[0].sms_balance) : smsBonus;
        await query("INSERT INTO sms_credit_transactions (isp_id, txn_type, sms_count, isp_balance_after, status, note) VALUES ($1::uuid, 'signup_bonus', $2, $3, 'completed', 'Welcome bonus on signup')", [isp.id, smsBonus, afterB]);
      }
    } catch (be) { try { require('../utils/logger').error('signup SMS bonus failed: ' + be.message); } catch(_){} }

    // Send welcome email
    try {
      await sendEmail({
        to: email,
        subject: 'Welcome to RumaLink Enterprise! 🎉',
        html: `
          <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto">
            <div style="background:#1a1a2e;padding:30px;text-align:center">
              <h1 style="color:#00d4aa;margin:0">RumaLink Enterprise</h1>
            </div>
            <div style="padding:30px">
              <h2>Welcome, ${owner_name}!</h2>
              <p>Your ISP account for <strong>${company_name}</strong> has been created successfully.</p>
              <p>You have been enrolled on our <strong>${plan_type === 'hotspot' ? 'Hotspot (3% commission)' : 'PPPoE ($0.25/user/month)'}</strong> plan.</p>
              <div style="background:#f5f5f5;padding:20px;border-radius:8px;margin:20px 0">
                <p><strong>Your API Key:</strong> ${isp.api_key}</p>
              </div>
              <a href="${process.env.FRONTEND_URL}/isp/dashboard" 
                 style="display:inline-block;background:#00d4aa;color:#fff;padding:12px 30px;border-radius:6px;text-decoration:none">
                Access Your Dashboard →
              </a>
            </div>
          </div>
        `
      });
    } catch (emailErr) {
      logger.error('Welcome email failed:', emailErr.message);
    }

    // Notify admin
    const io = req.app.get('io');
    io.to('admin').emit('new_isp', { isp });

    // Create notification for admin
    await query(`
      INSERT INTO notifications (type, title, message)
      VALUES ('info', 'New ISP Registered', $1)
    `, [`${company_name} has registered on the platform (${plan_type} plan)`]);

    const { token, refreshToken } = generateTokens({
      ispId: isp.id,
      email: isp.email,
      type: 'isp',
      plan: isp.plan_type
    });

    /* RL_SIGNUP_VERIFY: the email code sends automatically (free). The SMS code is sent on
       request from the verification screen, because every SMS costs real credits and an
       auto-send here would let a bot drain the platform balance from the signup form. */
    try { await require('../utils/verification').issueEmailLink(isp.id, email, req.ip); } catch (e) { logger.error('signup email link: ' + e.message); }
    res.status(201).json({
      message: 'Registration successful. Verify your email and phone to continue.',
      verification_required: ['phone','email'],
      isp: {
        id: isp.id,
        company_name: isp.company_name,
        owner_name: isp.owner_name,
        email: isp.email,
        plan_type: isp.plan_type,
        status: isp.status,
        api_key: isp.api_key
      },
      token,
      refreshToken
    });
  } catch (err) {
    next(err);
  }
});

// ============================================================
// ISP LOGIN
// ============================================================
router.post('/isp/login', [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty(),
], async (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { email, password } = req.body;

  try {
    const result = await query(
      'SELECT * FROM isps WHERE email = $1',
      [email]
    );
    const isp = result.rows[0];

    if (!isp || !(await bcrypt.compare(password, isp.password_hash))) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    if (isp.status === 'suspended') {
      return res.status(403).json({ error: 'Account suspended. Contact support at support@rumalink.co.ke' });
    }

    await query('UPDATE isps SET last_login = NOW() WHERE id = $1', [isp.id]);

    const { token, refreshToken } = generateTokens({
      ispId: isp.id,
      email: isp.email,
      type: 'isp',
      plan: isp.plan_type
    });

    /* RL_LOGIN_VERIFY: the token is still issued so the client can reach /api/isp/verify/*,
       but requireISP blocks everything else until both channels are verified. */
    const _miss = [];
    if (!isp.phone_verified) _miss.push('phone');
    if (!isp.email_verified) _miss.push('email');
    res.json({
      token,
      refreshToken,
      verification_required: _miss.length ? _miss : null,
      isp: {
        id: isp.id,
        company_name: isp.company_name,
        owner_name: isp.owner_name,
        email: isp.email,
        phone: isp.phone,
        plan_type: isp.plan_type,
        status: isp.status,
        api_key: isp.api_key,
        wallet_balance: isp.wallet_balance,
        logo_url: isp.logo_url,
        trial_ends_at: isp.trial_ends_at
      }
    });
  } catch (err) {
    next(err);
  }
});

// ============================================================
// ADMIN LOGIN
// ============================================================
router.post('/admin/login', [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty(),
], async (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { email, password } = req.body;

  try {
    const result = await query('SELECT * FROM admins WHERE email = $1 AND is_active = true', [email]);
    const admin = result.rows[0];

    if (!admin || !(await bcrypt.compare(password, admin.password_hash))) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    await query('UPDATE admins SET last_login = NOW() WHERE id = $1', [admin.id]);

    const { token, refreshToken } = generateTokens({
      adminId: admin.id,
      email: admin.email,
      role: admin.role,
      type: 'admin'
    });

    res.json({
      token,
      refreshToken,
      admin: {
        id: admin.id,
        name: admin.name,
        email: admin.email,
        role: admin.role
      }
    });
  } catch (err) {
    next(err);
  }
});

// ============================================================
// REFRESH TOKEN
// ============================================================
router.post('/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) return res.status(401).json({ error: 'Refresh token required' });

  try {
    const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    const { token, refreshToken: newRefresh } = generateTokens({
      ispId: decoded.ispId,
      adminId: decoded.adminId,
      email: decoded.email,
      type: decoded.type,
      role: decoded.role,
      plan: decoded.plan
    });
    res.json({ token, refreshToken: newRefresh });
  } catch (err) {
    res.status(403).json({ error: 'Invalid refresh token' });
  }
});

// ============================================================
// FORGOT PASSWORD
// ============================================================
router.post('/forgot-password', [
  body('email').isEmail().normalizeEmail(),
  body('type').isIn(['isp', 'admin']),
], async (req, res, next) => {
  const { email, type } = req.body;
  try {
    const table = type === 'admin' ? 'admins' : 'isps';
    const result = await query(`SELECT id, email FROM ${table} WHERE email = $1`, [email]);
    
    if (result.rows[0]) {
      const token = uuidv4();
      const expires = new Date(Date.now() + 3600000); // 1 hour
      
      await query(
        `UPDATE ${table} SET password_reset_token = $1, password_reset_expires = $2 WHERE id = $3`,
        [token, expires, result.rows[0].id]
      );

      const resetUrl = `${process.env.FRONTEND_URL}/reset-password?token=${token}&type=${type}`;
      
      await sendEmail({
        to: email,
        subject: 'Reset your RumaLink password',
        html: `<p>Click <a href="${resetUrl}">here</a> to reset your password. Link expires in 1 hour.</p>`
      });
    }

    // Always return success to prevent email enumeration
    res.json({ message: 'If that email exists, a reset link has been sent.' });
  } catch (err) {
    next(err);
  }
});

// ============================================================
// RESET PASSWORD
// ============================================================
router.post('/reset-password', [
  body('token').notEmpty(),
  body('password').isLength({ min: 8 }),
  body('type').isIn(['isp', 'admin']),
], async (req, res, next) => {
  const { token, password, type } = req.body;
  try {
    const table = type === 'admin' ? 'admins' : 'isps';
    const result = await query(
      `SELECT id FROM ${table} WHERE password_reset_token = $1 AND password_reset_expires > NOW()`,
      [token]
    );

    if (!result.rows[0]) {
      return res.status(400).json({ error: 'Invalid or expired reset token' });
    }

    const hash = await bcrypt.hash(password, 12);
    await query(
      `UPDATE ${table} SET password_hash = $1, password_reset_token = NULL, password_reset_expires = NULL WHERE id = $2`,
      [hash, result.rows[0].id]
    );

    res.json({ message: 'Password reset successful' });
  } catch (err) {
    next(err);
  }
});

// ============================================================
// GET CURRENT USER
// ============================================================
router.get('/me', authenticateToken, async (req, res, next) => {
  try {
    if (req.user.type === 'admin') {
      const result = await query('SELECT id, name, email, role FROM admins WHERE id = $1', [req.user.adminId]);
      return res.json({ user: result.rows[0], type: 'admin' });
    } else {
      const result = await query(
        `SELECT id, company_name, owner_name, email, phone, plan_type, status, 
                api_key, wallet_balance, logo_url, trial_ends_at, county, town
         FROM isps WHERE id = $1`,
        [req.user.ispId]
      );
      return res.json({ user: result.rows[0], type: 'isp' });
    }
  } catch (err) {
    next(err);
  }
});

module.exports = router;
