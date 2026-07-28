// RL_TV_RECONCILE: TV bindings/queues are ROUTER state — destroyed by re-provisioning or router
// replacement. This reconciler enforces desired state every 60s on whatever router is current:
//   1) ip-binding bypass exists for every bound, non-expired TV
//   2) the rl-tv queue exists at the package rate (rate limit can never silently vanish again)
//   3) usage accumulates durably in the DB (baseline + counter deltas) so expiry/re-provision
//      never resets a TV's data history
//   4) any hotspot session using a TV's voucher from a NON-TV MAC is disconnected (phone lockout)
const axios = require('axios');
const { query } = require('../config/database');
const mt = require('./mikrotik');
const logger = require('./logger');
let started = false;

async function passCore() {
  const tvs = await query(
    "SELECT bd.*, hp.bandwidth_down_mbps, hp.bandwidth_up_mbps FROM hotspot_bound_devices bd " +
    "LEFT JOIN hotspot_packages hp ON hp.id=bd.package_id " +
    "WHERE bd.is_bound=true AND bd.expires_at IS NOT NULL AND bd.expires_at > NOW()");
  for (const tv of tvs.rows) {
    try {
      const dev = (await query(
        "SELECT id FROM nas_devices WHERE isp_id=$1::uuid AND wireguard_ip IS NOT NULL ORDER BY last_seen DESC NULLS LAST LIMIT 1",
        [tv.isp_id])).rows[0];
      if (!dev) continue;
      // 1) binding (idempotent)
      try { await mt.addIpBindingBypass(dev.id, { mac_address: tv.mac_address, comment: 'RumaLink-TV ' + tv.mac_address }); } catch (e) {}
      // 2) queue at package rate
      let ip = null;
      try { ip = await mt.findIpForMac(dev.id, tv.mac_address); } catch (e) {}
      if (ip && ip !== tv.bound_ip) await query("UPDATE hotspot_bound_devices SET bound_ip=$1 WHERE id=$2::uuid", [ip, tv.id]).catch(()=>{});
      const cap = ((tv.bandwidth_up_mbps || tv.bandwidth_down_mbps || 0) + 'M/' + (tv.bandwidth_down_mbps || 0) + 'M');
      if (ip && cap !== '0M/0M') {
        try { await mt.applyQueueRateLimit(dev.id, { username: 'tv-' + String(tv.mac_address).replace(/:/g, ''), ip, max_limit: cap }); } catch (e) {}
      }
      // 3) durable usage accumulation
      try {
        const tvu = require('./tv-usage');
        const rs = await tvu.tvRouterStats(tv.isp_id, tv.mac_address);
        const curIn = Number(rs.bytes_in || 0), curOut = Number(rs.bytes_out || 0);
        let baseIn = Number(tv.usage_base_in || 0), baseOut = Number(tv.usage_base_out || 0);
        const lastIn = Number(tv.last_ctr_in || 0), lastOut = Number(tv.last_ctr_out || 0);
        if (curIn < lastIn || curOut < lastOut) { baseIn += lastIn; baseOut += lastOut; } // counter reset -> bank it
        await query("UPDATE hotspot_bound_devices SET usage_base_in=$1, usage_base_out=$2, last_ctr_in=$3, last_ctr_out=$4 WHERE id=$5::uuid",
          [baseIn, baseOut, curIn, curOut, tv.id]);
      } catch (e) {}
      /* RL_TV_FOLLOW_VOUCHER: the TV mirrors its voucher. Voucher deleted -> unbind the TV
         (binding+queue removed, expired). Voucher expiry edited -> TV expiry follows. */
      if (tv.active_voucher_id) {
        try {
          const vv = (await query("SELECT id, status, expires_at FROM hotspot_vouchers WHERE id=$1::uuid", [tv.active_voucher_id])).rows[0];
          /* RL_TV_SINGLE_OWNER: record the decision, do not touch the router here. Writing the
             binding directly made this a second writer alongside convergeTvBindings(), and two
             writers with separately maintained conditions is what made the binding flap. */
          const unbind = async () => {
            await query("UPDATE hotspot_bound_devices SET is_bound=false, expires_at=NOW() WHERE id=$1::uuid", [tv.id]).catch(()=>{});
            logger.info('[tv-reconcile] TV ' + tv.name + ' marked unbound (voucher gone/expired) — router converges next');
          };
          if (!vv) { await unbind(); continue; }
          if (String(vv.status||'') === 'expired' || (vv.expires_at && new Date(vv.expires_at) <= new Date())) { await unbind(); continue; }
          if (vv.expires_at && tv.expires_at && Math.abs(new Date(vv.expires_at) - new Date(tv.expires_at)) > 60000) {
            await query("UPDATE hotspot_bound_devices SET expires_at=$1 WHERE id=$2::uuid", [vv.expires_at, tv.id]).catch(()=>{});
            logger.info('[tv-reconcile] TV ' + tv.name + ' expiry synced to voucher edit');
          }
        } catch(e) {}
      }
      // 4) phone lockout: TV voucher must serve ONLY the TV's MAC
      if (tv.active_voucher_id) {
        try {
          const v = (await query("SELECT code FROM hotspot_vouchers WHERE id=$1::uuid", [tv.active_voucher_id])).rows[0];
          if (v && v.code) {
            const live = await mt.liveHotspotSessions(dev.id);
            for (const s of (Array.isArray(live) ? live : [])) {
              const su = String(s.user || s.username || '').split('@')[0];
              const sm = String(s['mac-address'] || s.mac_address || '').toUpperCase();
              if (su === v.code && sm && sm !== String(tv.mac_address).toUpperCase()) {
                try { await mt.disconnectHotspotSession(dev.id, s); } catch (e1) {
                  try { await mt.disconnectHotspotSession(dev.id, s['.id']); } catch (e2) {}
                }
                logger.info('[tv-reconcile] disconnected NON-TV device ' + sm + ' using TV voucher ' + v.code + ' (TV-only access enforced)');
              }
            }
          }
        } catch (e) {}
      }
    } catch (e) { logger.warn('[tv-reconcile] ' + (e && e.message)); }
  }
}

