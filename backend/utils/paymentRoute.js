// utils/paymentRoute.js — RL_PAYMENT_ROUTE
// One answer to "which gateway should this ISP's payment go through", used by every channel.
// The hotspot and the PPPoE portal each decided this for themselves and each recognised only an
// explicit 'intasend' selection, so an ISP that picked "M-Pesa STK" was sent to Daraja with no
// credentials: a 403 from Safaricom on one path and "M-Pesa not configured" on the other, two
// messages for one cause, neither naming it.
//
// RL_DARAJA_CREDS: an ISP's own Daraja keys live in isp_payment_methods (entered in the ISP
// dashboard), NOT in mpesa_configs. An earlier version of this file only consulted mpesa_configs,
// so an ISP holding perfectly good credentials was told none existed.
//
// RL_NO_SUBSTITUTION: when the selected gateway cannot be delivered we refuse and say what is
// missing. Quietly collecting through a different gateway would settle the customers' money into
// a different account with nobody told — a reconciliation problem that surfaces weeks later, when
// nobody remembers why. This was a deliberate decision; do not add a silent fallback.
const { query } = require('../config/database');
const logger = require('./logger');

async function ispMethod(ispId) {
  const r = await query(
    "SELECT method_type, provider FROM isp_payment_methods " +
    "WHERE isp_id = $1::uuid AND is_active = true ORDER BY is_default DESC, created_at ASC LIMIT 1",
    [ispId]);
  const row = r.rows[0] || {};
  return { method: String(row.method_type || '').toLowerCase(),
           provider: String(row.provider || '').toLowerCase() };
}

/* Complete Daraja credentials on the ISP's own record. Partial credentials count as absent:
   a half-configured ISP should get a clear message here, not a 403 from Safaricom later. */
async function darajaCreds(ispId) {
  try {
    const r = await query(
      "SELECT * FROM isp_payment_methods WHERE isp_id = $1::uuid " +
      "AND (method_type = 'mpesa_stk' OR method_type ILIKE '%daraja%') AND is_active = true " +
      "ORDER BY is_default DESC LIMIT 1", [ispId]);
    const cfg = r.rows[0];
    if (!cfg || cfg.use_admin_credentials) return null;
    const key = (cfg.consumer_key || '').trim();
    const sec = (cfg.consumer_secret || '').trim();
    const pk  = (cfg.passkey || '').trim();
    const sc  = (cfg.shortcode || cfg.till_number || cfg.paybill_number || '').trim();
    if (!key || !sec || !pk || !sc) return null;
    return { source: 'database', consumer_key: key, consumer_secret: sec, passkey: pk,
             shortcode: sc, environment: cfg.environment || 'production' };
  } catch (e) { logger.warn('[payment-route] daraja creds: ' + e.message); return null; }
}

async function darajaConfigured(ispId) {
  if (await darajaCreds(ispId)) return true;                    // ISP's own keys
  try { const r = await query("SELECT 1 FROM mpesa_configs WHERE is_active = true LIMIT 1");
        return !!r.rows[0]; } catch (e) { return false; }       // or a platform-wide config
}
async function providerActive(name) {
  try { const r = await query(
    "SELECT 1 FROM payment_provider_configs WHERE provider = $1 AND is_active = true LIMIT 1", [name]);
    return !!r.rows[0]; } catch (e) { return false; }
}

/* The ISP's choice is honoured whenever the platform can actually deliver it; when it cannot,
   we say so plainly rather than failing deep inside a gateway client — or worse, succeeding
   through the wrong one. */
async function resolve(ispId) {
  const m = await ispMethod(ispId);

  if (m.method === 'intasend' || m.provider === 'intasend') {
    if (await providerActive('intasend')) return { gateway: 'intasend', reason: 'ISP selected IntaSend' };
    return { gateway: null, error: 'IntaSend is selected but not configured by the platform admin.' };
  }

  if (m.method === 'equity' || m.provider === 'equity_jenga') {
    if (await providerActive('jenga')) return { gateway: 'jenga', reason: 'ISP selected Equity (Jenga)' };
    return { gateway: null, error: 'Equity (Jenga) is selected but not configured by the platform admin.' };
  }

  // "mpesa_stk", "daraja", or nothing chosen — all mean "collect by M-Pesa".
  const creds = await darajaCreds(ispId);
  if (creds) {
    logger.info('[payment-route] isp=' + ispId + ' -> daraja (own credentials, shortcode ' + creds.shortcode + ')');
    return { gateway: 'daraja', creds, reason: "M-Pesa via the ISP's own Daraja credentials" };
  }
  if (await darajaConfigured(ispId)) return { gateway: 'daraja', reason: 'M-Pesa via Daraja (platform config)' };

  logger.warn('[payment-route] isp=' + ispId + ' selected M-Pesa (Daraja) but no complete Daraja credentials are configured');
  return { gateway: null,
    error: 'M-Pesa (Daraja) is selected for this ISP but its Daraja credentials are missing or incomplete. ' +
           'Add them in the ISP dashboard, or change this ISP\'s payment method to a gateway that is configured.' };
}

async function useIntasend(ispId) { const r = await resolve(ispId); return r.gateway === 'intasend'; }

const paymentRoute = resolve;
paymentRoute.resolve = resolve;
paymentRoute.darajaCreds = darajaCreds;
module.exports = paymentRoute;
module.exports.resolve = resolve;
module.exports.useIntasend = useIntasend;
module.exports.ispMethod = ispMethod;
module.exports.darajaCreds = darajaCreds;
module.exports.darajaConfigured = darajaConfigured;
module.exports.providerActive = providerActive;
