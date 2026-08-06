#!/usr/bin/env bash
#
# fix_pppoe_walled_garden.sh — a paying customer is walled off by someone else's expiry.
#
# FOUND: rl-expired holds 100.64.0.232 tagged "RL-EXPIRED irene". That address now belongs to
# ORPHA, who is paid and connected. Irene expired, her IP was listed, she disconnected, and the
# pool handed the same address to the next customer — who inherited the block. "Connected but
# asked to pay" is precisely this.
#
# The flaw is restricting by IP when PPPoE addresses are recycled from a shared pool: the entry
# outlives the session it describes. Fixing the stale row is not enough, because the same
# collision will happen every time an expired subscriber disconnects.
#
# ALSO: daniel2 and mikrotiktest2 have no radcheck entry at all — imported subscribers with no
# password can never authenticate, which is the Access-Reject loop in the RADIUS log.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Who is wrongly walled right now"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
 const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
 const act=(await axios.get(b+'/ppp/active',{auth,timeout:15000})).data||[];
 const al=(await axios.get(b+'/ip/firewall/address-list',{auth,timeout:15000})).data||[];
 const byIp={}; act.forEach(a=>byIp[a.address]=a.name);
 for (const e of al.filter(x=>String(x.list)==='rl-expired')) {
   const ip=String(e.address).split('/')[0];
   const tagged=(String(e.comment||'').replace('RL-EXPIRED','')||'').trim();
   const now=byIp[ip]||'(nobody)';
   const wrong = now !== '(nobody)' && tagged && now.toLowerCase() !== tagged.toLowerCase();
   console.log('   '+ip+'  listed for ['+tagged+']  currently used by ['+now+']'+(wrong?'   <-- WRONGLY BLOCKED':''));
 }
 process.exit(0);
})();" 2>&1 | grep -v "^info:"

say "2) Free anyone blocked by a recycled address"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
 const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
 const act=(await axios.get(b+'/ppp/active',{auth,timeout:15000})).data||[];
 const al=(await axios.get(b+'/ip/firewall/address-list',{auth,timeout:15000})).data||[];
 const byIp={}; act.forEach(a=>byIp[a.address]=a.name);
 let freed=0;
 for (const e of al.filter(x=>String(x.list)==='rl-expired')) {
   const ip=String(e.address).split('/')[0];
   const tagged=(String(e.comment||'').replace('RL-EXPIRED','')||'').trim();
   const now=byIp[ip];
   if (now && tagged && now.toLowerCase() !== tagged.toLowerCase()) {
     await axios.delete(b+'/ip/firewall/address-list/'+encodeURIComponent(e['.id']),{auth,timeout:15000});
     console.log('   freed '+now+' (was blocked by '+tagged+\"'s old address \"+ip+')');
     freed++;
   }
 }
 console.log('   '+freed+' customer(s) freed');
 process.exit(0);
})();" 2>&1 | grep -v "^info:"

say "3) Stop it recurring — reconcile the list every minute"
sudo tee "$BE/utils/wg-reconcile.js" > /dev/null <<'JS'
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
JS
sudo chown www-data:www-data "$BE/utils/wg-reconcile.js"
sudo -u www-data node --check "$BE/utils/wg-reconcile.js" && echo "   wg-reconcile.js OK"
sudo cp "$BE/utils/cron.js" "$BE/utils/.cron.js.bak_$TS"
if sudo grep -q "wg-reconcile" "$BE/utils/cron.js"; then echo "   already registered"
else echo "try { require('./wg-reconcile').start(); } catch (e) { require('./logger').warn('[wg-reconcile] start: ' + e.message); }" | sudo tee -a "$BE/utils/cron.js" >/dev/null; echo "   registered"; fi
sudo -u www-data node --check "$BE/utils/cron.js" && echo "   cron.js OK"

say "4) Imported subscribers with no password"
q -c "SELECT s.username, s.status,
             (SELECT count(*) FROM radcheck rc WHERE rc.username = s.username) AS radcheck
      FROM pppoe_subscribers s
      WHERE NOT EXISTS (SELECT 1 FROM radcheck rc WHERE rc.username = s.username AND rc.attribute='Cleartext-Password')
      ORDER BY s.username;"
echo "   ${Y}these can never authenticate — they need credentials published${N}"

say "5) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 25 --nostream 2>/dev/null | grep -iE "wg-reconcile|error" | tail -4 | sed 's/^/   /'

say "6) Next"
cat <<'EOS'
   Ask orpha to reload — she should have service without reconnecting.
   Still to address, once you confirm this:
     - subscribers listed in section 4 have no RADIUS password
     - slow reconnection after payment (the unrestrict likely waits for a cron)
     - the pay page not appearing until the customer toggles their connection
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "PPPoE: clear walled-garden blocks left on recycled addresses (a paid customer inherited an expired one's IP)" 2>&1 | head -2 | sed 's/^/   /'
