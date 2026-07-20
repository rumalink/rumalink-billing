/**
 * RumaLink Enterprise — MAC Auth + RADIUS CoA Engine
 * Handles: MAC-based authentication, CoA disconnect/authorize, MAC cookie tracking
 */
const dgram = require('dgram');
const crypto = require('crypto');
const { query } = require('../config/database');
const logger = require('./logger');

// ── RADIUS Packet Types ──────────────────────────────────────
const RADIUS_CODE = {
  ACCESS_REQUEST: 1,
  ACCESS_ACCEPT: 2,
  ACCESS_REJECT: 3,
  ACCOUNTING_REQUEST: 4,
  ACCOUNTING_RESPONSE: 5,
  COA_REQUEST: 43,
  COA_ACK: 44,
  COA_NAK: 45,
  DISCONNECT_REQUEST: 40,
  DISCONNECT_ACK: 41,
  DISCONNECT_NAK: 42,
};

const RADIUS_ATTR = {
  USER_NAME: 1,
  USER_PASSWORD: 2,
  NAS_IP_ADDRESS: 4,
  FRAMED_IP_ADDRESS: 8,
  CALLING_STATION_ID: 31,
  CALLED_STATION_ID: 30,
  ACCT_SESSION_ID: 44,
  SESSION_TIMEOUT: 27,
  IDLE_TIMEOUT: 28,
  MIKROTIK_RATE_LIMIT: { vendor: 14988, type: 8 },
  MIKROTIK_GROUP: { vendor: 14988, type: 2 },
};

// ── Build RADIUS MD5 authenticator ──────────────────────────
function buildAuthenticator(code, id, length, secret, reqAuth = null) {
  if (code === RADIUS_CODE.ACCESS_REQUEST) {
    return crypto.randomBytes(16);
  }
  // For CoA/Disconnect: Response Authenticator = MD5(Code+ID+Length+RequestAuth+Attrs+Secret)
  const buf = Buffer.alloc(4);
  buf.writeUInt8(code, 0);
  buf.writeUInt8(id, 1);
  buf.writeUInt16BE(length, 2);
  const auth = reqAuth || Buffer.alloc(16);
  return crypto.createHash('md5')
    .update(buf).update(auth)
    .update(secret)
    .digest();
}

// ── Encode RADIUS attribute ──────────────────────────────────
function encodeAttr(type, value) {
  if (typeof value === 'string') {
    const vBuf = Buffer.from(value, 'utf8');
    const buf = Buffer.alloc(2 + vBuf.length);
    buf.writeUInt8(type, 0);
    buf.writeUInt8(2 + vBuf.length, 1);
    vBuf.copy(buf, 2);
    return buf;
  }
  if (Buffer.isBuffer(value)) {
    const buf = Buffer.alloc(2 + value.length);
    buf.writeUInt8(type, 0);
    buf.writeUInt8(2 + value.length, 1);
    value.copy(buf, 2);
    return buf;
  }
  if (typeof value === 'number') {
    const buf = Buffer.alloc(6);
    buf.writeUInt8(type, 0);
    buf.writeUInt8(6, 1);
    buf.writeUInt32BE(value, 2);
    return buf;
  }
  return Buffer.alloc(0);
}

// ── Encode Vendor-Specific Attribute (VSA) ──────────────────
function encodeVSA(vendorId, type, value) {
  const vBuf = typeof value === 'string' ? Buffer.from(value, 'utf8') : Buffer.alloc(4, 0);
  const vsa = Buffer.alloc(2 + vBuf.length);
  vsa.writeUInt8(type, 0);
  vsa.writeUInt8(2 + vBuf.length, 1);
  vBuf.copy(vsa, 2);

  const outer = Buffer.alloc(6 + vsa.length);
  outer.writeUInt8(26, 0); // Vendor-Specific type
  outer.writeUInt8(6 + vsa.length, 1);
  outer.writeUInt32BE(vendorId, 2);
  vsa.copy(outer, 6);
  return outer;
}

