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

  return {
    radiusSecret, apiUser, apiPass, network,
    gateway:   `192.168.${octet}.1`,
    poolStart: `192.168.${octet}.10`,
    poolEnd:   `192.168.${octet}.250`,
    doHotspot: ['hotspot', 'both'].includes(isp.plan_type),
    doPPPoE:   ['pppoe', 'both'].includes(isp.plan_type)
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
    provision_step: 'configured'
  };
  for (const [col, val] of Object.entries(extras)) {
    await query(`UPDATE nas_devices SET ${col}=$1 WHERE id=$2::uuid`, [val, nas.id]).catch(() => {});
  }
}

// Build the RouterOS .rsc script — ALL commands wrapped in :do{}on-error={}
function buildRouterScript(nas, isp, cfg, serverDomain, serverIp, token) {
  const { radiusSecret, apiUser, apiPass, network, gateway, poolStart, poolEnd, doHotspot, doPPPoE } = cfg;

  const hotspotSection = doHotspot ? `
# --- HOTSPOT ---
:do { /interface bridge add name=bridge-hotspot protocol-mode=rstp comment="RumaLink" } on-error={}
:foreach pname in={"ether2";"ether3";"ether4";"ether5";"wlan1";"wlan2"} do={ :do { /interface bridge port add bridge=bridge-hotspot interface=$pname comment="RumaLink" } on-error={} }
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
${hotspotSection}${pppoeSection}
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
    await query("UPDATE nas_devices SET is_online=true, last_seen=NOW(), updated_at=NOW() WHERE provision_token=$1", [req.params.token]);
    const cpu = (req.body || {}).cpu;
    if (cpu !== undefined) {
      query("UPDATE nas_devices SET cpu_load=$1::int WHERE provision_token=$2", [parseInt(cpu) || 0, req.params.token]).catch(() => {});
    }
    res.json({ ok: true });
  } catch (e) {
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


module.exports = router;
