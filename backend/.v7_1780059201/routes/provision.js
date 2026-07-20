/**
 * RumaLink — MikroTik RouterOS v7 Provisioning
 *
 * POST /:token         → records device check-in, returns JSON
 * GET  /:token/script  → returns raw .rsc config (MikroTik /import runs this)
 * POST /heartbeat/:token → keepalive ping
 */

const express = require('express');
const { query } = require('../config/database');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');

const router = express.Router();

// ──────────────────────────────────────────────────────────────
// Shared helper: build device config (credentials + subnet)
// ──────────────────────────────────────────────────────────────
async function buildDeviceConfig(nas, isp) {
  let radiusSecret = nas.secret;
  if (!radiusSecret || !String(radiusSecret).startsWith('RML')) {
    radiusSecret = 'RML' + uuidv4().replace(/-/g, '').substring(0, 16).toUpperCase();
  }
  const apiUser = nas.mikrotik_api_user || ('rl_' + nas.id.substring(0, 8));
  const apiPass = nas.mikrotik_api_password || uuidv4().substring(0, 12);

  let network = nas.hotspot_network;
  if (!network) {
    let octet = 100;
    try {
      const existing = await query(
        "SELECT hotspot_network FROM nas_devices WHERE hotspot_network IS NOT NULL AND id <> $1::uuid",
        [nas.id]
      );
      const used = new Set(existing.rows.map(r => r.hotspot_network).filter(Boolean));
      while (used.has(`192.168.${octet}.0/24`)) octet++;
    } catch (e) {}
    network = `192.168.${octet}.0/24`;
  }
  const octet = network.split('.')[2];

  // WireGuard: assign next available 10.8.0.x and generate keypair if missing
  let wgIp = nas.wireguard_ip;
  let wgPriv = nas.wireguard_private_key;
  let wgPub = nas.wireguard_public_key;
  if (!wgIp || !wgPriv || !wgPub) {
    try {
      const used = await query("SELECT wireguard_ip FROM nas_devices WHERE wireguard_ip IS NOT NULL AND id <> $1::uuid", [nas.id]);
      const taken = new Set(used.rows.map(r => r.wireguard_ip));
      let wgOctet = 2;
      while (taken.has(`10.8.0.${wgOctet}`) && wgOctet < 250) wgOctet++;
      wgIp = `10.8.0.${wgOctet}`;
    } catch(e) { wgIp = '10.8.0.2'; }
    // Generate WireGuard keypair via /usr/bin/wg (server-side, then inject into router config)
    try {
      const { execSync } = require('child_process');
      wgPriv = execSync('wg genkey').toString().trim();
      wgPub = execSync(`echo "${wgPriv}" | wg pubkey`).toString().trim();
    } catch(e) {
      // Fallback if wg tool unavailable — leave empty so script skips WG
      wgPriv = ''; wgPub = '';
    }
  }

  return {
    radiusSecret, apiUser, apiPass, network,
    gateway:   `192.168.${octet}.1`,
    poolStart: `192.168.${octet}.10`,
    poolEnd:   `192.168.${octet}.250`,
    doHotspot: ['hotspot', 'both'].includes(isp.plan_type),
    doPPPoE:   ['pppoe', 'both'].includes(isp.plan_type),
    wgIp, wgPriv, wgPub
  };
}