// ── Send RADIUS CoA / Disconnect packet to NAS ──────────────
function sendRadiusPacket({ nasIp, nasPort = 3799, secret, code, attributes, timeoutMs = 5000 }) {
  return new Promise((resolve, reject) => {
    const id = Math.floor(Math.random() * 256);
    const reqAuth = Buffer.alloc(16); // zero for CoA/Disconnect

    // Build attributes buffer
    const attrBufs = attributes.map(a => {
      if (a.vendor) return encodeVSA(a.vendor, a.type, a.value);
      return encodeAttr(a.type, a.value);
    });
    const attrsBuf = Buffer.concat(attrBufs);
    const totalLen = 20 + attrsBuf.length;

    // Build packet
    const packet = Buffer.alloc(totalLen);
    packet.writeUInt8(code, 0);
    packet.writeUInt8(id, 1);
    packet.writeUInt16BE(totalLen, 2);
    reqAuth.copy(packet, 4);
    attrsBuf.copy(packet, 20);

    // Compute real authenticator
    const realAuth = crypto.createHash('md5')
      .update(packet.slice(0, 4))
      .update(reqAuth)
      .update(attrsBuf)
      .update(secret)
      .digest();
    realAuth.copy(packet, 4);

    const socket = dgram.createSocket('udp4');
    const timer = setTimeout(() => {
      socket.close();
      reject(new Error(`RADIUS CoA timeout to ${nasIp}:${nasPort}`));
    }, timeoutMs);

    socket.on('message', (msg) => {
      clearTimeout(timer);
      socket.close();
      const respCode = msg.readUInt8(0);
      const respId = msg.readUInt8(1);
      if (respId !== id) return reject(new Error('RADIUS response ID mismatch'));
      resolve({
        code: respCode,
        ack: respCode === RADIUS_CODE.COA_ACK || respCode === RADIUS_CODE.DISCONNECT_ACK,
        codeName: Object.keys(RADIUS_CODE).find(k => RADIUS_CODE[k] === respCode) || respCode
      });
    });

    socket.on('error', (err) => { clearTimeout(timer); socket.close(); reject(err); });
    socket.send(packet, 0, packet.length, nasPort, nasIp, (err) => {
      if (err) { clearTimeout(timer); socket.close(); reject(err); }
    });
  });
}

// ── CoA: Disconnect a MAC from the NAS (triggers re-auth) ──
async function disconnectMAC({ nasIp, nasPort, secret, macAddress, sessionId, framedIp }) {
  const mac = normalizeMac(macAddress);
  logger.info(`CoA Disconnect → ${nasIp} for MAC ${mac}`);

  const attributes = [
    { type: RADIUS_ATTR.CALLING_STATION_ID, value: mac },
  ];
  if (sessionId) attributes.push({ type: RADIUS_ATTR.ACCT_SESSION_ID, value: sessionId });
  if (framedIp) {
    const ipBuf = Buffer.alloc(4);
    framedIp.split('.').forEach((o, i) => ipBuf.writeUInt8(parseInt(o), i));
    attributes.push({ type: RADIUS_ATTR.FRAMED_IP_ADDRESS, value: ipBuf });
  }

  try {
    const result = await sendRadiusPacket({
      nasIp, nasPort: nasPort || 3799, secret,
      code: RADIUS_CODE.DISCONNECT_REQUEST,
      attributes
    });
    logger.info(`CoA Disconnect result: ${result.codeName}`);
    return result;
  } catch (err) {
    logger.error(`CoA Disconnect failed for ${mac}:`, err.message);
    return { ack: false, error: err.message };
  }
}

// ── CoA: Update session (change rate limit, timeout) ────────
async function coaUpdateSession({ nasIp, nasPort, secret, macAddress, sessionId,
  rateLimit, sessionTimeout, mikrotikProfile }) {
  const mac = normalizeMac(macAddress);
  logger.info(`CoA Update → ${nasIp} for MAC ${mac}`);

  const attributes = [
    { type: RADIUS_ATTR.CALLING_STATION_ID, value: mac },
  ];
  if (sessionId) attributes.push({ type: RADIUS_ATTR.ACCT_SESSION_ID, value: sessionId });
  if (sessionTimeout) attributes.push({ type: RADIUS_ATTR.SESSION_TIMEOUT, value: sessionTimeout });
  if (rateLimit) attributes.push({ vendor: 14988, type: 8, value: rateLimit });
  if (mikrotikProfile) attributes.push({ vendor: 14988, type: 2, value: mikrotikProfile });

  try {
    const result = await sendRadiusPacket({
      nasIp, nasPort: nasPort || 3799, secret,
      code: RADIUS_CODE.COA_REQUEST,
      attributes
    });
    logger.info(`CoA Update result: ${result.codeName}`);
    return result;
  } catch (err) {
    logger.error(`CoA Update failed:`, err.message);
    return { ack: false, error: err.message };
  }
}

