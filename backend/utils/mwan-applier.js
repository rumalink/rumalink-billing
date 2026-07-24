// v62.105 — Multi-WAN Applier (SAFE: DHCP-distance management + VPS internet probes)
//
// SAFETY-FIRST DESIGN (learned from v62.104 incident):
//   - We NEVER set add-default-route=no. DHCP always creates working default routes,
//     so the router (and its WireGuard management tunnel) can never lose its path.
//   - Failover = adjusting each DHCP client's default-route-distance. The lowest
//     distance with internet wins; dead-internet links get parked at high distance.
//   - The VPS monitor pings per-WAN probe targets (forced via /32 routes) to detect
//     ACTUAL internet (not just gateway) and sets distances accordingly.
//
// MikroTik objects (all tagged "RL-MWAN"):
//   - DHCP client: add-default-route=yes, default-route-distance managed by VPS
//   - /32 probe route per WAN: <probe_target>/32 via <gateway> (for VPS internet checks)
//   - routing table rl_via_wanN (fib) + its default route (for policy routing)
//   - address-lists + mangle (for policy routing; RADIUS populates lists)

const { query } = require('../config/database');
const logger = require('./logger');

const RL_TAG = 'RL-MWAN';
const PARKED_DISTANCE = 200;

// Multi-role: a link can be in the LB pool AND a failover member. Flags drive grouping;
// fall back to the legacy single `role` for any link not yet migrated.
function roleFlags(l) {
  let inLb = l.in_load_balance === true;
  let isFo = l.is_failover === true;
  if (!inLb && !isFo) { inLb = (l.role === 'load_balance'); isFo = (l.role === 'failover_primary' || l.role === 'failover_backup'); }
  return { inLb, isFo };
}
const DEFAULT_PROBES = ['8.8.8.8', '1.1.1.1', '9.9.9.9', '208.67.222.222', '8.8.4.4', '64.6.64.6'];

async function mtCall(dev, method, path, body) {
  const url = 'http://' + dev.wireguard_ip + '/rest' + path;
  const authHdr = 'Basic ' + Buffer.from(dev.mikrotik_api_user + ':' + dev.mikrotik_api_password).toString('base64');
  const opts = {
    method,
    headers: { 'Authorization': authHdr, 'Content-Type': 'application/json', 'Accept': 'application/json' },
    signal: AbortSignal.timeout(15000)
  };
  if (body !== undefined) opts.body = JSON.stringify(body);
  const resp = await fetch(url, opts);
  let data = null;
  try { data = await resp.json(); } catch(e) {}
  if (!resp.ok) {
    const errMsg = (data && (data.detail || data.message || data.error)) || ('HTTP ' + resp.status);
    throw new Error(`${method} ${path} → ${errMsg}`);
  }
  return data;
}

// RL_TYPE_AWARE: detect what kind of uplink a link's physical port carries.
// Returns { type:'pppoe'|'dhcp'|'static', routeIface, gateway }.
//  - pppoe:  a /interface/pppoe-client bound to link.interface. Its route gateway is
//            the pppoe interface NAME (RouterOS uses the interface as the gateway).
//  - dhcp:   a /ip/dhcp-client on link.interface; gateway comes from the lease.
//  - static: a manual /ip/address on link.interface (+ link.gateway or a default route).
async function detectLinkType(dev, link, caches) {
  const c = caches || {};
  try {
    const pppoes = c.pppoe || await mtCall(dev, 'GET', '/interface/pppoe-client');
    const pc = (pppoes||[]).find(p => p.interface === link.interface);
    if (pc) {
      /* RL_PPPOE_PEER_GW: a PPPoE route gateway given as the INTERFACE NAME works in the main
         table but goes inactive inside a custom routing-table (rl_via_wanN) on RouterOS 7 —
         which silently sent all wan1-marked traffic back to main (observed 97/3 split on a
         50/50 config). The peer/next-hop IP resolves correctly in every table. RouterOS stores
         it as the `network` of the pppoe /32 address (local=172.31.0.33/32 network=172.31.0.1). */
      let peerIp = null;
      try {
        const addrs = c.addr || await mtCall(dev, 'GET', '/ip/address');
        const pa = (addrs||[]).find(a => a.interface === pc.name);
        if (pa && pa.network && pa.network !== '0.0.0.0') peerIp = String(pa.network).split('/')[0];
      } catch(e) {}
      return { type: 'pppoe', routeIface: pc.name, gateway: peerIp || pc.name, peerIp: peerIp };
    }
  } catch(e) {}
  try {
    const dhcps = c.dhcp || await mtCall(dev, 'GET', '/ip/dhcp-client');
    const dc = (dhcps||[]).find(d => d.interface === link.interface);
    if (dc) return { type: 'dhcp', routeIface: link.interface, gateway: (dc.gateway && dc.gateway !== '0.0.0.0') ? dc.gateway : null };
  } catch(e) {}
  // static
  return { type: 'static', routeIface: link.interface, gateway: (link.gateway||'').trim() || null };
}

async function resolveLinkGateway(dev, link, dhcpsCache, caches) {
  // explicit static gateway wins
  if (link.gateway && /^\d+\.\d+\.\d+\.\d+$/.test((link.gateway||'').trim())) return link.gateway.trim();
  // RL_TYPE_AWARE: detect type; PPPoE's "gateway" is the pppoe interface name.
  try {
    const t = await detectLinkType(dev, link, caches || (dhcpsCache ? { dhcp: dhcpsCache } : null));
    /* RL_RESOLVE_PEER_GW: prefer the PEER IP (t.gateway) over the interface name. An interface-name
       gateway goes inactive inside custom routing tables (rl_via_wanN) on RouterOS 7, which silently
       dumped all wan1-marked traffic back to the main table (97/3 split on a 50/50 config). */
    if (t.type === 'pppoe') return t.gateway || t.routeIface;
    if (t.type === 'dhcp' && t.gateway) return t.gateway;   // lease gw
    if (t.type === 'static' && t.gateway) return t.gateway; // configured gw
  } catch(e) {}
  // legacy dhcp fallback
  try {
    const dhcps = dhcpsCache || await mtCall(dev, 'GET', '/ip/dhcp-client');
    const dhcp = dhcps.find(d => d.interface === link.interface);
    if (dhcp && dhcp.gateway && dhcp.gateway !== '0.0.0.0') return dhcp.gateway;
  } catch(e) {}
  return null;
}

function assignProbeTargets(links) {
  const used = new Set(); const result = {};
  for (const link of links) {
    const t = (link.ping_target || '').trim();
    if (t && /^\d+\.\d+\.\d+\.\d+$/.test(t) && !used.has(t)) { result[link.id] = t; used.add(t); }
  }
  for (const link of links) {
    if (result[link.id]) continue;
    const avail = DEFAULT_PROBES.find(p => !used.has(p));
    const chosen = avail || ('8.8.8.' + (link.position % 250 + 1));
    result[link.id] = chosen; used.add(chosen);
  }
  return result;
}

