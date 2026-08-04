// RL_NAS_CONFIG_SYNC — keep nas_devices describing what the router actually runs.
//
// routes/nas.js stores '192.168.88.1' / '192.168.88.0/24' when a device is added without
// explicit values, while provision.js allocates a real per-router network and configures the
// MikroTik with THAT. Nothing reconciled them, so the device page showed a factory-default
// address the router had never used — misleading for the ISP and useless for support.
//
// Reads the router, writes the DATABASE, and never the reverse: these routers carry live PPPoE
// and hotspot customers, and pushing stored values back would renumber the network under them.
const axios = require('axios');
const { query } = require('../config/database');
const logger = require('./logger');

const TIMEOUT = 20000;

async function readRouter(dev) {
  const b = 'http://' + dev.wireguard_ip + '/rest';
  const auth = { username: dev.mikrotik_api_user, password: dev.mikrotik_api_password };
  const get = async p => { try { return (await axios.get(b + p, { auth, timeout: TIMEOUT })).data || []; } catch (e) { return []; } };

  const [addrs, bports, pools, nets, hs, dhcp, ifaces] = await Promise.all([
    get('/ip/address'), get('/interface/bridge/port'), get('/ip/pool'),
    get('/ip/dhcp-server/network'), get('/ip/hotspot'), get('/ip/dhcp-server'), get('/interface'),
  ]);

  const server = hs.find(x => !String(x.disabled).match(/true/)) || hs[0] || {};
  const hsIface = server.interface || '';
  const addr = addrs.find(a => a.interface === hsIface);          // e.g. 10.100.0.1/24
  const gateway = addr ? String(addr.address).split('/')[0] : null;
  const network = addr ? (() => {
    const [ip, cidr] = String(addr.address).split('/');
    const o = ip.split('.');
    return o[0] + '.' + o[1] + '.' + o[2] + '.0/' + (cidr || '24');
  })() : null;

  const dh = dhcp.find(d => d.interface === hsIface);
  const poolName = dh ? dh['address-pool'] : null;
  const pool = poolName ? pools.find(p => p.name === poolName) : null;
  const ranges = pool ? String(pool.ranges).split('-') : [];

  const net = nets.find(n => network && String(n.address).split('/')[0] === String(network).split('/')[0]);

  const ports = bports.filter(p => p.bridge === hsIface).map(p => p.interface).join(',');

  /* The WAN is whichever addressed interface is neither the hotspot bridge nor the WireGuard
     tunnel — a PPPoE uplink shows up as its own interface, so prefer a physical one. */
  const wanCand = addrs.filter(a => a.interface !== hsIface && !/wg|wireguard|rumalink-wg/i.test(a.interface));
  const phys = wanCand.find(a => /^ether|^sfp|^wlan/i.test(a.interface));
  const wan = phys ? phys.interface : (wanCand[0] ? wanCand[0].interface : null);

  return {
    hotspot_interface: hsIface || null,
    hotspot_gateway: gateway,
    hotspot_network: network,
    hotspot_pool_start: ranges[0] || null,
    hotspot_pool_end: ranges[1] || null,
    bridge_ports: ports || null,
    wan_interface: wan,
    dns_servers: net ? (net['dns-server'] || null) : null,
    hotspot_profile: server.profile || null,
    /* the device page reads these column names, not the hotspot_* ones */
    gateway_ip: gateway,
    ip_pool_start: ranges[0] || null,
    ip_pool_end: ranges[1] || null,
  };
}

async function syncDevice(dev) {
  const live = await readRouter(dev);
  if (!live.hotspot_interface) return { skipped: 'router unreachable or no hotspot' };

  const cols = (await query(
    "SELECT column_name FROM information_schema.columns WHERE table_name='nas_devices'")).rows.map(r => r.column_name);

  const sets = [], vals = [];
  Object.keys(live).forEach(k => {
    if (live[k] != null && cols.includes(k)) { vals.push(live[k]); sets.push(k + '=$' + vals.length); }
  });
  if (!sets.length) return { skipped: 'nothing to write' };
  vals.push(dev.id);
  await query('UPDATE nas_devices SET ' + sets.join(', ') + ', updated_at=NOW() WHERE id=$' + vals.length + '::uuid', vals);
  return { updated: live };
}

async function pass() {
  let devs = [];
  try {
    devs = (await query(
      'SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL')).rows;
  } catch (e) { logger.warn('[nas-config-sync] db: ' + e.message); return; }
  for (const d of devs) {
    try {
      const r = await syncDevice(d);
      if (r.updated) logger.info('[nas-config-sync] ' + d.name + ' gw=' + r.updated.hotspot_gateway +
        ' net=' + r.updated.hotspot_network + ' iface=' + r.updated.hotspot_interface);
    } catch (e) { logger.warn('[nas-config-sync] ' + d.name + ': ' + e.message); }
  }
}

function start() {
  setTimeout(function () { pass().catch(function () {}); }, 15000);
  setInterval(function () { pass().catch(function () {}); }, 10 * 60 * 1000);
  logger.info('[nas-config-sync] Registered (every 10m) — device page reflects the router, not stored defaults');
}

module.exports = { start, pass, syncDevice, readRouter };
