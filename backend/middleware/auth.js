const jwt = require('jsonwebtoken');
const { query } = require('../config/database');

const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired', code: 'TOKEN_EXPIRED' });
    }
    return res.status(403).json({ error: 'Invalid token' });
  }
};

const requireAdmin = async (req, res, next) => {
  if (!req.user || req.user.role !== 'superadmin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
};

const requireISP = async (req, res, next) => {
  if (!req.user || req.user.type !== 'isp') {
    return res.status(403).json({ error: 'ISP access required' });
  }
  // Fetch ISP status
  try {
    const result = await query('SELECT id, status, COALESCE(email_verified,false) AS email_verified, COALESCE(phone_verified,false) AS phone_verified FROM isps WHERE id = $1', [req.user.ispId]);
    if (!result.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    if (result.rows[0].status === 'suspended') {
      return res.status(403).json({ error: 'Account suspended. Contact support.' });
    }
    /* RL_VERIFY_GATE: both email and phone must be verified before an ISP can use the platform.
       Enforced here because requireISP is the single choke point every ISP-facing mount already
       passes through — gating each mount separately would eventually miss one, and a missed
       mount stays reachable with curl even when the UI hides it. */
    if (!result.rows[0].email_verified || !result.rows[0].phone_verified) {
      const missing = [];
      if (!result.rows[0].phone_verified) missing.push('phone');
      if (!result.rows[0].email_verified) missing.push('email');
      return res.status(403).json({ error: 'Verify your email address and phone number to access your dashboard.', code: 'VERIFICATION_REQUIRED', verification_required: missing });
    }
    req.isp = result.rows[0];
    next();
  } catch (err) {
    next(err);
  }
};

const authenticateAPIKey = async (req, res, next) => {
  const apiKey = req.headers['x-api-key'];
  if (!apiKey) return res.status(401).json({ error: 'API key required' });

  try {
    const result = await query(
      'SELECT id, status FROM isps WHERE api_key = $1',
      [apiKey]
    );
    if (!result.rows[0]) return res.status(401).json({ error: 'Invalid API key' });
    if (result.rows[0].status !== 'active') {
      return res.status(403).json({ error: 'ISP account not active' });
    }
    req.ispId = result.rows[0].id;
    next();
  } catch (err) {
    next(err);
  }
};

// v63: license gate — blocks ISP dashboard + new captive purchases once expired & unpaid
const requireActiveLicense = async (req, res, next) => {
  try {
    // Always let the billing/pay/status paths through so a locked ISP can still pay.
    const p = req.path || req.url || '';
    if (p.indexOf('/billing') !== -1) return next();

    // Resolve ISP id from either an ISP token (req.user.ispId) or a captive route param.
    const ispId = (req.user && req.user.ispId) || req.params.ispId || null;
    if (!ispId) return next();

    // Admin impersonation tokens are never locked out.
    if (req.user && (req.user.imp === true || req.user.impersonatedBy)) return next();

    const r = await query(
      'SELECT billing_exempt, license_expires_at, license_status FROM isps WHERE id = $1::uuid',
      [ispId]
    );
    const row = r.rows[0];
    if (!row) return next();

    // Safety switch: exempt ISPs are never gated.
    if (row.billing_exempt === true) return next();

    // No expiry set, or expiry in the future -> allow.
    if (!row.license_expires_at) return next();
    const now = Date.now();
    const exp = new Date(row.license_expires_at).getTime();
    if (now < exp) return next();

    // Expired & unpaid -> 402 with amount owed + open invoice id (best-effort).
    let amount = null, invoice_id = null;
    try {
      const inv = await query(
        "SELECT id, total_amount FROM isp_platform_invoices WHERE isp_id=$1::uuid AND status='pending' ORDER BY created_at DESC LIMIT 1",
        [ispId]
      );
      if (inv.rows[0]) { invoice_id = inv.rows[0].id; amount = Number(inv.rows[0].total_amount); }
    } catch (e) {}
    if (amount == null) {
      try {
        const billing = require('../utils/billing');
        const b = await billing.getIspBilling(ispId);
        const ws = b && (b.billing_window_start || b.subscription_started_at || b.trial_ends_at);
        const owed = await billing.computeOwed(ispId, ws, new Date());
        amount = owed ? Number(owed.total) : null;
      } catch (e) {}
    }
    return res.status(402).json({
      error: 'LICENSE_EXPIRED',
      code: 'LICENSE_EXPIRED',
      message: 'Your platform license has expired. Please renew to continue.',
      amount: amount,
      invoice_id: invoice_id
    });
  } catch (err) {
    return next(); // fail OPEN — never lock anyone out due to a gate error
  }
};

module.exports = { authenticateToken, requireAdmin, requireISP, authenticateAPIKey, requireActiveLicense };