async function buildPlan(deviceId, ispId) {
  const dr = await query(
    `SELECT d.*, i.id AS isp_id FROM nas_devices d JOIN isps i ON i.id = d.isp_id
     WHERE d.id = $1::uuid AND d.isp_id = $2::uuid`, [deviceId, ispId]);
  if (!dr.rows[0]) throw new Error('Device not found');
  const dev = dr.rows[0];

  const linksR = await query(`SELECT * FROM nas_wan_links WHERE nas_id = $1::uuid AND enabled = true ORDER BY position ASC`, [deviceId]);
  const links = linksR.rows;
  if (!links.length) throw new Error('No WAN links configured');

  const policiesR = await query(`SELECT * FROM nas_wan_policies WHERE nas_id = $1::uuid AND enabled = true ORDER BY priority ASC`, [deviceId]);
  const policies = policiesR.rows;

  const mode = dev.multi_wan_mode || 'none';
  if (mode === 'none') throw new Error('Multi-WAN mode is Disabled — nothing to apply');

  const failoverLinks = links.filter(l => roleFlags(l).isFo);
  const lbLinks = links.filter(l => roleFlags(l).inLb);
  const probes = assignProbeTargets(links);
  // RL_TYPE_AWARE: pre-fetch uplink caches so detectLinkType is cheap during plan build.
  let caches = {};
  try { caches.pppoe = await mtCall(dev, 'GET', '/interface/pppoe-client'); } catch(e){ caches.pppoe = []; }
  try { caches.dhcp  = await mtCall(dev, 'GET', '/ip/dhcp-client'); } catch(e){ caches.dhcp = []; }

  const ops = [];
  ops.push({ description: '🧹 Remove any previous RumaLink Multi-WAN configuration', cleanup: true });

  for (const link of links) {
    ops.push({ description: `🔌 Prepare interface ${link.interface} for WAN${link.position} (${link.name || ''})`, prepare_iface: link });
  }

  // Detect hotspot interface — hotspot MUST ride the MAIN routing table. RouterOS 7's
  // hotspot web-proxy can only use the default table, so routing hotspot via a custom
  // table makes the OS connectivity check fail ("connected, no internet") even though
  // browsing works. We skip hotspot from marking below; it load-balances via main ECMP.
  let hotspotIface = null;
  try {
    const _hs = await mtCall(dev, 'GET', '/ip/hotspot');
    if (Array.isArray(_hs) && _hs.length) hotspotIface = _hs[0].interface || null;
  } catch (e) { /* no hotspot, or router unreachable at plan-build time */ }

  // DHCP: KEEP add-default-route=YES. Set initial default-route-distance by priority.
  // Netwatch (added below) adjusts these distances locally on internet up/down.
  const healthyDist = {};
  let dist = 1;
  for (const link of links) {
    const _f = roleFlags(link);
    // LB pool members are ECMP at distance 1. Pure-failover links use their priority.
    let thisDist;
    if (_f.inLb) thisDist = 1;
    else if (_f.isFo) { thisDist = link.failover_priority ? parseInt(link.failover_priority) : dist; if (!link.failover_priority) dist++; }
    else thisDist = 1;
    healthyDist[link.id] = thisDist;
    // RL_TYPE_AWARE: patch the right object at apply time based on detected uplink type.
    ops.push({
      description: `⚙ ${link.interface}: set WAN${link.position} default-route-distance=${thisDist}`,
      _patch_distance_for_link: link, _distance: thisDist
    });
    // (failover distance handled above)
  }

  // Stable router DNS — independent of either WAN's ISP DNS. With multiple WANs, peer
  // DNS learned from a non-active WAN yields intermittent lookups, and the hotspot OS
  // connectivity check then flaps "connected, no internet". use-peer-dns=no (above) plus
  // static public resolvers here keep name resolution consistent over any WAN.
  ops.push({
    description: '\ud83e\udded Router DNS \u2192 static 8.8.8.8,1.1.1.1 + serve clients',
    method: 'POST', path: '/ip/dns/set',
    body: { servers: '8.8.8.8,1.1.1.1', 'allow-remote-requests': 'yes' }
  });
  ops.push({
    description: '\ud83e\uddf9 Flush DNS cache',
    method: 'POST', path: '/ip/dns/cache/flush', body: {}
  });

  // Interface-list RL-WAN = all WAN interfaces. Used so load-balance marking only
  // touches LAN-originated traffic (in-interface-list=!RL-WAN). Without this, WAN->LAN
  // return packets get connection-marked and mis-routed into a custom table that lacks
  // the connected LAN route — which is what broke hotspot return traffic under LB.
  ops.push({
    description: 'Create interface-list RL-WAN',
    method: 'PUT', path: '/interface/list',
    body: { name: 'RL-WAN', comment: `${RL_TAG} wanlist` }
  });
  for (const link of links) {
    ops.push({
      description: `Add ${link.interface} to RL-WAN`,
      method: 'PUT', path: '/interface/list/member',
      body: { list: 'RL-WAN', interface: link.interface, comment: `${RL_TAG} wanmember wan${link.position}` }
    });
  }

  // NAT — ensure EVERY WAN interface masquerades its egress traffic. Without this,
  // traffic that fails over (or is policy-routed) to a non-primary WAN leaves un-NAT'd
  // and never gets a return path. (Hotspot had a catch-all src-NAT so it survived, but
  // PPPoE and general traffic were only NAT'd out ether1 and broke on failover.)
  for (const link of links) {
    ops.push({
      description: `🔀 NAT masquerade out ${link.interface} (WAN${link.position})`,
      method: 'PUT', path: '/ip/firewall/nat',
      body: { chain: 'srcnat', 'out-interface': link.interface, action: 'masquerade', comment: `${RL_TAG} nat wan${link.position}` }
    });
  }

  // Routing tables for policy routing
  for (const link of links) {
    ops.push({
      description: `📋 Create routing table rl_via_wan${link.position}`,
      method: 'PUT', path: '/routing/table',
      body: { name: `rl_via_wan${link.position}`, fib: 'true', comment: `${RL_TAG} link${link.position}` }
    });
  }

  // /32 probe route per link (VPS pings these to check internet; always active because gw is directly connected)
  for (const link of links) {
    ops.push({
      description: `🔍 Probe route ${probes[link.id]}/32 via WAN${link.position} (for internet health checks)`,
      method: 'PUT', path: '/ip/route', _resolve_gw_for_link: link,
      body: {
        'dst-address': probes[link.id] + '/32', 'gateway': '__GATEWAY__',
        'comment': `${RL_TAG} probe wan${link.position} target=${probes[link.id]}`
      }
    });
  }

  // NETWATCH — local internet-health failover (runs ON the router, works even when
  // the active link's internet death cuts the VPS management tunnel). Each netwatch
  // pings its WAN's probe target (forced via the /32 route). On internet DOWN it parks
  // that WAN (distance 200); on UP it restores the WAN's priority distance. This is the
  // only mechanism that can act when the VPS is unreachable — it's tiny and local.
  if (failoverLinks.length > 0) {
    const nwInterval = Math.max(3, Math.min(15, parseInt(dev.multi_wan_check_interval) || 5));
    for (const link of failoverLinks) {
      const probeTarget = probes[link.id];
      const hd = healthyDist[link.id] || link.position;
      // RL_TYPE_AWARE: pick the correct "set distance" command for this link's uplink type.
      const lt = await detectLinkType(dev, link, caches);
      const setDist = (val) => {
        if (lt.type === 'pppoe') return `/interface pppoe-client set [find comment="${RL_TAG} wan${link.position}"] default-route-distance=${val}`;
        if (lt.type === 'dhcp')  return `/ip dhcp-client set [find comment="${RL_TAG} wan${link.position}"] default-route-distance=${val}`;
        return `/ip route set [find comment="${RL_TAG} wan${link.position}"] distance=${val}`;
      };
      ops.push({
        description: `🔔 Netwatch failover for WAN${link.position} [${lt.type}] (monitors ${probeTarget})`,
        method: 'PUT', path: '/tool/netwatch',
        body: {
          host: probeTarget,
          interval: nwInterval + 's',
          timeout: '3s',
          'up-script': `${setDist(hd)}; /ip route enable [find comment~"via=wan${link.position};"]`,
          'down-script': `${setDist(PARKED_DISTANCE)}; /ip route disable [find comment~"via=wan${link.position};"]`,
          comment: `${RL_TAG} netwatch wan${link.position}`
        }
      });
    }
  }

  // Default routes per CUSTOM table (policy routing) — PRIMARY WAN + FALLBACKS.
  // Each route is comment-tagged "via=wanX;" so Netwatch can enable/disable it on that
  // WAN's internet health. A policy-routed user prefers their assigned WAN (distance 1)
  // and falls back to other WANs (distance 2,3..) when it's down, automatically returning
  // when it recovers (enable/disable preserves distance ordering).
  for (const link of links) {
    const tbl = `rl_via_wan${link.position}`;
    // primary: this table's own WAN at distance 1
    ops.push({
      description: `🛣  ${tbl}: primary via WAN${link.position}`,
      method: 'PUT', path: '/ip/route', _resolve_gw_for_link: link,
      body: {
        'dst-address': '0.0.0.0/0', 'gateway': '__GATEWAY__',
        'routing-table': tbl, 'distance': '1', 'check-gateway': 'ping',
        'comment': `${RL_TAG} cust via=wan${link.position}; tbl=${tbl}`
      }
    });
    // fallbacks: every OTHER failover WAN, by priority
    let fbDist = 2;
    for (const other of failoverLinks) {
      if (other.id === link.id) continue;
      ops.push({
        description: `↪  ${tbl}: fallback via WAN${other.position} (dist ${fbDist})`,
        method: 'PUT', path: '/ip/route', _resolve_gw_for_link: other,
        body: {
          'dst-address': '0.0.0.0/0', 'gateway': '__GATEWAY__',
          'routing-table': tbl, 'distance': String(fbDist), 'check-gateway': 'ping',
          'comment': `${RL_TAG} cust via=wan${other.position}; tbl=${tbl}`
        }
      });
      fbDist++;
    }
  }

  // Hotspot bypasses ALL marking -> it load-balances via the MAIN-table ECMP rather
  // than a custom table (RouterOS 7 web-proxy limitation, see above). This rule is FIRST
  // in prerouting mangle so it wins before policy-mark / PCC. PPPoE and other LAN traffic
  // are still marked + load-balanced normally.
  if (hotspotIface) {
    ops.push({
      description: `\ud83d\udedc Hotspot (${hotspotIface}) bypasses marking -> main-table ECMP (web-proxy safe)`,
      method: 'PUT', path: '/ip/firewall/mangle',
      body: { chain: 'prerouting', 'in-interface': hotspotIface, action: 'accept', comment: `${RL_TAG} hs-skip` }
    });
  }

  // Address-list + policy-mark mangle per failover WAN — created ALWAYS (the list stays
  // empty until a user is assigned). RADIUS (Mikrotik-Address-List) for native PPPoE, or
  // the VPS reconciler for hotspot, adds a user's LIVE IP to rl_wanN_users; this mangle
  // then marks their traffic onto table rl_via_wanN. A sentinel keeps the list present.
  for (const link of links) {
    ops.push({
      description: `📋 Address-list rl_wan${link.position}_users (policy targets)`,
      method: 'PUT', path: '/ip/firewall/address-list',
      body: { list: `rl_wan${link.position}_users`, address: '127.255.255.254', comment: `${RL_TAG} sentinel wan${link.position}` }
    });
    ops.push({
      description: `🎯 Policy mark: rl_wan${link.position}_users → rl_via_wan${link.position}`,
      method: 'PUT', path: '/ip/firewall/mangle',
      body: {
        chain: 'prerouting', 'src-address-list': `rl_wan${link.position}_users`,
        'dst-address-type': '!local',
        action: 'mark-routing', 'new-routing-mark': `rl_via_wan${link.position}`,
        passthrough: 'no', comment: `${RL_TAG} policy-mark wan${link.position}`
      }
    });
  }

  // PCC load balance — CORRECT recipe. (1) classify NEW connections to a WAN with
  // mark-CONNECTION (sticky for the whole connection, weighted by lb_weight); (2)
  // mark-ROUTING for ALL packets of each marked connection. Restricted to
  // in-interface-list=!RL-WAN so only LAN-originated traffic is steered and WAN->LAN
  // return traffic is never mis-routed. (The old code marked routing on the first packet
  // only, so follow-up packets hit the ECMP main table and connections split across WANs
  // — fatal for hotspot, flaky for PPPoE.)
  if (lbLinks.length > 0) {
    const pccMode = dev.pcc_mode || 'both-addresses';
    const totalWeight = lbLinks.reduce((s, l) => s + (l.lb_weight || 1), 0);
    const slots = Math.max(lbLinks.length, Math.round(totalWeight / 10));
    // (1) classify new connections (mark-connection), weighted
    let cumIdx = 0;
    for (const link of lbLinks) {
      const linkSlots = Math.max(1, Math.round((link.lb_weight || 1) / 10));
      for (let i = 0; i < linkSlots; i++) {
        ops.push({
          description: `⚖  LB classify new conns → WAN${link.position} (${slots}/${cumIdx + i})`,
          method: 'PUT', path: '/ip/firewall/mangle',
          body: {
            chain: 'prerouting', 'connection-state': 'new', 'in-interface-list': '!RL-WAN',
            'dst-address-type': '!local',
            'per-connection-classifier': `${pccMode}:${slots}/${cumIdx + i}`,
            action: 'mark-connection', 'new-connection-mark': `rl_conn_wan${link.position}`,
            passthrough: 'yes', comment: `${RL_TAG} LB classify wan${link.position}`
          }
        });
      }
      cumIdx += linkSlots;
    }
    // (2) route ALL packets of each marked connection via its WAN
    for (const link of lbLinks) {
      ops.push({
        description: `⚖  LB route conn → rl_via_wan${link.position}`,
        method: 'PUT', path: '/ip/firewall/mangle',
        body: {
          chain: 'prerouting', 'connection-mark': `rl_conn_wan${link.position}`,
          'in-interface-list': '!RL-WAN',
          action: 'mark-routing', 'new-routing-mark': `rl_via_wan${link.position}`,
          passthrough: 'no', comment: `${RL_TAG} LB route wan${link.position}`
        }
      });
    }
  }

  // (Per-policy mangle is no longer needed: every failover WAN already has a
  //  src-address-list -> mark-routing rule above. A policy just decides which
  //  rl_wanN_users list a user's IP goes into, via RADIUS / the reconciler.)

  return { ops, dev, links, policies, mode, probes };
}

