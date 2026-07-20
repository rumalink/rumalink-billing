const express = require('express');
const { query } = require('../config/database');
const { registerMACAuth, revokeMACAuth, isRandomizedMAC, normalizeMac } = require('../utils/macAuth');
const logger = require('../utils/logger');
const router = express.Router();

router.post('/authorize', async (req, res) => {
  const username = req.body['User-Name'] || req.body.User_Name || '';
  const nasIp = req.body['NAS-IP-Address'] || req.body.NAS_IP_Address || '';
  const callingStation = req.body['Calling-Station-Id'] || req.body.Calling_Station_Id || '';
  logger.info(`RADIUS Auth: user=${username} nas=${nasIp} mac=${callingStation}`);

  try {
    const isMacAuth = /^([0-9a-fA-F]{2}[:\-]){5}[0-9a-fA-F]{2}$/.test(username);

    if (isMacAuth) {
      const mac = normalizeMac(username);
      const cached = await query(`
        SELECT m.*, hp.bandwidth_down_mbps, hp.bandwidth_up_mbps, hp.duration_hours, hp.mikrotik_profile
        FROM mac_auth_cache m LEFT JOIN hotspot_packages hp ON hp.id = m.package_id
        WHERE m.mac_address=$1 AND m.is_active=true AND (m.expires_at IS NULL OR m.expires_at > NOW())
      `, [mac]);

      if (cached.rows[0]) {
        const c = cached.rows[0];
        const reply = {};
        if (c.bandwidth_down_mbps) reply['Mikrotik-Rate-Limit'] = `${c.bandwidth_up_mbps||c.bandwidth_down_mbps}M/${c.bandwidth_down_mbps}M`;
        if (c.expires_at) { const rem = Math.floor((new Date(c.expires_at)-Date.now())/1000); if(rem>0) reply['Session-Timeout']=rem; }
        if (c.mikrotik_profile) reply['Mikrotik-Group'] = c.mikrotik_profile;
        logger.info(`MAC Auth ACCEPT (cache): ${mac}`);
        return res.json({ control: { 'Auth-Type': 'Accept' }, reply });
      }

      const radcheck = await query(`SELECT * FROM radcheck WHERE username=$1 AND attribute='Cleartext-Password'`, [mac]);
      if (radcheck.rows[0]) {
        const rr = await query(`SELECT attribute, value FROM radreply WHERE username=$1`, [mac]);
        const reply = {}; rr.rows.forEach(r => { reply[r.attribute] = r.value; });
        return res.json({ control: { 'Auth-Type': 'Accept' }, reply });
      }

      return res.status(404).json({ control: { 'Auth-Type': 'Reject' }, reply: { 'Reply-Message': 'Please open the captive portal to purchase access.' } });
    }

    // Voucher auth
    const voucher = await query(`
      SELECT hv.*, hp.mikrotik_profile, hp.bandwidth_down_mbps, hp.bandwidth_up_mbps, hp.duration_hours
      FROM hotspot_vouchers hv JOIN hotspot_packages hp ON hp.id=hv.package_id
      WHERE hv.code=$1 AND hv.status IN ('unused','active')
    `, [username]);

    if (voucher.rows[0]) {
      const v = voucher.rows[0];
      const reply = {};
      if (v.bandwidth_down_mbps) reply['Mikrotik-Rate-Limit'] = `${v.bandwidth_up_mbps||v.bandwidth_down_mbps}M/${v.bandwidth_down_mbps}M`;
      if (v.expires_at) { const rem = Math.floor((new Date(v.expires_at)-Date.now())/1000); if(rem>0) reply['Session-Timeout']=rem; }
      if (v.mikrotik_profile) reply['Mikrotik-Group'] = v.mikrotik_profile;
      if (callingStation) {
        await registerMACAuth({ macAddress: callingStation, ispId: v.isp_id, packageData: { id: null, duration_hours: v.duration_hours, bandwidth_down_mbps: v.bandwidth_down_mbps, bandwidth_up_mbps: v.bandwidth_up_mbps, mikrotik_profile: v.mikrotik_profile } });
      }
      return res.json({ control: { 'Auth-Type': 'Accept' }, reply });
    }

    // PPPoE auth
    const sub = await query(`
      SELECT ps.*, pp.mikrotik_profile, pp.bandwidth_down_mbps, pp.bandwidth_up_mbps, pp.address_pool
      FROM pppoe_subscribers ps JOIN pppoe_packages pp ON pp.id=ps.package_id
      WHERE ps.username=$1 AND ps.status='active'
    `, [username]);

    if (sub.rows[0]) {
      const s = sub.rows[0];
      const reply = {};
      if (s.address_pool) reply['Framed-Pool'] = s.address_pool;
      if (s.static_ip) reply['Framed-IP-Address'] = s.static_ip;
      if (s.bandwidth_down_mbps) reply['Mikrotik-Rate-Limit'] = `${s.bandwidth_up_mbps||s.bandwidth_down_mbps}M/${s.bandwidth_down_mbps}M`;
      if (s.mikrotik_profile) reply['Mikrotik-Group'] = s.mikrotik_profile;
      return res.json({ control: { 'Auth-Type': 'Accept' }, reply });
    }

    return res.status(404).json({ control: { 'Auth-Type': 'Reject' }, reply: { 'Reply-Message': 'Access denied.' } });
  } catch (err) {
    logger.error('RADIUS authorize error:', err.message);
    return res.status(500).json({});
  }
});

