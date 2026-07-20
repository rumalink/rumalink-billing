const { query } = require('../config/database');

function generateCode(prefix = '', length = 8) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = prefix;
  for (let i = 0; i < length; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code;
}

// Generate ISP-letter+counter username (e.g. K1, K2 for "Kimatech")
// Atomically increments isps.hotspot_counter to avoid race conditions.
async function generateIspUsername(ispId) {
  try {
    // Atomically grab name + bump counter
    const r = await query(
      `UPDATE isps
         SET hotspot_counter = COALESCE(hotspot_counter, 0) + 1
       WHERE id = $1::uuid
       RETURNING company_name, hotspot_counter`,
      [ispId]
    );
    if (!r.rows[0]) return generateCode('', 8); // fallback
    const name = (r.rows[0].company_name || 'X').trim();
    const firstChar = (name.match(/[A-Za-z]/) || ['X'])[0].toUpperCase();
    return firstChar + r.rows[0].hotspot_counter;
  } catch (e) {
    return generateCode('', 8); // fallback on any error
  }
}

module.exports = { generateCode, generateIspUsername };