async function cleanupRouter(dev) {
  const removed = [];
  const delTagged = async (listPath, removePath) => {
    try {
      const items = await mtCall(dev, 'GET', listPath);
      for (const it of items) {
        if ((it.comment || '').startsWith(RL_TAG)) {
          await mtCall(dev, 'POST', removePath, { '.id': it['.id'] });
          removed.push(removePath + ' ' + it['.id']);
        }
      }
    } catch (e) { logger.warn('[mwan-cleanup] ' + listPath + ': ' + e.message); }
  };
  await delTagged('/tool/netwatch', '/tool/netwatch/remove');
  await delTagged('/ip/firewall/nat', '/ip/firewall/nat/remove');
  await delTagged('/interface/list/member', '/interface/list/member/remove');
  await delTagged('/interface/list', '/interface/list/remove');
  await delTagged('/ip/route', '/ip/route/remove');
  await delTagged('/ip/firewall/mangle', '/ip/firewall/mangle/remove');
  await delTagged('/ip/firewall/address-list', '/ip/firewall/address-list/remove');
  await delTagged('/routing/table', '/routing/table/remove');
  // NOTE: we intentionally do NOT touch add-default-route here — DHCP keeps managing
  // default routes. On revert we just reset distances to 1 so nothing stays parked.
  try {
    const dhcps = await mtCall(dev, 'GET', '/ip/dhcp-client');
    for (const d of dhcps) {
      if ((d.comment || '').startsWith(RL_TAG)) {
        await mtCall(dev, 'PATCH', '/ip/dhcp-client/' + d['.id'], { 'add-default-route': 'yes', 'default-route-distance': '1', 'use-peer-dns': 'yes', comment: '' });
        removed.push('dhcp-client reset ' + d['.id']);
      }
    }
  } catch (e) { logger.warn('[mwan-cleanup] dhcp: ' + e.message); }
  return removed;
}

async function prepareInterface(dev, link) {
  const ops = [];
  try {
    const ports = await mtCall(dev, 'GET', '/interface/bridge/port');
    const port = ports.find(p => p.interface === link.interface);
    if (port) {
      ops.push(`Removed ${link.interface} from bridge ${port.bridge}`);
      await mtCall(dev, 'POST', '/interface/bridge/port/remove', { '.id': port['.id'] });
    }
  } catch (e) { logger.warn('[mwan-prep] bridge: ' + e.message); }

  let hasIp = false, hasDhcp = false, hasPppoe = false;
  try { hasIp = (await mtCall(dev, 'GET', '/ip/address')).some(a => a.interface === link.interface); } catch(e){}
  try { hasDhcp = (await mtCall(dev, 'GET', '/ip/dhcp-client')).some(d => d.interface === link.interface); } catch(e){}
  // RL_TYPE_AWARE: a pppoe-client uplink already provides the WAN — never add DHCP on it.
  try { hasPppoe = (await mtCall(dev, 'GET', '/interface/pppoe-client')).some(p => p.interface === link.interface); } catch(e){}
  // RL_DUAL_CLIENT_PREP: if this port has PPPoE, remove any leftover UNMANAGED dhcp-client on it
  // (the stale bootstrap lease that otherwise keeps a competing default route at distance 1).
  if (hasPppoe) {
    try {
      const dcs = await mtCall(dev, 'GET', '/ip/dhcp-client');
      for (const dc of (dcs||[])) {
        const cm = dc.comment || '';
        if (dc.interface === link.interface && !cm.includes(RL_TAG) && !cm.includes('RumaLink')) {
          try { await mtCall(dev, 'POST', '/ip/dhcp-client/remove', { '.id': dc['.id'] }); ops.push(`Removed stale bootstrap DHCP on ${link.interface}`); } catch(e){}
        }
      }
    } catch(e){}
  }

  // KEEP add-default-route=yes — never cut the router's path
  if (!hasIp && !hasDhcp && !hasPppoe && !link.gateway) {
    try {
      await mtCall(dev, 'PUT', '/ip/dhcp-client', { interface: link.interface, 'add-default-route': 'yes', comment: `${RL_TAG} wan${link.position}` });
      ops.push(`Added DHCP-client on ${link.interface}`);
    } catch (e) { throw new Error(`DHCP-client on ${link.interface}: ${e.message}`); }
  }
  return ops;
}

async function applyPlan(deviceId, ispId) {
  const { ops, dev, links } = await buildPlan(deviceId, ispId);
  const results = []; const errors = [];

  results.push({ step: 'cleanup', message: 'Removing previous config...' });
  const cleaned = await cleanupRouter(dev);
  results.push({ step: 'cleanup', message: `Removed ${cleaned.length} previous objects` });

  for (const link of links) {
    try { const prepOps = await prepareInterface(dev, link); for (const m of prepOps) results.push({ step: 'prepare', message: m }); }
    catch (e) { errors.push(`prepare ${link.interface}: ${e.message}`); }
  }
  await new Promise(r => setTimeout(r, 1500));

  let dhcpsCache = [];
  try { dhcpsCache = await mtCall(dev, 'GET', '/ip/dhcp-client'); } catch(e){}

  for (const op of ops) {
    if (op.cleanup || op.prepare_iface) continue;
    try {
      let body = op.body;
      if (op._resolve_gw_for_link) {
        const gw = await resolveLinkGateway(dev, op._resolve_gw_for_link, dhcpsCache);
        if (!gw) { const m = `Skipped: no gateway for ${op._resolve_gw_for_link.interface}`; errors.push(m); results.push({ step: 'skipped', message: m }); continue; }
        body = { ...body, gateway: gw };
      }
      if (op._patch_dhcp_for_link) {
        const dhcp = dhcpsCache.find(d => d.interface === op._patch_dhcp_for_link.interface);
        if (!dhcp) { const m = `Skipped: no DHCP-client on ${op._patch_dhcp_for_link.interface}`; errors.push(m); results.push({ step: 'skipped', message: m }); continue; }
        await mtCall(dev, 'PATCH', op.path + '/' + dhcp['.id'], body);
        results.push({ step: 'op', message: op.description }); continue;
      }
      // RL_TYPE_AWARE: set default-route-distance on whatever uplink type this link is.
      if (op._patch_distance_for_link) {
        const link = op._patch_distance_for_link; const d = String(op._distance);
        const t = await detectLinkType(dev, link, { dhcp: dhcpsCache });
        try {
          if (t.type === 'pppoe') {
            const pcs = await mtCall(dev, 'GET', '/interface/pppoe-client');
            const pc = (pcs||[]).find(p => p.interface === link.interface);
            if (pc) { await mtCall(dev, 'PATCH', '/interface/pppoe-client/' + pc['.id'], { 'add-default-route': 'yes', 'default-route-distance': d, 'use-peer-dns': 'no', comment: `${RL_TAG} wan${link.position}` });
              results.push({ step: 'op', message: op.description + ' (pppoe)' }); continue; }
          } else if (t.type === 'dhcp') {
            const dc = dhcpsCache.find(x => x.interface === link.interface);
            if (dc) { await mtCall(dev, 'PATCH', '/ip/dhcp-client/' + dc['.id'], { 'add-default-route': 'yes', 'default-route-distance': d, 'use-peer-dns': 'no', comment: `${RL_TAG} wan${link.position}` });
              results.push({ step: 'op', message: op.description + ' (dhcp)' }); continue; }
          } else {
            // static: ensure a default route exists at this distance via the configured gw
            const gw = (link.gateway||'').trim();
            if (gw) { await mtCall(dev, 'PUT', '/ip/route', { 'dst-address': '0.0.0.0/0', gateway: gw, distance: d, comment: `${RL_TAG} wan${link.position}` });
              results.push({ step: 'op', message: op.description + ' (static)' }); continue; }
          }
          const m = `Skipped distance: ${link.interface} type=${t.type} not found`; results.push({ step: 'skipped', message: m }); continue;
        } catch(e){ const m = `${op.description}: ${e.message}`; if (/already|such name|duplicate/i.test(m)) { results.push({step:'ok',message:op.description}); } else { errors.push(m); results.push({step:'error',message:m}); } continue; }
      }
      await mtCall(dev, op.method, op.path, body);
      results.push({ step: 'op', message: op.description });
    } catch (e) {
      // RL_ALREADY_EXISTS_OK: an object that already exists is the desired state, not a failure.
      // (e.g. RL-WAN interface list / members are now pre-created during provisioning.)
      const _msg = String(e && e.message || '');
      if (/already have|already exists|such name|duplicate|already a member|failure: entry already exists/i.test(_msg)) {
        results.push({ step: 'ok', message: `${op.description}: already present (ok)` });
      } else {
        const m = `${op.description}: ${e.message}`;
        errors.push(m);
        results.push({ step: 'error', message: m });
      }
    }
  }

  await query(`UPDATE nas_devices SET multi_wan_applied_at = NOW() WHERE id = $1::uuid AND isp_id = $2::uuid`, [deviceId, ispId]);
  try { await monitorDevice(deviceId); } catch(e) { logger.warn('[mwan-apply] initial monitor: ' + e.message); }

  return { ok: errors.length === 0, results, errors, applied_count: results.length, error_count: errors.length };
}

async function revertPlan(deviceId, ispId) {
  const dr = await query('SELECT * FROM nas_devices WHERE id = $1::uuid AND isp_id = $2::uuid', [deviceId, ispId]);
  if (!dr.rows[0]) throw new Error('Device not found');
  const removed = await cleanupRouter(dr.rows[0]);
  await query(`UPDATE nas_devices SET multi_wan_applied_at = NULL WHERE id = $1::uuid AND isp_id = $2::uuid`, [deviceId, ispId]);
  await query(`UPDATE nas_wan_links SET current_status = 'unknown' WHERE nas_id = $1::uuid`, [deviceId]);
  return { ok: true, removed_count: removed.length, removed };
}