// ── After successful payment: disconnect MAC → triggers re-auth ──
async function triggerMACReconnect({ ispId, macAddress, packageData }) {
  try {
    // Find the NAS device this MAC is connected to
    const session = await query(`
      SELECT hs.nas_id, hs.radius_session_id, hs.ip_address, hs.id as session_id,
             n.nas_ip, n.nas_port, n.secret
      FROM hotspot_sessions hs
      JOIN nas_devices n ON n.id = hs.nas_id
      WHERE hs.isp_id = $1 AND hs.mac_address = $2 AND hs.status = 'active'
      ORDER BY hs.started_at DESC LIMIT 1
    `, [ispId, normalizeMac(macAddress)]);

    if (!session.rows[0]) {
      logger.info(`No active session found for MAC ${macAddress} — payment logged, user will auto-auth on next connect`);
      return { triggered: false, reason: 'no_active_session' };
    }

    const s = session.rows[0];

    // Register MAC as authorized in RADIUS for next connect
    await registerMACAuth({ macAddress, ispId, packageData });

    // Send CoA Disconnect to NAS — device will immediately retry, hitting new RADIUS auth
    const result = await disconnectMAC({
      nasIp: s.nas_ip,
      nasPort: s.nas_port,
      secret: s.secret,
      macAddress,
      sessionId: s.radius_session_id,
      framedIp: s.ip_address
    });

    // Update session status
    await query(`UPDATE hotspot_sessions SET status='closed', ended_at=NOW() WHERE id=$1`, [s.session_id]);

    return { triggered: true, coaResult: result };
  } catch (err) {
    logger.error('triggerMACReconnect error:', err.message);
    return { triggered: false, error: err.message };
  }
}

