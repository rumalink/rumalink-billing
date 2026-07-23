// utils/router-harden.js — RL_ROUTER_HARDEN
// Every 2 minutes, ensure each ONLINE router has the performance + auth settings that today's
// fixes established, so a delete/re-add (or a router provisioned before these fixes) self-heals:
//   - fasttrack established/related (throughput on low-power routers)
//   - MSS clamp on the PPPoE WAN (recovers fragmentation loss)
//   - pcq queue types + hotspot user-profile uses pcq
//   - hotspot profiles: login-by has 'mac', NO 'mac-cookie', mac-auth-password set
// Idempotent: only creates what's missing; never duplicates.
const { query } = require('../config/database');
const logger = require('./logger');
const axios = require('axios');

async function onlineRouters() {
  const r = await query("SELECT wireguard_ip, mikrotik_api_user, mikrotik_api_password, name FROM nas_devices WHERE is_online=true AND wireguard_ip IS NOT NULL");
  return r.rows;
}

async function harden(d) {
  const auth = { username: d.mikrotik_api_user, password: d.mikrotik_api_password };
  const b = 'http://' + d.wireguard_ip + '/rest';
  const get = async p => (await axios.get(b + p, { auth, timeout: 8000 })).data || [];
  const put = async (p, body) => axios.put(b + p, body, { auth, timeout: 8000 });
  const patch = async (p, body) => axios.patch(b + p, body, { auth, timeout: 8000 });
  const del = async (p, id) => axios.delete(b + p + '/' + encodeURIComponent(id), { auth, timeout: 8000 });
  const move = async (p, id, dest) => axios.post(b + p + '/move', { numbers: id, destination: dest }, { auth, timeout: 8000 });

  // 1) fasttrack pair
  const filter = await get('/ip/firewall/filter');
  const hasFt = filter.some(f => f.action === 'fasttrack-connection');
  if (!hasFt) {
    const fwd = filter.filter(f => f.chain === 'forward');
    const firstId = fwd.length ? fwd[0]['.id'] : null;
    const r1 = await put('/ip/firewall/filter', { chain:'forward', action:'fasttrack-connection', 'connection-state':'established,related', comment:'RL-FASTTRACK est' });
    const r2 = await put('/ip/firewall/filter', { chain:'forward', action:'accept', 'connection-state':'established,related', comment:'RL-FASTTRACK accept' });
    if (firstId) for (const id of [r1.data['.id'], r2.data['.id']]) { try { await axios.post(b+'/ip/firewall/filter/move',{numbers:id,destination:firstId},{auth,timeout:8000}); } catch(e){} }
    logger.info('[router-harden] ' + d.name + ' fasttrack added');
  }

  // 2) MSS clamp on pppoe (only if a pppoe WAN iface exists)
  const ifs = await get('/interface');
  const pppoeWan = ifs.find(i => i.name === 'rl-wan-pppoe');
  if (pppoeWan) {
    const mangle = await get('/ip/firewall/mangle');
    const hasClamp = mangle.some(m => m.action === 'change-mss' && /RL-MSS/.test(String(m.comment||'')));
    if (!hasClamp) {
      await put('/ip/firewall/mangle', { chain:'forward', action:'change-mss', 'new-mss':'clamp-to-pmtu', protocol:'tcp', 'tcp-flags':'syn', 'out-interface':'rl-wan-pppoe', comment:'RL-MSS clamp pppoe out' });
      await put('/ip/firewall/mangle', { chain:'forward', action:'change-mss', 'new-mss':'clamp-to-pmtu', protocol:'tcp', 'tcp-flags':'syn', 'in-interface':'rl-wan-pppoe', comment:'RL-MSS clamp pppoe in' });
      logger.info('[router-harden] ' + d.name + ' MSS clamp added');
    }
  }

  // 3) pcq types + hotspot user-profile uses pcq
  const qt = await get('/queue/type');
  const ensureType = async (name, classifier) => {
    const t = qt.find(x => x.name === name);
    const body = { kind:'pcq', 'pcq-rate':'0', 'pcq-classifier':classifier, 'pcq-limit':'50', 'pcq-total-limit':'2000' };
    try { if (t) await patch('/queue/type/'+encodeURIComponent(t['.id']), body); else await put('/queue/type', Object.assign({name}, body)); } catch(e){}
  };
  await ensureType('pcq-download-default','dst-address');
  await ensureType('pcq-upload-default','src-address');
  const ups = await get('/ip/hotspot/user/profile');
  for (const u of ups) {
    if (String(u['queue-type']||'') !== 'pcq-upload-default/pcq-download-default') {
      try { await patch('/ip/hotspot/user/profile/'+encodeURIComponent(u['.id']), { 'queue-type':'pcq-upload-default/pcq-download-default' }); } catch(e){}
    }
  }

  // 5) RL-PPPOE-WALL (SAFE): expired-PPPoE walled garden. Scoped to the PPPoE pool (100.64.0.0/24)
  //    AND the rl-expired list, so hotspot (192.168.100.x) can NEVER match. Allow DNS + portal, drop rest.
  //    NO dst-nat redirect (portal is username-based; the redirect broke hotspot before).
  try {
    const fw = await get('/ip/firewall/filter');
    const hasWall = fw.some(function(x){ return /RL-PPPOE-WALL/.test(String(x.comment||'')); });
    if (!hasWall) {
      var W = { chain:'forward', 'src-address':'100.64.0.0/24', 'src-address-list':'rl-expired' };
      await put('/ip/firewall/filter', Object.assign({}, W, { protocol:'udp', 'dst-port':'53', action:'accept', comment:'RL-PPPOE-WALL dns' }));
      await put('/ip/firewall/filter', Object.assign({}, W, { protocol:'tcp', 'dst-port':'53', action:'accept', comment:'RL-PPPOE-WALL dns2' }));
      await put('/ip/firewall/filter', Object.assign({}, W, { 'dst-address-list':'rl-portal', action:'accept', comment:'RL-PPPOE-WALL portal' }));
      await put('/ip/firewall/filter', Object.assign({}, W, { action:'drop', comment:'RL-PPPOE-WALL drop' }));
      logger.info('[router-harden] ' + d.name + ' RL-PPPOE-WALL (scoped) added');
    }
  } catch (e) { logger.warn('[router-harden] wall: ' + e.message); }

  // 6) RL_PPPOE_FULL — RL-PPPOE-NOFT: exclude the PPPoE pool from fasttrack so per-user queues
  //    actually cap the speed (fasttracked conns bypass queues -> uncapped bursts + instability).
  //    Must sit ABOVE the fasttrack rule. Scoped to 100.64.0.0/24 so hotspot keeps fasttrack.
  try {
    const fw2 = await get('/ip/firewall/filter');
    const haveNoft = fw2.filter(function(x){ return /RL-PPPOE-NOFT/.test(String(x.comment||'')); });
    const ftRule = fw2.find(function(x){ return x.action === 'fasttrack-connection'; });
    if (ftRule && haveNoft.length < 2) {
      for (const x of haveNoft) { try { await del('/ip/firewall/filter', x['.id']); } catch(e){} }
      const a1 = await put('/ip/firewall/filter', { chain:'forward', action:'accept', 'connection-state':'established,related', 'src-address':'100.64.0.0/24', comment:'RL-PPPOE-NOFT src' });
      const a2 = await put('/ip/firewall/filter', { chain:'forward', action:'accept', 'connection-state':'established,related', 'dst-address':'100.64.0.0/24', comment:'RL-PPPOE-NOFT dst' });
      for (const id of [a1.data['.id'], a2.data['.id']]) { try { await move('/ip/firewall/filter', id, ftRule['.id']); } catch(e){} }
      logger.info('[router-harden] ' + d.name + ' RL-PPPOE-NOFT added above fasttrack');
    }
  } catch (e) { logger.warn('[router-harden] noft: ' + e.message); }

  // 7) RL-PPPOE-CAPTIVE: dst-nat expired-PPPoE port-80 to the nginx responder so the phone shows
  //    'Sign in to network' and opens the pay portal. Scoped to 100.64.0.0/24 + rl-expired list.
  try {
    const nat = await get('/ip/firewall/nat');
    const haveCap = nat.some(function(x){ return /RL-PPPOE-CAPTIVE/.test(String(x.comment||'')); });
    if (!haveCap) {
      await put('/ip/firewall/nat', { chain:'dstnat', 'src-address':'100.64.0.0/24', 'src-address-list':'rl-expired', protocol:'tcp', 'dst-port':'80', action:'dst-nat', 'to-addresses':'10.8.0.1', 'to-ports':'80', comment:'RL-PPPOE-CAPTIVE redirect' });
      logger.info('[router-harden] ' + d.name + ' RL-PPPOE-CAPTIVE added');
    }
  } catch (e) { logger.warn('[router-harden] captive: ' + e.message); }

  // 8) DEDUPE: keep exactly one of each RL-PPPOE-WALL rule (repeated passes can double them).
  try {
    const fw3 = await get('/ip/firewall/filter');
    const seen = {};
    for (const x of fw3) {
      const c = String(x.comment||'');
      if (/RL-PPPOE-WALL|RL-PPPOE-NOFT/.test(c)) {
        if (seen[c]) { try { await del('/ip/firewall/filter', x['.id']); logger.info('[router-harden] deduped ' + c); } catch(e){} }
        else seen[c] = true;
      }
    }
  } catch (e) { logger.warn('[router-harden] dedupe: ' + e.message); }

  // 4) hotspot profiles: mac yes, mac-cookie no, mac-auth-password set
  const profs = await get('/ip/hotspot/profile');
  for (const p of profs) {
    const lb = String(p['login-by']||'');
    if (/mac-cookie/.test(lb) || !/(^|,)mac(,|$)/.test(lb)) {
      const cleaned = lb.split(',').filter(x => x && x !== 'mac-cookie');
      if (!cleaned.includes('mac')) cleaned.unshift('mac');
      try { await patch('/ip/hotspot/profile/'+encodeURIComponent(p['.id']), { 'login-by': cleaned.join(','), 'mac-auth-password':'RLMACAUTH' }); logger.info('[router-harden] ' + d.name + ' profile ' + p.name + ' login-by normalized'); } catch(e){}
    }
  }
}

async function pass() {
  let routers;
  try { routers = await onlineRouters(); } catch (e) { logger.warn('[router-harden] list: ' + e.message); return; }
  for (const d of routers) {
    try { await harden(d); } catch (e) { logger.warn('[router-harden] ' + (d.name||d.wireguard_ip) + ': ' + e.message); }
  }
}

function start() {
  setInterval(function () { pass().catch(function (e) { logger.warn('[router-harden] ' + e.message); }); }, 120000);
  setTimeout(function(){ pass().catch(function(e){ logger.warn('[router-harden] first: ' + e.message); }); }, 15000);
  logger.info('[router-harden] started (120s)');
}

module.exports = { start: start, pass: pass, harden: harden };