function start() {
  if (started) return; started = true;
  setInterval(() => pass().catch(e => logger.warn('[tv-reconcile] pass: ' + e.message)), 60 * 1000);
  setTimeout(() => pass().catch(()=>{}), 8000); // first pass shortly after boot
  logger.info('[tv-reconcile] Registered (every 60s) — TV binding/queue/usage/lockout self-healing');
}
// RL_TV_FAST: activate ONE TV immediately after purchase (binding + queue), with short retries
// because the TV's IP may not be in the lease table for a second or two after it connects.
async function applyOne(ispId, mac, attempts) {
  const tries = attempts || 6;
  for (let i = 0; i < tries; i++) {
    try {
      const tv = (await query(
        "SELECT bd.*, hp.bandwidth_down_mbps, hp.bandwidth_up_mbps FROM hotspot_bound_devices bd " +
        "LEFT JOIN hotspot_packages hp ON hp.id=bd.package_id " +
        "WHERE bd.isp_id=$1::uuid AND UPPER(bd.mac_address)=UPPER($2) LIMIT 1", [ispId, mac])).rows[0];
      if (!tv) return { ok:false, note:'no bound device row' };
      const dev = (await query(
        "SELECT id FROM nas_devices WHERE isp_id=$1::uuid AND wireguard_ip IS NOT NULL ORDER BY last_seen DESC NULLS LAST LIMIT 1",
        [tv.isp_id])).rows[0];
      if (!dev) return { ok:false, note:'no device' };
      // 1) binding first — this is what lets the TV bypass the login page (the part that must be instant)
      try { await mt.addIpBindingBypass(dev.id, { mac_address: tv.mac_address, comment: 'RumaLink-TV ' + tv.mac_address }); } catch (e) {}
      // 2) queue once we can resolve the IP
      let ip = null;
      try { ip = await mt.findIpForMac(dev.id, tv.mac_address); } catch (e) {}
      if (ip) {
        if (ip !== tv.bound_ip) await query("UPDATE hotspot_bound_devices SET bound_ip=$1 WHERE id=$2::uuid", [ip, tv.id]).catch(function(){});
        const cap = ((tv.bandwidth_up_mbps || tv.bandwidth_down_mbps || 0) + 'M/' + (tv.bandwidth_down_mbps || 0) + 'M');
        if (cap !== '0M/0M') {
          try { await mt.applyQueueRateLimit(dev.id, { username: 'tv-' + String(tv.mac_address).replace(/:/g, ''), ip: ip, max_limit: cap }); } catch (e) {}
        }
        logger.info('[tv-reconcile] FAST activate ' + mac + ' bound+queued @ ' + ip + ' (try ' + (i+1) + ')');
        return { ok:true, ip:ip };
      }
      // binding is done; IP not yet known -> wait briefly and retry the queue
      await new Promise(function(r){ setTimeout(r, 2500); });
    } catch (e) { logger.warn('[tv-reconcile] applyOne ' + mac + ': ' + e.message); return { ok:false, error:e.message }; }
  }
  logger.info('[tv-reconcile] FAST activate ' + mac + ' bound (queue deferred to next pass — no IP yet)');
  return { ok:true, note:'bound, queue deferred' };
}


