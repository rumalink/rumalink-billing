// utils/walledGarden.js — move a PPPoE subscriber between full service and the rl-expired walled garden.
const { query } = require('../config/database');
const coa = require('./coa');
const mikrotik = require('./mikrotik');
const logger = require('./logger');

const EXPIRED_PROFILE = 'rl-expired';

// Resolve the device for a subscriber: explicit nas_id, else first device for the ISP.
async function resolveDeviceId(sub) {
  if (sub.nas_id) return sub.nas_id;
  if (sub.isp_id) {
    const d = await query(`SELECT id FROM nas_devices WHERE isp_id=$1::uuid ORDER BY created_at ASC LIMIT 1`, [sub.isp_id]);
    if (d.rows[0]) return d.rows[0].id;
  }
  return null;
}

// Bounce a PPPoE session so a new RADIUS profile applies immediately.
// Primary: REST API /ppp/active remove (reliable over WG). Fallback: CoA disconnect.
async function bounce(deviceId, username) {
  if (!deviceId) return { ok: false, error: 'no device' };
  try {
    const r = await mikrotik.disconnectPppoe(deviceId, username);
    if (r && r.ok) return { ok: true, via: 'api', removed: r.removed };
    // If API found no active session, that's fine (applies on next connect).
    if (r && r.removed === 0) return { ok: true, via: 'api', removed: 0 };
  } catch (e) { logger.warn(`[WG] api bounce ${username}: ${e.message}`); }
  // Fallback: CoA (best-effort).
  try { const c = await coa.sendDisconnect(deviceId, username); return { ok: !!(c && c.ok), via: 'coa' }; }
  catch (e) { return { ok: false, error: e.message }; }
}

// RL_RESTRICT_IP: add a subscriber's CURRENT session IP to the rl-expired address-list on the router,
// so walling applies immediately even to an already-connected user (who never re-auths into rl-expired).
async function listExpiredIp(sub, add) {
  try {
    const axios = require('axios');
    const deviceId = await resolveDeviceId(sub);
    const dev = (await query(`SELECT wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE id=$1::uuid LIMIT 1`, [deviceId])).rows[0];
    if (!dev) return { ok:false, note:'no device' };
    const auth = { username:dev.mikrotik_api_user, password:dev.mikrotik_api_password }; const b='http://'+dev.wireguard_ip+'/rest';
    const act = (await axios.get(b+'/ppp/active?name='+encodeURIComponent(sub.username),{auth,timeout:8000}).catch(function(){return {data:[]};})).data||[];
    const ip = act[0] && act[0].address;
    const existing = (await axios.get(b+'/ip/firewall/address-list',{auth,timeout:8000}).catch(function(){return {data:[]};})).data||[];
    if (add) {
      if (!ip) return { ok:false, note:'no active ip' };
      const already = existing.find(function(a){ return a.list==='rl-expired' && String(a.address).split('/')[0]===ip; });
      if (!already) { await axios.put(b+'/ip/firewall/address-list',{ list:'rl-expired', address:ip, comment:'RL-EXPIRED '+sub.username },{auth,timeout:8000}); }
      logger.info('[WG] listExpiredIp ADD '+sub.username+' '+ip);
      return { ok:true, ip:ip };
    } else {
      // remove ALL rl-expired entries tagged for this user (by comment) or matching current ip
      for (const a of existing) {
        if (a.list==='rl-expired' && (String(a.comment||'').indexOf(sub.username)>=0 || (ip && String(a.address).split('/')[0]===ip))) {
          try { await axios.delete(b+'/ip/firewall/address-list/'+encodeURIComponent(a['.id']),{auth,timeout:8000}); } catch(e){}
        }
      }
      logger.info('[WG] listExpiredIp REMOVE '+sub.username);
      return { ok:true };
    }
  } catch (e) { logger.warn('[WG] listExpiredIp '+sub.username+': '+e.message); return { ok:false, error:e.message }; }
}

async function setGroup(username, groupValue) {
  const existing = await query(`SELECT id FROM radreply WHERE username=$1 AND attribute='Mikrotik-Group' LIMIT 1`, [username]);
  if (existing.rows[0]) await query(`UPDATE radreply SET value=$2, op='=' WHERE username=$1 AND attribute='Mikrotik-Group'`, [username, groupValue]);
  else await query(`INSERT INTO radreply (username, attribute, op, value) VALUES ($1,'Mikrotik-Group', ':=',$2)`, [username, groupValue]);
}

// Restrict: drop into the walled garden (still online, only the pay page reachable).
async function restrict(sub) {
  try {
    await query(`DELETE FROM radcheck WHERE username=$1 AND attribute='Auth-Type' AND value='Reject'`, [sub.username]).catch(() => {});
    await setGroup(sub.username, EXPIRED_PROFILE);
    await query(`UPDATE pppoe_subscribers SET status='expired', updated_at=NOW() WHERE id=$1`, [sub.id]);
    /* RL_NO_STATIC_EXPIRED: this added the subscriber's live address to rl-expired by hand. The
       rl-expired PPP profile already carries address-list=rl-expired, so MikroTik adds that
       address itself on connect and REMOVES it on disconnect — its entry is dynamic and owned by
       the session. The manual copy was static: nothing owned it, so it survived the disconnect and
       the pool handed the address to the next customer, who inherited the block. Orpha lost
       service to Irene's leftover this way.
       The bounce below forces re-authentication into rl-expired within seconds, and the profile
       creates the correct entry. Adding one here bought nothing and left litter behind. */
    /* (static add removed — the rl-expired profile manages the address list) */
    const deviceId = await resolveDeviceId(sub);
    const b = await bounce(deviceId, sub.username);
    logger.info(`[WG] restrict ${sub.username} -> ${EXPIRED_PROFILE} (bounce ${b.via||'none'} ok=${b.ok})`);
    return { ok: true, bounce: b };
  } catch (e) { logger.error(`[WG] restrict failed ${sub.username}: ${e.message}`); return { ok: false, error: e.message }; }
}