router.post('/accounting', async (req, res) => {
  const st = req.body['Acct-Status-Type']||req.body.Acct_Status_Type;
  const sid = req.body['Acct-Session-Id']||req.body.Acct_Session_Id;
  const user = req.body['User-Name']||req.body.User_Name||'';
  const nasIp = req.body['NAS-IP-Address']||req.body.NAS_IP_Address||'';
  const dl = parseInt(req.body['Acct-Output-Octets']||0);
  const ul = parseInt(req.body['Acct-Input-Octets']||0);
  const dur = parseInt(req.body['Acct-Session-Time']||0);
  const ip = req.body['Framed-IP-Address']||req.body.Framed_IP_Address;
  const mac = req.body['Calling-Station-Id']||req.body.Calling_Station_Id;
  const cause = req.body['Acct-Terminate-Cause']||req.body.Acct_Terminate_Cause;
  const isMac = /^([0-9a-fA-F]{2}[:\-]){5}[0-9a-fA-F]{2}$/.test(user);

  try {
    if (st === 'Start') {
      const nas = await query(`SELECT id, isp_id FROM nas_devices WHERE nas_ip=$1 LIMIT 1`, [nasIp]);
      if (!isMac) {
        const sub = await query(`SELECT id, isp_id FROM pppoe_subscribers WHERE username=$1`, [user]);
        if (sub.rows[0]) await query(`INSERT INTO pppoe_sessions (isp_id,subscriber_id,nas_id,radius_session_id,framed_ip,nas_ip,status) VALUES ($1,$2,$3,$4,$5,$6,'active') ON CONFLICT DO NOTHING`, [sub.rows[0].isp_id,sub.rows[0].id,nas.rows[0]?.id,sid,ip,nasIp]);
      } else {
        const nMac = normalizeMac(user);
        const v = await query(`SELECT id,isp_id,nas_id FROM hotspot_vouchers WHERE used_by_mac=$1 AND status='active' ORDER BY used_at DESC LIMIT 1`, [nMac]);
        if (v.rows[0]) await query(`INSERT INTO hotspot_sessions (isp_id,voucher_id,nas_id,radius_session_id,mac_address,ip_address,nas_ip,status) VALUES ($1,$2,$3,$4,$5,$6,$7,'active') ON CONFLICT DO NOTHING`, [v.rows[0].isp_id,v.rows[0].id,nas.rows[0]?.id,sid,nMac,ip,nasIp]);
      }
    } else if (st === 'Stop') {
      const tbl = isMac ? 'hotspot_sessions' : 'pppoe_sessions';
      await query(`UPDATE ${tbl} SET status='closed',ended_at=NOW(),bytes_downloaded=$1,bytes_uploaded=$2,session_time_seconds=$3,terminate_cause=$4 WHERE radius_session_id=$5`, [dl,ul,dur,cause,sid]);
    } else if (st === 'Interim-Update') {
      const tbl = isMac ? 'hotspot_sessions' : 'pppoe_sessions';
      await query(`UPDATE ${tbl} SET bytes_downloaded=$1,bytes_uploaded=$2,session_time_seconds=$3 WHERE radius_session_id=$4`, [dl,ul,dur,sid]);
      if (isMac) {
        const nMac = normalizeMac(user);
        const c = await query(`SELECT expires_at FROM mac_auth_cache WHERE mac_address=$1 AND is_active=true`, [nMac]);
        if (c.rows[0]?.expires_at && new Date(c.rows[0].expires_at) < new Date()) await revokeMACAuth({ macAddress: nMac });
      }
    }
  } catch (err) { logger.error('RADIUS acct error:', err.message); }
  res.json({});
});

router.post('/post-auth', (req, res) => res.json({}));
router.post('/mac-cookie', async (req, res) => {
  const { mac } = req.body;
  if (!mac) return res.json({ valid: false });
  try {
    const r = await query(`SELECT m.*, hp.bandwidth_down_mbps, hp.bandwidth_up_mbps FROM mac_auth_cache m LEFT JOIN hotspot_packages hp ON hp.id=m.package_id WHERE m.mac_address=$1 AND m.is_active=true AND (m.expires_at IS NULL OR m.expires_at > NOW())`, [normalizeMac(mac)]);
    res.json({ valid: !!r.rows[0], package: r.rows[0] || null });
  } catch (e) { res.json({ valid: false }); }
});
router.get('/mac-check/:mac', (req, res) => {
  res.json({ mac: req.params.mac, randomized: isRandomizedMAC(req.params.mac), normalized: normalizeMac(req.params.mac) });
});

module.exports = router;