async function persistConfig(nas, cfg) {
  await query(
    `UPDATE nas_devices SET secret=$1::varchar, is_provisioned=true, provisioned_at=NOW(),
       hotspot_enabled=$2::boolean, pppoe_enabled=$3::boolean, is_online=true,
       last_seen=NOW(), updated_at=NOW() WHERE id=$4::uuid`,
    [cfg.radiusSecret, cfg.doHotspot, cfg.doPPPoE, nas.id]
  );
  const extras = {
    hotspot_network: cfg.network, hotspot_gateway: cfg.gateway,
    hotspot_pool_start: cfg.poolStart, hotspot_pool_end: cfg.poolEnd,
    mikrotik_api_user: cfg.apiUser, mikrotik_api_password: cfg.apiPass,
    provision_step: 'configured',
    wireguard_ip: cfg.wgIp, wireguard_private_key: cfg.wgPriv, wireguard_public_key: cfg.wgPub
  };

  // Register router as a WireGuard peer on the VPS server (so handshake succeeds)
  if (cfg.wgPub && cfg.wgIp) {
    try {
      const { execSync } = require('child_process');
      // Check if already a peer (avoid duplicate)
      const peers = execSync('wg show wg0 peers 2>/dev/null || echo ""').toString();
      if (!peers.includes(cfg.wgPub)) {
        // Add live (no restart needed)
        execSync(`wg set wg0 peer "${cfg.wgPub}" allowed-ips ${cfg.wgIp}/32 persistent-keepalive 25`);
        // Also persist into wg0.conf for next reboot
        const peerBlock = `\n[Peer]\nPublicKey = ${cfg.wgPub}\nAllowedIPs = ${cfg.wgIp}/32\nPersistentKeepalive = 25\n`;
        execSync(`grep -q "${cfg.wgPub}" /etc/wireguard/wg0.conf || echo "${peerBlock}" >> /etc/wireguard/wg0.conf`);
        logger.info(`WG peer registered: ${cfg.wgIp} pubkey=${cfg.wgPub.substring(0,16)}...`);
      }
    } catch (e) {
      logger.warn('WG peer registration failed: ' + e.message + ' (router will provision but tunnel won\'t connect until manually added)');
    }
  }
  for (const [col, val] of Object.entries(extras)) {
    await query(`UPDATE nas_devices SET ${col}=$1 WHERE id=$2::uuid`, [val, nas.id]).catch(() => {});
  }
}

