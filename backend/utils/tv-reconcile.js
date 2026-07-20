// RL_TV_RECONCILE: TV bindings/queues are ROUTER state — destroyed by re-provisioning or router
// replacement. This reconciler enforces desired state every 60s on whatever router is current:
//   1) ip-binding bypass exists for every bound, non-expired TV
//   2) the rl-tv queue exists at the package rate (rate limit can never silently vanish again)
//   3) usage accumulates durably in the DB (baseline + counter deltas) so expiry/re-provision
//      never resets a TV's data history
//   4) any hotspot session using a TV's voucher from a NON-TV MAC is disconnected (phone lockout)
const { query } = require('../config/database');
const mt = require('./mikrotik');
const logger = require('./logger');
let started = false;

async function pass() {
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
          const unbind = async () => {
            try { await mt.removeIpBinding(dev.id, tv.mac_address); } catch(e){}
            const qn = 'tv-' + String(tv.mac_address).replace(/:/g,'');
            try { await mt.removeQueueRateLimit(dev.id, { username: qn }); } catch(e1){ try { await mt.removeQueueRateLimit(dev.id, qn); } catch(e2){} }
            await query("UPDATE hotspot_bound_devices SET is_bound=false, expires_at=NOW() WHERE id=$1::uuid", [tv.id]).catch(()=>{});
            logger.info('[tv-reconcile] TV ' + tv.name + ' unbound (voucher deleted/expired)');
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
module.exports = { start, pass };