/* RL_TV_SINGLE_OWNER: the one place that decides what the router should hold for TVs.
   Desired state comes from the database; anything WE previously created and no longer want is
   withdrawn. Only entries carrying our own comment are touched — a binding an ISP added by hand
   for a printer or a camera is never removed by us. */
async function convergeTvBindings() {
  const devs = (await query(
    "SELECT id, isp_id, wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices " +
    "WHERE wireguard_ip IS NOT NULL AND is_online = true")).rows;

  for (const dev of devs) {
    try {
      const want = await query(
        "SELECT UPPER(mac_address) AS mac FROM hotspot_bound_devices " +
        "WHERE isp_id = $1::uuid AND is_bound = true AND expires_at IS NOT NULL AND expires_at > NOW()",
        [dev.isp_id]);
      const wanted = want.rows.map(function (r) { return r.mac; });
      const auth = { username: dev.mikrotik_api_user, password: dev.mikrotik_api_password };
      const base = 'http://' + dev.wireguard_ip + '/rest';

      let binds = [], queues = [];
      try { binds = (await axios.get(base + '/ip/hotspot/ip-binding', { auth, timeout: 8000 })).data || []; } catch (e) { continue; }
      try { queues = (await axios.get(base + '/queue/simple', { auth, timeout: 8000 })).data || []; } catch (e) {}

      for (const b of binds) {
        const mac = String(b['mac-address'] || '').toUpperCase();
        if (!mac || !/RumaLink-TV/i.test(String(b.comment || ''))) continue;
        if (wanted.indexOf(mac) >= 0) continue;
        try {
          await axios.delete(base + '/ip/hotspot/ip-binding/' + encodeURIComponent(b['.id']), { auth, timeout: 8000 });
          logger.info('[tv-reconcile] withdrew binding ' + mac + ' (no longer entitled)');
        } catch (e) {}
      }

      const wantedNc = wanted.map(function (m) { return m.replace(/:/g, ''); });
      for (const q of queues) {
        const name = String(q.name || '');
        if (!/^(rl-)?tv-/i.test(name)) continue;
        const macNc = name.replace(/^rl-tv-/i, '').replace(/^tv-/i, '').toUpperCase();
        if (wantedNc.indexOf(macNc) >= 0) continue;
        try {
          await axios.delete(base + '/queue/simple/' + encodeURIComponent(q['.id']), { auth, timeout: 8000 });
          logger.info('[tv-reconcile] withdrew TV queue ' + name);
        } catch (e) {}
      }
    } catch (e) { logger.warn('[tv-reconcile] converge: ' + e.message); }
  }
}

/* Wrapping rather than editing inside passCore(): every existing caller — the 60s interval, the
   module exports, strand-heal's post-change trigger — picks this up with no further changes. */
async function pass() {
  await passCore();
  try { await convergeTvBindings(); } catch (e) { logger.warn('[tv-reconcile] converge: ' + e.message); }
}

module.exports = { start, pass, applyOne }; /* RL_TV_FAST */