// Build the RouterOS .rsc script — ALL commands wrapped in :do{}on-error={}
function buildRouterScript(nas, isp, cfg, serverDomain, serverIp, token) {
  const { radiusSecret, apiUser, apiPass, network, gateway, poolStart, poolEnd, doHotspot, doPPPoE } = cfg;

  // WireGuard tunnel (only if keys generated and server endpoint available)
  // Read LIVE server pubkey from filesystem (env may be stale if WG was reinstalled)
  let wgServerPub = process.env.WIREGUARD_SERVER_PUBKEY || '';
  try {
    const fs = require('fs');
    const livePub = fs.readFileSync('/etc/wireguard/server_public.key', 'utf8').trim();
    if (livePub) wgServerPub = livePub;
  } catch(e) {}
  const wgEndpoint = process.env.WIREGUARD_ENDPOINT || (serverDomain + ':51820');
  const wireguardSection = (cfg.wgIp && cfg.wgPriv && wgServerPub) ? `
# --- WIREGUARD TUNNEL (RumaLink central management) ---
:do { /interface wireguard remove [find name="rumalink-wg"] } on-error={}
:do { /interface wireguard add name="rumalink-wg" private-key="${cfg.wgPriv}" listen-port=51820 comment="RumaLink" } on-error={}
:do { /ip address remove [find comment="RumaLink-wg"] } on-error={}
:do { /ip address add address=${cfg.wgIp}/24 interface=rumalink-wg comment="RumaLink-wg" } on-error={}
:do { /interface wireguard peers remove [find comment="RumaLink-hub"] } on-error={}
:do { /interface wireguard peers add interface=rumalink-wg public-key="${wgServerPub}" endpoint-address=${wgEndpoint.split(':')[0]} endpoint-port=${wgEndpoint.split(':')[1]||'51820'} allowed-address=10.8.0.0/24 persistent-keepalive=25s comment="RumaLink-hub" } on-error={}
:log info "RumaLink WireGuard tunnel up at ${cfg.wgIp}"
` : '';

  // Bridge ports: ISP-selected (nas.bridge_ports), else all ethers except WAN
  let bridgePorts = (nas.bridge_ports || '').split(',').map(s => s.trim()).filter(Boolean);
  if (bridgePorts.length === 0) {
    const allIf = (nas.available_interfaces || '').split(',').map(s => s.trim()).filter(Boolean);
    const wan = nas.wan_interface || 'ether1';
    bridgePorts = allIf.filter(i => i !== wan);
    if (bridgePorts.length === 0) bridgePorts = ['ether2', 'ether3', 'ether4', 'ether5'];
  }
  const bridgePortsList = bridgePorts.map(p => '"' + p + '"').join(';');
  const bridgePortsBlock = `:foreach pname in={${bridgePortsList}} do={ :do { /interface bridge port add bridge=bridge-hotspot interface=$pname comment="RumaLink" } on-error={} }`;

  const hotspotSection = doHotspot ? `
# --- HOTSPOT ---
:do { /interface bridge add name=bridge-hotspot protocol-mode=rstp comment="RumaLink" } on-error={}
${bridgePortsBlock}
:do { /ip address remove [find comment="RumaLink-hs"] } on-error={}
:do { /ip address add address=${gateway}/24 interface=bridge-hotspot comment="RumaLink-hs" } on-error={}
:do { /ip pool remove [find name="rl-pool"] } on-error={}
:do { /ip pool add name="rl-pool" ranges=${poolStart}-${poolEnd} } on-error={}
:do { /ip dhcp-server remove [find name="rl-dhcp"] } on-error={}
:do { /ip dhcp-server add name="rl-dhcp" interface=bridge-hotspot address-pool=rl-pool lease-time=1h disabled=no } on-error={}
:do { /ip dhcp-server network remove [find comment="RumaLink-net"] } on-error={}
:do { /ip dhcp-server network add address=${network} gateway=${gateway} dns-server=8.8.8.8,8.8.4.4 comment="RumaLink-net" } on-error={}
:do { /ip hotspot profile remove [find name="rl-hsprof"] } on-error={}
:do { /ip hotspot profile add name="rl-hsprof" hotspot-address=${gateway} dns-name="wifi.rumalink" html-directory=hotspot login-by=http-chap,http-pap,mac-cookie } on-error={}
:do { /ip hotspot remove [find name="rl-hotspot"] } on-error={}
:do { /ip hotspot add name="rl-hotspot" interface=bridge-hotspot address-pool=rl-pool profile="rl-hsprof" addresses-per-mac=2 disabled=no } on-error={}
:do { /ip firewall nat add chain=srcnat src-address=${network} action=masquerade comment="RumaLink-hs" } on-error={}
:do { /ip hotspot user remove [find name="rumalink"] } on-error={}
:do { /ip hotspot user add name="rumalink" password="rumalink" profile=default comment="RumaLink-generic" } on-error={}
:do { /ip dns set allow-remote-requests=yes } on-error={}
:do { /ip hotspot profile set [find name="rl-hsprof"] login-by=http-chap,http-pap,mac-cookie } on-error={}
:do { /ip hotspot walled-garden remove [find comment="RumaLink-portal"] } on-error={}
:do { /ip hotspot walled-garden add dst-host="${serverDomain}" comment="RumaLink-portal" } on-error={}
:do { /ip hotspot walled-garden add dst-host="*.safaricom.co.ke" comment="RumaLink-portal" } on-error={}
# Download RumaLink branded login.html (replaces MikroTik default)
:do { /tool fetch url=("https://${serverDomain}/api/provision/${token}/login-html") mode=https dst-path="hotspot/login.html" } on-error={}
:do { /ip hotspot profile set [find name="rl-hsprof"] html-directory=hotspot } on-error={}
` : '';

  const pppoeSection = doPPPoE ? `
# --- PPPOE ---
:do { /ip pool add name="rl-pppoe-pool" ranges="100.64.0.2-100.64.0.254" } on-error={}
:do { /ppp profile add name="rl-pppoe-profile" local-address="100.64.0.1" remote-address="rl-pppoe-pool" dns-server="8.8.8.8,1.1.1.1" } on-error={}
:do { /interface bridge add name=bridge-pppoe comment="RumaLink" } on-error={}
:foreach pname in={"ether3";"ether4";"ether5"} do={ :do { /interface bridge port add bridge=bridge-pppoe interface=$pname comment="RumaLink-pppoe" } on-error={} }
:do { /interface pppoe-server server add service-name="rumalink" interface=bridge-pppoe default-profile="rl-pppoe-profile" authentication=pap,chap,mschap1,mschap2 one-session-per-host=yes disabled=no } on-error={}
:do { /ppp aaa set use-radius=yes accounting=yes interim-update=5m } on-error={}
` : '';

  return `# RumaLink Auto-Config for ${isp.company_name} - ${isp.plan_type.toUpperCase()}
:log info "RumaLink: starting configuration"
:do { /ip firewall nat remove [find comment="RumaLink-nat"] } on-error={}
:do { /radius remove [find comment="RumaLink"] } on-error={}
:do { /ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=yes } on-error={}
:do { /ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade comment="RumaLink-nat" } on-error={}
:do { /radius add address=${serverIp} secret="${radiusSecret}" service=hotspot,ppp authentication-port=1812 accounting-port=1813 timeout=3000ms comment="RumaLink" } on-error={}
:do { /radius incoming set accept=yes port=3799 } on-error={}
${wireguardSection}${hotspotSection}${pppoeSection}
:do { /user group add name="rumalink-api" policy="api,read,write,reboot,test,ssh,winbox" comment="RumaLink" } on-error={}
:do { /user remove [find name="${apiUser}"] } on-error={}
:do { /user add name="${apiUser}" password="${apiPass}" group=rumalink-api comment="RumaLink" } on-error={}
:do { /ip service enable api } on-error={}
:do { /ip service enable api-ssl } on-error={}
:do { /system scheduler remove [find name="rl-heartbeat"] } on-error={}
:do { /system scheduler add name="rl-heartbeat" interval=5m comment="RumaLink" on-event=("/tool fetch url=\\"https://${serverDomain}/api/provision/heartbeat/${token}\\" http-method=post http-data=\\"cpu=0\\" keep-result=no") } on-error={}
:log info "RumaLink: configuration complete"
:put "RumaLink Setup Complete - Plan: ${isp.plan_type}"
`;
}