// ===================== VPS MONITOR =====================

// RL_QUALITY_FAILOVER: parse a MikroTik rtt string ("2ms198us", "1s2ms", "500us") -> ms
function rlRttToMs(v){
  if (!v) return null;
  var ms = 0, m;
  if ((m = String(v).match(/(\d+)s/))) ms += parseInt(m[1]) * 1000;
  if ((m = String(v).match(/(\d+)ms/))) ms += parseInt(m[1]);
  if ((m = String(v).match(/(\d+)us/))) ms += parseInt(m[1]) / 1000;
  return ms;
}


// ─── RL_OOKLA_PROBE ──────────────────────────────────────────────────────────
// Does REAL traffic complete through THIS SPECIFIC WAN?
//
// Ping proves a box answered ICMP. It cannot prove the internet works — DNS can be dead,
// transit down, TCP blackholed, and ping still returns 70ms/0% loss. That is exactly the
// failure that got past the old check while Ookla (real TCP, real bytes) saw it instantly.
//
// HOW THE BINDING WORKS (proven, with a control, on an RB951):
//   /tool/fetch has no interface= or routing-table= option, and IGNORES src-address. It
//   follows the routing table — so a DNS-resolved target leaves via the DEFAULT route and
//   silently tests WAN1 no matter which link we meant. The fix is to pin a /32 route for the
//   TARGET IP through the WAN under test, and fetch that IP directly (no DNS). The packet
//   then MUST follow the /32.  dead WAN -> Idle timeout;  live WAN -> finished.
//
// WHAT COUNTS AS SUCCESS: any HTTP RESPONSE — including 403/404. "Fetch failed with status"
// means TCP connected, TLS completed and the server answered. That is a full round trip and
// proves the link carries real traffic. Only connection-level errors mean the link is dead.
// RL_DISJOINT_TARGETS: every WAN must probe DIFFERENT destination IPs.
// A /32 route pins ONE destination to ONE gateway — so if two links share a target, only one
// route can win and the other link's fetch silently leaves via the wrong WAN. That is exactly
// what made a cable-connected but internet-dead link report "Internet ✓ fetched 1.6s".
// (Your original ping design already did this correctly: 8.8.8.8 -> WAN1, 1.1.1.1 -> WAN2.)
//
// All of these are confirmed to answer HTTPS by raw IP with no Host header. Two per WAN keeps
// a quorum: one target's outage cannot fake a link failure — BOTH must fail.
const TARGET_POOL = [
  ['1.0.0.1', '9.9.9.9'],              // WAN1
  ['208.67.222.222', '8.8.8.8'],       // WAN2
  ['8.8.4.4', '64.6.64.6'],            // WAN3
  ['1.1.1.1', '149.112.112.112'],      // WAN4
];
function targetsForLink(link) {
  const i = (Number(link.position) || 1) - 1;
  return TARGET_POOL[i % TARGET_POOL.length];
}

function probeTier(board) {
  const b = String(board || '').toLowerCase();
  if (/rb951|rb750r2|rb941|hap lite|rb750up/.test(b))    return { tier:'lite',     slowMs:4000, timeoutS:8 };
  if (/rb750gr3|hex|hap ac2|rb760|rb962|rb2011/.test(b)) return { tier:'standard', slowMs:3000, timeoutS:8 };
  if (/rb4011|rb5009|ccr|crs3|rb1100/.test(b))           return { tier:'strong',   slowMs:2500, timeoutS:8 };
  return { tier:'lite', slowMs:4000, timeoutS:8 };
}

// Classify RouterOS's fetch error. This distinguishes "the link is broken" from
// "the server said no" — a distinction ping can never make.
function classifyFetch(msg) {
  const d = String(msg || '').toLowerCase();
  if (/failed with status/.test(d))            return 'reached';    // server ANSWERED -> link works
  if (/idle timeout|timeout/.test(d))          return 'timeout';    // no TCP -> link dead
  if (/network unreachable|no route/.test(d))  return 'unreachable';
  if (/refused|reset/.test(d))                 return 'refused';
  if (/host is unknown/.test(d))               return 'dns';
  return 'unknown';
}

// Ensure a /32 for this target exists via this WAN's gateway, so the fetch is BOUND to it.
async function ensureProbeRoute(dev, link, ip, gw) {
  const comment = 'RL-OOKLA probe wan' + link.position + ' ' + ip;
  try {
    const routes = await mtCall(dev, 'GET', '/ip/route');

    // Remove ANY other /32 for this same destination — a duplicate would make the route
    // ambiguous and the fetch would leave via whichever one RouterOS happened to prefer.
    for (const r of (routes || [])) {
      if (r['dst-address'] !== ip + '/32') continue;
      if ((r.comment || '') === comment) continue;
      if (!/RL-OOKLA/.test(r.comment || '')) continue;   // never touch the user's own routes
      try { await mtCall(dev, 'DELETE', '/ip/route/' + encodeURIComponent(r['.id'])); } catch (e) {}
    }

    const mine = (routes || []).find(r => (r.comment || '') === comment);
    if (mine) {
      if (mine.gateway === gw) return true;
      try { await mtCall(dev, 'DELETE', '/ip/route/' + encodeURIComponent(mine['.id'])); } catch (e) {}
    }
    await mtCall(dev, 'PUT', '/ip/route', {
      'dst-address': ip + '/32', gateway: gw, distance: '1', comment,
    });
    return true;
  } catch (e) { return false; }
}


async function fetchVia(dev, ip, tier) {
  const t0 = Date.now();
  try {
    const resp = await mtCall(dev, 'POST', '/tool/fetch', {
      url: 'https://' + ip + '/',
      'http-method': 'get', 'keep-result': 'no',
      'check-certificate': 'no', 'as-value': '',
      duration: String(tier.timeoutS),
    });
    const arr = Array.isArray(resp) ? resp : [resp];
    const last = arr[arr.length - 1] || {};
    const ok = String(last.status || '').includes('finish');
    return { ok, ms: Date.now() - t0, stage: ok ? 'complete' : 'partial' };
  } catch (e) {
    const cls = classifyFetch(e.message);
    // 'reached' = the server answered with an HTTP error. TCP+TLS completed, so the link
    // carries real traffic. This IS a success.
    if (cls === 'reached') return { ok: true, ms: Date.now() - t0, stage: 'complete' };
    return { ok: false, ms: Date.now() - t0, stage: cls, err: String(e.message).slice(0, 90) };
  }
}

async function internetProbe(dev, link, tier, gw) {
  if (Number(dev.cpu_load || 0) > 70) return { skipped: true };
  if (!gw) return { skipped: false, usable: false, stage: 'no-gateway', ms: null };

  let last = null;
  for (const ip of targetsForLink(link)) {
    const routed = await ensureProbeRoute(dev, link, ip, gw);
    if (!routed) continue;
    const r = await fetchVia(dev, ip, tier);
    last = r;
    // First success proves the link. Stop — no need to burn the router's CPU further.
    if (r.ok) {
      return { skipped:false, usable:true, degraded: r.ms > tier.slowMs, ms:r.ms, stage:'complete', target:ip };
    }
  }
  // Every target failed at the connection level -> the LINK is down, not one unlucky target.
  return { skipped:false, usable:false, degraded:false,
           ms: last ? last.ms : null, stage: last ? last.stage : 'unknown',
           err: last ? last.err : null };
}

// RL_PING_CONFIRM: ICMP loss to anycast targets (8.8.8.8/1.1.1.1) is frequently rate-limit
// policing — and RouterOS REST ping can return before the final reply, manufacturing phantom
// 1-packet loss. Ookla never false-alarms on this because it judges by real transfer. So: any
// nonzero loss is immediately re-tested and the BETTER run wins. Only reproducible loss counts.
async function pingProbe(dev, target) {
  const a = await pingProbeOnce(dev, target);
  if (!a || !(a.lossPct > 0)) return a;
  const b = await pingProbeOnce(dev, target);
  if (!b) return a;
  return (Number(b.lossPct||0) < Number(a.lossPct||0)) ? b : a;
}
async function pingProbeOnce(dev, target) {
  try {
    // count 5 gives a better jitter/loss read; still tiny.
    const resp = await mtCall(dev, 'POST', '/ping', { address: target, count: '10' }); /* RL_JITTER_N10: 5-ping max-min jitter is noise */
    if (Array.isArray(resp) && resp.length) {
      const ok = resp.filter(p => parseInt(p.received || 0) > 0).length;
      let rtt = null; const timed = resp.find(p => p['avg-rtt']); if (timed) rtt = timed['avg-rtt'];
      // RL_QUALITY_FAILOVER: latency (avg), jitter (max-min), loss %.
      const last = resp[resp.length - 1] || {};
      const sent = parseInt(last.sent || resp.length || 0);
      const recv = parseInt(last.received || ok || 0);
      const lossPct = sent > 0 ? Math.round(((sent - recv) / sent) * 100) : 100;
      const latencyMs = rlRttToMs(last['avg-rtt'] || rtt);
      /* RL_JITTER_RFC3550: jitter is the mean deviation between CONSECUTIVE packets, not the
         max-min RANGE. Range is inflated by a single outlier: a healthy link measured
         samples 54,55,71,43,37,8,42,35,36,34,79,8,8,8,8 -> range 71.9ms but true jitter 17.3ms.
         The old range-based value tripped the quality threshold constantly on good links
         (which is why RL_JITTER_SOLO exists to suppress the false positives). */
      let jitterMs = null;
      const _times = resp.map(function(p){ return rlRttToMs(p.time); }).filter(function(n){ return n !== null && n !== undefined && !isNaN(n) && n > 0; });
      if (_times.length > 1) {
        let _d = 0;
        for (let _i = 1; _i < _times.length; _i++) _d += Math.abs(_times[_i] - _times[_i - 1]);
        jitterMs = Math.round((_d / (_times.length - 1)) * 10) / 10;
      } else if (last['max-rtt'] && last['min-rtt']) {
        /* fallback only if per-packet times are unavailable */
        jitterMs = Math.max(0, (rlRttToMs(last['max-rtt']) || 0) - (rlRttToMs(last['min-rtt']) || 0));
      }
      return { ok: ok > 0, rtt, latencyMs, jitterMs, lossPct };
    }
  } catch (e) { return { ok: false, err: e.message, lossPct: 100 }; }
  return { ok: false, lossPct: 100 };
}

