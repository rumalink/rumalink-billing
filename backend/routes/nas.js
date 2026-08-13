/* RL_NO_FAKE_DEFAULTS: these fields defaulted to 192.168.88.x — MikroTik's factory
   addressing — whenever a device was added without them. provision.js allocates the real
   per-router network, so the stored literals described a network that never existed and
   the device page showed the wrong gateway. Leave them null; nas-config-sync fills them
   in from the router once it is reachable. */
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
  // ─── v58: RADIUS-HEARTBEAT-CHECK — verify /radius entry exists on router ───
  // If router lost config (reboot, factory reset), restore it
  try {
    const nasId = req.params.nasId || req.body.nas_id;
    if (nasId) {
      // Run async check, don't block heartbeat response
      setImmediate(async () => {
        try {
          const r = await query(
            `SELECT id, wireguard_ip, mikrotik_api_user, mikrotik_api_password, radius_secret
             FROM nas_devices WHERE id = $1::uuid LIMIT 1`,
            [nasId]
          );
          if (!r.rows[0] || !r.rows[0].radius_secret) return;
          const { wireguard_ip, mikrotik_api_user, mikrotik_api_password, radius_secret } = r.rows[0];
          const axios = require('axios');
          const baseURL = `http://${wireguard_ip}/rest`;
          const auth = { username: mikrotik_api_user, password: mikrotik_api_password };
          const entries = await axios.get(baseURL + '/radius', { auth, timeout: 5000 });
          const hasVps = (entries.data || []).some(e => e.address === '10.8.0.1');
          if (!hasVps) {
            require('../utils/logger').warn(`[RADIUS-HEARTBEAT-CHECK] missing /radius entry on ${wireguard_ip} - restoring`);
            await axios.put(baseURL + '/radius', {
              address: '10.8.0.1',
              secret: radius_secret,
              service: 'hotspot,login',
              timeout: '3s',
              'src-address': wireguard_ip,
              'authentication-port': '1812',
              'accounting-port': '1813',
              comment: 'RumaLink-VPS'
            }, { auth, timeout: 5000 });
            require('../utils/logger').info(`[RADIUS-HEARTBEAT-CHECK] /radius entry restored on ${wireguard_ip}`);
          }
        } catch(e) { /* silently */ }
      });
    }
  } catch(e) {}
  
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

    /* RL_WINBOX_ALLOC: winbox_port used to default to 8291 — the port on the ROUTER, not a
       forwarding port on this server. Every device claimed the same number and none of them fell
       inside the 20001-20050 range the firewall opens, so remote access only ever worked where
       somebody assigned a port by hand. Take the next free one at creation. */
    let _winboxPort = null;
    try {
      const _used = (await query('SELECT winbox_port FROM nas_devices WHERE winbox_port IS NOT NULL')).rows
        .map(function (r) { return parseInt(r.winbox_port, 10); }).filter(function (n) { return n >= 20001 && n <= 20050; });
      for (let _p = 20001; _p <= 20050; _p++) {
        if (_used.indexOf(_p) === -1) { _winboxPort = _p; break; }
      }
      if (!_winboxPort) require('../utils/logger').warn('[nas] no free WinBox port in 20001-20050 — remote access unavailable for this device');
    } catch (e) { require('../utils/logger').warn('[nas] winbox port: ' + e.message); }

    const result = await query(`
      INSERT INTO nas_devices (isp_id, name, description, provision_token, provision_url,
        antishare_enabled, antishare_max_devices, bridged_ports, winbox_port)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
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
      `hotspot_gateway=${hotspot_gateway || null}`,
      `hotspot_network=${hotspot_network || null}`,
      `hotspot_pool_start=${hotspot_pool_start || null}`,
      `hotspot_pool_end=${hotspot_pool_end || null}`
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
        hotspot_gateway: hotspot_gateway || null,
        hotspot_network: hotspot_network || null,
        hotspot_pool_start: hotspot_pool_start || null,
        hotspot_pool_end: hotspot_pool_end || null,
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
      'SELECT * FROM nas_devices WHERE id = $1::uuid AND isp_id = $2::uuid',
      [req.params.id, req.user.ispId]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Device not found' });

    // Get session counts (safe: each in its own try, default to 0 if table missing/perms)
    let hotspot_sessions = 0, pppoe_sessions = 0;
    try {
      const r = await query("SELECT COUNT(*)::int as c FROM hotspot_sessions WHERE nas_id = $1::uuid AND status = 'active'", [req.params.id]);
      hotspot_sessions = r.rows[0]?.c || 0;
    } catch(e) {}
    try {
      const r = await query("SELECT COUNT(*)::int as c FROM pppoe_sessions WHERE nas_id = $1::uuid AND status = 'active'", [req.params.id]);
      pppoe_sessions = r.rows[0]?.c || 0;
    } catch(e) {}

    // Get WireGuard handshake info if device has a WG IP
    let wg_last_handshake_seconds = null;
    const dev = result.rows[0];
    if (dev.wireguard_public_key) {
      try {
        const { execSync } = require('child_process');
        const dump = execSync('sudo -n wg show wg0 dump 2>/dev/null', { stdio: ['pipe','pipe','ignore'] }).toString();
        // Format: privkey pubkey psk endpoint allowed-ips latest-handshake rx tx keepalive
        // After header line, peer lines start with their pubkey
        const lines = dump.split('\n');
        for (const line of lines) {
          const parts = line.split('\t');
          if (parts[0] === dev.wireguard_public_key) {
            const ts = parseInt(parts[4]);
            if (ts > 0) wg_last_handshake_seconds = Math.floor(Date.now()/1000) - ts;
            break;
          }
        }
      } catch(e) {}
    }

    res.json({ device: { ...dev, wg_last_handshake_seconds }, sessions: { hotspot_sessions, pppoe_sessions } });
  } catch (err) { 
    require('../utils/logger').error('NAS GET /:id error:', err.message);
    res.status(500).json({ error: err.message });
  }
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



// ─── Phase C: REST API to router via WireGuard tunnel ───
const mt = require('../utils/mikrotik');

// GET /api/nas/:id/test-tunnel — actively test reachability via WG
/* RL_DEVICE_HEALTH: one call for everything the router can tell us about itself. Split across
   several endpoints it would mean several round trips, and this page already waits on enough.
   Cached briefly because a router's health does not change between two clicks, and a page that
   stalls on the API is a page nobody opens. */
const _rlDevHealth = new Map();
router.get('/:id/health', async (req, res) => {
  try {
    const fresh = String(req.query.fresh || '') === '1';
    const key = String(req.params.id);
    const hit = _rlDevHealth.get(key);
    if (!fresh && hit && (Date.now() - hit.t) < 20000) return res.json(hit.v);

    const dr = await query(
      'SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE id=$1::uuid AND isp_id=$2::uuid',
      [req.params.id, req.user.ispId]);
    const dev = dr.rows[0];
    if (!dev) return res.status(404).json({ error: 'Device not found' });
    if (!dev.wireguard_ip) return res.json({ reachable: false, reason: 'No tunnel address yet' });

    const axios = require('axios');
    const b = 'http://' + dev.wireguard_ip + '/rest';
    const auth = { username: dev.mikrotik_api_user, password: dev.mikrotik_api_password };
    const g = async (path) => {
      try { const r = await axios.get(b + path, { auth, timeout: 9000, validateStatus: () => true });
            return (r.status === 200) ? r.data : null; } catch (e) { return null; }
    };

    const [resource, health, ifaces, hs, ppp, queues, filters, settings, profiles, routes] = await Promise.all([
      g('/system/resource'), g('/system/health'), g('/interface'),
      g('/ip/hotspot/active'), g('/ppp/active'), g('/queue/simple'),
      g('/ip/firewall/filter'), g('/ip/settings'), g('/ip/hotspot/user/profile'), g('/ip/route'),
    ]);

    if (!resource) {
      const out = { reachable: false, reason: 'Router did not answer over the tunnel' };
      _rlDevHealth.set(key, { t: Date.now(), v: out });
      return res.json(out);
    }

    const totalMem = Number(resource['total-memory']) || 0;
    const freeMem  = Number(resource['free-memory']) || 0;
    const totalHdd = Number(resource['total-hdd-space']) || 0;
    const freeHdd  = Number(resource['free-hdd-space']) || 0;

    /* The guards exist because each of these failed silently in production: fasttrack bypassed
       every simple queue, shared-users=1 overrode the per-package limit RADIUS sends, and an
       accept rule above the expiry rules let expired customers keep browsing. Config that looks
       right and behaves wrong is the expensive kind, so show it plainly. */
    const fwd = (filters || []).filter(x => x.chain === 'forward');
    const ftRules = (filters || []).filter(x => x.action === 'fasttrack-connection').length;
    const acceptIdx = fwd.findIndex(x => x.action === 'accept' &&
      String(x['connection-state'] || '') === 'established,related' && !x['src-address-list']);
    const lastExpired = fwd.map((x, i) => String(x['src-address-list'] || '') === 'rl-expired' ? i : -1)
      .reduce((a, c) => Math.max(a, c), -1);
    const sharedUsers = (profiles || []).map(x => Number(x['shared-users'] || 1));
    const defaultRoutes = (routes || []).filter(x => String(x['dst-address'] || '') === '0.0.0.0/0');

    const checks = [
      { key: 'fasttrack', label: 'Rate limits enforced',
        ok: ftRules === 0,
        detail: ftRules === 0 ? 'No fasttrack rule' : ftRules + ' fasttrack rule(s) — queues are being bypassed' },
      { key: 'accept_order', label: 'Expiry rules take effect',
        ok: (lastExpired === -1 || acceptIdx === -1 || acceptIdx > lastExpired),
        detail: (lastExpired === -1 || acceptIdx === -1 || acceptIdx > lastExpired)
          ? 'Accept rule sits below the expiry rules'
          : 'Accept rule is ABOVE the expiry rules — expired users keep browsing' },
      { key: 'shared_users', label: 'Device limits honoured',
        ok: sharedUsers.every(n => n >= 10),
        detail: sharedUsers.every(n => n >= 10)
          ? 'Hotspot profile does not cap simultaneous logins'
          : 'A hotspot profile caps logins, overriding the package limit' },
      { key: 'radius', label: 'RADIUS configured',
        ok: !!(profiles || []).length,
        detail: (profiles || []).length + ' hotspot profile(s)' },
      { key: 'wan', label: 'Default route present',
        ok: defaultRoutes.some(r2 => String(r2.active) === 'true'),
        detail: defaultRoutes.length + ' default route(s), ' +
                defaultRoutes.filter(r2 => String(r2.active) === 'true').length + ' active' },
    ];

    const out = {
      reachable: true,
      fetched_at: new Date().toISOString(),
      system: {
        board: resource['board-name'] || null,
        version: resource.version || null,
        uptime: resource.uptime || null,
        cpu_load: Number(resource['cpu-load']) || 0,
        cpu_count: Number(resource['cpu-count']) || 1,
        cpu_freq: resource['cpu-frequency'] || null,
        mem_total_mb: Math.round(totalMem / 1048576),
        mem_free_mb: Math.round(freeMem / 1048576),
        mem_used_pct: totalMem ? Math.round(((totalMem - freeMem) / totalMem) * 100) : 0,
        disk_total_mb: Math.round(totalHdd / 1048576),
        disk_free_mb: Math.round(freeHdd / 1048576),
        disk_used_pct: totalHdd ? Math.round(((totalHdd - freeHdd) / totalHdd) * 100) : 0,
        temperature: health ? (Array.isArray(health)
          ? (health.find(h => /temp/i.test(h.name || ''))||{}).value
          : health.temperature) || null : null,
        voltage: health ? (Array.isArray(health)
          ? (health.find(h => /volt/i.test(h.name || ''))||{}).value
          : health.voltage) || null : null,
      },
      services: {
        hotspot_sessions: (hs || []).length,
        pppoe_sessions: (ppp || []).length,
        queues: (queues || []).length,
        interfaces_up: (ifaces || []).filter(x => String(x.running) === 'true').length,
        interfaces_total: (ifaces || []).length,
      },
      checks,
      checks_ok: checks.filter(c => c.ok).length,
      checks_total: checks.length,
    };
    _rlDevHealth.set(key, { t: Date.now(), v: out });
    res.json(out);
  } catch (err) {
    require('../utils/logger').warn('[device-health] ' + err.message);
    res.status(500).json({ reachable: false, reason: err.message });
  }
});

router.get('/:id/test-tunnel', async (req, res) => {
  try {
    // Confirm ownership
    const own = await query(
      'SELECT id FROM nas_devices WHERE id = $1::uuid AND isp_id = $2::uuid',
      [req.params.id, req.user.ispId]
    );
    if (!own.rows[0]) return res.status(404).json({ error: 'Device not found' });

    const result = await mt.testConnectivity(req.params.id);
    res.json(result);
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// GET /api/nas/:id/live-sessions — pull active hotspot sessions FROM the router
router.get('/:id/live-sessions', async (req, res) => {
  try {
    const own = await query(
      'SELECT id FROM nas_devices WHERE id = $1::uuid AND isp_id = $2::uuid',
      [req.params.id, req.user.ispId]
    );
    if (!own.rows[0]) return res.status(404).json({ error: 'Device not found' });

    const sessions = await mt.liveHotspotSessions(req.params.id);
    res.json({ sessions });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/nas/:id/disconnect-session/:sid — kick a user off the router
router.post('/:id/disconnect-session/:sid', async (req, res) => {
  try {
    const own = await query(
      'SELECT id FROM nas_devices WHERE id = $1::uuid AND isp_id = $2::uuid',
      [req.params.id, req.user.ispId]
    );
    if (!own.rows[0]) return res.status(404).json({ error: 'Device not found' });

    const result = await mt.disconnectHotspotSession(req.params.id, req.params.sid);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// v62.86: Live bandwidth — WAN (ISP) + aggregated client traffic (hotspot + ALL PPPoE)
// Semantic mapping (so the UI can show meaningful labels):
//   ether1.rx     = download FROM ISP  → wan.down_bps
//   ether1.tx     = upload TO ISP      → wan.up_bps
//   bridge-hotspot.tx = router pushing data TO hotspot clients  → lan.down_bps
//   bridge-hotspot.rx = clients sending data IN to router       → lan.up_bps
//   <pppoe-*>.tx  = router pushing data TO PPPoE client         → added to lan.down_bps
//   <pppoe-*>.rx  = PPPoE client sending data IN                → added to lan.up_bps
router.get('/:id/bandwidth', async (req, res) => {
  try {
    const r = await query(
      'SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password, wan_interface, hotspot_interface FROM nas_devices WHERE id = $1::uuid AND isp_id = $2::uuid',
      [req.params.id, req.user.ispId]
    );
    if (!r.rows[0]) return res.status(404).json({ error: 'Device not found' });
    const dev = r.rows[0];
    if (!dev.wireguard_ip || !dev.mikrotik_api_user || !dev.mikrotik_api_password) {
      return res.json({ error: 'API credentials not set on this device' });
    }

    const baseUrl = 'http://' + dev.wireguard_ip;
    const authHdr = 'Basic ' + Buffer.from(dev.mikrotik_api_user + ':' + dev.mikrotik_api_password).toString('base64');
    const wanIface = dev.wan_interface || 'ether1';
    const lanIface = dev.hotspot_interface || 'bridge-hotspot';

    async function monitor(iface) {
      try {
        const resp = await fetch(baseUrl + '/rest/interface/monitor-traffic', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Authorization': authHdr },
          body: JSON.stringify({ interface: iface, once: '' }),
          signal: AbortSignal.timeout(4000)
        });
        if (!resp.ok) return null;
        const data = await resp.json();
        const row = Array.isArray(data) ? data[0] : data;
        if (!row) return null;
        return {
          iface,
          rx_bps: parseInt(row['rx-bits-per-second'] || 0),
          tx_bps: parseInt(row['tx-bits-per-second'] || 0)
        };
      } catch (e) {
        return null;
      }
    }

    // Discover all running PPPoE-in interfaces (server-side, one per PPPoE session)
    let pppoeIfaces = [];
    try {
      const ifResp = await fetch(baseUrl + '/rest/interface', { headers: { 'Authorization': authHdr }, signal: AbortSignal.timeout(3000) });
      if (ifResp.ok) {
        const ifs = await ifResp.json();
        pppoeIfaces = ifs
          .filter(i => i.type === 'pppoe-in' && i.running === 'true')
          .map(i => i.name);
      }
    } catch(e) {}

    // Run WAN + bridge + all pppoe monitors in parallel
    const allIfaces = [wanIface, lanIface, ...pppoeIfaces];
    const results = await Promise.all(allIfaces.map(monitor));

    const wanR = results[0];
    const bridgeR = results[1];
    const pppoeRs = results.slice(2).filter(x => x !== null);

    // Aggregate client traffic
    let lanDownBps = bridgeR ? bridgeR.tx_bps : 0; // router → clients
    let lanUpBps   = bridgeR ? bridgeR.rx_bps : 0; // clients → router
    for (const p of pppoeRs) {
      lanDownBps += p.tx_bps;
      lanUpBps   += p.rx_bps;
    }

    res.json({
      ok: true,
      wan: wanR ? {
        iface: wanR.iface,
        // Semantic: which direction is which
        down_bps: wanR.rx_bps,  // from ISP (downloading)
        up_bps:   wanR.tx_bps,  // to ISP (uploading)
        // Backward compat:
        rx_bps: wanR.rx_bps,
        tx_bps: wanR.tx_bps
      } : null,
      lan: {
        iface: lanIface + (pppoeRs.length ? ` + ${pppoeRs.length} PPPoE` : ''),
        bridge_iface: lanIface,
        pppoe_sessions: pppoeIfaces,
        down_bps: lanDownBps,  // router → clients (client downloads)
        up_bps:   lanUpBps,    // clients → router (client uploads)
        // Backward compat (but with swapped semantics):
        rx_bps: lanUpBps,
        tx_bps: lanDownBps,
        breakdown: {
          hotspot: bridgeR ? { down_bps: bridgeR.tx_bps, up_bps: bridgeR.rx_bps } : null,
          pppoe: pppoeRs.map(p => ({ iface: p.iface, down_bps: p.tx_bps, up_bps: p.rx_bps }))
        }
      }
    });
  } catch (err) {
    require('../utils/logger').error('[nas bandwidth] ' + err.message);
    res.json({ error: err.message });
  }
});




// v62.87: ISP link status — current state for one device
/* RL_LIVE_CONNS: live per-WAN connection view.
   PCC stamps every new connection with rl_conn_wanN. That mark is the ONLY reliable way to say
   which uplink a flow actually took — byte counters tell you the aggregate, but not who went
   where. Reading it back gives a true picture of whether the hash is obeying the weights. */

// Destination IP ranges -> service. Everything is HTTPS on 443, so this is attribution by IP
// OWNERSHIP, not packet inspection. DPI on a 600MHz RB951 would cripple the router, so we do
// not attempt it. CDN-hosted services may surface as their CDN rather than the app.
const RL_SERVICES = [
  { re: /^(142\.250\.|172\.217\.|216\.58\.|74\.125\.|173\.194\.|64\.233\.)/, name: 'YouTube / Google', icon: '▶', color: '#e74c3c' },
  { re: /^(157\.240\.|31\.13\.|179\.60\.|129\.134\.|66\.220\.)/,              name: 'Meta (FB/IG/WA)', icon: 'f', color: '#5eb3ff' },
  { re: /^(23\.6[0-9]\.|23\.[4-5][0-9]\.|104\.9[0-9]\.|2\.16\.)/,               name: 'Akamai CDN',      icon: '◆', color: '#f0a020' },
  { re: /^(13\.2[0-9]\.|52\.|54\.|3\.[0-9])/,                                      name: 'AWS',             icon: '☁', color: '#f0a020' },
  { re: /^(104\.1[6-9]\.|172\.6[4-9]\.|1\.1\.1\.1|1\.0\.0\.1)/,              name: 'Cloudflare',      icon: '☁', color: '#c678dd' },
  { re: /^(151\.101\.|199\.232\.)/,                                                 name: 'Fastly CDN',      icon: '◆', color: '#f0a020' },
  { re: /^(8\.8\.8\.8|8\.8\.4\.4|9\.9\.9\.9|208\.67\.)/,                    name: 'DNS',             icon: '◉', color: '#7788aa' },
  { re: /^(140\.82\.|192\.30\.|185\.199\.)/,                                      name: 'GitHub',          icon: '⌥', color: '#8899bb' },
  { re: /^(17\.[0-9]+\.)/,                                                            name: 'Apple',           icon: '', color: '#8899bb' },
  { re: /^(204\.79\.|13\.107\.|40\.[0-9]+\.)/,                                    name: 'Microsoft',       icon: '⊞', color: '#5eb3ff' },
];
function rlIdentify(ip) {
  for (const s of RL_SERVICES) if (s.re.test(ip)) return s;
  return { name: null, icon: '·', color: '#7788aa' };
}

router.get('/:id/connections', async (req, res) => {
  try {
    const r = await query(
      `SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password, multi_wan_mode
         FROM nas_devices WHERE id = $1::uuid AND isp_id = $2::uuid`,
      [req.params.id, req.user.ispId]);
    const dev = r.rows[0];
    if (!dev) return res.status(404).json({ error: 'Device not found' });
    if (!dev.wireguard_ip) return res.json({ ok: true, conns: [], wans: [], note: 'no tunnel' });

    const links = (await query(
      'SELECT position, interface, name, lb_weight, in_load_balance FROM nas_wan_links WHERE nas_id = $1::uuid ORDER BY position',
      [req.params.id])).rows;

    const auth = 'Basic ' + Buffer.from(dev.mikrotik_api_user + ':' + dev.mikrotik_api_password).toString('base64');
    const resp = await fetch('http://' + dev.wireguard_ip + '/rest/ip/firewall/connection',
      { headers: { Authorization: auth, Accept: 'application/json' }, signal: AbortSignal.timeout(12000) });
    if (!resp.ok) throw new Error('router HTTP ' + resp.status);
    const raw = await resp.json();

    const wans = {};
    links.forEach(l => { wans['rl_conn_wan' + l.position] = {
      position: l.position, interface: l.interface, weight: l.lb_weight,
      flows: 0, bytes: 0, in_lb: l.in_load_balance }; });

    const conns = [];
    for (const c of (raw || [])) {
      const mark = c['connection-mark'];
      if (!mark || !wans[mark]) continue;   // unmarked = the router's own traffic, not a customer

      const dst = String(c['dst-address'] || '').split(':')[0];
      const src = String(c['src-address'] || '').split(':')[0];
      const port = String(c['dst-address'] || '').split(':')[1] || '';
      const bytes = Number(c['orig-bytes'] || 0) + Number(c['repl-bytes'] || 0);
      const svc = rlIdentify(dst);

      wans[mark].flows++;
      wans[mark].bytes += bytes;

      conns.push({
        src, dst, port, bytes,
        proto: c.protocol || '',
        wan: wans[mark].position,
        iface: wans[mark].interface,
        service: svc.name, icon: svc.icon, color: svc.color,
        timeout: c.timeout || '',
      });
    }
    conns.sort((a, b) => b.bytes - a.bytes);

    res.json({ ok: true, conns: conns.slice(0, 40), wans: Object.values(wans),
               total: conns.length, mode: dev.multi_wan_mode });
  } catch (err) {
    require('../utils/logger').error('[connections] ' + err.message);
    res.status(500).json({ error: 'Failed to read connections', detail: err.message });
  }
});

router.get('/:id/link-status', async (req, res) => {
  try {
    const r = await query(
      `SELECT id, name, isp_link_status, isp_link_changed_at, isp_link_last_checked, isp_link_consecutive_failures, isp_link_notifications_enabled
       FROM nas_devices WHERE id = $1::uuid AND isp_id = $2::uuid`,
      [req.params.id, req.user.ispId]
    );
    if (!r.rows[0]) return res.status(404).json({ error: 'Device not found' });
    res.json({ ok: true, ...r.rows[0] });
  } catch (err) {
    require('../utils/logger').error('[link-status] ' + err.message);
    res.status(500).json({ error: err.message });
  }
});

// v62.87: ISP link event history — last N events from nas_events table
router.get('/:id/link-events', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const r = await query(
      `SELECT id, event_type, message, created_at
       FROM nas_events
       WHERE nas_id = $1::uuid AND isp_id = $2::uuid
         AND event_type IN ('isp_link_down', 'isp_link_up', 'isp_link_check_failed')
       ORDER BY created_at DESC LIMIT $3`,
      [req.params.id, req.user.ispId, limit]
    );
    res.json({ ok: true, events: r.rows });
  } catch (err) {
    require('../utils/logger').error('[link-events] ' + err.message);
    res.status(500).json({ error: err.message });
  }
});

// v62.87: Manual ISP link check — trigger immediate ping test
router.post('/:id/link-check', async (req, res) => {
  try {
    const r = await query(
      `SELECT id, wireguard_ip, mikrotik_api_user, mikrotik_api_password
       FROM nas_devices WHERE id = $1::uuid AND isp_id = $2::uuid`,
      [req.params.id, req.user.ispId]
    );
    if (!r.rows[0]) return res.status(404).json({ error: 'Device not found' });
    const dev = r.rows[0];
    if (!dev.wireguard_ip || !dev.mikrotik_api_user) {
      return res.status(400).json({ error: 'Device not provisioned' });
    }

    // Trigger immediate check via the monitor
    const { checkSingleDevice } = require('../utils/isp-monitor');
    const result = await checkSingleDevice(req.params.id);
    res.json({ ok: true, ...result });
  } catch (err) {
    require('../utils/logger').error('[link-check] ' + err.message);
    res.status(500).json({ error: err.message });
  }
});

// v62.87: Toggle SMS notifications for this device
router.put('/:id/link-notifications', async (req, res) => {
  try {
    const { enabled } = req.body;
    const r = await query(
      `UPDATE nas_devices SET isp_link_notifications_enabled = $1
       WHERE id = $2::uuid AND isp_id = $3::uuid
       RETURNING isp_link_notifications_enabled`,
      [!!enabled, req.params.id, req.user.ispId]
    );
    if (!r.rows[0]) return res.status(404).json({ error: 'Device not found' });
    res.json({ ok: true, enabled: r.rows[0].isp_link_notifications_enabled });
  } catch (err) {
    require('../utils/logger').error('[link-notifications] ' + err.message);
    res.status(500).json({ error: err.message });
  }
});




// v62.96: Multi-WAN unlimited links + policy engine

router.get('/:id/multi-wan', async (req, res) => {
  try {
    const r = await query(
      `SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password,
              multi_wan_mode, multi_wan_check_interval, multi_wan_fail_threshold,
              pcc_mode, multi_wan_applied_at,
              wan_quality_enabled, wan_quality_latency_ms, wan_quality_jitter_ms, wan_quality_loss_pct, wan_quality_trip_count, wan_quality_recover_count /* RL_QUALITY_DASH */
       FROM nas_devices WHERE id = $1::uuid AND isp_id = $2::uuid`,
      [req.params.id, req.user.ispId]
    );
    if (!r.rows[0]) return res.status(404).json({ error: 'Device not found' });
    const dev = r.rows[0];

    const links = await query(
      `SELECT id, position, name, interface, gateway, ping_target, role, lb_weight, enabled, current_status, in_load_balance, is_failover, failover_priority,
              probe_verdict, probe_stage, fetch_ms, consec_fetch_fail, internet_ok, last_fetch_at
       FROM nas_wan_links WHERE nas_id = $1::uuid ORDER BY position ASC`   /* RL_PROBE_UI: the real-internet verdict must reach the UI */,
      [req.params.id]
    );
    const policies = await query(
      `SELECT id, priority, name, match_type, match_value, action_type, target_link_id, target_link_ids, enabled
       FROM nas_wan_policies WHERE nas_id = $1::uuid ORDER BY priority ASC`,
      [req.params.id]
    );

    let availableInterfaces = ['ether1','ether2','ether3','ether4','ether5'];
    if (dev.wireguard_ip && dev.mikrotik_api_user) {
      try {
        const baseUrl = 'http://' + dev.wireguard_ip;
        const authHdr = 'Basic ' + Buffer.from(dev.mikrotik_api_user + ':' + dev.mikrotik_api_password).toString('base64');
        const ifResp = await fetch(baseUrl + '/rest/interface/ethernet', {
          headers: { 'Authorization': authHdr },
          signal: AbortSignal.timeout(3000)
        });
        if (ifResp.ok) {
          const ifs = await ifResp.json();
          availableInterfaces = ifs.map(i => i.name).sort();
        }
      } catch(e) {}
    }

    const pppoePkg = await query('SELECT id, name FROM pppoe_packages WHERE isp_id = $1::uuid AND is_active = true ORDER BY name', [req.user.ispId]);
    const hsPkg = await query('SELECT id, name FROM hotspot_packages WHERE isp_id = $1::uuid AND is_active = true ORDER BY name', [req.user.ispId]);
    const subs = await query("SELECT id, username, full_name FROM pppoe_subscribers WHERE isp_id = $1::uuid AND status = 'active' ORDER BY username LIMIT 200", [req.user.ispId]);

    res.json({
      ok: true,
      config: {
        mode: dev.multi_wan_mode || 'none',
        check_interval_sec: dev.multi_wan_check_interval || 10,
        fail_threshold: dev.multi_wan_fail_threshold || 3,
        wan_quality_enabled: dev.wan_quality_enabled !== false,
        wan_quality_latency_ms: dev.wan_quality_latency_ms || 100,
        wan_quality_jitter_ms: dev.wan_quality_jitter_ms || 30,
        wan_quality_loss_pct: dev.wan_quality_loss_pct || 2,
        wan_quality_trip_count: dev.wan_quality_trip_count || 3,
        wan_quality_recover_count: dev.wan_quality_recover_count || 20, /* RL_QUALITY_DASH */
        pcc_mode: dev.pcc_mode || 'both-addresses',
        applied_at: dev.multi_wan_applied_at
      },
      links: links.rows,
      policies: policies.rows,
      available_interfaces: availableInterfaces,
      pppoe_packages: pppoePkg.rows,
      hotspot_packages: hsPkg.rows,
      pppoe_subscribers: subs.rows
    });
  } catch (err) {
    require('../utils/logger').error('[multi-wan GET] ' + err.message);
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id/multi-wan', async (req, res) => {
  try {
    const b = req.body || {};
    const validModes = ['none','failover','load_balance','both'];
    if (!validModes.includes(b.mode)) {
      return res.status(400).json({ error: 'Invalid mode' });
    }

    const dev = await query(
      'SELECT id FROM nas_devices WHERE id = $1::uuid AND isp_id = $2::uuid',
      [req.params.id, req.user.ispId]
    );
    if (!dev.rows[0]) return res.status(404).json({ error: 'Device not found' });

    const links = Array.isArray(b.links) ? b.links : [];
    const ifaces = links.map(l => l.interface);
    if (new Set(ifaces).size !== ifaces.length) {
      return res.status(400).json({ error: 'Each link must use a unique interface' });
    }

    await query(
      `UPDATE nas_devices SET
         multi_wan_mode = $1,
         multi_wan_check_interval = $2,
         multi_wan_fail_threshold = $3,
         pcc_mode = $4,
         wan_quality_enabled = $7,
         wan_quality_latency_ms = $8,
         wan_quality_jitter_ms = $9,
         wan_quality_loss_pct = $10,
         wan_quality_trip_count = $11,
         wan_quality_recover_count = $12
       WHERE id = $5::uuid AND isp_id = $6::uuid`,
      [
        b.mode,
        parseInt(b.check_interval_sec) || 10,
        parseInt(b.fail_threshold) || 3,
        b.pcc_mode || 'both-addresses',
        req.params.id,
        req.user.ispId,
        b.wan_quality_enabled !== false,
        parseInt(b.wan_quality_latency_ms) || 100,
        parseInt(b.wan_quality_jitter_ms) || 30,
        parseInt(b.wan_quality_loss_pct) || 2,
        parseInt(b.wan_quality_trip_count) || 3,
        parseInt(b.wan_quality_recover_count) || 20
      ]
    );

    await query('DELETE FROM nas_wan_policies WHERE nas_id = $1::uuid', [req.params.id]);

    const incomingLinkIds = links.filter(l => l.id).map(l => l.id);
    if (incomingLinkIds.length) {
      await query(
        `DELETE FROM nas_wan_links WHERE nas_id = $1::uuid AND id NOT IN (SELECT unnest($2::uuid[]))`,
        [req.params.id, incomingLinkIds]
      );
    } else {
      await query('DELETE FROM nas_wan_links WHERE nas_id = $1::uuid', [req.params.id]);
    }

    for (let i = 0; i < links.length; i++) {
      const l = links[i];
      // Multi-role flags: accept explicit flags from the UI; else derive from legacy role.
      const inLb = (l.in_load_balance !== undefined) ? !!l.in_load_balance : (l.role === 'load_balance');
      const isFo = (l.is_failover !== undefined) ? !!l.is_failover : (l.role === 'failover_primary' || l.role === 'failover_backup');
      const foPrio = (l.failover_priority !== undefined && l.failover_priority !== null && l.failover_priority !== '') ? parseInt(l.failover_priority) : null;
      // Keep legacy `role` in sync for anything still reading it (a both-link reads as load_balance).
      const role = inLb ? 'load_balance' : (isFo ? ((foPrio && foPrio > 1) ? 'failover_backup' : 'failover_primary') : 'dedicated');
      if (l.id) {
        await query(
          `UPDATE nas_wan_links SET
             position = $1, name = $2, interface = $3, gateway = $4, ping_target = $5,
             role = $6, lb_weight = $7, enabled = $8,
             in_load_balance = $9, is_failover = $10, failover_priority = $11
           WHERE id = $12::uuid AND nas_id = $13::uuid`,
          [i + 1, l.name || null, l.interface, l.gateway || null, l.ping_target || '8.8.8.8',
           role, parseInt(l.lb_weight) || 50, l.enabled !== false,
           inLb, isFo, foPrio, l.id, req.params.id]
        );
      } else {
        await query(
          `INSERT INTO nas_wan_links (nas_id, position, name, interface, gateway, ping_target, role, lb_weight, enabled, in_load_balance, is_failover, failover_priority)
           VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
          [req.params.id, i + 1, l.name || null, l.interface, l.gateway || null, l.ping_target || '8.8.8.8',
           role, parseInt(l.lb_weight) || 50, l.enabled !== false, inLb, isFo, foPrio]
        );
      }
    }

    /* RL_POLICY_POS: links are saved above, so resolve policy targets AFTER — by real uuid,
       or by position ("pos:N") for links that had no id when the policy was created in the UI.
       Also hard-validate uuids so strings like "null"/"undefined" can never reach ::uuid. */
    const _lr = await query('SELECT id, position FROM nas_wan_links WHERE nas_id = $1::uuid ORDER BY position', [req.params.id]);
    const _posToId = {}; _lr.rows.forEach(r => { _posToId[r.position] = r.id; });
    const _isUuid = v => typeof v === 'string' && /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(v);
    const _resolve = v => {
      if (!v || typeof v !== 'string') return null;
      if (v.startsWith('pos:')) return _posToId[parseInt(v.slice(4), 10)] || null;
      return _isUuid(v) ? v : null;
    };
    const policies = Array.isArray(b.policies) ? b.policies : [];
    let savedPolicies = 0;
    for (let i = 0; i < policies.length; i++) {
      const p = policies[i];
      const tid = _resolve(p.target_link_id);
      const tids = (Array.isArray(p.target_link_ids) ? p.target_link_ids : []).map(_resolve).filter(Boolean);
      if (p.action_type === 'use_link' && !tid) continue;
      if (p.action_type === 'load_balance_pool' && !tids.length) continue;
      await query(
        `INSERT INTO nas_wan_policies (nas_id, priority, name, match_type, match_value, action_type, target_link_id, target_link_ids, enabled)
         VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8::uuid[], $9)`,
        [
          req.params.id,
          i + 1,
          p.name || ('Policy ' + (i+1)),
          p.match_type,
          p.match_value || null,
          p.action_type,
          tid,
          tids,
          p.enabled !== false
        ]
      );
      savedPolicies++;
    }

    res.json({ ok: true, mode: b.mode, link_count: links.length, policy_count: savedPolicies, dropped_policies: policies.length - savedPolicies }); /* RL_POLICY_POS */
  } catch (err) {
    require('../utils/logger').error('[multi-wan PUT] ' + err.message);
    res.status(500).json({ error: err.message });
  }
});


