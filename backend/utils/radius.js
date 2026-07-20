// utils/radius.js — Realm-aware username helpers for multi-tenant RADIUS
// Pattern: voucher.code = "K6", radius_username = "K6@<isp_short_id>"
// Where isp_short_id = first 8 chars of isp.id UUID

/**
 * Build the realm-suffixed RADIUS username for a voucher.
 * Returns e.g. "K6@3d71deb2" for ISP with id "3d71deb2-8c88-..."
 */
function radiusUsername(code, ispId) {
  if (!code || !ispId) return code;
  const shortId = String(ispId).replace(/-/g, '').slice(0, 8).toLowerCase();
  // Idempotent: if already has realm, return as-is
  if (String(code).includes('@')) return String(code);
  return `${code}@${shortId}`;
}

/**
 * Split a realmed RADIUS username back into { code, realm } parts.
 */
function splitRealm(username) {
  const parts = String(username || '').split('@');
  if (parts.length < 2) return { code: parts[0] || '', realm: null };
  return { code: parts[0], realm: parts[1] };
}

/**
 * Get the realm/short_id for an ISP.
 */
function ispRealm(ispId) {
  return String(ispId || '').replace(/-/g, '').slice(0, 8).toLowerCase();
}

module.exports = { radiusUsername, splitRealm, ispRealm };
