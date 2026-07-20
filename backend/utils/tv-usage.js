// RL_TV_USAGE_HELPER: read bypass-TV live status + usage from the router (queue counters + hotspot host),
// because bypass-bound TVs never authenticate via RADIUS and thus have NO radacct records.
const axios = require('axios');
const { query } = require('../config/database');

function macNoColons(m){ return String(m||'').replace(/:/g,'').toUpperCase(); }

// Returns { online, bytes_in, bytes_out, ip } for one TV MAC on the ISP's router(s).
async function tvRouterStats(ispId, mac) {
  const out = { online:false, bytes_in:0, bytes_out:0, ip:null };
  let nasRows;
  try {
    nasRows = (await query("SELECT id, wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE isp_id=$1::uuid AND wireguard_ip IS NOT NULL", [ispId])).rows;
  } catch(e){ return out; }
  const macCF = macNoColons(mac);
  for (const nas of (nasRows||[])) {
    if (!nas.wireguard_ip || !nas.mikrotik_api_user) continue;
    const api = axios.create({ baseURL:'http://'+nas.wireguard_ip+'/rest', timeout:4000, auth:{username:nas.mikrotik_api_user,password:nas.mikrotik_api_password}, validateStatus:()=>true });
    // queue byte counters (authoritative for total usage)
    try {
      const r = await api.get('/queue/simple');
      if (r.status===200 && Array.isArray(r.data)) {
        const q = r.data.find(x => macNoColons((x.name||'').replace('rl-tv-','')) === macCF || String(x.name||'')==='rl-tv-'+macCF);
        if (q && q.bytes) {
          /* RL_TV_UD_FIX: queue bytes = 'upload/download'. bytes_in=UPLOAD, bytes_out=DOWNLOAD,
             to match user.html which treats input as ↑upload and output as ↓download. */
          const parts = String(q.bytes).split('/');
          out.bytes_in  = Number(parts[0]||0); // upload (from client) -> ↑ (small for a TV)
          out.bytes_out = Number(parts[1]||0); // download (to client) -> ↓ (big for a TV)
        }
      }
    } catch(e){}
    // hotspot host: presence + idle-time for live status + current ip
    try {
      const h = await api.get('/ip/hotspot/host');
      if (h.status===200 && Array.isArray(h.data)) {
        const host = h.data.find(x => macNoColons(x['mac-address']) === macCF);
        if (host) {
          out.ip = host.address || out.ip;
          /* RL_TV_ONLINE_V2: a bypassed TV host is 'online' when idle-time is short (seconds, or
             under 5 minutes). RouterOS idle-time format: '5s', '2m30s', '1h2m', '3d4h'. */
          const idle = String(host['idle-time']||'').trim();
          let online = host['bypassed'] === true || host['bypassed'] === 'true' || !!host.address;
          if (/[hdw]/.test(idle)) online = false;
          else { const mm = idle.match(/(\d+)\s*m/); if (mm && Number(mm[1]) >= 5) online = false; }
          out.online = online;
          if (host['bytes-in'] || host['bytes-out']) {
            // prefer host counters if queue gave nothing
            if (!out.bytes_in && !out.bytes_out) { out.bytes_in = Number(host['bytes-in']||0); out.bytes_out = Number(host['bytes-out']||0); } /* RL_TV_UD_FIX: in=upload, out=download */
          }
        }
      }
    } catch(e){}
        if (out.online || out.bytes_in || out.bytes_out) break; // found on this router
  }
  return out;
}

module.exports = { tvRouterStats, macNoColons };
