// RL_ISP_ALERT — one place that tells the ISP account owner something happened to their router.
//
// isp-monitor already sends total-outage / restored SMS. Multi-WAN failover had no notification
// at all: a link could flip to the backup and the ISP would only learn of it from the bill or a
// customer complaint. This helper is shared so every alert reaches the same recipient, in the
// same format, with the same protection against flapping.
//
// EDGE-TRIGGERED: an alert is sent only when the state for (device, kind) actually CHANGES.
// A link that flaps every poll would otherwise send a message every poll — which trains the
// recipient to ignore the alerts that matter.
const { query } = require('../config/database');
const logger = require('./logger');

const lastState = new Map();   // `${nasId}|${kind}` -> last state string

function normalizePhone(raw) {
  const d = String(raw || '').replace(/\D/g, '');
  if (!d) return null;
  if (d.startsWith('254')) return d;
  if (d.startsWith('0')) return '254' + d.slice(1);
  if (d.length === 9) return '254' + d;
  return d;
}

async function logEvent(nasId, ispId, eventType, message) {
  try {
    await query('INSERT INTO nas_events (nas_id, isp_id, event_type, message) VALUES ($1::uuid,$2::uuid,$3,$4)',
      [nasId, ispId, eventType, message]);
  } catch (e) { logger.warn('[isp-alert] event log: ' + e.message); }
}

/* Send only when the state changed. Returns true if an SMS was actually sent. */
async function notify({ nasId, ispId, kind, state, eventType, message }) {
  const key = nasId + '|' + kind;
  if (lastState.get(key) === state) return false;      // unchanged — stay quiet
  const first = !lastState.has(key);
  lastState.set(key, state);
  if (first) return false;   // first observation after a restart is the baseline, not an event

  await logEvent(nasId, ispId, eventType, message);
  try {
    const r = await query(
      'SELECT id, company_name, phone, sms_gateway, sms_api_key, sms_sender_id, sms_username, sms_partner_id, sms_api_secret FROM isps WHERE id=$1::uuid',
      [ispId]);
    const isp = r.rows[0];
    if (!isp) return false;
    const to = normalizePhone(isp.phone);
    if (!to) { logger.warn('[isp-alert] ' + (isp.company_name || ispId) + ' has no phone — SMS skipped'); return false; }
    const row = Object.assign({}, isp);
    if (!row.sms_gateway) row.sms_gateway = 'rumalink';
    await require('./sms').sendSMS({ to, message, isp: row });
    logger.info('[isp-alert] ' + eventType + ' SMS sent to ' + to + ' (' + kind + ' -> ' + state + ')');
    return true;
  } catch (e) {
    logger.error('[isp-alert] SMS failed (' + eventType + '): ' + e.message);
    return false;
  }
}

/* Seed the baseline without alerting — used on the first pass after a restart. */
function seed(nasId, kind, state) {
  const key = nasId + '|' + kind;
  if (!lastState.has(key)) lastState.set(key, state);
}

module.exports = { notify, seed, normalizePhone, logEvent };
