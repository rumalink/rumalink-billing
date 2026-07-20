const express = require('express');
const { query } = require('../config/database');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');

const router = express.Router();

router.post('/:token', async (req, res, next) => {
  const { token } = req.params;
  try {
    const deviceRes = await query('SELECT * FROM nas_devices WHERE provision_token=$1', [token]);
    if (!deviceRes.rows[0]) return res.status(404).json({ error: 'Invalid provisioning token.' });

    const nas = deviceRes.rows[0];
    const ispRes = await query('SELECT * FROM isps WHERE id=$1', [nas.isp_id]);
    if (!ispRes.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    const isp = ispRes.rows[0];

    const { identity, version, version_string, board, mac, wan_ip } = req.body;

    // Clean values — MikroTik may send arrays or "ip/prefix" format
    const cleanStr = v => (Array.isArray(v) ? v[0] : String(v||'')).trim();
    const cleanIp  = v => cleanStr(v).split('/')[0].trim() || null;

    const devIdentity = cleanStr(identity) || nas.name || 'MikroTik';
    const devVersion  = cleanStr(version || version_string);
    const devBoard    = cleanStr(board);
    const devMac      = cleanStr(mac);
    const devWanIp    = cleanIp(wan_ip);

    const radiusSecret = `RML${uuidv4().replace(/-/g,'').substring(0,16).toUpperCase()}`;
    const apiUser = `rl_${nas.id.substring(0,8)}`;
    const apiPass = uuidv4().substring(0,12);

    // Allocate a unique subnet
    const existingNets = await query('SELECT hotspot_network FROM nas_devices WHERE hotspot_network IS NOT NULL AND id <> $1', [nas.id]);
    const usedNets = new Set(existingNets.rows.map(r => r.hotspot_network).filter(Boolean));
    let octet = 100;
    while (usedNets.has(`192.168.${octet}.0/24`)) octet++;
    const network   = `192.168.${octet}.0/24`;
    const gateway   = `192.168.${octet}.1`;
    const poolStart = `192.168.${octet}.10`;
    const poolEnd   = `192.168.${octet}.250`;

    const doHotspot = ['hotspot','both'].includes(isp.plan_type);
    const doPPPoE   = ['pppoe','both'].includes(isp.plan_type);

    const serverDomain = (process.env.BASE_URL||'https://rumalinkenterprise.online').replace(/https?:\/\//,'');
    const serverIp     = process.env.RADIUS_HOST || serverDomain.split(':')[0];
    const baseUrl      = process.env.BASE_URL || 'https://rumalinkenterprise.online';
    const winboxUrl    = `https://winbox.mikrotik.com/winbox64.exe?${devWanIp||'ROUTER_IP'}:8291`;

    // Core UPDATE — only columns guaranteed to exist in original schema
    await query(`
      UPDATE nas_devices SET
        mikrotik_identity = $1::varchar,
        mikrotik_version  = $2::varchar,
        mikrotik_board    = $3::varchar,
        mikrotik_mac      = $4::varchar,
        wan_ip            = $5::varchar,
        nas_ip            = COALESCE(nas_ip, $5::varchar),
        secret            = $6::varchar,
        is_provisioned    = true,
        provisioned_at    = NOW(),
        hotspot_enabled   = $7::boolean,
        pppoe_enabled     = $8::boolean,
        is_online         = true,
        last_seen         = NOW(),
        updated_at        = NOW()
      WHERE id = $9::uuid
    `, [devIdentity, devVersion, devBoard, devMac, devWanIp, radiusSecret, doHotspot, doPPPoE, nas.id]);

    // Optional columns (added by migrations — skip if missing)
    const extras = {
      hotspot_network:     network,
      hotspot_gateway:     gateway,
      hotspot_pool_start:  poolStart,
      hotspot_pool_end:    poolEnd,
      mikrotik_api_user:   apiUser,
      mikrotik_api_password: apiPass,
      remote_winbox_url:   winboxUrl,
      provision_step:      'configured'
    };
    for (const [col, val] of Object.entries(extras)) {
      await query(`UPDATE nas_devices SET ${col}=$1 WHERE id=$2::uuid`, [val, nas.id]).catch(() => {});
    }

    await query(`INSERT INTO notifications (isp_id,type,title,message,link) VALUES ($1,'success','MikroTik Provisioned',$2,'/isp/dashboard.html')`,
      [nas.isp_id, `"${devIdentity}" (${devBoard||'MikroTik'}) provisioned. Plan: ${isp.plan_type.toUpperCase()}`]);
    query(`INSERT INTO nas_events (nas_id,isp_id,event_type,message) VALUES ($1,$2,'provisioned',$3)`,
      [nas.id, nas.isp_id, `Provisioned. Board:${devBoard} Plan:${isp.plan_type}`]).catch(()=>{});
    const io = req.app.get('io');
    if (io) io.to(`isp_${nas.isp_id}`).emit('device_provisioned', { device_id: nas.id, identity: devIdentity });

    const hotspotSection = doHotspot ? `
#--------------------------------------------------------------
# HOTSPOT
#--------------------------------------------------------------
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
/ip hotspot set [find name=rl-hotspot] profile=rl-hotspot comment="RumaLink"
/ip hotspot walled-garden remove [find comment~"RumaLink"] ignore-errors=yes
/ip hotspot walled-garden add dst-host="${serverDomain}" comment="RumaLink-portal"
/ip hotspot walled-garden add dst-host="*.safaricom.co.ke" comment="RumaLink-mpesa"
/ip hotspot walled-garden ip remove [find comment~"RumaLink"] ignore-errors=yes
/ip hotspot walled-garden ip add dst-address=${serverIp} comment="RumaLink-server"
` : '';

    const pppoeSection = doPPPoE ? `
#--------------------------------------------------------------
# PPPOE
#--------------------------------------------------------------
/interface bridge add name=bridge-pppoe comment="RumaLink" ignore-errors=yes
/interface bridge port add bridge=bridge-pppoe interface=ether3 comment="RumaLink-pppoe" ignore-errors=yes
/interface bridge port add bridge=bridge-pppoe interface=ether4 comment="RumaLink-pppoe" ignore-errors=yes
/ppp profile add name="rl-pppoe-profile" use-radius=yes dns-server=8.8.8.8,8.8.4.4 change-tcp-mss=yes comment="RumaLink" ignore-errors=yes
/interface pppoe-server server add name="rl-pppoe" interface=bridge-pppoe authentication=mschap2 keepalive-timeout=10 max-mtu=1480 max-mru=1480 default-profile=rl-pppoe-profile comment="RumaLink" ignore-errors=yes
/ppp aaa set use-radius=yes interim-update=5m
` : '';

    const fullScript = `
#================================================================
# RumaLink Enterprise - MikroTik Auto-Configuration
# ISP: ${isp.company_name}  |  Device: ${devIdentity}
# Plan: ${isp.plan_type.toUpperCase()}  |  Date: ${new Date().toISOString()}
#================================================================

/ip firewall filter remove [find comment~"RumaLink"] ignore-errors=yes
/ip firewall nat remove [find comment~"RumaLink"] ignore-errors=yes
/radius remove [find comment~"RumaLink"] ignore-errors=yes
/system script remove [find comment~"RumaLink"] ignore-errors=yes
/system scheduler remove [find comment~"RumaLink"] ignore-errors=yes

/ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=yes
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade comment="RumaLink-nat"
/radius add address=${serverIp} secret="${radiusSecret}" service=hotspot,pppoe authentication-port=1812 accounting-port=1813 timeout=3000ms comment="RumaLink"
/radius incoming set accept=yes port=3799
${hotspotSection}${pppoeSection}
/user remove [find name="${apiUser}"] ignore-errors=yes
/user add name="${apiUser}" password="${apiPass}" group=full comment="RumaLink"
/ip service enable api
/ip service set api port=8728
/system identity set name="${devIdentity}"
/system logging add topics=radius,hotspot action=memory comment="RumaLink"

/system script add name="rl-heartbeat" policy=read,write,test comment="RumaLink" source={
  :local cpu [/system resource get cpu-load]
  :local mf [/system resource get free-memory]
  :local mt [/system resource get total-memory]
  :local df [/system resource get free-hdd-space]
  :local dt [/system resource get total-hdd-space]
  :local up [/system resource get uptime]
  /tool fetch url="https://${serverDomain}/api/provision/heartbeat/${token}" http-method=post http-data=("cpu=".cpu."&mem_free=".mf."&mem_total=".mt."&disk_free=".df."&disk_total=".dt."&uptime=".up) keep-result=no
}
/system scheduler add name="rl-heartbeat" interval=5m on-event=rl-heartbeat start-time=startup comment="RumaLink"

:log info "RumaLink config complete!"
:put "======================================================"
:put " RumaLink Setup Complete!"
:put " RADIUS: ${serverIp}  Secret: ${radiusSecret}"
:put " Plan: ${isp.plan_type.toUpperCase()}"
:put " API User: ${apiUser}  Pass: ${apiPass}  Port:8728"
:put " Winbox: ${winboxUrl}"
:put "======================================================"
`.trim();

    res.json({
      success: true,
      message: 'Device provisioned! Copy the mikrotik_script and run it in your MikroTik terminal.',
      config: { radius_server: serverIp, radius_port_auth: 1812, radius_port_acct: 1813, radius_secret: radiusSecret, coa_port: 3799, nas_id: nas.id, api_user: apiUser, api_password: apiPass, api_port: 8728, hotspot_login_url: `${baseUrl}/captive/classic.html?isp=${nas.isp_id}&nas=${nas.id}`, remote_winbox_url: winboxUrl, plan: isp.plan_type, hotspot_network: network, hotspot_gateway: gateway, mikrotik_script: fullScript }
    });
  } catch (err) {
    logger.error('Provision error:', err.message, err.stack);
    next(err);
  }
});

router.post('/heartbeat/:token', async (req, res) => {
  const { cpu, mem_free, mem_total, disk_free, disk_total, uptime } = req.body;
  try {
    await query('UPDATE nas_devices SET is_online=true, last_seen=NOW(), updated_at=NOW() WHERE provision_token=$1', [req.params.token]);
    if (cpu !== undefined) {
      const memUsed = (mem_total && mem_free) ? Math.round((mem_total - mem_free)/1048576) : null;
      query(`UPDATE nas_devices SET cpu_load=$1, memory_used_mb=$2, memory_total_mb=$3, disk_used_mb=$4, disk_total_mb=$5, uptime_seconds=$6 WHERE provision_token=$7`,
        [parseInt(cpu)||0, memUsed, mem_total?Math.round(mem_total/1048576):null, (disk_total&&disk_free)?Math.round((disk_total-disk_free)/1048576):null, disk_total?Math.round(disk_total/1048576):null, uptime?(()=>{const s=String(uptime);return (parseInt((s.match(/(\d+)d/)||[0,0])[1])||0)*86400+(parseInt((s.match(/(\d+)h/)||[0,0])[1])||0)*3600+(parseInt((s.match(/(\d+)m/)||[0,0])[1])||0)*60+(parseInt((s.match(/(\d+)s/)||[0,0])[1])||0)})():null, req.params.token]
      ).catch(()=>{});
    }
    res.json({ ok: true });
  } catch(e) { res.json({ ok: false }); }
});

module.exports = router;