// RL_BYTES_CARRIED: how much data has each WAN actually carried? After a failover you need
// to know what the BACKUP cost you — backup uplinks are often metered or capped, and a failover
// nobody noticed can quietly run up a large bill.
async function trackWanBytes(dev, link) {
  try {
    const ifaces = await mtCall(dev, 'GET', '/interface');
    const i = (ifaces || []).find(x => x.name === link.interface);
    if (!i) return;
    const tx = Number(i['tx-byte'] || 0), rx = Number(i['rx-byte'] || 0);
    const lt = link.last_tx_bytes == null ? null : Number(link.last_tx_bytes);
    const lr = link.last_rx_bytes == null ? null : Number(link.last_rx_bytes);
    let d = 0;
    // A negative delta means the counter reset (reboot) — book nothing rather than a wild figure.
    if (lt != null && tx >= lt) d += (tx - lt);
    if (lr != null && rx >= lr) d += (rx - lr);
    await query('UPDATE nas_wan_links SET bytes_carried = COALESCE(bytes_carried,0) + $1, last_tx_bytes=$2, last_rx_bytes=$3 WHERE id=$4::uuid',
      [d, tx, rx, link.id]);
  } catch (e) {}
}

// RL_POOL_EVICT: in a load-balanced setup, "failing over" means LEAVING THE POOL.
//
// Traffic here is steered by PCC connection marks, NOT by the main routing table — your router
// has ZERO main default routes in this mode. So the old park (raising default-route-distance)
// had nothing to act on: it was a complete no-op that only painted a red label while new
// connections kept being hashed onto the sick link.
//
// Disabling a link's "LB classify" mangle rules stops NEW connections being assigned to it.
// Existing connections keep their mark and finish naturally, so nobody is cut off mid-download.
//
// SAFETY: we never empty the pool. If every link is degraded there is nowhere better to go, so
// we re-enable them all — a black-holed customer is worse than a slow one.
// RL_CONN_FLUSH: PCC connection-marks are STICKY — evicting a link only affects NEW connections.
// A viewer's established stream stays glued to the sick link and buffers forever. Clearing that
// link's tracked connections forces flows to re-hash onto healthy links; players reconnect in
// ~1-2s and their buffer absorbs it. This is the piece that makes failover invisible to users.
async function flushLinkConnections(dev, link) {
  try {
    const conns = await mtCall(dev, 'GET', '/ip/firewall/connection?connection-mark=rl_conn_wan' + link.position);
    let n = 0;
    for (const c of (Array.isArray(conns)?conns:[]).slice(0, 500)) {
      try { await mtCall(dev, 'DELETE', '/ip/firewall/connection/' + encodeURIComponent(c['.id'])); n++; } catch(e){}
    }
    if (n) logger.info('[mwan-flush] ' + dev.name + ' WAN' + link.position + ': cleared ' + n + ' established connection(s) — flows re-hash to healthy links now');
    return n;
  } catch (e) { logger.warn('[mwan-flush] ' + (e && e.message)); return 0; }
}

// RL_TP_PROBE: Ookla-style throughput. Ping and a tiny fetch cannot tell 3 Mbps from 50 Mbps —
// but a user streaming video can. Download real bytes through the pinned /32 for up to 5s and
// compute effective Mbps from RouterOS fetch's 'downloaded' counter. Adaptive: only runs when the
// link already looks suspect (or every ~10 min as a baseline), so it doesn't burn metered data.
async function throughputProbe(dev, link, gw) {
  try {
    const ip = targetsForLink(link)[0];
    const ok = await ensureProbeRoute(dev, link, ip, gw);
    if (!ok) return null;
    const t0 = Date.now();
    let downloadedKiB = 0;
    try {
      const resp = await mtCall(dev, 'POST', '/tool/fetch', {
        url: 'https://' + ip + '/', 'http-method': 'get', 'keep-result': 'no',
        'check-certificate': 'no', 'as-value': '', duration: '5',
      });
      const arr = Array.isArray(resp) ? resp : [resp];
      const last = arr[arr.length-1] || {};
      downloadedKiB = parseFloat(String(last['downloaded']||'0')) || 0;
    } catch (e) { /* fetch error: no throughput evidence from this pass */ return null; }
    const secs = Math.max(0.5, (Date.now() - t0) / 1000);
    // tiny pages give tiny numbers; treat <8KiB transferred as 'no evidence' rather than 'slow'
    if (downloadedKiB < 8) return null;
    const mbps = (downloadedKiB * 1024 * 8) / secs / 1e6;
    return Math.round(mbps * 100) / 100;
  } catch (e) { return null; }
}

async function setPoolMembership(dev, link, inPool) {
  try {
    const rules = await mtCall(dev, 'GET', '/ip/firewall/mangle');
    const mine = (rules || []).filter(r =>
      new RegExp('LB classify wan' + link.position + '\\b').test(r.comment || ''));
    if (!mine.length) return false;

    const want = inPool ? 'false' : 'true';
    let changed = 0;
    for (const r of mine) {
      if (String(r.disabled) === want) continue;
      await mtCall(dev, 'PATCH', '/ip/firewall/mangle/' + encodeURIComponent(r['.id']),
                   { disabled: want });
      changed++;
    }
    if (changed) {
      logger.info('[mwan-pool] ' + dev.name + ' WAN' + link.position + ' (' + link.interface + '): ' +
                  (inPool ? 'RETURNED to the LB pool' : 'EVICTED from the LB pool — new connections will avoid it') +
                  ' (' + changed + ' rule' + (changed === 1 ? '' : 's') + ')');
    }
    return changed > 0;
  } catch (e) {
    logger.warn('[mwan-pool] ' + (e && e.message));
    return false;
  }
}

// Recovery by RATIO over the last 8 samples (~2 min), never by consecutive count.
// The old rule needed N good samples IN A ROW, and a single bad sample reset the counter to
// zero — so a flapping link (bad,bad,good,bad,bad...) could never recover and stayed parked
// forever. That is exactly what pinned WAN1. A majority of good samples is the honest test.
function poolVerdict(history) {
  const h = String(history || '').slice(-8);
  if (h.length < 4) return null;               // not enough evidence yet — change nothing
  const bad  = (h.match(/1/g) || []).length;
  const good = h.length - bad;
  return { good, bad, healthy: good >= bad, samples: h.length };
}

// RL_WG_RECONCILE: keep the expired-user walled garden alive.
//
// Provisioning adds these four rules with  place-before=0 , which fails on an invalid index —
// and  on-error={}  swallows the error. On this router only the DROP survived: the three ACCEPT
// rules (DNS, DNS/tcp, portal) were silently lost. An expired subscriber therefore got a TOTAL
// BLACK HOLE — no DNS, no pay page, no internet, and no way to pay. Worse than free service.
//
// So we do not trust provisioning to have worked. Every cycle we check the four rules exist and
// recreate any that are missing, in the correct order (accepts BEFORE the drop — a drop above
// them blocks everything). Cheap: one GET, and writes only when something is actually absent.
const RL_WG_RULES = [
  { c: 'RumaLink-wg-pppoe-dns',    b: { chain:'forward', 'src-address-list':'rl-expired', protocol:'udp', 'dst-port':'53', action:'accept' } },
  { c: 'RumaLink-wg-pppoe-dns2',   b: { chain:'forward', 'src-address-list':'rl-expired', protocol:'tcp', 'dst-port':'53', action:'accept' } },
  { c: 'RumaLink-wg-pppoe-portal', b: { chain:'forward', 'src-address-list':'rl-expired', 'dst-address-list':'rl-portal', action:'accept' } },
  { c: 'RumaLink-wg-pppoe-drop',   b: { chain:'forward', 'src-address-list':'rl-expired', action:'drop' } },
];

async function reconcileWalledGarden(dev) {
  try {
    const fw = await mtCall(dev, 'GET', '/ip/firewall/filter');
    const have = (fw || []).filter(x => /RumaLink-wg-pppoe/.test(x.comment || ''));
    const missing = RL_WG_RULES.filter(r => !have.some(x => (x.comment || '') === r.c));
    if (!missing.length) return;

    // If anything is missing the ORDER is already suspect, so rebuild the whole set rather than
    // patching one rule into an unknown position.
    for (const x of have) {
      try { await mtCall(dev, 'DELETE', '/ip/firewall/filter/' + encodeURIComponent(x['.id'])); } catch (e) {}
    }
    for (const r of RL_WG_RULES) {
      try { await mtCall(dev, 'PUT', '/ip/firewall/filter', { ...r.b, comment: r.c }); } catch (e) {}
    }
    logger.warn('[walled-garden] ' + dev.name + ': rebuilt ' + RL_WG_RULES.length +
                ' rules (' + missing.length + ' were missing — expired users would have been ' +
                'black-holed with no way to reach the pay page)');
  } catch (e) { /* non-fatal */ }
}

