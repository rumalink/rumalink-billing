// utils/billing.js — RumaLink platform billing calculator
// Model: two clocks. license_expires_at = fixed monthly anchor (advances 1 month,
// from previous expiry if paid on-time, else from payment date if paid late).
// billing_window_start = dynamic; jumps to the payment instant on each payment.
//
// Charges (combined invoice):
//   hotspot_fee = 3% of hotspot revenue collected in [window_start, window_end)
//   pppoe_fee   = KES 32 * (distinct PPPoE users active at any point in the window)

const { query } = require('../config/database');

const HOTSPOT_RATE = 0.03;      // fallback default if platform_settings is empty
const PPPOE_PER_USER = 32.00;   // fallback default if platform_settings is empty

// Read platform-wide commission defaults (single source of truth). Falls back to the
// constants above if the table/rows are missing. Per-ISP overrides are applied in computeOwed.
async function getPlatformRates() {
  let hotspot = HOTSPOT_RATE, pppoe = PPPOE_PER_USER;
  try {
    const r = await query("SELECT key, value FROM platform_settings WHERE key IN ('hotspot_commission_rate','pppoe_per_user_fee')");
    for (const row of r.rows) {
      if (row.key === 'hotspot_commission_rate' && row.value != null) hotspot = parseFloat(row.value);
      if (row.key === 'pppoe_per_user_fee' && row.value != null) pppoe = parseFloat(row.value);
    }
  } catch (e) { /* table may not exist yet; use defaults */ }
  if (!(hotspot >= 0)) hotspot = HOTSPOT_RATE;
  if (!(pppoe >= 0)) pppoe = PPPOE_PER_USER;
  return { hotspot, pppoe };
}

// Add one calendar month, preserving day/time (JS Date handles month rollover).
function addMonth(d) {
  const dt = new Date(d);
  const day = dt.getDate();
  dt.setDate(1);
  dt.setMonth(dt.getMonth() + 1);
  const lastDay = new Date(dt.getFullYear(), dt.getMonth() + 1, 0).getDate();
  dt.setDate(Math.min(day, lastDay));
  return dt;
}

// New expiry: on-time (pay on/before current expiry) -> prevExpiry + 1mo.
// Late (pay after expiry) -> paymentDate + 1mo.
function nextExpiry(prevExpiry, paymentDate) {
  const prev = new Date(prevExpiry);
  const pay = new Date(paymentDate || Date.now());
  return pay <= prev ? addMonth(prev) : addMonth(pay);
}

// Compute what an ISP owes for the window [windowStart, windowEnd).
async function computeOwed(ispId, windowStart, windowEnd) {
  let wsDate = new Date(windowStart);
  const weDate = new Date(windowEnd || Date.now());
  // If the window start is in the future (ISP still in trial) or after the end,
  // there is nothing to bill yet — clamp to an empty window.
  const inverted = wsDate.getTime() >= weDate.getTime();
  const ws = (inverted ? weDate : wsDate).toISOString();
  const we = weDate.toISOString();

  // Hotspot revenue: PAID customer hotspot payments in the window.
  // Identified by description starting 'Hotspot'; platform charges excluded.
  const hot = await query(
    `SELECT COALESCE(SUM(amount),0) AS rev
       FROM payments
      WHERE isp_id=$1::uuid AND status='paid'
        AND created_at >= $2 AND created_at < $3
        AND description ILIKE 'Hotspot%'
        AND COALESCE(payment_method,'') <> 'admin_charge'
        AND COALESCE(payment_method,'') <> 'platform'`,
    [ispId, ws, we]
  );
  const hotspotRevenue = parseFloat(hot.rows[0].rev) || 0;
  // platform card is the single source of truth: always use the platform default rates,
  // ignoring any per-ISP commission_rate / pppoe_rate_per_user columns.
  const _rates = await getPlatformRates();
  const effHotspotRate = _rates.hotspot;
  const effPppoeFee = _rates.pppoe;
  const hotspotFee = Math.round(hotspotRevenue * effHotspotRate * 100) / 100;

  // PPPoE users active at any point in the window: sessions overlapping the window,
  // plus any subscriber currently active (covers always-on with no closed session).
  const ppp = await query(
    /* RL_PPPOE_COUNT_LIVE: bill the subscribers who exist when the invoice is raised — active or
       expired — and nobody who has been deleted. It matches what All Users shows, so the invoice
       can be checked against the dashboard instead of taken on trust.
       The previous version also counted anyone with a session in the window, which swept in
       accounts the ISP had since deleted: billing for customers they no longer have, with no
       screen anywhere showing why the number was higher than their list. */
    `SELECT COUNT(*) AS cnt FROM pppoe_subscribers
      WHERE isp_id = $1::uuid AND deleted_at IS NULL`,
    [ispId]
  );
  const pppoeUsers = parseInt(ppp.rows[0].cnt) || 0;
  const pppoeFee = Math.round(pppoeUsers * effPppoeFee * 100) / 100;

  const total = Math.round((hotspotFee + pppoeFee) * 100) / 100;
  return {
    not_started: inverted,
    window_start: ws,
    window_end: we,
    hotspot_revenue: hotspotRevenue,
    hotspot_rate: effHotspotRate,
    hotspot_fee: hotspotFee,
    pppoe_users: pppoeUsers,
    amount_per_user: effPppoeFee,
    pppoe_fee: pppoeFee,
    total
  };
}

// Load an ISP's current billing state.
async function getIspBilling(ispId) {
  const r = await query(
    `SELECT id, company_name, plan_type, license_status, billing_exempt,
            subscription_started_at, license_expires_at, billing_window_start, trial_ends_at
       FROM isps WHERE id=$1::uuid`,
    [ispId]
  );
  return r.rows[0] || null;
}

module.exports = { HOTSPOT_RATE, PPPOE_PER_USER, getPlatformRates, addMonth, nextExpiry, computeOwed, getIspBilling };
