// RL_WG_RECONCILE — the rl-expired list holds IP ADDRESSES, and PPPoE addresses are recycled.
//
// When an expired subscriber disconnects, the pool hands their address to the next customer, who
// inherits the block: connected, paying, and shown the pay page. Orpha was blocked by Irene's old
// address this way. The entry describes a session that no longer exists.
//
// Every minute: for each rl-expired entry, ask who holds that address NOW. If it is someone else,
// or nobody, or the tagged subscriber is no longer expired, drop the entry. Errs towards removing
// a block, because wrongly restricting a paying customer is worse than briefly failing to
// restrict an expired one — the expiry sweep re-adds it within the minute either way.
const axios = require('axios');
const { query } = require('../config/database');
const logger = require('./logger');

async function pass() {
  let devs = [];
  try {
    devs = (await query(
      'SELECT id, name, isp_id, wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL AND is_online = true')).rows;
  } catch (e) { return; }

  for (const dev of devs) {
    const b = 'http://' + dev.wireguard_ip + '/rest';
    const auth = { username: dev.mikrotik_api_user, password: dev.mikrotik_api_password };
    try {
      const act = (await axios.get(b + '/ppp/active', { auth, timeout: 8000 })).data || [];
      const al  = (await axios.get(b + '/ip/firewall/address-list', { auth, timeout: 8000 })).data || [];
      const holder = {};
      act.forEach(a => { if (a.address) holder[String(a.address)] = String(a.name || ''); });

      for (const e of al.filter(x => String(x.list) === 'rl-expired')) {
        const ip = String(e.address || '').split('/')[0];
        const tagged = String(e.comment || '').replace('RL-EXPIRED', '').trim();
        if (!tagged) continue;                    // untagged entries are not ours to judge
        const now = holder[ip];

        let drop = null;
        if (now && now.toLowerCase() !== tagged.toLowerCase()) {
          drop = 'address now held by ' + now;
        } else if (!now) {
          drop = 'nobody holds this address';
        } else {
          const s = (await query(
            "SELECT status, next_billing_date FROM pppoe_subscribers WHERE lower(username) = lower($1) LIMIT 1",
            [tagged])).rows[0];
          if (s && s.next_billing_date && new Date(s.next_billing_date) > new Date() && String(s.status) !== 'expired') {
            drop = tagged + ' has paid';
          }
        }

        if (drop) {
          await axios.delete(b + '/ip/firewall/address-list/' + encodeURIComponent(e['.id']), { auth, timeout: 8000 }).catch(() => {});
          logger.info('[wg-reconcile] ' + dev.name + ': removed rl-expired ' + ip + ' (' + drop + ')');
        }
      }
    } catch (e) { logger.warn('[wg-reconcile] ' + dev.name + ': ' + e.message); }
  }
}

function start() {
  setTimeout(function () { pass().catch(function () {}); }, 20000);
  setInterval(function () { pass().catch(function () {}); }, 60000);
  logger.info('[wg-reconcile] Registered (every 60s) — clears blocks left on recycled PPPoE addresses');
}

module.exports = { start, pass };
