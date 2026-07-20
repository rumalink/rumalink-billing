// utils/effectiveRate.js — resolve the effective hotspot commission rate for a payment.
// Order: per-ISP override (isps.commission_rate) -> platform default (platform_settings) -> 0.03.
const { query } = require('../config/database');

async function platformHotspotRate() {
  try {
    const r = await query("SELECT value FROM platform_settings WHERE key='hotspot_commission_rate' LIMIT 1");
    if (r.rows[0] && r.rows[0].value != null) {
      const v = parseFloat(r.rows[0].value);
      if (v >= 0 && v <= 1) return v;
    }
  } catch (e) { /* table may not exist */ }
  return 0.03;
}

// platform card is the single source of truth: per-ISP override is ignored on purpose.
// (param kept for call-site compatibility.)
async function effectiveHotspotRate(_ispRateRaw) {
  return await platformHotspotRate();
}

module.exports = { platformHotspotRate, effectiveHotspotRate };