// ──────────────────────────────────────────────────────────────
// POST /:token — device check-in (returns JSON)
// ──────────────────────────────────────────────────────────────
router.post('/:token', async (req, res) => {
  const { token } = req.params;
  try {
    const deviceRes = await query('SELECT * FROM nas_devices WHERE provision_token = $1', [token]);
    if (!deviceRes.rows[0]) return res.status(404).json({ error: 'Invalid provisioning token.' });
    const nas = deviceRes.rows[0];

    const ispRes = await query('SELECT * FROM isps WHERE id = $1', [nas.isp_id]);
    if (!ispRes.rows[0]) return res.status(404).json({ error: 'ISP not found.' });
    const isp = ispRes.rows[0];

    const body = req.body || {};
    const clean = v => {
      if (v == null) return '';
      let s = Array.isArray(v) ? (v[0] || '') : String(v);
      s = s.trim();
      if (s.startsWith('[') || s.indexOf('/system') > -1 || s.indexOf('/interface') > -1 || s.indexOf('/ip ') > -1) return '';
      return s;
    };
    const identity = clean(body.identity) || nas.name || 'MikroTik';
    const board = clean(body.board);
    const mac = clean(body.mac);

    logger.info(`Provision check-in: token=${token} identity=${identity}`);

    const cfg = await buildDeviceConfig(nas, isp);
    await persistConfig(nas, cfg);

    // Save MikroTik metadata if columns exist
    for (const [col, val] of [['mikrotik_identity', identity], ['mikrotik_board', board], ['mikrotik_mac', mac]]) {
      if (val) await query(`UPDATE nas_devices SET ${col}=$1 WHERE id=$2::uuid`, [val, nas.id]).catch(() => {});
    }

    query(`INSERT INTO notifications (isp_id,type,title,message,link) VALUES ($1::uuid,'success','MikroTik Connected',$2,'/isp/dashboard.html')`,
      [nas.isp_id, `"${identity}" checked in. Run the import command to apply config.`]).catch(() => {});

    const serverDomain = (process.env.BASE_URL || 'https://rumalinkenterprise.online').replace(/^https?:\/\//, '');
    res.json({
      success: true,
      message: 'Device registered. Use the GET /script endpoint to configure.',
      script_url: `https://${serverDomain}/api/provision/${token}/script`
    });
  } catch (err) {
    logger.error('Provision POST error:', err.message);
    res.status(500).json({ error: 'Provisioning failed: ' + err.message });
  }
});

// ──────────────────────────────────────────────────────────────
// GET /:token/script — returns raw .rsc for /import
// ──────────────────────────────────────────────────────────────
router.get('/:token/script', async (req, res) => {
  const { token } = req.params;
  try {
    const deviceRes = await query('SELECT * FROM nas_devices WHERE provision_token = $1', [token]);
    if (!deviceRes.rows[0]) {
      return res.status(404).type('text/plain').send(':log error "RumaLink: invalid token"');
    }
    const nas = deviceRes.rows[0];

    const ispRes = await query('SELECT * FROM isps WHERE id = $1', [nas.isp_id]);
    if (!ispRes.rows[0]) {
      return res.status(404).type('text/plain').send(':log error "RumaLink: ISP not found"');
    }
    const isp = ispRes.rows[0];

    const cfg = await buildDeviceConfig(nas, isp);
    await persistConfig(nas, cfg);

    const serverDomain = (process.env.BASE_URL || 'https://rumalinkenterprise.online').replace(/^https?:\/\//, '');
    const serverIp = process.env.RADIUS_HOST || serverDomain.split(':')[0];

    query(`INSERT INTO notifications (isp_id,type,title,message,link) VALUES ($1::uuid,'success','MikroTik Configured',$2,'/isp/dashboard.html')`,
      [nas.isp_id, `"${nas.name || 'Router'}" pulled and imported its config.`]).catch(() => {});
    query(`INSERT INTO nas_events (nas_id,isp_id,event_type,message) VALUES ($1::uuid,$2::uuid,'provisioned','Config imported')`,
      [nas.id, nas.isp_id]).catch(() => {});
    const io = req.app.get('io');
    if (io) io.to(`isp_${nas.isp_id}`).emit('device_provisioned', { device_id: nas.id });

    const script = buildRouterScript(nas, isp, cfg, serverDomain, serverIp, token);
    res.type('text/plain').send(script);
  } catch (err) {
    logger.error('Provision script error:', err.message);
    res.status(500).type('text/plain').send(':log error "RumaLink error"');
  }
});

// ──────────────────────────────────────────────────────────────
// POST /heartbeat/:token — keepalive
// ──────────────────────────────────────────────────────────────
router.post('/heartbeat/:token', async (req, res) => {
  try {
    const body = req.body || {};
    const cpu = parseInt(body.cpu) || 0;
    // Memory: MikroTik sends bytes (e.g. "256000000"). Convert to MB.
    const toMB = v => v == null ? null : Math.round(parseFloat(String(v).replace(/[^\d.]/g,'')) / (1024*1024));
    const memFree = toMB(body.mem_free);
    const memTotal = toMB(body.mem_total);
    const memUsedMB = (memTotal != null && memFree != null) ? Math.max(0, memTotal - memFree) : null;
    const diskFree = toMB(body.disk_free);
    const diskTotal = toMB(body.disk_total);
    const diskUsedMB = (diskTotal != null && diskFree != null) ? Math.max(0, diskTotal - diskFree) : null;
    // Uptime: MikroTik string like "1w2d3h4m5s" — parse to seconds
    let uptimeSec = null;
    const u = String(body.uptime || '');
    if (u) {
      const m = u.match(/(?:(\d+)w)?(?:(\d+)d)?(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?/);
      if (m) {
        uptimeSec = (parseInt(m[1])||0)*604800 + (parseInt(m[2])||0)*86400 + (parseInt(m[3])||0)*3600 + (parseInt(m[4])||0)*60 + (parseInt(m[5])||0);
      }
    }

    await query(
      `UPDATE nas_devices SET
         is_online=true, last_seen=NOW(),
         cpu_load=$1::int,
         memory_used_mb=COALESCE($2::int, memory_used_mb),
         memory_total_mb=COALESCE($3::int, memory_total_mb),
         disk_used_mb=COALESCE($4::int, disk_used_mb),
         disk_total_mb=COALESCE($5::int, disk_total_mb),
         uptime_seconds=COALESCE($6::bigint, uptime_seconds),
         updated_at=NOW()
       WHERE provision_token=$7`,
      [cpu, memUsedMB, memTotal, diskUsedMB, diskTotal, uptimeSec, req.params.token]
    );

    // Broadcast to ISP dashboard via websocket
    try {
      const dev = await query('SELECT id, isp_id, name FROM nas_devices WHERE provision_token=$1', [req.params.token]);
      const io = req.app.get('io');
      if (io && dev.rows[0]) {
        io.to(`isp_${dev.rows[0].isp_id}`).emit('device_metrics', {
          device_id: dev.rows[0].id,
          cpu, memory_used_mb: memUsedMB, memory_total_mb: memTotal,
          disk_used_mb: diskUsedMB, disk_total_mb: diskTotal, uptime_seconds: uptimeSec
        });
      }
    } catch(e) {}

    res.json({ ok: true });
  } catch (e) {
    logger.error('heartbeat error:', e.message);
    res.json({ ok: false });
  }
});


router.get('/:token/login-html', async (req, res) => {
  try {
    const deviceRes = await query('SELECT * FROM nas_devices WHERE provision_token=$1', [req.params.token]);
    if (!deviceRes.rows[0]) return res.status(404).type('text/plain').send('not found');
    const nas = deviceRes.rows[0];
    const serverDomain = (process.env.BASE_URL || 'https://rumalinkenterprise.online').replace(/^https?:\/\//, '');
    const html = `<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Connecting...</title>
<style>body{font-family:sans-serif;background:#0d1530;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;text-align:center}.s{width:50px;height:50px;border:4px solid rgba(0,212,170,.2);border-top-color:#00d4aa;border-radius:50%;animation:r 1s linear infinite;margin:0 auto 16px}@keyframes r{to{transform:rotate(360deg)}}</style></head>
<body><div><div class="s"></div><p>Connecting to WiFi...</p></div>
<script>(function(){var p=new URLSearchParams();p.set('isp','${nas.isp_id}');p.set('nas','${nas.id}');p.set('mac','$(mac)');p.set('ip','$(ip)');p.set('loginurl','$(link-login-only)');p.set('linkorig','$(link-orig)');window.location.href='https://${serverDomain}/captive/classic.html?'+p.toString();})();</script>
</body></html>`;
    res.type('text/html').send(html);
  } catch (err) { res.status(500).type('text/plain').send('error'); }
});



// ── POST /:token/interfaces — router reports its ethernet ports + which has internet ──
// MikroTik calls this during bootstrap so the dashboard can ask which ports to bridge.
router.post('/:token/interfaces', async (req, res) => {
  try {
    const deviceRes = await query('SELECT * FROM nas_devices WHERE provision_token=$1', [req.params.token]);
    if (!deviceRes.rows[0]) return res.status(404).json({ error: 'Invalid token' });
    const nas = deviceRes.rows[0];

    // req.body.interfaces = "ether1,ether2,ether3,ether4,ether5"
    // req.body.wan = "ether1" (the one with internet / default route)
    const body = req.body || {};
    const allIfaces = String(body.interfaces || '').split(',').map(s => s.trim()).filter(Boolean);
    const wanIface = String(body.wan || 'ether1').trim();

    // Bridge candidates = all interfaces EXCEPT the WAN port
    const bridgeCandidates = allIfaces.filter(i => i !== wanIface);

    // Save discovered interfaces
    await query(
      `UPDATE nas_devices SET wan_interface=$1::varchar, available_interfaces=$2::varchar, updated_at=NOW() WHERE id=$3::uuid`,
      [wanIface, allIfaces.join(','), nas.id]
    ).catch(()=>{});

    // Notify dashboard via websocket that interfaces are ready to pick
    const io = req.app.get('io');
    if (io) io.to(`isp_${nas.isp_id}`).emit('interfaces_discovered', {
      device_id: nas.id, wan: wanIface, bridge_candidates: bridgeCandidates, all: allIfaces
    });

    res.json({ success: true, wan: wanIface, bridge_candidates: bridgeCandidates });
  } catch (err) {
    logger.error('Interface discovery error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── GET /:token/interfaces — dashboard polls discovered interfaces ──
router.get('/:token/interfaces', async (req, res) => {
  try {
    const r = await query('SELECT wan_interface, available_interfaces, bridge_ports FROM nas_devices WHERE provision_token=$1', [req.params.token]);
    if (!r.rows[0]) return res.status(404).json({ error: 'Invalid token' });
    const all = (r.rows[0].available_interfaces || '').split(',').map(s=>s.trim()).filter(Boolean);
    const wan = r.rows[0].wan_interface || 'ether1';
    res.json({
      discovered: all.length > 0,
      wan,
      all_interfaces: all,
      bridge_candidates: all.filter(i => i !== wan),
      selected_bridge_ports: (r.rows[0].bridge_ports || '').split(',').map(s=>s.trim()).filter(Boolean)
    });
  } catch (err) {
    res.json({ discovered: false });
  }
});

// ── POST /:token/set-bridge-ports — dashboard saves which ports to bridge ──
router.post('/:token/set-bridge-ports', async (req, res) => {
  try {
    const ports = String((req.body||{}).ports || '').split(',').map(s=>s.trim()).filter(Boolean);
    await query('UPDATE nas_devices SET bridge_ports=$1::varchar, updated_at=NOW() WHERE provision_token=$2',
      [ports.join(','), req.params.token]);
    res.json({ success: true, ports });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


module.exports = router;
