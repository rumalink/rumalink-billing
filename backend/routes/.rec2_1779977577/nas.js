const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();

// ============================================================
// MIKROTIK PROVISIONING ENDPOINT (no auth - uses token)
// ============================================================
router.post('/provision/:token', async (req, res, next) => {
  const { token } = req.params;
  try {
    const device = await query(
      'SELECT * FROM nas_devices WHERE provision_token = $1 AND is_provisioned = false',
      [token]
    );
    
    if (!device.rows[0]) {
      return res.status(404).json({ error: 'Invalid or already used provisioning token' });
    }

    const nas = device.rows[0];
    const { identity, version, board, mac, wan_ip, nas_ip, nas_port } = req.body;

    // Generate RADIUS secret for this device
    const radiusSecret = `RML${uuidv4().replace(/-/g, '').substring(0, 16)}`;

    const updated = await query(`
      UPDATE nas_devices SET
        mikrotik_identity = $1,
        mikrotik_version = $2,
        mikrotik_board = $3,
        mikrotik_mac = $4,
        wan_ip = $5,
        nas_ip = COALESCE($6, wan_ip),
        nas_port = COALESCE($7, 3799),
        secret = $8,
        is_provisioned = true,
        provisioned_at = NOW(),
        is_online = true,
        last_seen = NOW(),
        updated_at = NOW()
      WHERE id = $9
      RETURNING *
    `, [identity, version, board, mac, wan_ip, nas_ip, nas_port, radiusSecret, nas.id]);

    // Return configuration to MikroTik
    const serverIp = process.env.RADIUS_HOST || 'your_server_ip';
    
    res.json({
      success: true,
      message: 'Device provisioned successfully',
      config: {
        radius_server: serverIp,
        radius_port_auth: 1812,
        radius_port_acct: 1813,
        radius_secret: radiusSecret,
        nas_identifier: nas.id,
        // Hotspot config
        hotspot_login_url: `${process.env.BASE_URL}/hotspot/${nas.isp_id}/login`,
        hotspot_walled_garden: [`${process.env.BASE_URL}`, 'rumalink.co.ke'],
        // API access
        api_endpoint: process.env.BASE_URL,
        api_key: (await query('SELECT api_key FROM isps WHERE id = $1', [nas.isp_id])).rows[0]?.api_key
      }
    });

    // Notify ISP via socket
    const io = req.app.get('io');
    io.to(`isp_${nas.isp_id}`).emit('device_provisioned', {
      device_id: nas.id,
      identity: identity,
      message: 'MikroTik device successfully provisioned!'
    });

    // Create notification
    await query(`
      INSERT INTO notifications (isp_id, type, title, message, link)
      VALUES ($1, 'success', 'Device Provisioned', $2, '/dashboard/devices')
    `, [nas.isp_id, `MikroTik device "${identity}" has been successfully provisioned and is ready to use.`]);

  } catch (err) { next(err); }
});

// Heartbeat from MikroTik
router.post('/heartbeat/:token', async (req, res, next) => {
  const { token } = req.params;
  const { active_hotspot_users, active_pppoe_users, cpu_load, memory_free } = req.body;
  try {
    await query(`
      UPDATE nas_devices SET is_online = true, last_seen = NOW(), updated_at = NOW()
      WHERE provision_token = $1
    `, [token]);
    res.json({ status: 'ok' });
  } catch (err) { next(err); }
});

// ============================================================
// ISP DEVICE MANAGEMENT (auth required)
// ============================================================
router.use(authenticateToken, requireISP);

// Get all devices for ISP
router.get('/', async (req, res, next) => {
  try {
    const result = await query(`
      SELECT id, name, description, nas_ip, wan_ip, is_provisioned, is_online,
             hotspot_enabled, pppoe_enabled, provision_token, provisioned_at,
             mikrotik_identity, mikrotik_version, mikrotik_board, last_seen,
             created_at
      FROM nas_devices WHERE isp_id = $1 ORDER BY created_at DESC
    `, [req.user.ispId]);
    res.json({ devices: result.rows });
  } catch (err) { next(err); }
});

