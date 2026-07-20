/**
 * RumaLink — MikroTik RouterOS v7 Provisioning
 *
 * Flow: ISP pastes /tool fetch command → router POSTs identity to this endpoint
 *       → server returns full .rsc config script → router applies it → done
 */

const express = require('express');
const { query } = require('../config/database');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');

const router = express.Router();

router.post('/:token', async (req, res) => {
  const { token } = req.params;

  try {
    // Lookup device by provision token
    const deviceRes = await query(
      'SELECT * FROM nas_devices WHERE provision_token = $1',
      [token]
    );
    if (!deviceRes.rows[0]) {
      return res.status(404).json({ error: 'Invalid provisioning token.' });
    }
    const nas = deviceRes.rows[0];

    const ispRes = await query('SELECT * FROM isps WHERE id = $1', [nas.isp_id]);
    if (!ispRes.rows[0]) return res.status(404).json({ error: 'ISP not found.' });
    const isp = ispRes.rows[0];

    // ── Sanitize inputs from MikroTik (arrays, IP/mask format) ─
    const clean = v => (Array.isArray(v) ? v[0] : String(v == null ? '' : v)).trim();
    const cleanIp = v => clean(v).split('/')[0].split('%')[0].trim() || null;

    const identity = clean(req.body.identity) || nas.name || 'MikroTik';
    const version  = clean(req.body.version);
    const board    = clean(req.body.board);
    const mac      = clean(req.body.mac);
    const wanIp    = cleanIp(req.body.wan_ip);

    // ── Generate per-device credentials ───────────────────────
    const radiusSecret = 'RML' + uuidv4().replace(/-/g, '').substring(0, 16).toUpperCase();
    const apiUser = 'rl_' + nas.id.substring(0, 8);
    const apiPass = uuidv4().substring(0, 12);

    // ── Allocate unique /24 subnet ────────────────────────────
    let octet = 100;
    try {
      const existing = await query(
        "SELECT hotspot_network FROM nas_devices WHERE hotspot_network IS NOT NULL AND id <> $1::uuid",
        [nas.id]
      );
      const used = new Set(existing.rows.map(r => r.hotspot_network).filter(Boolean));
      while (used.has(`192.168.${octet}.0/24`)) octet++;
    } catch (e) { /* column may not exist */ }

    const network    = `192.168.${octet}.0/24`;
    const gateway    = `192.168.${octet}.1`;
    const poolStart  = `192.168.${octet}.10`;
    const poolEnd    = `192.168.${octet}.250`;

    const doHotspot = ['hotspot', 'both'].includes(isp.plan_type);
    const doPPPoE   = ['pppoe',   'both'].includes(isp.plan_type);

    const serverDomain = (process.env.BASE_URL || 'https://rumalinkenterprise.online').replace(/^https?:\/\//, '');
    const serverIp     = process.env.RADIUS_HOST || serverDomain.split(':')[0];
    const baseUrl      = process.env.BASE_URL || 'https://rumalinkenterprise.online';
    const winboxUrl    = `https://winbox.mikrotik.com/winbox64.exe?${wanIp || 'ROUTER_IP'}:8291`;

    // ── Save core data (only columns that ALWAYS exist) ───────
    // Type casts prevent "inconsistent types deduced for parameter" error
    await query(
      `UPDATE nas_devices SET
         mikrotik_identity = $1::varchar,
         mikrotik_version  = $2::varchar,
         mikrotik_board    = $3::varchar,
         mikrotik_mac      = $4::varchar,
         wan_ip            = $5::varchar,
         nas_ip            = COALESCE(nas_ip, $5::varchar, 'pending'::varchar),
         secret            = $6::varchar,
         is_provisioned    = true,
         provisioned_at    = NOW(),
         hotspot_enabled   = $7::boolean,
         pppoe_enabled     = $8::boolean,
         is_online         = true,
         last_seen         = NOW(),
         updated_at        = NOW()
       WHERE id = $9::uuid`,
      [identity, version, board, mac, wanIp, radiusSecret, doHotspot, doPPPoE, nas.id]
    );

    // ── Save optional columns (each in its own try/catch) ─────
    const extras = {
      hotspot_network:       network,
      hotspot_gateway:       gateway,
      hotspot_pool_start:    poolStart,
      hotspot_pool_end:      poolEnd,
      mikrotik_api_user:     apiUser,
      mikrotik_api_password: apiPass,
      remote_winbox_url:     winboxUrl,
      provision_step:        'configured'
    };
    for (const [col, val] of Object.entries(extras)) {
      try {
        await query(`UPDATE nas_devices SET ${col} = $1 WHERE id = $2::uuid`, [val, nas.id]);
      } catch (e) { /* column missing — skip */ }
    }

    // ── Notify ISP ────────────────────────────────────────────
    try {
      await query(
        `INSERT INTO notifications (isp_id, type, title, message, link)
         VALUES ($1::uuid, 'success', 'MikroTik Provisioned', $2, '/isp/dashboard.html')`,
        [nas.isp_id, `"${identity}" (${board || 'MikroTik'}) provisioned. Plan: ${isp.plan_type.toUpperCase()}`]
      );
    } catch (e) { /* non-fatal */ }

    // Try logging event (table may not exist)
    query(
      `INSERT INTO nas_events (nas_id, isp_id, event_type, message)
       VALUES ($1::uuid, $2::uuid, 'provisioned', $3)`,
      [nas.id, nas.isp_id, `Provisioned ${identity} on ${isp.plan_type}`]
    ).catch(() => {});

    // WebSocket notify
    const io = req.app.get('io');
    if (io) io.to(`isp_${nas.isp_id}`).emit('device_provisioned', { device_id: nas.id, identity });

    // ── Build the RouterOS v7 .rsc script ─────────────────────
    const hotspotSection = doHotspot ? `
#--- HOTSPOT (RouterOS v7) ---
/interface bridge add name=bridge-hotspot protocol-mode=rstp comment="RumaLink" ignore-errors=yes
/interface bridge port add bridge=bridge-hotspot interface=ether2 comment="RumaLink" ignore-errors=yes
/interface bridge port add bridge=bridge-hotspot interface=ether3 comment="RumaLink" ignore-errors=yes
/interface bridge port add bridge=bridge-hotspot interface=ether4 comment="RumaLink" ignore-errors=yes
/interface bridge port add bridge=bridge-hotspot interface=wlan1 comment="RumaLink" ignore-errors=yes
/ip address remove [find comment="RumaLink-hs"] ignore-errors=yes
/ip address add address=${gateway}/24 interface=bridge-hotspot comment="RumaLink-hs"
/ip pool remove [find name="rl-pool"] ignore-errors=yes
/ip pool add name="rl-pool" ranges=${poolStart}-${poolEnd} comment="RumaLink"
/ip dhcp-server remove [find name="rl-dhcp"] ignore-errors=yes
/ip dhcp-server add name="rl-dhcp" interface=bridge-hotspot address-pool=rl-pool lease-time=1h disabled=no comment="RumaLink"
/ip dhcp-server network remove [find comment="RumaLink-net"] ignore-errors=yes
/ip dhcp-server network add address=${network} gateway=${gateway} dns-server=8.8.8.8,8.8.4.4 comment="RumaLink-net"
/ip hotspot setup hotspot-interface=bridge-hotspot address-pool=rl-pool masquerade-network=yes name=rl-hotspot
/ip hotspot profile set [find name=rl-hotspot] use-radius=yes mac-auth-mode=mac-as-username-and-password interim-update=1m login-page="https://${serverDomain}/captive/classic.html?isp=${nas.isp_id}&nas=${nas.id}" comment="RumaLink"
/ip hotspot walled-garden remove [find comment~"RumaLink"] ignore-errors=yes
/ip hotspot walled-garden add dst-host="${serverDomain}" comment="RumaLink-portal"
/ip hotspot walled-garden add dst-host="*.safaricom.co.ke" comment="RumaLink-mpesa"
` : '';

    const pppoeSection = doPPPoE ? `
#--- PPPOE ---
/interface bridge add name=bridge-pppoe comment="RumaLink" ignore-errors=yes
/interface bridge port add bridge=bridge-pppoe interface=ether3 comment="RumaLink-pppoe" ignore-errors=yes
/ppp profile add name="rl-pppoe-profile" use-radius=yes dns-server=8.8.8.8,8.8.4.4 change-tcp-mss=yes comment="RumaLink" ignore-errors=yes
/interface pppoe-server server add name="rl-pppoe" interface=bridge-pppoe authentication=mschap2 max-mtu=1480 max-mru=1480 default-profile=rl-pppoe-profile comment="RumaLink" ignore-errors=yes
/ppp aaa set use-radius=yes interim-update=5m
` : '';

    const fullScript = `# RumaLink Auto-Config — ${identity} (${isp.plan_type.toUpperCase()})
/ip firewall nat remove [find comment="RumaLink-nat"] ignore-errors=yes
/radius remove [find comment~"RumaLink"] ignore-errors=yes
/ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=yes
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade comment="RumaLink-nat"
/radius add address=${serverIp} secret="${radiusSecret}" service=hotspot,pppoe authentication-port=1812 accounting-port=1813 timeout=3000ms comment="RumaLink"
/radius incoming set accept=yes port=3799
${hotspotSection}${pppoeSection}
/user remove [find name="${apiUser}"] ignore-errors=yes
/user add name="${apiUser}" password="${apiPass}" group=full comment="RumaLink"
/ip service enable api
/system identity set name="${identity}"
:log info "RumaLink config done"
:put "RumaLink Setup Complete - RADIUS:${serverIp} Secret:${radiusSecret}"`;

    res.json({
      success: true,
      message: 'Device provisioned!',
      config: {
        radius_server:     serverIp,
        radius_secret:     radiusSecret,
        api_user:          apiUser,
        api_password:      apiPass,
        remote_winbox_url: winboxUrl,
        plan:              isp.plan_type,
        hotspot_network:   network,
        hotspot_gateway:   gateway,
        mikrotik_script:   fullScript
      }
    });

  } catch (err) {
    logger.error('Provision error:', err.message);
    logger.error(err.stack);
    res.status(500).json({ error: 'Provisioning failed: ' + err.message });
  }
});

// Heartbeat
router.post('/heartbeat/:token', async (req, res) => {
  try {
    await query(
      "UPDATE nas_devices SET is_online=true, last_seen=NOW(), updated_at=NOW() WHERE provision_token=$1",
      [req.params.token]
    );

    // Optional telemetry
    const { cpu, mem_free, mem_total, disk_free, disk_total } = req.body;
    if (cpu !== undefined) {
      const memUsed = (mem_total && mem_free) ? Math.round((Number(mem_total) - Number(mem_free))/1048576) : null;
      const memTot  = mem_total ? Math.round(Number(mem_total)/1048576) : null;
      const diskUsed = (disk_total && disk_free) ? Math.round((Number(disk_total) - Number(disk_free))/1048576) : null;
      const diskTot = disk_total ? Math.round(Number(disk_total)/1048576) : null;
      query(
        `UPDATE nas_devices SET cpu_load=$1::int, memory_used_mb=$2::int, memory_total_mb=$3::int,
                                disk_used_mb=$4::int, disk_total_mb=$5::int WHERE provision_token=$6`,
        [parseInt(cpu)||0, memUsed, memTot, diskUsed, diskTot, req.params.token]
      ).catch(()=>{});
    }
    res.json({ ok: true });
  } catch (e) {
    res.json({ ok: false });
  }
});

module.exports = router;