// v62.99: Multi-WAN preview/apply/revert endpoints

router.get('/:id/multi-wan/preview', async (req, res) => {
  try {
    const applier = require('../utils/mwan-applier');
    const plan = await applier.buildPlan(req.params.id, req.user.ispId);
    // Strip out internal-only fields, return just descriptions for preview
    const previewOps = plan.ops.map(o => ({
      description: o.description,
      cleanup: !!o.cleanup,
      prepare: !!o.prepare_iface,
      method: o.method,
      path: o.path,
      body: o.body
    }));
    res.json({
      ok: true,
      mode: plan.mode,
      link_count: plan.links.length,
      policy_count: plan.policies.length,
      operations: previewOps
    });
  } catch (err) {
    require('../utils/logger').error('[multi-wan preview] ' + err.message);
    res.status(500).json({ error: err.message });
  }
});

router.post('/:id/multi-wan/apply', async (req, res) => {
  try {
    const applier = require('../utils/mwan-applier');
    const result = await applier.applyPlan(req.params.id, req.user.ispId);
    res.json(result);
  } catch (err) {
    require('../utils/logger').error('[multi-wan apply] ' + err.message);
    res.status(500).json({ error: err.message });
  }
});

router.post('/:id/multi-wan/revert', async (req, res) => {
  try {
    const applier = require('../utils/mwan-applier');
    const result = await applier.revertPlan(req.params.id, req.user.ispId);
    res.json(result);
  } catch (err) {
    require('../utils/logger').error('[multi-wan revert] ' + err.message);
    res.status(500).json({ error: err.message });
  }
});

// v62.101: Live status of each WAN link
router.get('/:id/multi-wan/link-status', async (req, res) => {
  try {
    const applier = require('../utils/mwan-applier');
    const result = await applier.getLinkStatus(req.params.id, req.user.ispId);
    res.json(result);
  } catch (err) {
    require('../utils/logger').error('[multi-wan link-status] ' + err.message);
    res.status(500).json({ error: err.message });
  }
});


module.exports = router;
