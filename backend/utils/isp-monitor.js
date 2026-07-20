// v62.87 — ISP Link Monitor
// Polls all online MikroTik devices every 60s, checks if they can reach the internet
// (via /tool/ping to 8.8.8.8 + 1.1.1.1). Tracks state transitions, logs events to 
// nas_events, and sends SMS notifications to the ISP admin on UP↔DOWN changes.

const { query } = require('../config/database');
const logger = require('./logger');
const { sendSMS } = require('./sms');

// Configuration
const PING_TARGETS = ['8.8.8.8', '1.1.1.1'];          // Try multiple targets
const PING_COUNT = '3';                                // 3 pings per target
const CONSECUTIVE_FAILURES_TO_FLIP = 2;                // 2 failed checks = DOWN  (~2 min)
const CONSECUTIVE_SUCCESSES_TO_FLIP = 1;               // 1 successful = UP (immediate restore notice)
const PING_TIMEOUT_MS = 10000;                         // 10 s per ping batch

// Helper: format duration as "Xh Ym" or "Xm"
function fmtDuration(sec) {
  if (!sec || sec < 0) return '0m';
  const d = Math.floor(sec / 86400);
  const h = Math.floor((sec % 86400) / 3600);
  const m = Math.floor((sec % 3600) / 60);
  if (d > 0) return `${d}d ${h}h`;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

// Helper: format timestamp as "HH:MM, DD MMM"
function fmtTime(ts) {
  const d = new Date(ts);
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return `${hh}:${mm}, ${day} ${months[d.getMonth()]}`;
}

// Helper: normalize Kenyan phone for SMS (254XXX format)
function normalizePhone(raw) {
  if (!raw) return null;
  const s = String(raw).replace(/[^0-9+]/g, '');
  if (s.startsWith('+254')) return s.substring(1);
  if (s.startsWith('254')) return s;
  if (s.startsWith('0') && s.length === 10) return '254' + s.substring(1);
  if (s.length === 9) return '254' + s;
  return s;
}

// Try to ping a target from MikroTik via REST API
async function pingFromRouter(baseUrl, authHdr, target) {
  try {
    const resp = await fetch(baseUrl + '/rest/ping', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': authHdr },
      body: JSON.stringify({ address: target, count: PING_COUNT }),
      signal: AbortSignal.timeout(PING_TIMEOUT_MS)
    });
    if (!resp.ok) return { ok: false, error: 'http ' + resp.status };
    const data = await resp.json();
    if (!Array.isArray(data) || !data.length) return { ok: false, error: 'no response' };
    // Each row has "status" — "ok" means reply received
    const successCount = data.filter(p => (p.status || 'ok') === 'ok' || p.time).length;
    return { ok: successCount > 0, sent: data.length, received: successCount };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

// Send SMS notification about link state change. Returns boolean of whether SMS was attempted.
async function sendLinkSMS(ispId, deviceName, newStatus, changedAt, durationSec) {
  try {
    const ispR = await query(
      `SELECT id, company_name, phone, sms_gateway, sms_api_key, sms_sender_id
       FROM isps WHERE id = $1::uuid`, [ispId]
    );
    if (!ispR.rows[0]) return false;
    const isp = ispR.rows[0];
    if (!isp.phone) {
      logger.warn(`[isp-monitor] ISP ${isp.company_name} has no phone — skipping SMS`);
      return false;
    }
    const recipient = normalizePhone(isp.phone);
    if (!recipient) return false;

    let message;
    if (newStatus === 'down') {
      message = `🔴 RumaLink Alert: Your MikroTik "${deviceName}" has LOST internet from its ISP provider at ${fmtTime(changedAt)}. You'll get another SMS when service is restored.`;
    } else if (newStatus === 'up') {
      const dur = fmtDuration(durationSec);
      message = `🟢 RumaLink: Internet to "${deviceName}" has been RESTORED at ${fmtTime(changedAt)}. Outage lasted ${dur}.`;
    } else {
      return false;
    }

    await sendSMS({ to: recipient, message, isp });
    logger.info(`[isp-monitor] SMS sent to ${recipient} for ${deviceName} → ${newStatus}`);
    return true;
  } catch (e) {
    logger.error(`[isp-monitor] SMS send failed: ${e.message}`);
    return false;
  }
}

// Insert nas_event log
async function logEvent(nasId, ispId, eventType, message) {
  try {
    await query(
      `INSERT INTO nas_events (nas_id, isp_id, event_type, message) VALUES ($1::uuid, $2::uuid, $3, $4)`,
      [nasId, ispId, eventType, message]
    );
  } catch (e) {
    logger.error(`[isp-monitor] event log failed: ${e.message}`);
  }
}

// Check a single device — used both by cron + manual /link-check endpoint
async function checkSingleDevice(deviceId) {
  const r = await query(
    `SELECT id, isp_id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password,
            is_online, isp_link_status, isp_link_consecutive_failures, isp_link_changed_at,
            isp_link_notifications_enabled
     FROM nas_devices WHERE id = $1::uuid`, [deviceId]
  );
  if (!r.rows[0]) return { error: 'device not found' };
  const dev = r.rows[0];

  if (!dev.wireguard_ip || !dev.mikrotik_api_user || !dev.mikrotik_api_password) {
    return { error: 'device not provisioned' };
  }

  const baseUrl = 'http://' + dev.wireguard_ip;
  const authHdr = 'Basic ' + Buffer.from(dev.mikrotik_api_user + ':' + dev.mikrotik_api_password).toString('base64');

  // Try all targets, success if at least one responds
  let anySuccess = false;
  const results = [];
  for (const target of PING_TARGETS) {
    const r = await pingFromRouter(baseUrl, authHdr, target);
    results.push({ target, ...r });
    if (r.ok) { anySuccess = true; break; }  // short-circuit on first success
  }

  const checkPassed = anySuccess;
  const now = new Date();
  const previousStatus = dev.isp_link_status || 'unknown';
  let newStatus = previousStatus;
  let consecFailures = dev.isp_link_consecutive_failures || 0;
  let stateChanged = false;

  if (checkPassed) {
    if (previousStatus !== 'up') {
      // Was down/unknown — now back up
      newStatus = 'up';
      stateChanged = (previousStatus === 'down');  // only "changed" if was explicitly down before
      consecFailures = 0;
    } else {
      consecFailures = 0;
    }
  } else {
    consecFailures++;
    if (consecFailures >= CONSECUTIVE_FAILURES_TO_FLIP && previousStatus !== 'down') {
      newStatus = 'down';
      stateChanged = true;
    }
  }

  // Update DB
  await query(
    `UPDATE nas_devices SET
       isp_link_status = $1,
       isp_link_last_checked = $2,
       isp_link_consecutive_failures = $3,
       isp_link_changed_at = CASE WHEN $4 THEN $2 ELSE isp_link_changed_at END
     WHERE id = $5::uuid`,
    [newStatus, now, consecFailures, stateChanged, dev.id]
  );

  // Log event + send SMS if state changed
  if (stateChanged) {
    const eventType = newStatus === 'down' ? 'isp_link_down' : 'isp_link_up';
    const lastChanged = dev.isp_link_changed_at ? new Date(dev.isp_link_changed_at) : now;
    const durationSec = newStatus === 'up' ? Math.floor((now - lastChanged) / 1000) : 0;
    let msg;
    if (newStatus === 'down') {
      msg = `ISP link DOWN — pings to ${PING_TARGETS.join(', ')} all failed (${consecFailures} consecutive failures)`;
    } else {
      msg = `ISP link RESTORED — outage lasted ${fmtDuration(durationSec)}`;
    }
    await logEvent(dev.id, dev.isp_id, eventType, msg);
    logger.info(`[isp-monitor] ${dev.name}: ${previousStatus} → ${newStatus} (${msg})`);

    // SMS (respects per-device notifications toggle)
    if (dev.isp_link_notifications_enabled !== false) {
      await sendLinkSMS(dev.isp_id, dev.name, newStatus, now, durationSec);
    }
  }

  return {
    status: newStatus,
    previous_status: previousStatus,
    state_changed: stateChanged,
    consecutive_failures: consecFailures,
    last_checked: now,
    ping_results: results
  };
}

// Cron job: run every 60s, check all "online" devices
async function pollAllDevices() {
  try {
    const r = await query(
      `SELECT id, name FROM nas_devices
       WHERE wireguard_ip IS NOT NULL AND mikrotik_api_user IS NOT NULL
         AND is_provisioned = true`
    );
    const devices = r.rows;
    if (!devices.length) return;
    
    // Run all checks in parallel (with safety: cap at 20 concurrent)
    const limit = 20;
    for (let i = 0; i < devices.length; i += limit) {
      const batch = devices.slice(i, i + limit);
      await Promise.all(batch.map(d => checkSingleDevice(d.id).catch(e => {
        logger.warn(`[isp-monitor] ${d.name}: ${e.message}`);
      })));
    }
  } catch (e) {
    logger.error(`[isp-monitor] pollAllDevices: ${e.message}`);
  }
}

module.exports = {
  checkSingleDevice,
  pollAllDevices,
  PING_TARGETS,
  CONSECUTIVE_FAILURES_TO_FLIP
};