// Restore: back to full service (package profile) after payment.
async function restore(sub, packageProfile) {
  try {
    await query(`DELETE FROM radcheck WHERE username=$1 AND attribute='Auth-Type' AND value='Reject'`, [sub.username]).catch(() => {});
    if (packageProfile) await setGroup(sub.username, packageProfile);
    else await query(`DELETE FROM radreply WHERE username=$1 AND attribute='Mikrotik-Group'`, [sub.username]).catch(() => {});
    await query(`UPDATE pppoe_subscribers SET status='active', updated_at=NOW() WHERE id=$1`, [sub.id]);
    await listExpiredIp(sub, false); /* RL_RESTRICT_IP: unlist on restore */
    /* RL_RESTORE_RATE: always (re)apply the package rate-limit so a renewed subscriber is speed-capped.
       Previously only set on a package-switch, so same-package renewals ran unlimited. */
    try {
      const pk = await query(
        `SELECT pp.bandwidth_down_mbps AS down, pp.bandwidth_up_mbps AS up
           FROM pppoe_subscribers ps JOIN pppoe_packages pp ON pp.id = ps.package_id
          WHERE ps.id = $1 LIMIT 1`, [sub.id]);
      const row = pk.rows[0];
      if (row && (row.down || row.up)) {
        const rate = (row.up || row.down) + 'M/' + (row.down || row.up) + 'M';
        await query(`DELETE FROM radreply WHERE username=$1 AND attribute='Mikrotik-Rate-Limit'`, [sub.username]).catch(() => {});
        await query(`INSERT INTO radreply (username, attribute, op, value) VALUES ($1,'Mikrotik-Rate-Limit', ':=',$2)`, [sub.username, rate]).catch(() => {});
        logger.info(`[WG] restore rate ${sub.username} -> ${rate}`);
      }
    } catch (e) { logger.warn(`[WG] restore rate ${sub.username}: ${e.message}`); }
    const deviceId = await resolveDeviceId(sub);
    const b = await bounce(deviceId, sub.username);
    logger.info(`[WG] restore ${sub.username} -> ${packageProfile || 'default'} (bounce ${b.via||'none'} ok=${b.ok})`);
    /* RL_QUEUE_RATE: after the bounce, give the session a moment then queue its IP so speed applies now */
    setTimeout(function(){ applyQueueRate(sub).catch(function(){}); }, 6000);
    return { ok: true, bounce: b };
  } catch (e) { logger.error(`[WG] restore failed ${sub.username}: ${e.message}`); return { ok: false, error: e.message }; }
}

// RL_QUEUE_RATE: apply a simple queue on the router for a subscriber's live IP so the package
// rate takes effect immediately (PPPoE RADIUS rate-limit only applies on a full re-auth, which a
// WiFi off/on does not force). Queue is keyed by the active session address.
async function applyQueueRate(sub) {
  try {
    const mikrotik = require('./mikrotik');
    const axios = require('axios');
    const pk = await query(`SELECT pp.bandwidth_down_mbps AS down, pp.bandwidth_up_mbps AS up FROM pppoe_subscribers ps JOIN pppoe_packages pp ON pp.id=ps.package_id WHERE ps.id=$1 LIMIT 1`, [sub.id]);
    const row = pk.rows[0]; if (!row || !(row.down||row.up)) return { ok:false, note:'no rate' };
    const deviceId = await resolveDeviceId(sub);
    const dev = await query(`SELECT wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE id=$1::uuid LIMIT 1`, [deviceId]);
    const d = dev.rows[0]; if (!d) return { ok:false, note:'no device' };
    const auth = { username:d.mikrotik_api_user, password:d.mikrotik_api_password }; const b='http://'+d.wireguard_ip+'/rest';
    // find the subscriber's live IP
    const act = (await axios.get(b+'/ppp/active?name='+encodeURIComponent(sub.username),{auth,timeout:8000}).catch(function(){return {data:[]};})).data||[];
    const ip = act[0] && act[0].address; if (!ip) return { ok:false, note:'no active session' };
    const maxLimit = (row.up||row.down)+'M/'+(row.down||row.up)+'M';
    const qname = 'rl-pppoe-'+sub.username;
    const existing = (await axios.get(b+'/queue/simple',{auth,timeout:8000}).catch(function(){return {data:[]};})).data||[];
    const found = existing.find(function(q){ return q.name===qname; });
    const body = { name:qname, target:ip+'/32', 'max-limit':maxLimit, comment:'RL-PPPOE-RATE' };
    if (found) { await axios.patch(b+'/queue/simple/'+encodeURIComponent(found['.id']), body, {auth,timeout:8000}); }
    else { await axios.put(b+'/queue/simple', body, {auth,timeout:8000}); }
    logger.info('[WG] queue rate '+sub.username+' -> '+maxLimit+' @ '+ip);
    return { ok:true, rate:maxLimit, ip:ip };
  } catch (e) { logger.warn('[WG] applyQueueRate '+sub.username+': '+e.message); return { ok:false, error:e.message }; }
}

module.exports = { restrict, restore, setGroup, resolveDeviceId, bounce, applyQueueRate, listExpiredIp, EXPIRED_PROFILE }; /* RL_QUEUE_RATE */
