#!/usr/bin/env bash
#
# sync_nas_config_from_router.sh — make the dashboard tell the truth about each router.
#
# THE MISMATCH: routes/nas.js stores literals when a device is added without explicit values
#   hotspot_gateway || '192.168.88.1'   hotspot_network || '192.168.88.0/24'
#   hotspot_pool_start || '192.168.88.10'  hotspot_pool_end || '192.168.88.250'
# but provision.js ALLOCATES a real per-router network (this one got 10.100.0.0/24) and
# configures the MikroTik with that. Nothing ever reconciled the two, so the device page shows
# a factory-default address the router has never used.
#
# DIRECTION OF THE FIX: read the router, write the DATABASE. Never the reverse. This RB5009 is
# carrying 17 PPPoE customers and a live hotspot; pushing the stored values back would renumber
# the network and disconnect all of them.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The real column names"
q -c "SELECT column_name FROM information_schema.columns WHERE table_name='nas_devices'
        AND (column_name ILIKE '%hotspot%' OR column_name ILIKE '%pool%' OR column_name ILIKE '%gateway%'
             OR column_name ILIKE '%wan%' OR column_name ILIKE '%bridge%' OR column_name ILIKE '%dns%')
      ORDER BY column_name;"

say "2) Stored values right now"
q -c "SELECT name, wan_interface, hotspot_interface, bridge_ports, hotspot_gateway,
             hotspot_network, hotspot_pool_start, hotspot_pool_end FROM nas_devices;" 2>&1 | head -12

say "3) Create utils/nas-config-sync.js (writes only to the database)"
sudo tee "$BE/utils/nas-config-sync.js" > /dev/null <<'JS'
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
JS
sudo chown www-data:www-data "$BE/utils/nas-config-sync.js"
sudo -u www-data node --check "$BE/utils/nas-config-sync.js" && echo "   nas-config-sync.js syntax OK"

say "4) Dry run — what it reads from the live router (no write yet)"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const {query}=require('$BE/config/database');
const s=require('$BE/utils/nas-config-sync');
(async()=>{
  const d=(await query('SELECT id,name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL')).rows;
  for(const dev of d){ const live=await s.readRouter(dev);
    console.log('   '+dev.name+':'); Object.keys(live).forEach(k=>console.log('     '+k+' = '+live[k])); }
  process.exit(0);
})();" 2>&1 | grep -v "^info:" | sed 's/^/  /'

say "5) Apply it (database only — the router is not touched)"
read -r -p "   Write these values to nas_devices? (y/N): " GO || true
if [ "${GO:-n}" = "y" ] || [ "${GO:-n}" = "Y" ]; then
  sudo -u www-data node -e "
  require('dotenv').config({path:'$BE/.env'});
  (async()=>{ await require('$BE/utils/nas-config-sync').pass(); console.log('   synced'); process.exit(0); })();" 2>&1 | grep -vE "^info: \[" | sed 's/^/  /'
  q -c "SELECT name, wan_interface, hotspot_interface, hotspot_gateway, hotspot_network,
               hotspot_pool_start, hotspot_pool_end, bridge_ports FROM nas_devices;" 2>&1 | head -10
else echo "   skipped"; fi

say "6) Register it so it stays true"
sudo cp "$BE/utils/cron.js" "$BE/utils/.cron.js.bak_$TS"
if sudo grep -q "nas-config-sync" "$BE/utils/cron.js"; then echo "   already registered"
else echo "try { require('./nas-config-sync').start(); } catch (e) { require('./logger').warn('[nas-config-sync] start: ' + e.message); }" | sudo tee -a "$BE/utils/cron.js" >/dev/null; echo "   registered"; fi
sudo -u www-data node --check "$BE/utils/cron.js" && echo "   cron.js OK"

say "7) Stop nas.js inventing 192.168.88.x for NEW routers"
sudo cp "$BE/routes/nas.js" "$BE/routes/.nas.js.bak_$TS"
sudo python3 - "$BE/routes/nas.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_NO_FAKE_DEFAULTS' in s:
    print("   already patched"); sys.exit(0)
n = len(re.findall(r"\|\| '192\.168\.88\.[0-9/]+'", s))
s = re.sub(r"(hotspot_gateway)( \|\| '192\.168\.88\.1')", r"\1 || null", s)
s = re.sub(r"(hotspot_network)( \|\| '192\.168\.88\.0/24')", r"\1 || null", s)
s = re.sub(r"(hotspot_pool_start)( \|\| '192\.168\.88\.10')", r"\1 || null", s)
s = re.sub(r"(hotspot_pool_end)( \|\| '192\.168\.88\.250')", r"\1 || null", s)
if "RL_NO_FAKE_DEFAULTS" not in s:
    s = ("/* RL_NO_FAKE_DEFAULTS: these fields defaulted to 192.168.88.x — MikroTik's factory\n"
         "   addressing — whenever a device was added without them. provision.js allocates the real\n"
         "   per-router network, so the stored literals described a network that never existed and\n"
         "   the device page showed the wrong gateway. Leave them null; nas-config-sync fills them\n"
         "   in from the router once it is reachable. */\n") + s
open(p,'w').write(s); print(f"   {n} hardcoded default(s) replaced with null")
PY
cd "$BE" && sudo -u www-data node --check routes/nas.js && echo "   nas.js OK"
grep -c "192.168.88" "$BE/routes/nas.js" | sed 's/^/   remaining 192.168.88 in nas.js: /'

say "8) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 30 --nostream 2>/dev/null | grep -iE "nas-config-sync|error" | tail -5 | sed 's/^/   /'
echo "   ${Y}Reload the MikroTik device page — Configuration should now match the router.${N}"

say "9) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Device page reflects live router config; stop storing 192.168.88.x factory defaults" 2>&1 | head -2 | sed 's/^/   /'