// ── Register MAC address as authorized in RADIUS ─────────────
async function registerMACAuth({ macAddress, ispId, packageData, expiresAt, voucherUsername }) { /* RL_MAC_USERNAME_REMAP */ /* RL_MAC_AUTORECONNECT */
  const mac = normalizeMac(macAddress);              // lowercase-colon
  const macUpper = mac.toUpperCase();                // uppercase-colon (MikroTik may send either)
  const macForms = [mac, macUpper];
  const username = mac; // MAC = username in MAC auth

  try {
    // Remove any existing RADIUS reject for this MAC
    await query(`DELETE FROM radcheck WHERE username=$1 AND attribute='Auth-Type'`, [mac]);

    // RL_MACAUTH_ACCEPT: MikroTik mac-as-username sends an EMPTY password, so we
    // authorize on the username (MAC) alone via Auth-Type := Accept. Store BOTH
    // cases to match whatever case MikroTik sends.
    for (const mform of macForms) {
      await query(`DELETE FROM radcheck WHERE username=$1`, [mform]);
      await query(`
        INSERT INTO radcheck (username, attribute, op, value)
        VALUES ($1, 'Auth-Type', ':=', 'Accept')
      `, [mform]);
    }

    // RL_MAC_USERNAME_REMAP: attribute the MAC-auth session to the voucher by
    // returning User-Name = realmed voucher name. NAS uses this for radacct + UI.
    if (voucherUsername) {
      for (const mform of macForms) {
        await query(`DELETE FROM radreply WHERE username=$1 AND attribute='User-Name'`, [mform]);
        await query(`INSERT INTO radreply (username, attribute, op, value) VALUES ($1, 'User-Name', ':=', $2)`, [mform, voucherUsername]);
      }
    }

    // Set Session-Timeout = REMAINING seconds to expiry (not a fresh full duration).
    let seconds = null;
    if (expiresAt) {
      seconds = Math.max(60, Math.floor((new Date(expiresAt).getTime() - Date.now()) / 1000));
    } else if (packageData?.duration_hours) {
      seconds = packageData.duration_hours * 3600;
    }
    if (seconds && seconds > 0) {
      for (const mform of macForms) {
        await query(`DELETE FROM radreply WHERE username=$1 AND attribute='Session-Timeout'`, [mform]);
        await query(`INSERT INTO radreply (username, attribute, op, value) VALUES ($1,'Session-Timeout','=',$2)`, [mform, String(seconds)]);
      }
    }

    // Set bandwidth (MikroTik rate limit)
    if (packageData?.bandwidth_down_mbps) {
      const up = packageData.bandwidth_up_mbps || packageData.bandwidth_down_mbps;
      const down = packageData.bandwidth_down_mbps;
      const rateLimit = `${up}M/${down}M`;
      for (const mform of macForms) {
        await query(`DELETE FROM radreply WHERE username=$1 AND attribute='Mikrotik-Rate-Limit'`, [mform]);
        await query(`INSERT INTO radreply (username, attribute, op, value) VALUES ($1,'Mikrotik-Rate-Limit','=',$2)`, [mform, rateLimit]);
      }
    }

    // Set MikroTik profile
    if (packageData?.mikrotik_profile) {
      await query(`DELETE FROM radusergroup WHERE username=$1`, [mac]);
      await query(`INSERT INTO radusergroup (username, groupname, priority) VALUES ($1,$2,1)`,
        [mac, packageData.mikrotik_profile]);
    }

    // Store MAC auth record
    await query(`
      INSERT INTO mac_auth_cache (mac_address, isp_id, package_id, authorized_at, expires_at, is_active)
      VALUES ($1,$2,$3,NOW(),$4,true)
      ON CONFLICT (mac_address) DO UPDATE SET
        isp_id=$2, package_id=$3, authorized_at=NOW(), expires_at=$4, is_active=true
    `, [mac, ispId, packageData?.id,
        packageData?.duration_hours
          ? new Date(Date.now() + packageData.duration_hours * 3600000)
          : null]);

    logger.info(`MAC ${mac} registered in RADIUS auth`);
    return true;
  } catch (err) {
    logger.error('registerMACAuth error:', err.message);
    return false;
  }
}

// ── Revoke MAC auth (on expiry) ──────────────────────────────
async function revokeMACAuth({ macAddress, ispId }) {
  const mac = normalizeMac(macAddress);
  try {
    await query(`DELETE FROM radcheck WHERE username=$1`, [mac]);
    await query(`DELETE FROM radreply WHERE username=$1`, [mac]);
    await query(`DELETE FROM radusergroup WHERE username=$1`, [mac]);
    await query(`UPDATE mac_auth_cache SET is_active=false WHERE mac_address=$1`, [mac]);

    // Find NAS and send disconnect
    const nas = await query(`
      SELECT n.nas_ip, n.nas_port, n.secret
      FROM mac_auth_cache m JOIN nas_devices n ON n.isp_id = m.isp_id
      WHERE m.mac_address=$1 LIMIT 1
    `, [mac]);

    if (nas.rows[0]) {
      await disconnectMAC({ ...nas.rows[0], macAddress: mac });
    }

    logger.info(`MAC ${mac} revoked from RADIUS`);
    return true;
  } catch (err) {
    logger.error('revokeMACAuth error:', err.message);
    return false;
  }
}

// ── Normalize MAC address format ─────────────────────────────
function normalizeMac(mac) {
  if (!mac) return '';
  return mac.toLowerCase().replace(/[^a-f0-9]/g, '')
    .match(/.{1,2}/g)?.join(':') || mac;
}

// ── Check if MAC is randomized (privacy MAC) ─────────────────
function isRandomizedMAC(mac) {
  if (!mac) return false;
  const first = parseInt(mac.replace(/[^a-f0-9]/gi, '').substring(0, 2), 16);
  // Bit 1 of first octet = locally administered (randomized)
  return (first & 0x02) !== 0;
}

module.exports = {
  disconnectMAC,
  coaUpdateSession,
  triggerMACReconnect,
  registerMACAuth,
  revokeMACAuth,
  isRandomizedMAC,
  normalizeMac,
};
