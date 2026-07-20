// utils/coa.js — Send RADIUS CoA / Disconnect-Request packets to NAS devices
// Uses radclient to construct + send standard Disconnect-Request packets.
// Replaces REST POST /ip/hotspot/active/remove with proper RADIUS pattern.
//
// MikroTik defaults: accepts incoming RADIUS requests on UDP 1700 when
// /radius/incoming accept=yes is set. We configure this in v57 setup.

const { execFile } = require('child_process');
const { query } = require('../config/database');
const logger = require('./logger');

/**
 * Send a Disconnect-Request to terminate a user's session on the NAS.
 * @param {string} deviceId - nas_devices.id (UUID)
 * @param {string} username - the User-Name (e.g. "K6") to disconnect
 * @returns {Promise<{ok, accepted, ack, raw, error}>}
 */
async function sendDisconnect(deviceId, username) {
  try {
    const r = await query(
      `SELECT wireguard_ip, radius_secret FROM nas_devices WHERE id = $1::uuid LIMIT 1`,
      [deviceId]
    );
    if (!r.rows[0]) return { ok: false, error: 'NAS not found' };
    const { wireguard_ip, radius_secret } = r.rows[0];
    if (!radius_secret) return { ok: false, error: 'No radius_secret for NAS' };

    return new Promise((resolve) => {
      const target = `${wireguard_ip}:3799`;
      // radclient: send disconnect packet
      const proc = execFile('radclient',
        ['-x', '-t', '3', '-r', '1', target, 'disconnect', radius_secret],
        { timeout: 5000 },
        (err, stdout, stderr) => {
          const raw = (stdout || '') + (stderr || '');
          if (err && !raw.includes('Disconnect-ACK')) {
            return resolve({ ok: false, accepted: false, error: err.message, raw });
          }
          const ack = raw.includes('Disconnect-ACK');
          const nak = raw.includes('Disconnect-NAK');
          resolve({ ok: ack, accepted: ack, ack, nak, raw });
        }
      );
      // Provide User-Name attribute via stdin
      proc.stdin.write(`User-Name="${username}"\n`);
      proc.stdin.end();
    });
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

/**
 * Send a CoA-Update to change attributes on an active session.
 * Useful when package bandwidth changes mid-session.
 * @param {string} deviceId 
 * @param {string} username
 * @param {object} attributes - e.g. { 'Mikrotik-Rate-Limit': '10M/10M' }
 */
async function sendCoAUpdate(deviceId, username, attributes) {
  try {
    const r = await query(
      `SELECT wireguard_ip, radius_secret FROM nas_devices WHERE id = $1::uuid LIMIT 1`,
      [deviceId]
    );
    if (!r.rows[0]) return { ok: false, error: 'NAS not found' };
    const { wireguard_ip, radius_secret } = r.rows[0];
    if (!radius_secret) return { ok: false, error: 'No radius_secret for NAS' };

    return new Promise((resolve) => {
      const target = `${wireguard_ip}:3799`;
      const proc = execFile('radclient',
        ['-x', '-t', '3', '-r', '1', target, 'coa', radius_secret],
        { timeout: 5000 },
        (err, stdout, stderr) => {
          const raw = (stdout || '') + (stderr || '');
          if (err && !raw.includes('CoA-ACK')) {
            return resolve({ ok: false, error: err.message, raw });
          }
          const ack = raw.includes('CoA-ACK');
          resolve({ ok: ack, accepted: ack, raw });
        }
      );
      const attrLines = [`User-Name="${username}"`];
      for (const [k, v] of Object.entries(attributes || {})) {
        attrLines.push(`${k}="${v}"`);
      }
      proc.stdin.write(attrLines.join(',') + '\n');
      proc.stdin.end();
    });
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

module.exports = { sendDisconnect, sendCoAUpdate };
