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


// v62.46: Trigger clients-rumalink.conf sync after secret changes.
// Falls back gracefully if sudo not allowed — cron job (every minute) catches it.
function triggerRadiusClientsSync() {
  try {
    const { exec } = require('child_process');
    exec('sudo -n /usr/local/bin/rumalink-radius-clients-sync.sh', { timeout: 5000 }, (err) => {
      if (err) logger.warn('[v62.46] radius clients sync deferred to cron: ' + err.message);
      else logger.info('[v62.46] radius clients-rumalink.conf synced');
    });
  } catch (e) { /* fire and forget */ }
}

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
  // v62.46: keep FreeRADIUS clients.conf in sync
  triggerRadiusClientsSync();

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
  // Use the server's PUBLIC IP for endpoint, not hostname.
  // MikroTik DNS may not resolve hostnames at WireGuard handshake time.
  let wgEndpoint = process.env.WIREGUARD_ENDPOINT_IP;
  if (!wgEndpoint) {
    try {
      const { execSync } = require('child_process');
      const ip = execSync('curl -s --max-time 3 https://api.ipify.org', { stdio: ['pipe','pipe','ignore'] }).toString().trim();
      if (ip && /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(ip)) {
        wgEndpoint = ip + ':51820';
      }
    } catch(e) {}
  }
  if (!wgEndpoint) {
    wgEndpoint = process.env.WIREGUARD_ENDPOINT || (serverDomain + ':51820');
  }
  const wireguardSection = (cfg.wgIp && cfg.wgPriv && wgServerPub) ? `
# --- WIREGUARD TUNNEL (RumaLink central management) ---
# Clean any leftover RumaLink WG config
:do { /interface wireguard peers remove [find comment="RumaLink-hub"] } on-error={}
:do { /interface wireguard remove [find name="rumalink-wg"] } on-error={}
# Create WG interface (disabled=no + mtu=1420 are essential)
:do { /interface wireguard add name="rumalink-wg" private-key="${cfg.wgPriv}" listen-port=51820 mtu=1420 disabled=no comment="RumaLink" } on-error={}
# Assign WG IP
:do { /ip address remove [find comment="RumaLink-wg"] } on-error={}
:do { /ip address add address=${cfg.wgIp}/24 interface=rumalink-wg comment="RumaLink-wg" } on-error={}
# Add the server as peer (endpoint is SERVER IP, not hostname — DNS unreliable here)
:do { /interface wireguard peers add interface=rumalink-wg public-key="${wgServerPub}" endpoint-address=${wgEndpoint.split(':')[0]} endpoint-port=${wgEndpoint.split(':')[1]||'51820'} allowed-address=10.8.0.0/24 persistent-keepalive=25s comment="RumaLink-hub" } on-error={}
# Make sure firewall allows the WG handshake outbound (rare but happens)
:do { /ip firewall filter remove [find comment="RumaLink-wg-out"] } on-error={}
:do { /ip firewall filter add chain=output action=accept protocol=udp dst-port=51820 comment="RumaLink-wg-out" } on-error={}
:log info "RumaLink WG: interface=rumalink-wg ip=${cfg.wgIp} endpoint=${wgEndpoint}"
:delay 3s
:log info ("RumaLink WG handshake status: " . [/interface wireguard peers get [find comment=\"RumaLink-hub\"] last-handshake])
` : '';

  // Bridge ports: ISP-selected (nas.bridge_ports), else all ethers except WAN
  let bridgePorts = (nas.bridge_ports || '').split(',').map(s => s.trim()).filter(Boolean);
  if (bridgePorts.length === 0) {
    const allIf = (nas.available_interfaces || '').split(',').map(s => s.trim()).filter(Boolean);
    const wan = nas.wan_interface || 'ether1';
    bridgePorts = allIf.filter(i => i !== wan);
    if (bridgePorts.length === 0) bridgePorts = ['ether2', 'ether3', 'ether4', 'ether5', 'wlan1'];
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
:do { /ip hotspot profile add name="rl-hsprof" hotspot-address=${gateway} dns-name="wifi.rumalink" html-directory=hotspot login-by=http-chap,http-pap } on-error={}
:do { /ip hotspot remove [find name="rl-hotspot"] } on-error={}
:do { /ip hotspot add name="rl-hotspot" interface=bridge-hotspot address-pool=rl-pool profile="rl-hsprof" addresses-per-mac=2 disabled=no } on-error={}
:do { /ip firewall nat add chain=srcnat src-address=${network} action=masquerade comment="RumaLink-hs" } on-error={}
:do { /ip hotspot user remove [find name="rumalink"] } on-error={}
:do { /ip hotspot user add name="rumalink" password="rumalink" profile=default comment="RumaLink-generic" } on-error={}
:do { /ip dns set allow-remote-requests=yes } on-error={}
:do { /ip hotspot profile set [find name="rl-hsprof"] login-by=http-chap,http-pap } on-error={}
:do { /ip hotspot walled-garden remove [find comment="RumaLink-portal"] } on-error={}
:do { /ip hotspot walled-garden add dst-host="${serverDomain}" comment="RumaLink-portal" } on-error={}
:do { /ip hotspot walled-garden add dst-host="*.safaricom.co.ke" comment="RumaLink-portal" } on-error={}
# Download RumaLink branded login.html (replaces MikroTik default)
:do { /tool fetch url=("https://${serverDomain}/api/provision/${token}/login-html") mode=https dst-path="hotspot/login.html" } on-error={}
:do { /ip hotspot profile set [find name="rl-hsprof"] html-directory=hotspot } on-error={}
:do { /ip hotspot profile set [find name="rl-hsprof"] use-radius=yes radius-accounting=yes radius-interim-update=2m } on-error={}
` : '';

  const pppoeSection = doPPPoE ? `
# --- PPPOE (v62.47: walled-garden + auto-redirect to pay page) ---
:do { /ip pool add name="rl-pppoe-pool" ranges="100.64.0.2-100.64.0.254" } on-error={}
:do { /ppp profile add name="rl-pppoe-profile" local-address="100.64.0.1" remote-address="rl-pppoe-pool" dns-server="8.8.8.8,1.1.1.1" } on-error={}
:do { /interface pppoe-server server remove [find service-name="rumalink"] } on-error={}
:do { /interface pppoe-server server add service-name="rumalink" interface=bridge-hotspot default-profile="rl-pppoe-profile" authentication=pap,chap,mschap1,mschap2 one-session-per-host=yes max-sessions=200 disabled=no } on-error={}
:do { /ppp aaa set use-radius=yes accounting=yes interim-update=5m } on-error={}
# --- Walled-garden + auto-redirect for EXPIRED PPPoE (v62.47) ---
:do { /ppp profile add name="rl-expired" local-address="100.64.0.1" remote-address="rl-pppoe-pool" dns-server="8.8.8.8,1.1.1.1" address-list="rl-expired" } on-error={}
# Resolve the portal's PUBLIC IP into an address-list (so the pay page is reachable over the internet).
:do { /ip firewall address-list remove [find comment="RumaLink-portal-ip"] } on-error={}
:do { :local pip [:resolve ${serverDomain}]; /ip firewall address-list add list="rl-portal" address=$pip comment="RumaLink-portal-ip" } on-error={}
:do { /ip firewall address-list add list="rl-portal" address="${serverIp}" comment="RumaLink-portal-ip" } on-error={}
# Allow DNS + portal; redirect bare HTTP to the pay page; drop the rest.
# RL_ORDER_NOTE: these are added in order (dns, dns2, portal, then drop) and RouterOS
# appends to the end of the chain, so the accepts naturally precede the drop. Do NOT add
# place-before=0 — it fails on an empty/invalid index and on-error={} hides it, which once
# left ONLY the drop in place and black-holed every expired user (no DNS, no pay page).
:do { /ip firewall filter remove [find comment~"RumaLink-wg-pppoe"] } on-error={}
:do { /ip firewall filter add chain=forward src-address-list="rl-expired" protocol=udp dst-port=53 action=accept comment="RumaLink-wg-pppoe-dns" } on-error={}
:do { /ip firewall filter add chain=forward src-address-list="rl-expired" protocol=tcp dst-port=53 action=accept comment="RumaLink-wg-pppoe-dns2" } on-error={}
:do { /ip firewall filter add chain=forward src-address-list="rl-expired" dst-address-list="rl-portal" action=accept comment="RumaLink-wg-pppoe-portal" } on-error={}
# Transparent HTTP redirect: expired user's port-80 traffic is dst-nat'd to the server's redirect page.
:do { /ip firewall nat remove [find comment="RumaLink-wg-pppoe-redirect"] } on-error={}
:do { :local pip [:resolve ${serverDomain}]; /ip firewall nat add chain=dstnat src-address-list="rl-expired" protocol=tcp dst-port=80 action=dst-nat to-addresses=$pip to-ports=80 comment="RumaLink-wg-pppoe-redirect" } on-error={}
# Anything else from an expired user is dropped (HTTPS sites fail -> phone shows the captive page).
:do { /ip firewall filter add chain=forward src-address-list="rl-expired" action=drop comment="RumaLink-wg-pppoe-drop" } on-error={}
` : '';

  return `# RumaLink Auto-Config for ${isp.company_name} - ${isp.plan_type.toUpperCase()}
:log info "RumaLink: starting configuration"
:do { /ip firewall nat remove [find comment="RumaLink-nat"] } on-error={}
:do { /radius remove [find] } on-error={}
:do { /ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=yes } on-error={}
:do { /interface list add name=RL-WAN comment="RumaLink" } on-error={}
:do {
  :local drif ""
  :local dr [/ip route find where dst-address="0.0.0.0/0" active=yes]
  :if ([:len \$dr] > 0) do={ :set drif [/ip route get [:pick \$dr 0] interface] }
  :if ([:len \$drif] > 0) do={ :do { /interface list member add list=RL-WAN interface=\$drif comment="RumaLink" } on-error={} }
} on-error={}
:do { /ip firewall nat add chain=srcnat out-interface-list=RL-WAN action=masquerade comment="RumaLink-nat" } on-error={}
:do { /ip firewall nat add chain=srcnat action=masquerade comment="RumaLink-nat-fallback" } on-error={}
:do { /radius add address=${serverIp} secret="${radiusSecret}" service=hotspot,ppp authentication-port=1812 accounting-port=1813 timeout=3000ms require-message-auth=no comment="RumaLink" } on-error={}
:do { /radius incoming set accept=yes port=3799 } on-error={}
${wireguardSection}${hotspotSection}${pppoeSection}
:do { /user group add name="rumalink-api" policy="api,read,write,reboot,test,ssh,winbox" comment="RumaLink" } on-error={}
:do { /user remove [find name="${apiUser}"] } on-error={}
:do { /user add name="${apiUser}" password="${apiPass}" group=rumalink-api comment="RumaLink" } on-error={}
:do { /ip service enable api } on-error={}
:do { /ip service enable api-ssl } on-error={}
# Enable REST API (HTTP/www) but ONLY accept connections from the WG subnet (security)
:do { /ip service enable www } on-error={}
:do { /ip service set www address=10.8.0.0/24 } on-error={}
# Also restrict the binary API services to WG for safety
:do { /ip service set api address=10.8.0.0/24 } on-error={}
:do { /ip service set api-ssl address=10.8.0.0/24 } on-error={}
# Ensure the api user we generated has full=yes group permissions (read-only by default)
:do { /user set [find name="${apiUser}"] group=full } on-error={}
:do { /system scheduler remove [find name="rl-heartbeat"] } on-error={}
:do { /system scheduler add name="rl-heartbeat" interval=5m comment="RumaLink" on-event=("/tool fetch url=\\"https://${serverDomain}/api/provision/heartbeat/${token}\\" http-method=post http-data=(\\"cpu=\\".[/system resource get cpu-load].\\"&mem_free=\\".[/system resource get free-memory].\\"&mem_total=\\".[/system resource get total-memory].\\"&disk_free=\\".[/system resource get free-hdd-space].\\"&disk_total=\\".[/system resource get total-hdd-space].\\"&uptime=\\".[/system resource get uptime].\\"&board=\\".[/system resource get board-name].\\"&version=\\".[/system resource get version].\\"&identity=\\".[/system identity get name]) keep-result=no") } on-error={}
# Send one heartbeat immediately (don't wait 5min for first scheduler run)
:delay 3s
:do { /tool fetch url=("https://${serverDomain}/api/provision/heartbeat/${token}") http-method=post http-data=("cpu=".[/system resource get cpu-load]."&mem_free=".[/system resource get free-memory]."&mem_total=".[/system resource get total-memory]."&disk_free=".[/system resource get free-hdd-space]."&disk_total=".[/system resource get total-hdd-space]."&uptime=".[/system resource get uptime]."&board=".[/system resource get board-name]."&version=".[/system resource get version]."&identity=".[/system identity get name]) keep-result=no } on-error={}
:log info "RumaLink: first heartbeat sent"
# --- RL_MAINSCRIPT_PORTREPORT: detect ethernet ports and report them so the dashboard can show the WAN picker ---
:local iflist ""
:foreach i in=[/interface ethernet find] do={
  :local nm [/interface ethernet get \$i name]
  :if ([:len \$iflist] > 0) do={ :set iflist (\$iflist . ",") }
  :set iflist (\$iflist . \$nm)
}
:put ("RumaLink detected ports: " . \$iflist)
:local wanIf ""
:do {
  :local gw [/ip route find where dst-address="0.0.0.0/0" active=yes]
  :if ([:len \$gw] > 0) do={ :set wanIf [/ip route get [:pick \$gw 0] interface] }
} on-error={}
:do {
  /tool fetch url=("https://${serverDomain}/api/provision/${token}/interfaces") mode=https http-method=post http-header-field="Content-Type: application/json" http-data=("{\\"interfaces\\":\\"" . \$iflist . "\\",\\"wan\\":\\"" . \$wanIf . "\\"}") keep-result=no
} on-error={}
# --- RL_WAN_CONFIGURE: poll for the dashboard WAN selection, then configure the uplink ---
:put "RumaLink: waiting for you to pick the WAN port in the dashboard..."
# RL_WAN_GLOBAL_SCOPE: declare ALL globals so values set by the imported rl-wan.rsc are visible here
:global rlSel 0
:global rlWanPort ""
:global rlWanType ""
:global rlUser ""
:global rlPass ""
:global rlSip ""
:global rlSgw ""
:global rlBridge ""
:local done false
:local tries 0
:while (\$done = false && \$tries < 24) do={
  :set tries (\$tries + 1)
  :do {
    /tool fetch url=("https://${serverDomain}/api/provision/${token}/wan-config") mode=https dst-path=rl-wan.rsc keep-result=yes
    :delay 1s
    /import file-name=rl-wan.rsc
  } on-error={}
  :if (\$rlSel = 1) do={
    :set done true
    :put ("RumaLink: configuring WAN " . \$rlWanPort . " (" . \$rlWanType . ")")
    :do { :foreach dc in=[/ip dhcp-client find where comment="RumaLink-bootstrap"] do={ :if ([/ip dhcp-client get \$dc interface] != \$rlWanPort) do={ /ip dhcp-client remove \$dc } } } on-error={}
    :do { /interface list member remove [find list=RL-WAN comment="RumaLink"] } on-error={}
    :if (\$rlWanType = "pppoe") do={
      :do { /interface pppoe-client remove [find name="rl-wan-pppoe"] } on-error={}
      :do { /interface pppoe-client add name="rl-wan-pppoe" interface=\$rlWanPort user=\$rlUser password=\$rlPass add-default-route=yes use-peer-dns=yes disabled=no comment="RumaLink-wan" } on-error={}
      :do { /interface list member add list=RL-WAN interface="rl-wan-pppoe" comment="RumaLink" } on-error={}
    }
    :if (\$rlWanType = "dhcp") do={
      :do { /ip dhcp-client remove [find interface=\$rlWanPort] } on-error={}
      :do { /ip dhcp-client add interface=\$rlWanPort add-default-route=yes use-peer-dns=yes disabled=no comment="RumaLink-wan" } on-error={}
      :do { /interface list member add list=RL-WAN interface=\$rlWanPort comment="RumaLink" } on-error={}
    }
    :if (\$rlWanType = "static") do={
      :do { /ip address remove [find comment="RumaLink-wan"] } on-error={}
      :do { /ip address add address=\$rlSip interface=\$rlWanPort comment="RumaLink-wan" } on-error={}
      :do { /ip route add dst-address=0.0.0.0/0 gateway=\$rlSgw comment="RumaLink-wan" } on-error={}
      :do { /interface list member add list=RL-WAN interface=\$rlWanPort comment="RumaLink" } on-error={}
    }
    # RL_BRIDGE_REBUILD: make the hotspot bridge match the dashboard selection
    :if ([:len \$rlBridge] > 0) do={
      # remove all RumaLink-managed bridge ports, then add back only the selected ones
      :do { /interface bridge port remove [find comment="RumaLink"] } on-error={}
      :local bl [:toarray \$rlBridge]
      :foreach bp in=\$bl do={
        :if (\$bp != \$rlWanPort) do={ :do { /interface bridge port add bridge=bridge-hotspot interface=\$bp comment="RumaLink" } on-error={} }
      }
      :put ("RumaLink: bridge set to " . \$rlBridge)
    }
    :do { /file remove [find name="rl-wan.rsc"] } on-error={}
    :put "RumaLink: WAN configured."
  } else={ :delay 4s }
}
:if (\$done = false) do={
  :put "RumaLink: no WAN picked yet - keeping temporary DHCP so you stay online. Pick it in the dashboard, then re-run the import."
}
:log info "RumaLink: configuration complete"
:put "RumaLink Setup Complete - Plan: ${isp.plan_type}"
`;
}

// ──────────────────────────────────────────────────────────────
// POST /:token — device check-in (returns JSON)
// ──────────────────────────────────────────────────────────────
// v62.19: sync secret column with radius_secret for backward compat
async function syncProvisionSecret(nasId) {
  try {
    await query("UPDATE nas_devices SET secret = radius_secret WHERE id = $1::uuid AND radius_secret IS NOT NULL AND secret IS DISTINCT FROM radius_secret", [nasId]);
  } catch (e) { /* ignore */ }
}

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
    // v62.50: RADIUS lives on WG hub 10.8.0.1, NOT the public domain IP
    const serverIp = process.env.RADIUS_HOST || '10.8.0.1';

    query(`INSERT INTO notifications (isp_id,type,title,message,link) VALUES ($1::uuid,'success','MikroTik Configured',$2,'/isp/dashboard.html')`,
      [nas.isp_id, `"${nas.name || 'Router'}" pulled and imported its config.`]).catch(() => {});
    query(`INSERT INTO nas_events (nas_id,isp_id,event_type,message) VALUES ($1::uuid,$2::uuid,'provisioned','Config imported')`,
      [nas.id, nas.isp_id]).catch(() => {});
    
    // ─── AUTO-PROVISION RADIUS: backfill secret, push /radius entry, rebuild clients.conf ───
    try {
      // 1. Ensure radius_secret is set
      const secretRow = await query(
        `UPDATE nas_devices 
            SET radius_secret = COALESCE(NULLIF(radius_secret, ''), encode(gen_random_bytes(16), 'hex'))
          WHERE id = $1::uuid 
        RETURNING radius_secret, wireguard_ip, mikrotik_api_user, mikrotik_api_password`,
        [nas.id]
      );
      const ns = secretRow.rows[0];
      if (ns && ns.wireguard_ip) {
        // 2. Push /radius entry via REST
        try {
          const mt = require('../utils/mikrotik');
          // Use mt's loadDevice + clientFor
          const dev = await mt.loadDevice(ns.id);
          const client = mt.clientFor ? mt.clientFor(dev) : null;
          if (client) {
            // Remove existing RumaLink-VPS entries
            const existing = await client.get('/radius');
            for (const r of (existing.data || [])) {
              if (r.comment === 'RumaLink-VPS' || r.address === '10.8.0.1') {
                await client.del('/radius/' + r['.id']);
              }
            }
            // Add fresh
            await client.put('/radius', {
              address: '10.8.0.1',
              secret: ns.radius_secret,
              service: 'hotspot,ppp',
              timeout: '3s',
              'src-address': ns.wireguard_ip,
              'authentication-port': '1812',
              'accounting-port': '1813',
              comment: 'RumaLink-VPS'
            });
            require('../utils/logger').info(`[RADIUS-PROVISION] added /radius entry on ${ns.id}`);
          }
        } catch(e) { require('../utils/logger').warn(`[RADIUS-PROVISION] router push failed: ${e.message}`); }

        // 3. Rebuild clients.conf and reload FreeRADIUS
        try {
          const { execFile } = require('child_process');
          execFile('/usr/local/bin/rl-rebuild-radius-clients', [], { timeout: 5000 }, (err, stdout, stderr) => {
            if (err) require('../utils/logger').warn(`[RADIUS-PROVISION] clients rebuild: ${err.message}`);
            else require('../utils/logger').info(`[RADIUS-PROVISION] clients.conf rebuilt`);
          });
        } catch(e) {}
      }
    } catch(e) { require('../utils/logger').warn(`[RADIUS-PROVISION] error: ${e.message}`); }

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
         mikrotik_board=COALESCE(NULLIF($7,''), mikrotik_board),
         mikrotik_version=COALESCE(NULLIF($8,''), mikrotik_version),
         mikrotik_identity=COALESCE(NULLIF($9,''), mikrotik_identity),
         updated_at=NOW()
       WHERE provision_token=$10`,
      [cpu, memUsedMB, memTotal, diskUsedMB, diskTotal, uptimeSec,
       body.board || null, body.version || null, body.identity || null,
       req.params.token]
    );

    // Broadcast to ISP dashboard via websocket
    try {
      const dev = await query('SELECT id, isp_id, name FROM nas_devices WHERE provision_token=$1', [req.params.token]);
      
    // ─── AUTO-PROVISION RADIUS: backfill secret, push /radius entry, rebuild clients.conf ───
    try {
      // 1. Ensure radius_secret is set
      const secretRow = await query(
        `UPDATE nas_devices 
            SET radius_secret = COALESCE(NULLIF(radius_secret, ''), encode(gen_random_bytes(16), 'hex'))
          WHERE id = $1::uuid 
        RETURNING radius_secret, wireguard_ip, mikrotik_api_user, mikrotik_api_password`,
        [nas.id]
      );
      const ns = secretRow.rows[0];
      if (ns && ns.wireguard_ip) {
        // 2. Push /radius entry via REST
        try {
          const mt = require('../utils/mikrotik');
          // Use mt's loadDevice + clientFor
          const dev = await mt.loadDevice(ns.id);
          const client = mt.clientFor ? mt.clientFor(dev) : null;
          if (client) {
            // Remove existing RumaLink-VPS entries
            const existing = await client.get('/radius');
            for (const r of (existing.data || [])) {
              if (r.comment === 'RumaLink-VPS' || r.address === '10.8.0.1') {
                await client.del('/radius/' + r['.id']);
              }
            }
            // Add fresh
            await client.put('/radius', {
              address: '10.8.0.1',
              secret: ns.radius_secret,
              service: 'hotspot,ppp',
              timeout: '3s',
              'src-address': ns.wireguard_ip,
              'authentication-port': '1812',
              'accounting-port': '1813',
              comment: 'RumaLink-VPS'
            });
            require('../utils/logger').info(`[RADIUS-PROVISION] added /radius entry on ${ns.id}`);
          }
        } catch(e) { require('../utils/logger').warn(`[RADIUS-PROVISION] router push failed: ${e.message}`); }

        // 3. Rebuild clients.conf and reload FreeRADIUS
        try {
          const { execFile } = require('child_process');
          execFile('/usr/local/bin/rl-rebuild-radius-clients', [], { timeout: 5000 }, (err, stdout, stderr) => {
            if (err) require('../utils/logger').warn(`[RADIUS-PROVISION] clients rebuild: ${err.message}`);
            else require('../utils/logger').info(`[RADIUS-PROVISION] clients.conf rebuilt`);
          });
        } catch(e) {}
      }
    } catch(e) { require('../utils/logger').warn(`[RADIUS-PROVISION] error: ${e.message}`); }

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



// ── GET /:token/discover — RL_PROVISION_DISCOVER: bootstrap + list ports ──
router.get('/:token/discover', async (req, res) => {
  const { token } = req.params;
  try {
    const deviceRes = await query('SELECT * FROM nas_devices WHERE provision_token = $1', [token]);
    if (!deviceRes.rows[0]) return res.status(404).type('text/plain').send(':log error "RumaLink: invalid token"');
    const serverDomain = (process.env.BASE_URL || 'https://rumalinkenterprise.online').replace(/^https?:\/\//, '');

    const rsc =
`# RumaLink — STEP 1: Discover ports & get online
:log info "RumaLink discover: starting"
:do {
  :local haveInet false
  :foreach dc in=[/ip dhcp-client find] do={ :if ([/ip dhcp-client get \$dc status] = "bound") do={ :set haveInet true } }
  :if (\$haveInet = false) do={
    :do { /ip dhcp-client add interface=ether1 disabled=no comment="RumaLink-bootstrap" } on-error={}
    :delay 6s
  }
} on-error={}
:local iflist ""
:foreach i in=[/interface ethernet find] do={
  :local nm [/interface ethernet get \$i name]
  :if ([:len \$iflist] > 0) do={ :set iflist (\$iflist . ",") }
  :set iflist (\$iflist . \$nm)
}
:put ("RumaLink detected ports: " . \$iflist)
:local wanIf ""
:do {
  :local gw [/ip route find where dst-address="0.0.0.0/0" active=yes]
  :if ([:len \$gw] > 0) do={ :set wanIf [/ip route get [:pick \$gw 0] interface] }
} on-error={}
:do {
  /tool fetch url=("https://${serverDomain}/api/provision/${token}/interfaces") mode=https http-method=post http-header-field="Content-Type: application/json" http-data=("{\\"interfaces\\":\\"" . \$iflist . "\\",\\"wan\\":\\"" . \$wanIf . "\\"}") keep-result=no
} on-error={}
:put "===================================================="
:put "RumaLink STEP 2 - set your MAIN link, then import"
:put "Type ONE set of these lines (edit the values), press enter,"
:put "then run the import line at the bottom."
:put ""
:put "  PPPoE (most common):"
:put "    :global rlWanPort ether1"
:put "    :global rlWanType pppoe"
:put "    :global rlPPPoEUser myuser"
:put "    :global rlPPPoEPass mypass"
:put ""
:put "  OR DHCP on a port:"
:put "    :global rlWanPort ether1"
:put "    :global rlWanType dhcp"
:put ""
:put "  OR static IP:"
:put "    :global rlWanPort ether1"
:put "    :global rlWanType static"
:put "    :global rlStaticIp 197.0.0.2/30"
:put "    :global rlStaticGw 197.0.0.1"
:put ""
:put "Then run this one line:"
:put ("  /tool fetch url=https://${serverDomain}/api/provision/${token}/script mode=https dst-path=rumalink-setup.rsc")
:put "  :delay 2s"
:put "  /import file-name=rumalink-setup.rsc"
:put "===================================================="
:log info "RumaLink discover: done"
`;
    res.type('text/plain').send(rsc);
  } catch (err) {
    require('../utils/logger').error('discover error: ' + err.message);
    res.status(500).type('text/plain').send(':log error "RumaLink discover error"');
  }
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
    
    // ─── AUTO-PROVISION RADIUS: backfill secret, push /radius entry, rebuild clients.conf ───
    try {
      // 1. Ensure radius_secret is set
      const secretRow = await query(
        `UPDATE nas_devices 
            SET radius_secret = COALESCE(NULLIF(radius_secret, ''), encode(gen_random_bytes(16), 'hex'))
          WHERE id = $1::uuid 
        RETURNING radius_secret, wireguard_ip, mikrotik_api_user, mikrotik_api_password`,
        [nas.id]
      );
      const ns = secretRow.rows[0];
      if (ns && ns.wireguard_ip) {
        // 2. Push /radius entry via REST
        try {
          const mt = require('../utils/mikrotik');
          // Use mt's loadDevice + clientFor
          const dev = await mt.loadDevice(ns.id);
          const client = mt.clientFor ? mt.clientFor(dev) : null;
          if (client) {
            // Remove existing RumaLink-VPS entries
            const existing = await client.get('/radius');
            for (const r of (existing.data || [])) {
              if (r.comment === 'RumaLink-VPS' || r.address === '10.8.0.1') {
                await client.del('/radius/' + r['.id']);
              }
            }
            // Add fresh
            await client.put('/radius', {
              address: '10.8.0.1',
              secret: ns.radius_secret,
              service: 'hotspot,ppp',
              timeout: '3s',
              'src-address': ns.wireguard_ip,
              'authentication-port': '1812',
              'accounting-port': '1813',
              comment: 'RumaLink-VPS'
            });
            require('../utils/logger').info(`[RADIUS-PROVISION] added /radius entry on ${ns.id}`);
          }
        } catch(e) { require('../utils/logger').warn(`[RADIUS-PROVISION] router push failed: ${e.message}`); }

        // 3. Rebuild clients.conf and reload FreeRADIUS
        try {
          const { execFile } = require('child_process');
          execFile('/usr/local/bin/rl-rebuild-radius-clients', [], { timeout: 5000 }, (err, stdout, stderr) => {
            if (err) require('../utils/logger').warn(`[RADIUS-PROVISION] clients rebuild: ${err.message}`);
            else require('../utils/logger').info(`[RADIUS-PROVISION] clients.conf rebuilt`);
          });
        } catch(e) {}
      }
    } catch(e) { require('../utils/logger').warn(`[RADIUS-PROVISION] error: ${e.message}`); }

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

// ── POST /:token/set-wan — RL_WAN_SELECT: dashboard saves WAN port + type + creds + LAN ports ──
router.post('/:token/set-wan', async (req, res) => {
  try {
    const b = req.body || {};
    const wanPort = String(b.wan_port || '').trim();
    const wanType = ['pppoe','dhcp','static'].includes(b.wan_type) ? b.wan_type : 'dhcp';
    if (!wanPort) return res.status(400).json({ error: 'wan_port required' });

    const bridgePorts = String(b.ports || '').split(',').map(x=>x.trim()).filter(Boolean)
      .filter(x => x !== wanPort); // never bridge the WAN port

    const pppoeUser = wanType === 'pppoe' ? (String(b.pppoe_user||'').trim() || null) : null;
    const pppoePass = wanType === 'pppoe' ? (String(b.pppoe_pass||'').trim() || null) : null;
    const staticIp  = wanType === 'static' ? (String(b.static_ip||'').trim() || null) : null;
    const staticGw  = wanType === 'static' ? (String(b.static_gw||'').trim() || null) : null;

    await query(
      `UPDATE nas_devices SET
         wan_interface=$1::varchar, wan_type=$2::varchar,
         wan_pppoe_user=$3, wan_pppoe_pass=$4, wan_static_ip=$5, wan_static_gw=$6,
         bridge_ports=$7::varchar, wan_selected=true, updated_at=NOW()
       WHERE provision_token=$8`,
      [wanPort, wanType, pppoeUser, pppoePass, staticIp, staticGw, bridgePorts.join(','), req.params.token]
    );
    res.json({ success: true, wan: wanPort, wan_type: wanType, bridge_ports: bridgePorts });
  } catch (err) {
    require('../utils/logger').error('set-wan error: ' + err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── GET /:token/wan-config — RL_WAN_CONFIGURE: returns a tiny .rsc that sets :global vars ──
// The router fetches+imports this (no JSON parsing on RouterOS => no quote-escaping bugs).
router.get('/:token/wan-config', async (req, res) => {
  try {
    const r = await query(
      'SELECT wan_interface, wan_type, wan_pppoe_user, wan_pppoe_pass, wan_static_ip, wan_static_gw, wan_selected, bridge_ports FROM nas_devices WHERE provision_token=$1',
      [req.params.token]);
    if (!r.rows[0] || !r.rows[0].wan_selected) {
      return res.type('text/plain').send(':global rlSel 0\n');
    }
    const d = r.rows[0];
    const esc = v => String(v == null ? '' : v).replace(/[\\"\r\n]/g, ''); // strip quotes/newlines for safety
    const lines = [
      ':global rlSel 1',
      ':global rlWanPort "' + esc(d.wan_interface || 'ether1') + '"',
      ':global rlWanType "' + esc(d.wan_type || 'dhcp') + '"',
      ':global rlUser "' + esc(d.wan_pppoe_user) + '"',
      ':global rlPass "' + esc(d.wan_pppoe_pass) + '"',
      ':global rlSip "' + esc(d.wan_static_ip) + '"',
      ':global rlSgw "' + esc(d.wan_static_gw) + '"',
      ':global rlBridge "' + esc(d.bridge_ports) + '"', /* RL_BRIDGE_REBUILD */
      ''
    ];
    res.type('text/plain').send(lines.join('\n'));
  } catch (err) {
    res.type('text/plain').send(':global rlSel 0\n');
  }
});




// ─── v61: RADIUS-PROVISION-V61 — comprehensive RADIUS setup on router during provision ───
async function rumalinkRadiusProvisionV61(nas_id) {
  const log = require('../utils/logger');
  try {
    const r = await query(
      `SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password, radius_secret
       FROM nas_devices WHERE id = $1::uuid LIMIT 1`,
      [nas_id]
    );
    if (!r.rows[0]) { log.warn(`[RADIUS-PROVISION-V61] no NAS ${nas_id}`); return; }
    const nas = r.rows[0];
    if (!nas.wireguard_ip || !nas.mikrotik_api_user) { log.warn(`[RADIUS-PROVISION-V61] missing creds for ${nas_id}`); return; }
    
    // Ensure radius_secret exists
    let secret = nas.radius_secret;
    if (!secret) {
      const crypto = require('crypto');
      secret = crypto.randomBytes(16).toString('hex');
      await query(`UPDATE nas_devices SET radius_secret = $1 WHERE id = $2::uuid`, [secret, nas_id]);
    await syncProvisionSecret(nas.id);
      log.info(`[RADIUS-PROVISION-V61] generated secret for ${nas.name}`);
    }
    
    const axios = require('axios');
    const baseURL = `http://${nas.wireguard_ip}/rest`;
    const auth = { username: nas.mikrotik_api_user, password: nas.mikrotik_api_password };
    
    // 1. /radius entry pointing to 10.8.0.1 (clean + create)
    try {
      const existing = await axios.get(baseURL + '/radius', { auth, timeout: 5000 });
      const vpsEntries = (existing.data || []).filter(e => e.address === '10.8.0.1');
      for (const e of vpsEntries) {
        await axios.delete(`${baseURL}/radius/${e['.id']}`, { auth, timeout: 5000 });
      }
      await axios.put(baseURL + '/radius', {
        address: '10.8.0.1',
        secret,
        service: 'hotspot,login',
        timeout: '3s',
        'src-address': nas.wireguard_ip,
        'authentication-port': '1812',
        'accounting-port': '1813',
        comment: 'RumaLink-VPS'
      }, { auth, timeout: 5000 });
      log.info(`[RADIUS-PROVISION-V61] /radius entry ensured on ${nas.name}`);
    } catch(e) { log.warn(`[RADIUS-PROVISION-V61] /radius: ${e.message}`); }
    
    // 2. /radius/incoming accept=yes port=3799 (for CoA-Disconnect from VPS)
    try {
      await axios.post(baseURL + '/radius/incoming/set', {
        accept: 'yes',
        port: '3799'
      }, { auth, timeout: 5000 });
      log.info(`[RADIUS-PROVISION-V61] /radius/incoming set on ${nas.name}`);
    } catch(e) {
      // Fallback: many RouterOS versions use PATCH /radius/incoming
      try {
        await axios.patch(baseURL + '/radius/incoming', {
          accept: 'yes',
          port: '3799'
        }, { auth, timeout: 5000 });
        log.info(`[RADIUS-PROVISION-V61] /radius/incoming patched on ${nas.name}`);
      } catch(e2) { log.warn(`[RADIUS-PROVISION-V61] /radius/incoming: ${e2.message}`); }
    }
    
    // 3. Find rl-hsprof and apply RADIUS settings
    try {
      const profs = await axios.get(`${baseURL}/ip/hotspot/profile`, { auth, timeout: 5000 });
      const rlprof = (profs.data || []).find(p => p.name === 'rl-hsprof' || p.name === 'hsprof1');
      if (rlprof) {
        await axios.patch(`${baseURL}/ip/hotspot/profile/${rlprof['.id']}`, {
          'use-radius': 'yes',
          'radius-accounting': 'yes',
          'radius-interim-update': '2m',
          'radius-mac-format': 'XX:XX:XX:XX:XX:XX',
          'nas-port-type': 'wireless-802.11',
          'login-by': 'http-chap,http-pap'
        }, { auth, timeout: 5000 });
        log.info(`[RADIUS-PROVISION-V61] rl-hsprof RADIUS settings applied on ${nas.name}`);
      } else {
        log.warn(`[RADIUS-PROVISION-V61] rl-hsprof not found on ${nas.name}`);
      }
    } catch(e) { log.warn(`[RADIUS-PROVISION-V61] hsprof: ${e.message}`); }
    
    log.info(`[RADIUS-PROVISION-V61] complete for ${nas.name}`);
  } catch (err) {
    require('../utils/logger').error(`[RADIUS-PROVISION-V61] ${err.message}`);
  }
}
// ─── /end RADIUS-PROVISION-V61 ───



// ─── v61: Manual re-apply endpoint for existing NASs ───
// POST /api/provision/v61-reapply/:nasId — re-run RADIUS-PROVISION-V61 on an existing router
// Useful for fixing routers provisioned before v61 was deployed
router.post('/v61-reapply/:nasId', async (req, res) => {
  try {
    const nasId = req.params.nasId;
    // Fire-and-forget (could take seconds)
    setImmediate(() => rumalinkRadiusProvisionV61(nasId));
    res.json({ ok: true, message: 'RADIUS-PROVISION-V61 triggered', nasId });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

module.exports = router;
