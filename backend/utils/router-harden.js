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
  const get = async p => (await axios.get(b + p, { auth, timeout: 25000 })).data || [];
  const put = async (p, body) => axios.put(b + p, body, { auth, timeout: 25000 });
  const patch = async (p, body) => axios.patch(b + p, body, { auth, timeout: 25000 });
  const del = async (p, id) => axios.delete(b + p + '/' + encodeURIComponent(id), { auth, timeout: 25000 });
  const move = async (p, id, dest) => axios.post(b + p + '/move', { numbers: id, destination: dest }, { auth, timeout: 25000 });

  // 1) RL_NO_FASTTRACK — fasttrack is DELIBERATELY NOT enabled on RumaLink routers.
  //    Fasttracked packets bypass the forwarding pipeline that /queue/simple lives in, so
  //    every per-user rate limit (hotspot rl-<code>, PPPoE, TV rl-tv-<mac>) silently stops
  //    being enforced. Shaping is the product, so fasttrack can only ever accelerate traffic
  //    we are not billing — effectively nothing on a hotspot/PPPoE router. We therefore
  //    ensure it is ABSENT/DISABLED rather than adding it.
  //    NOTE: the general `accept established,related` rule IS kept — it is required for
  //    return traffic and is unrelated to fasttrack.
  const filter = await get('/ip/firewall/filter');
  for (const f of filter) {
    if (f.action === 'fasttrack-connection') {
      try {
        await del('/ip/firewall/filter', f['.id']);
        logger.warn('[router-harden] ' + d.name + ' FASTTRACK RULE FOUND — deleted it; rate limits were being bypassed');
      } catch (e) { logger.warn('[router-harden] fasttrack delete: ' + e.message); }
    }
  }
  // keep the connectivity-critical established/related accept
  if (!filter.some(f => /RL-FASTTRACK accept/.test(String(f.comment || '')))) {
    try {
      await put('/ip/firewall/filter', { chain:'forward', action:'accept', 'connection-state':'established,related', comment:'RL-FASTTRACK accept' });
      logger.info('[router-harden] ' + d.name + ' established/related accept restored');
    } catch (e) {}
  }

  // 1b) RL_ACCEPT_ORDER — the bare `accept established,related` rule must sit BELOW every
  //     rl-expired rule. Above them, an expired customer's already-open connections are accepted
  //     before reaching the expiry reject, and they keep browsing after their package ends.
  //     Enforced by DELETE + re-ADD (an append reliably lands last) rather than a positional
  //     move: positional moves previously black-holed every expired user. Safe because the
  //     forward chain has no terminal drop — during the sub-millisecond gap traffic falls
  //     through to the chain's default accept.
  try {
    const fwA = await get('/ip/firewall/filter');
    const fwd = fwA.filter(x => x.chain === 'forward');
    const acceptIdx = fwd.findIndex(x =>
      x.action === 'accept' &&
      String(x['connection-state'] || '') === 'established,related' &&
      !x['src-address'] && !x['dst-address'] && !x['src-address-list'] && !x['dst-address-list']);
    const lastExpiredIdx = fwd.map((x, i) =>
      String(x['src-address-list'] || '') === 'rl-expired' ? i : -1)
      .reduce((a, b) => Math.max(a, b), -1);
    if (acceptIdx > -1 && lastExpiredIdx > -1 && acceptIdx < lastExpiredIdx) {
      const rule = fwd[acceptIdx];
      const body = { chain: 'forward', action: 'accept', 'connection-state': 'established,related',
                     comment: rule.comment || 'RL-FASTTRACK accept' };
      try {
        await del('/ip/firewall/filter', rule['.id']);
        await put('/ip/firewall/filter', body);
        logger.warn('[router-harden] ' + d.name +
          ' established/related accept was ABOVE the expiry rules (position ' + acceptIdx +
          ' vs ' + lastExpiredIdx + ') — moved to the bottom; expired users could bypass the walled garden');
      } catch (e) { logger.warn('[router-harden] accept-order: ' + e.message); }
    }
  } catch (e) { logger.warn('[router-harden] accept-order: ' + e.message); }

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
  /* RL_PCQ_DROPPED: RouterOS 7.19 rejects 'pcq-upload-default/pcq-download-default' on HOTSPOT
     user profiles (that combined form is PPP-profile syntax) — it failed on every pass and logged
     a warning every 2 minutes. Hotspot speed is enforced by the RADIUS Mikrotik-Rate-Limit reply,
     which is verified working, so pcq on the user profile is unnecessary. Step removed. */

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
      await put('/ip/firewall/filter', Object.assign({}, W, { action:'reject', 'reject-with':'icmp-admin-prohibited', comment:'RL-PPPOE-WALL drop' })); /* RL_WALL_REJECT: reject (not drop) so expired clients fail fast and the OS re-probes -> portal appears quickly */
      logger.info('[router-harden] ' + d.name + ' RL-PPPOE-WALL (scoped) added');
    }
  } catch (e) { logger.warn('[router-harden] wall: ' + e.message); }

  // 6) RL_NOFT_OBSOLETE — RL-PPPOE-NOFT is intentionally NOT created any more.
  //    It existed only to keep the PPPoE pool out of fasttrack. Fasttrack is no longer used
  //    (see RL_NO_FASTTRACK above), so the rule had no purpose — and because it accepted
  //    established,related ABOVE the RL-PPPOE-WALL drops, it let expired customers keep
  //    using already-open connections past expiry. Removing it closes that leak at the
  //    firewall level; expired-enforcer.js remains as defence in depth.
  try {
    const fwN = await get('/ip/firewall/filter');
    for (const x of fwN) {
      if (/RL-PPPOE-NOFT|RL-HOTSPOT-NOFT/.test(String(x.comment || ''))) {
        try { await del('/ip/firewall/filter', x['.id']); logger.info('[router-harden] ' + d.name + ' removed obsolete ' + x.comment); } catch (e) {}
      }
    }
  } catch (e) { logger.warn('[router-harden] noft-cleanup: ' + e.message); }



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
    if (/mac-cookie/.test(lb) || /http-chap/.test(lb) || !/(^|,)mac(,|$)/.test(lb)) {
      /* RL_PAP_ONLY: strip http-chap too — the captive page submits a PLAINTEXT password via
         /login?username=..&password=.., which a CHAP-enabled servlet rejects before contacting RADIUS. */
      const cleaned = lb.split(',').filter(x => x && x !== 'mac-cookie' && x !== 'http-chap');
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
