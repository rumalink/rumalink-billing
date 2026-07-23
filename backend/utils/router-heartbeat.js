// utils/router-heartbeat.js — RL_ACTIVE_HEARTBEAT
// Every minute, actively probe each device over WireGuard. If it answers, mark is_online=true + last_seen=NOW().
// This makes is_online reflect ACTUAL reachability, not just whether the router happened to POST in.
// Fixes: after a reboot/re-add, reconcilers (harden, walling, strand-heal) no longer skip a live router.
const { query } = require('../config/database');
const logger = require('./logger');
const axios = require('axios');

async function pass() {
  let devs;
  try { devs = (await query("SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL")).rows; }
  catch (e) { logger.warn('[heartbeat] list: ' + e.message); return; }
  for (const d of devs) {
    let up = false;
    try {
      await axios.get('http://' + d.wireguard_ip + '/rest/system/resource',
        { auth: { username: d.mikrotik_api_user, password: d.mikrotik_api_password }, timeout: 6000 });
      up = true;
    } catch (e) { up = false; }
    try {
      if (up) {
        await query("UPDATE nas_devices SET is_online=true, last_seen=NOW(), updated_at=NOW() WHERE id=$1::uuid", [d.id]);
      }
      // note: we do NOT force is_online=false here — the existing cron handles stale-marking after 5 min,
      // but since we refresh last_seen every minute for reachable routers, a truly-down router ages out correctly.
    } catch (e) { logger.warn('[heartbeat] update ' + d.name + ': ' + e.message); }
  }
}

function start() {
  setInterval(function () { pass().catch(function (e) { logger.warn('[heartbeat] ' + e.message); }); }, 60000);
  setTimeout(function () { pass().catch(function () {}); }, 5000);
  logger.info('[heartbeat] active reachability heartbeat started (60s)');
}

module.exports = { start: start, pass: pass };