async function monitorDevice(deviceId) {
  const dr = await query(
    `SELECT * FROM nas_devices WHERE id = $1::uuid AND multi_wan_applied_at IS NOT NULL AND multi_wan_mode IS NOT NULL AND multi_wan_mode != 'none'`, [deviceId]);
  if (!dr.rows[0]) return null;
  const dev = dr.rows[0];

  const linksR = await query(`SELECT * FROM nas_wan_links WHERE nas_id = $1::uuid AND enabled = true ORDER BY position ASC`, [deviceId]);
  const links = linksR.rows;
  if (!links.length) return null;

  const mode = dev.multi_wan_mode;
  const probes = assignProbeTargets(links);

  let dhcps = [], routes = [], interfaces = [], addrs = [];
  try { dhcps = await mtCall(dev, 'GET', '/ip/dhcp-client'); } catch(e){ return null; } // if router unreachable, bail (never break things)
  try { routes = await mtCall(dev, 'GET', '/ip/route'); } catch(e){}
  try { interfaces = await mtCall(dev, 'GET', '/interface'); } catch(e){}
  try { addrs = await mtCall(dev, 'GET', '/ip/address'); } catch(e){}

  // Keep /32 probe routes pointing at current gateways
  for (const link of links) {
    const gw = await resolveLinkGateway(dev, link, dhcps);
    if (!gw) {
      // RL_DOWN_VERDICT: no gateway = the link has no working uplink. Record it rather than
      // silently skipping, otherwise the row keeps its last (healthy) value forever.
      try {
        await query(
          `UPDATE nas_wan_links SET probe_verdict='down', probe_stage='no-gateway',
                  fetch_ms=NULL, internet_ok=false, last_fetch_at=NOW(),
                  consec_fetch_fail = COALESCE(consec_fetch_fail,0) + 1
           WHERE id=$1::uuid`, [link.id]);
      } catch (e) { /* non-fatal */ }
      continue;
    }
    const probeTarget = probes[link.id];
    const probeRoute = routes.find(r => (r.comment || '') === `${RL_TAG} probe wan${link.position} target=${probeTarget}`);
    if (probeRoute && probeRoute.gateway !== gw) {
      try { await mtCall(dev, 'PATCH', '/ip/route/' + probeRoute['.id'], { gateway: gw }); } catch(e){}
    }
  }

  // Check internet per link (via /32 probe route)
  const linkState = [];
  for (const link of links) {
    const iface = interfaces.find(i => i.name === link.interface);
    const dhcp = dhcps.find(d => d.interface === link.interface);
    const addr = addrs.find(a => a.interface === link.interface);
    // RL_STATUS_TYPEAWARE: pppoe/dhcp/static-aware ip, gateway, up.
    let _pppoes = []; try { _pppoes = await mtCall(dev, 'GET', '/interface/pppoe-client'); } catch(e){}
    const _pp = _pppoes.find(p => p.interface === link.interface);
    let ip, gateway, linkUp;
    if (_pp) {
      const _paddr = addrs.find(a => a.interface === _pp.name);
      ip = (_paddr && _paddr.address) || _pp['local-address'] || 'pppoe';
      gateway = _pp.name;
      linkUp = (_pp.running === 'true' || _pp.running === true);
    } else {
      ip = (dhcp && dhcp.address) || (addr && addr.address) || null;
      gateway = (dhcp && dhcp.gateway) || link.gateway || null;
      linkUp = iface ? (iface.running === 'true') : false;
    }
    let internetOk = false, rtt = null, q = {};
    if (linkUp) {
      // Ping is KEPT — it still gives latency / jitter / loss, which GRADE a working link.
      const p = await pingProbe(dev, probes[link.id]);
      rtt = p.rtt; q = p;

      // RL_REAL_INTERNET: but the VERDICT comes from a real fetch, not from ICMP.
      const tier = probeTier(dev.mikrotik_board);
      // RL_CACHES_FIX: fetch the address list HERE (one cheap GET) and pass it down,
      // instead of referencing an out-of-scope `caches` that threw every cycle.
      // RL_GW_SCOPE: `gw` was declared in a DIFFERENT for-loop (line ~701) and is NOT in
      // scope here. internetProbe was therefore called with undefined, ensureProbeRoute never
      // ran, no /32 routes were created, and every fetch escaped to the default route — so
      // BOTH links were really testing WAN1. Resolve the gateway HERE, in the loop that uses it.
      let _gw = null;
      try { _gw = await resolveLinkGateway(dev, link, dhcps); } catch (e) { _gw = null; }
      if (!_gw) _gw = link.resolved_gateway || link.gateway || null;
      try { await trackWanBytes(dev, link); } catch (e) {}
      const net  = await internetProbe(dev, link, tier, _gw);

      let verdict, fails = Number(link.consec_fetch_fail || 0);

      if (net.skipped) {
        // Router too busy — never add load. Trust ping this cycle.
        internetOk = p.ok;
        verdict = 'skipped';
      } else if (net.usable) {
        // Definitive: we fetched real content through this WAN.
        internetOk = true;
        fails = 0;
        verdict = net.degraded ? 'slow' : 'good';
        if (net.degraded) logger.info(`[real-internet] ${dev.name} WAN${link.position}: usable but SLOW (${net.ms}ms)`);
      } else if (!p.ok) {
        // Fetch failed AND ping failed → genuinely down.
        internetOk = false;
        fails += 1;
        verdict = 'down';
        logger.warn(`[real-internet] ${dev.name} WAN${link.position}: DOWN (fetch ${net.stage}, ping also failed)`);
      } else {
        // Fetch failed but ping still answers. THIS is the case that caught your ISP out —
        // ICMP fine, real traffic dead. But a single fetch failure can also be a transient
        // REST/router hiccup, so we require 3 consecutive failures before acting. A false
        // DOWN causes needless failovers, which is worse than a slow-to-notice DOWN.
        fails += 1;
        if (fails >= 3) {
          internetOk = false;
          verdict = 'down';
          logger.warn(`[real-internet] ${dev.name} WAN${link.position}: FETCH FAILED at ${net.stage} ` +
                      `but ping OK (${p.latencyMs}ms/${p.lossPct}%) — ICMP was lying. ` +
                      `${fails} consecutive failures → DECLARING DOWN`);
        } else {
          internetOk = true;   // not yet enough evidence to fail over
          verdict = 'suspect';
          logger.warn(`[real-internet] ${dev.name} WAN${link.position}: fetch failed at ${net.stage} ` +
                      `but ping OK — suspect ${fails}/3 (holding)`);
        }
      }

      try {
        await query(
          `UPDATE nas_wan_links SET probe_verdict=$1, probe_stage=$2, fetch_ms=$3,
                  last_fetch_at=NOW(), consec_fetch_fail=$4 WHERE id=$5::uuid`,
          [verdict, net.stage || null, net.ms || null, fails, link.id]);
      } catch (e) { /* non-fatal */ }
    }
    else {
      // RL_DOWN_VERDICT: a link that is not up must still RECORD that fact. Previously the
      // probe sat behind `if (linkUp)` and a down link's row was simply never written — so
      // an unplugged WAN kept displaying its last healthy reading (good, 2413ms) for hours.
      // On a failover dashboard a stale 'good' on a dead link is worse than no data at all.
      internetOk = false;
      try {
        await query(
          `UPDATE nas_wan_links SET probe_verdict='down', probe_stage='no-address',
                  fetch_ms=NULL, internet_ok=false, last_fetch_at=NOW(),
                  consec_fetch_fail = COALESCE(consec_fetch_fail,0) + 1
           WHERE id=$1::uuid`, [link.id]);
      } catch (e) { /* non-fatal */ }
      logger.info(`[real-internet] ${dev.name} WAN${link.position} (${link.interface}): DOWN — no IP address on the interface`);
    }
    linkState.push({ link, dhcp, ip, gateway, linkUp, internetOk, rtt, q, probeVerdict: (typeof verdict !== "undefined" ? verdict : null) });
  }

  // NOTE: Failover distance management is now handled LOCALLY by Netwatch on the
  // router (see buildPlan). The VPS monitor is READ-ONLY here — it only reads state
  // and updates the DB for the UI. This avoids fighting netwatch and, crucially, works
  // correctly: netwatch fails over even when this VPS can't reach the router.

  // Read routes to see which default is currently active
  let routes2 = routes;
  try { routes2 = await mtCall(dev, 'GET', '/ip/route'); } catch(e){}

  for (const s of linkState) {
    const activeDefault = routes2.find(r =>
      r['dst-address'] === '0.0.0.0/0' && (r['routing-table'] || 'main') === 'main' &&
      r.gateway === s.gateway && r.active === 'true');
    const isActive = !!activeDefault;
    let status;
    if (!s.linkUp || !s.ip) status = 'offline';
    else if (!s.internetOk) status = 'no-internet';
    else if (isActive) status = 'online';
    else status = 'standby';

    await query(
      `UPDATE nas_wan_links SET current_status=$1, resolved_ip=$2, resolved_gateway=$3, last_checked_at=NOW(), last_rtt=$4, is_active=$5, internet_ok=$6 WHERE id=$7::uuid`,
      [status, s.ip, s.gateway, s.rtt, isActive, s.internetOk, s.link.id]);
  }

  // ─── RL_QUALITY_FAILOVER: degraded-but-not-down detection + netwatch coordination ───
  // The VPS measures latency/jitter/loss per link. When the MAIN (primary) link is
  // degraded past thresholds for trip_count samples, we DISABLE its /32 probe route so
  // Netwatch's own ping fails and it runs its existing down-script (park main -> backup).
  // On recovery for recover_count samples, we re-enable the probe route (netwatch up-script
  // restores main). Hard-down failover stays entirely with netwatch, untouched.
  try {
    // RL_LB_NO_PARK: in LOAD-BALANCE-ONLY mode there is no failover, so nothing should be
    // parked. Park works by raising default-route-distance — but this mode has no main
    // default routes at all, so the action is a NO-OP that merely paints a false
    // "Degraded — on backup" label on a healthy link (0% loss, 1.4s fetch). Quality is still
    // MEASURED and displayed; it just does not trigger a failover that does not exist here.
    // Quality-driven action in load-balance (dropping a sick link from the PCC pool) belongs
    // in the load_balance + failover mode, where it is the correct behaviour.
    const _lbOnly = String(dev.multi_wan_mode || '') === 'load_balance';
    if (dev.wan_quality_enabled !== false && !_lbOnly) {
      const latTh  = dev.wan_quality_latency_ms || 100;
      const jitTh  = dev.wan_quality_jitter_ms || 30;
      const lossTh = dev.wan_quality_loss_pct || 2;
      const tripN  = dev.wan_quality_trip_count || 3;
      const recovN = dev.wan_quality_recover_count || 20;

      for (const s of linkState) {
        const link = s.link;
        // Only manage FAILOVER links that are a primary (the one we want to leave when bad).
        const isPrimary = (link.role === 'failover_primary') || (link.failover_priority === 1);

        // RL_HARDDOWN: primary offline or no-internet must fail over (not just quality).
        if (isPrimary && (s.linkUp === false || s.internetOk === false)) {
          try {
            const _t = await detectLinkType(dev, link, { dhcp: dhcps });
            if (_t.type === 'pppoe') {
              const _pps = await mtCall(dev, 'GET', '/interface/pppoe-client');
              const _p = (_pps||[]).find(x => x.name === _t.pppoeName || x.interface === link.interface);
              if (_p) await mtCall(dev, 'PATCH', '/interface/pppoe-client/' + _p['.id'], { 'default-route-distance': '200' });
            } else {
              const _dcs = await mtCall(dev, 'GET', '/ip/dhcp-client');
              const _dc = (_dcs||[]).find(x => x.interface === link.interface);
              if (_dc) await mtCall(dev, 'PATCH', '/ip/dhcp-client/' + _dc['.id'], { 'default-route-distance': '200' });
            }
            logger.info(`[mwan-harddown] ${dev.name} WAN${link.position}: primary hard-down (up=${s.linkUp} net=${s.internetOk}) -> parked 200, backup active`);
          } catch(e){ logger.warn('[mwan-harddown] ' + e.message); }
        }
        if (!isPrimary) continue;

        const q = s.q || {};
        // Evaluate degradation ONLY when the link is up + has internet (else it's a hard-down case → netwatch).
        let degraded = false;
        if (s.linkUp && s.internetOk) {
          const badLat  = (q.latencyMs != null) && (q.latencyMs > latTh);
          const badJit  = (q.jitterMs  != null) && (q.jitterMs  > jitTh);
          const badLoss = (q.lossPct   != null) && (q.lossPct   > lossTh);
          // RL_SLOW_TRIP: the fetch verdict now decides too. A link that fetched in 5.1s is unusable
          // for customers even when ping looks fine — and that evidence was previously displayed
          // and then thrown away here. ANY signal is sufficient; a link need not FAIL to be worth
          // leaving. 'slow' means real bytes took longer than this board's threshold.
          const slowFetch = (s.probeVerdict === 'slow') || (q.probeDegraded === true);
          /* RL_JITTER_SOLO: jitter breaching alone (good latency, 0% loss, fast fetch) is usually
             sampling noise — a 94 Mbps link isn't 'degrading' because one ping came back late.
             Jitter counts on its own only when SUBSTANTIAL (1.5x threshold); with any other bad
             signal it counts normally. */
          /* RL_LOSS_SOLO: the fetch probe is real TCP+TLS through this link. If it completed fast
             and latency+jitter are fine, a small ICMP loss is policing noise, not link loss — real
             loss degrades TCP visibly. Solo ICMP loss must be >=20% (reproducible after the
             confirmation re-test) to count; corroborated loss counts at the user's threshold. */
          const jitSolo = badJit && !badLat && !badLoss && !slowFetch;
          const lossSolo = badLoss && !badLat && !badJit && !slowFetch;
          degraded = badLat || slowFetch
            || (badLoss && (!lossSolo || q.lossPct >= 20))
            || (badJit && (!jitSolo || q.jitterMs > jitTh * 1.5));
          s._slowFetch = slowFetch;
        }
        /* RL_TP_WIRE: adaptive Ookla-style check. Runs when the link looks suspect (degraded or
           slow fetch) or as a ~10-min baseline. Below the floor => severe degraded signal. */
        try {
          const minMbps = Number(dev.wan_quality_min_mbps || 3);
          const lastTp = link.tp_checked_at ? new Date(link.tp_checked_at).getTime() : 0;
          const tpDue = (Date.now() - lastTp) > 10*60*1000;
          if (s.linkUp && s.internetOk && (degraded || s._slowFetch || tpDue)) {
            const gw2 = link.resolved_gateway || link.gateway;
            const mbps = gw2 ? await throughputProbe(dev, link, gw2) : null;
            await query('UPDATE nas_wan_links SET last_mbps=$1, tp_checked_at=NOW() WHERE id=$2::uuid', [mbps, link.id]).catch(()=>{});
            if (mbps != null && mbps < minMbps) {
              degraded = true; s._slowFetch = true; /* counts as severe (double weight + fast trip) */
              logger.info('[mwan-tp] ' + dev.name + ' WAN' + link.position + ': ' + mbps + ' Mbps < floor ' + minMbps + ' Mbps — stream-killing slow, counting as severe');
            } else if (mbps != null) {
              logger.info('[mwan-tp] ' + dev.name + ' WAN' + link.position + ': ' + mbps + ' Mbps (floor ' + minMbps + ')');
            }
          }
        } catch(e) { /* throughput probe is best-effort */ }

        // hysteresis counters
        let cd = link.consec_degraded || 0;
        let cg = link.consec_good || 0;
        let qstate = link.quality_state || 'good';
        let parked = link.quality_parked === true;

        // RL_ROLLING_WINDOW: the old line reset cd to 0 on a SINGLE good sample, so a FLAPPING
        // link (bad,bad,good,bad,bad...) never reached tripN-in-a-row and degraded forever. That
        // is why WAN1 sat at consec_degraded=4 while customers buffered. Count bad samples in the
        // last 10 instead, so intermittent degradation still trips.
        let cs = Number(link.consec_slow || 0);
        let hist = String(link.sample_history || '');
        hist = (hist + (degraded ? '1' : '0')).slice(-10);
        const badInWindow = (hist.match(/1/g) || []).length;
        /* RL_SEVERE_TRIP: heavy loss is a stream-killer NOW, not in 2 minutes. A sample with
           >=20% loss (or a dead fetch) counts DOUBLE toward the trip threshold, so a hard
           degradation trips in ~half the samples while mild wobble keeps the user's setting. */
        const sevSample = degraded && (((q.lossPct != null) && (q.lossPct >= 20)) || s._slowFetch);
        if (degraded) { cd += (sevSample ? 2 : 1); cg = 0; } else { cg++; if (badInWindow === 0) cd = 0; }
        // A slow fetch is high-confidence (real bytes really took seconds) so it trips FAST.
        if (s._slowFetch) cs++; else cs = 0;

        let doPark = false, doUnpark = false;
        // A slow fetch trips in 3 samples (~45s); ping metrics keep the conservative tripN
        // because they are noisy. The rolling window also trips, so a flapping link cannot
        // dodge failover by producing the occasional good sample.
        const slowTrip = cs >= 2; /* RL_SEVERE_TRIP: real-bytes-slow trips in 2 samples (~30s) */
        const pingTrip = cd >= tripN || badInWindow >= tripN;
        /* RL_NO_BACKUP_GUARD: parking the primary only makes sense if another usable link can take
           over. With the backup dead, parking just mislabels a healthy-enough primary and disables
           its policy routes. Never park without an alternative; force-unpark if stuck that way. */
        /* RL_STRICT_ALTS: an alternative counts only if PROVEN up with internet. '!== false' let
           an offline link with undefined state count as usable, defeating the no-backup guard. */
        const _usableAlts = (linkState || []).filter(x => x.link && x.link.id !== link.id
          && x.linkUp === true && x.internetOk === true).length;
        if (!parked && (slowTrip || pingTrip)) {
          if (_usableAlts > 0) { doPark = true; parked = true; qstate = 'degraded'; }
          else { qstate = 'degrading'; /* label the quality, but keep carrying traffic */ }
        }
        if (parked && _usableAlts === 0) { doUnpark = true; parked = false; qstate = degraded ? 'degrading' : 'good';
          try { require('./logger'); } catch(_e){}
        }
        
        // RL_POOL_EVICT: in 'both' mode the meaningful action is pool membership, not route
        // distance — there are no main default routes here for distance to affect.
        const _both = String(dev.multi_wan_mode || '') === 'both';
        if (_both && roleFlags(link).inLb) {
          const pv = poolVerdict(hist);
          if (pv) {
            // Count how many OTHER lb links are currently healthy. We must never empty the pool:
            // if every link is bad, a black-holed customer is worse than a slow one.
            const others = (links || []).filter(x => x.id !== link.id && roleFlags(x).inLb);
            const othersHealthy = others.filter(x => {
              /* RL_POOL_DEAD_NOT_HEALTHY: a hard-down link (no link / no internet) is NOT a healthy
                 alternative, even though it has no quality samples ('no samples' used to pass). */
              const xs = (linkState || []).find(ls => ls.link && ls.link.id === x.id);
              if (xs && (xs.linkUp === false || xs.internetOk === false)) return false;
              const ov = poolVerdict(x.sample_history);
              return !ov || ov.healthy;
            }).length;
        
            const shouldBeInPool = pv.healthy || othersHealthy === 0;
            const isInPool = link.in_pool !== false;
            if (shouldBeInPool !== isInPool) {
              await setPoolMembership(dev, link, shouldBeInPool);
              await query('UPDATE nas_wan_links SET in_pool=$1 WHERE id=$2::uuid',
                          [shouldBeInPool, link.id]);
              if (!shouldBeInPool) { try { await flushLinkConnections(dev, link); } catch(_e){} } /* RL_FLUSH_WIRE */
              if (!shouldBeInPool) {
                logger.info('[mwan-pool] WAN' + link.position + ' evicted: ' + pv.bad + '/' + pv.samples +
                            ' bad samples. Traffic will hash onto the healthy links.');
              } else if (othersHealthy === 0) {
                logger.warn('[mwan-pool] WAN' + link.position + ' kept in pool: ALL links degraded, ' +
                            'nowhere better to go. A slow link beats no link.');
              }
            }
            /* RL_POOL_DEAD_EVICT: any OTHER lb link that is hard-down must be OUT of the PCC pool —
               PCC keeps hashing onto its mark, and that traffic blackholes or silently falls back
               to another link while the UI mislabels where it went. */
            for (const ox of others) {
              const oxs = (linkState || []).find(ls => ls.link && ls.link.id === ox.id);
              const oxDead = oxs && (oxs.linkUp === false || oxs.internetOk === false);
              if (oxDead && ox.in_pool !== false) {
                try {
                  await setPoolMembership(dev, ox, false);
                  await query('UPDATE nas_wan_links SET in_pool=$1 WHERE id=$2::uuid', [false, ox.id]);
                  try { await flushLinkConnections(dev, ox); } catch(_e){}
                  logger.info('[mwan-pool] WAN' + ox.position + ' evicted: link DOWN — its PCC hash share was mismarking traffic.');
                } catch(pe){ logger.warn('[mwan-pool] dead-evict WAN' + ox.position + ': ' + pe.message); }
              }
            }
          }
        }
        /* RL_UNPARK_REACHABLE: this was an 'else if' chained behind the 'both'-mode pool branch,
           so for any LB-member link the unpark could NEVER run — a link parked once stayed parked
           forever (WAN1 sat at consec_good=23, recover=2, still parked). Independent 'if' now. */
        if (parked && cg >= recovN) { doUnpark = true; parked = false; qstate = 'good'; }
        else if (!parked) { qstate = (badInWindow >= 2) ? 'degrading' : 'good'; } /* RL_LABEL_PERSIST: label needs persistence, one blip stays 'good' */

        // RL_QUALITY_RECONCILE: reconcile the router distance to the 'parked' state EVERY run
        // (not just on doPark/doUnpark). Fixes the stuck "parked=true but distance=1" desync.
        {
          const healthyDistance = link.failover_priority ? parseInt(link.failover_priority) : (link.position || 1);
          const desiredDist = parked ? PARKED_DISTANCE : healthyDistance;
          try {
            const t = await detectLinkType(dev, link, { dhcp: s.dhcp ? [s.dhcp] : null });
            let curDist = null, patched = false;
            // RL_DUAL_CLIENT_FIX: set the distance on EVERY default-route source bound to this
            // physical interface — the pppoe-client AND any dhcp-client on the same port — so a
            // leftover/stray client can't keep carrying traffic after we park.
            try {
              const pppoes = await mtCall(dev, 'GET', '/interface/pppoe-client');
              for (const p of (pppoes||[])) {
                if (p.interface === link.interface || p.name === t.pppoeName) {
                  const cd2 = parseInt(p['default-route-distance']);
                  if (cd2 !== desiredDist) { await mtCall(dev, 'PATCH', '/interface/pppoe-client/' + p['.id'], { 'default-route-distance': String(desiredDist) }); patched = true; }
                  if (curDist === null) curDist = cd2;
                }
              }
            } catch(e){}
            try {
              const dhcps2 = await mtCall(dev, 'GET', '/ip/dhcp-client');
              for (const dc of (dhcps2||[])) {
                if (dc.interface === link.interface) {
                  const cd3 = parseInt(dc['default-route-distance']);
                  if (cd3 !== desiredDist) { await mtCall(dev, 'PATCH', '/ip/dhcp-client/' + dc['.id'], { 'default-route-distance': String(desiredDist) }); patched = true; }
                  if (curDist === null) curDist = cd3;
                }
              }
            } catch(e){}
            // static default routes via this link's gateway (if any)
            if (t.type === 'static' && t.gateway) {
              try {
                const rts = await mtCall(dev, 'GET', '/ip/route');
                for (const r of (rts||[])) {
                  if (r['dst-address']==='0.0.0.0/0' && r.gateway === t.gateway && (r['routing-table']||'main')==='main' && !(r.comment||'').includes('cust via=')) {
                    const cd4 = parseInt(r.distance);
                    if (cd4 !== desiredDist) { await mtCall(dev, 'PATCH', '/ip/route/' + r['.id'], { distance: String(desiredDist) }); patched = true; }
                    if (curDist === null) curDist = cd4;
                  }
                }
              } catch(e){}
            }
            // Keep the custom-table policy routes in sync with parked state.
            try {
              const rts2 = await mtCall(dev, 'GET', '/ip/route');
              for (const r of (rts2||[])) {
                if ((r.comment||'').includes(`via=wan${link.position};`)) {
                  const wantDisabled = parked ? 'true' : 'false';
                  if (String(r.disabled) !== wantDisabled) await mtCall(dev, 'PATCH', '/ip/route/' + r['.id'], { disabled: wantDisabled });
                }
              }
            } catch(e){}
            if (doPark) { try { await flushLinkConnections(dev, link); } catch(_e){} }
            if (patched || doPark || doUnpark) {
              logger.info(`[mwan-quality] ${dev.name} WAN${link.position} [${t.type}]: ${parked ? 'PARKED dist='+PARKED_DISTANCE+' (→ backup)' : 'ACTIVE dist='+healthyDistance}${patched ? ' [router corrected '+curDist+'→'+desiredDist+']' : ''} lat=${q.latencyMs}ms jit=${q.jitterMs}ms loss=${q.lossPct}%`);
            }
            try {
              await query(
                `INSERT INTO nas_events (nas_id, isp_id, event_type, message, created_at)
                 VALUES ($1::uuid, $2::uuid, $3, $4, NOW())`,
                [dev.id, dev.isp_id, doPark ? 'wan_quality_degraded' : 'wan_quality_recovered',
                 doPark
                   ? `WAN${link.position} degraded (lat ${Math.round(q.latencyMs||0)}ms, jitter ${Math.round(q.jitterMs||0)}ms, loss ${q.lossPct}%) — failed over to backup`
                   : `WAN${link.position} quality recovered — restored as primary`]
              );
            } catch(e){ /* nas_events may differ; ignore */ }
          } catch(e){ logger.warn('[mwan-quality] direct distance set failed: ' + e.message); }
        }

        await query(
          `UPDATE nas_wan_links SET last_latency_ms=$1, last_jitter_ms=$2, last_loss_pct=$3,
             quality_state=$4, consec_degraded=$5, consec_good=$6, quality_parked=$7, sample_history=$9, consec_slow=$10 WHERE id=$8::uuid`,
          [q.latencyMs ?? null, q.jitterMs ?? null, q.lossPct ?? null, qstate, cd, cg, parked, link.id, hist, cs]);
      }
    }
  } catch (e) { logger.warn('[mwan-quality] eval error: ' + e.message); }

  /* RL_MWAN_REPAIR: if the DB says this device HAS multi-wan applied but the router has ZERO
     RL-MWAN objects, the router config was wiped (reboot into a bad state, manual clear,
     re-provision). Re-apply so failover/load-balancing comes back on its own.
     Guards: only when config exists in DB; only on a COMPLETE absence (partial states are
     normal mid-change); rate-limited to once per 10 min so a persistent failure cannot loop. */
  try {
    let mangles = [];
    try { mangles = await mtCall(dev, 'GET', '/ip/firewall/mangle'); } catch(e) { mangles = null; }
    if (Array.isArray(mangles)) {
      const tagged = mangles.filter(function(m){ return String(m.comment||'').indexOf(RL_TAG) === 0; }).length;
      const taggedRoutes = (routes||[]).filter(function(r){ return String(r.comment||'').indexOf(RL_TAG) === 0; }).length;
      if (tagged === 0 && taggedRoutes === 0) {
        const lastTry = _mwanRepairAt[deviceId] || 0;
        if (Date.now() - lastTry > 600000) {
          _mwanRepairAt[deviceId] = Date.now();
          logger.warn('[mwan-repair] ' + (dev.name||deviceId) + ': RL-MWAN objects missing on router but config exists in DB -> re-applying');
          try {
            const r = await applyPlan(deviceId, dev.isp_id);
            logger.info('[mwan-repair] ' + (dev.name||deviceId) + ': re-applied (' + ((r&&r.results&&r.results.length)||0) + ' ops, ' + ((r&&r.errors&&r.errors.length)||0) + ' errors)');
          } catch (e) { logger.error('[mwan-repair] ' + (dev.name||deviceId) + ': re-apply failed: ' + e.message); }
        }
      }
    }
  } catch (e) { logger.warn('[mwan-repair] check: ' + e.message); }

  return { ok: true, links: linkState.length };
}

