// utils/walledGarden.js — move a PPPoE subscriber between full service and the rl-expired walled garden.
const { query } = require('../config/database');
const coa = require('./coa');
const mikrotik = require('./mikrotik');
const logger = require('./logger');

const EXPIRED_PROFILE = 'rl-expired';

// Resolve the device for a subscriber: explicit nas_id, else first device for the ISP.
async function resolveDeviceId(sub) {
  if (sub.nas_id) return sub.nas_id;
  if (sub.isp_id) {
    const d = await query(`SELECT id FROM nas_devices WHERE isp_id=$1::uuid ORDER BY created_at ASC LIMIT 1`, [sub.isp_id]);
    if (d.rows[0]) return d.rows[0].id;
  }
  return null;
}

// Bounce a PPPoE session so a new RADIUS profile applies immediately.
// Primary: REST API /ppp/active remove (reliable over WG). Fallback: CoA disconnect.
async function bounce(deviceId, username) {
  if (!deviceId) return { ok: false, error: 'no device' };
  try {
    const r = await mikrotik.disconnectPppoe(deviceId, username);
    if (r && r.ok) return { ok: true, via: 'api', removed: r.removed };
    // If API found no active session, that's fine (applies on next connect).
    if (r && r.removed === 0) return { ok: true, via: 'api', removed: 0 };
  } catch (e) { logger.warn(`[WG] api bounce ${username}: ${e.message}`); }
  // Fallback: CoA (best-effort).
  try { const c = await coa.sendDisconnect(deviceId, username); return { ok: !!(c && c.ok), via: 'coa' }; }
  catch (e) { return { ok: false, error: e.message }; }
}

async function setGroup(username, groupValue) {
  const existing = await query(`SELECT id FROM radreply WHERE username=$1 AND attribute='Mikrotik-Group' LIMIT 1`, [username]);
  if (existing.rows[0]) await query(`UPDATE radreply SET value=$2, op='=' WHERE username=$1 AND attribute='Mikrotik-Group'`, [username, groupValue]);
  else await query(`INSERT INTO radreply (username, attribute, op, value) VALUES ($1,'Mikrotik-Group','=',$2)`, [username, groupValue]);
}

// Restrict: drop into the walled garden (still online, only the pay page reachable).
async function restrict(sub) {
  try {
    await query(`DELETE FROM radcheck WHERE username=$1 AND attribute='Auth-Type' AND value='Reject'`, [sub.username]).catch(() => {});
    await setGroup(sub.username, EXPIRED_PROFILE);
    await query(`UPDATE pppoe_subscribers SET status='expired', updated_at=NOW() WHERE id=$1`, [sub.id]);
    const deviceId = await resolveDeviceId(sub);
    const b = await bounce(deviceId, sub.username);
    logger.info(`[WG] restrict ${sub.username} -> ${EXPIRED_PROFILE} (bounce ${b.via||'none'} ok=${b.ok})`);
    return { ok: true, bounce: b };
  } catch (e) { logger.error(`[WG] restrict failed ${sub.username}: ${e.message}`); return { ok: false, error: e.message }; }
}

// Restore: back to full service (package profile) after payment.
async function restore(sub, packageProfile) {
  try {
    await query(`DELETE FROM radcheck WHERE username=$1 AND attribute='Auth-Type' AND value='Reject'`, [sub.username]).catch(() => {});
    if (packageProfile) await setGroup(sub.username, packageProfile);
    else await query(`DELETE FROM radreply WHERE username=$1 AND attribute='Mikrotik-Group'`, [sub.username]).catch(() => {});
    await query(`UPDATE pppoe_subscribers SET status='active', updated_at=NOW() WHERE id=$1`, [sub.id]);
    const deviceId = await resolveDeviceId(sub);
    const b = await bounce(deviceId, sub.username);
    logger.info(`[WG] restore ${sub.username} -> ${packageProfile || 'default'} (bounce ${b.via||'none'} ok=${b.ok})`);
    return { ok: true, bounce: b };
  } catch (e) { logger.error(`[WG] restore failed ${sub.username}: ${e.message}`); return { ok: false, error: e.message }; }
}

module.exports = { restrict, restore, setGroup, resolveDeviceId, bounce, EXPIRED_PROFILE };