// Add new device (creates provisioning token/link)
router.post('/', async (req, res, next) => {
  const {
    name, description,
    antishare_enabled, antishare_max_devices, bridged_ports,
    wan_interface, hotspot_interface, hotspot_gateway, hotspot_network,
    hotspot_pool_start, hotspot_pool_end
  } = req.body;
  if (!name) return res.status(400).json({ error: 'Device name is required' });

  try {
    const token = uuidv4();
    const provisionUrl = `${process.env.BASE_URL}/api/provision/${token}`;

    const result = await query(`
      INSERT INTO nas_devices (isp_id, name, description, provision_token, provision_url,
        antishare_enabled, antishare_max_devices, bridged_ports)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING id, name, description, provision_token, provision_url, created_at
    `, [req.user.ispId, name, description || null, token, provisionUrl,
        antishare_enabled || false, antishare_max_devices || 1,
        JSON.stringify(bridged_ports || ['ether2','ether3','ether4','wlan1'])]);

    // Build the full one-command provisioning fetch that MikroTik pastes
    const provBody = [
      'identity=[/system identity get name]',
      'version=[/system package get [find name=routeros] version]',
      'board=[/system resource get board-name]',
      `antishare_enabled=${antishare_enabled ? 'true' : 'false'}`,
      `antishare_max_devices=${antishare_max_devices || 1}`,
      `bridged_ports=${(bridged_ports || ['ether2','ether3','ether4','wlan1']).join(',')}`,
      `wan_interface=${wan_interface || 'ether1'}`,
      `hotspot_interface=${hotspot_interface || 'bridge-local'}`,
      `hotspot_gateway=${hotspot_gateway || '192.168.88.1'}`,
      `hotspot_network=${hotspot_network || '192.168.88.0/24'}`,
      `hotspot_pool_start=${hotspot_pool_start || '192.168.88.10'}`,
      `hotspot_pool_end=${hotspot_pool_end || '192.168.88.250'}`
    ].join('&');

    // Full MikroTik provisioning command
    const mikrotikScript = `/tool fetch url="${provisionUrl}" http-method=post http-data="${provBody}" output=user as-value`;

    // Generate full config by calling provision internally
    let fullConfig = null;
    try {
      const axios = require('axios');
      const provRes = await axios.post(provisionUrl, {
        identity: name, version: 'unknown', board: 'unknown', mac: 'pending',
        wan_ip: '0.0.0.0',
        antishare_enabled, antishare_max_devices,
        bridged_ports: bridged_ports || ['ether2','ether3','ether4','wlan1'],
        wan_interface: wan_interface || 'ether1',
        hotspot_interface: hotspot_interface || 'bridge-local',
        hotspot_gateway: hotspot_gateway || '192.168.88.1',
        hotspot_network: hotspot_network || '192.168.88.0/24',
        hotspot_pool_start: hotspot_pool_start || '192.168.88.10',
        hotspot_pool_end: hotspot_pool_end || '192.168.88.250',
      }, { timeout: 10000 });
      fullConfig = provRes.data?.config;
    } catch (provErr) {
      logger.warn('Could not pre-fetch provision config:', provErr.message);
    }

    // Reset provisioned status if pre-fetch ran it
    await query('UPDATE nas_devices SET is_provisioned=false, provisioned_at=null WHERE provision_token=$1', [token]);

    res.status(201).json({
      device: result.rows[0],
      provision_url: provisionUrl,
      config: fullConfig,
      mikrotik_script: mikrotikScript
    });
  } catch (err) { next(err); }
});

// Get device detail
router.get('/:id', async (req, res, next) => {
  try {
    const result = await query(
      'SELECT * FROM nas_devices WHERE id = $1 AND isp_id = $2',
      [req.params.id, req.user.ispId]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Device not found' });

    // Get session counts
    const sessions = await query(`
      SELECT 
        (SELECT COUNT(*) FROM hotspot_sessions WHERE nas_id = $1 AND status = 'active') as hotspot_sessions,
        (SELECT COUNT(*) FROM pppoe_sessions WHERE nas_id = $1 AND status = 'active') as pppoe_sessions
    `, [req.params.id]);

    res.json({ device: result.rows[0], sessions: sessions.rows[0] });
  } catch (err) { next(err); }
});

// Update device
router.put('/:id', async (req, res, next) => {
  const { name, description, hotspot_enabled, pppoe_enabled, hotspot_profile, pppoe_pool, winbox_port } = req.body;
  try {
    const result = await query(`
      UPDATE nas_devices SET name=$1, description=$2, hotspot_enabled=$3, pppoe_enabled=$4,
             hotspot_profile=$5, pppoe_pool=$6, winbox_port=$7, updated_at=NOW()
      WHERE id=$8 AND isp_id=$9
      RETURNING *
    `, [name, description, hotspot_enabled, pppoe_enabled, hotspot_profile, pppoe_pool, winbox_port, req.params.id, req.user.ispId]);

    if (!result.rows[0]) return res.status(404).json({ error: 'Device not found' });
    res.json({ device: result.rows[0] });
  } catch (err) { next(err); }
});

// Delete device
router.delete('/:id', async (req, res, next) => {
  try {
    await query('DELETE FROM nas_devices WHERE id = $1 AND isp_id = $2', [req.params.id, req.user.ispId]);
    res.json({ message: 'Device removed' });
  } catch (err) { next(err); }
});

// Regenerate provision token
router.post('/:id/regenerate-token', async (req, res, next) => {
  try {
    const token = uuidv4();
    const provisionUrl = `${process.env.BASE_URL}/api/provision/${token}`;
    const result = await query(
      `UPDATE nas_devices SET provision_token=$1, provision_url=$2, is_provisioned=false, updated_at=NOW()
       WHERE id=$3 AND isp_id=$4 RETURNING provision_token, provision_url`,
      [token, provisionUrl, req.params.id, req.user.ispId]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Device not found' });
    res.json({
      provision_token: result.rows[0].provision_token,
      provision_url: result.rows[0].provision_url,
      mikrotik_script: generateMikrotikScript(provisionUrl)
    });
  } catch (err) { next(err); }
});

module.exports = router;