async function monitorAll() {
  try {
    const dr = await query(`SELECT id FROM nas_devices WHERE multi_wan_applied_at IS NOT NULL AND multi_wan_mode IS NOT NULL AND multi_wan_mode != 'none'`);
    for (const row of dr.rows) {
      try { await monitorDevice(row.id); } catch (e) { logger.warn(`[mwan-monitor] device ${row.id}: ${e.message}`); }
    }
    return dr.rows.length;
  } catch (e) { logger.error('[mwan-monitor] monitorAll: ' + e.message); return 0; }
}

async function getLinkStatus(deviceId, ispId) {
  const dr = await query('SELECT multi_wan_applied_at FROM nas_devices WHERE id = $1::uuid AND isp_id = $2::uuid', [deviceId, ispId]);
  if (!dr.rows[0]) throw new Error('Device not found');
  const linksR = await query(
    `SELECT id, position, name, interface, role, current_status, resolved_ip, resolved_gateway, last_checked_at, last_rtt, is_active, internet_ok, ping_target,
            last_latency_ms, last_jitter_ms, last_loss_pct, quality_state, quality_parked /* RL_QUALITY_DASH */,
              probe_verdict, probe_stage, fetch_ms, consec_fetch_fail, last_fetch_at,
            bytes_carried, bytes_since, in_load_balance, lb_weight, in_pool, probe_verdict, probe_stage, fetch_ms, consec_fetch_fail, last_fetch_at, consec_slow, sample_history
       FROM nas_wan_links WHERE nas_id = $1::uuid AND enabled = true ORDER BY position ASC`, [deviceId]);
  const statuses = linksR.rows.map(l => {
    const status = l.current_status || 'unknown';
    const isBackup = l.role === 'failover_backup';
    let label = 'Unknown';
    if (status === 'online') label = 'Online';
    else if (status === 'standby') label = isBackup ? 'Standby' : 'Ready';
    else if (status === 'no-internet') label = 'No Internet';
    else if (status === 'offline') label = 'Offline';
    return {
      id: l.id, position: l.position, interface: l.interface, name: l.name, role: l.role,
      status, status_label: label, ip: l.resolved_ip, gateway: l.resolved_gateway,
      internet_ok: l.internet_ok, is_active: l.is_active,
      gateway_ping_ok: status !== 'offline', external_ping_ok: l.internet_ok,
      // RL_STATUS_FIELDS: the real-internet verdict must reach the UI. Without these the
      // status line falls back to external_ping_ok — the ICMP flag that reported
      // "70ms, 0% loss, Good" while the ISP's transit was dead and nothing would load.
      probe_verdict: l.probe_verdict, probe_stage: l.probe_stage,
      bytes_carried: l.bytes_carried, bytes_since: l.bytes_since,
      // RL_LB_FIELDS: renderLbSplit() filters on in_load_balance and scales the bar by
      // lb_weight. Without these the filter drops every link and the visual renders nothing.
      in_load_balance: l.in_load_balance, lb_weight: l.lb_weight,
      in_pool: l.in_pool,
      fetch_ms: l.fetch_ms, consec_fetch_fail: l.consec_fetch_fail,
      last_fetch_at: l.last_fetch_at,
      route_active_in_main: l.is_active, rtt: l.last_rtt, ping_target: l.ping_target, checked_at: l.last_checked_at,
      latency_ms: l.last_latency_ms, jitter_ms: l.last_jitter_ms, loss_pct: l.last_loss_pct,
      quality_state: l.quality_state, quality_parked: l.quality_parked /* RL_QUALITY_DASH */
    };
  });
  return { ok: true, statuses, applied: !!dr.rows[0].multi_wan_applied_at };
}

module.exports = { buildPlan, applyPlan, revertPlan, cleanupRouter, getLinkStatus, monitorDevice, monitorAll };
