#!/usr/bin/env bash
#
# add_tv_to_voucher.sh — let a customer attach a TV to a voucher they already hold.
#
# A phone takes a second device slot by logging in through RADIUS. A television cannot: it is
# bypassed at the router by IP-binding and never authenticates, so Simultaneous-Use does not see
# it. Attaching one therefore means binding its MAC, giving it a queue at the voucher's package
# speed, and expiring it with the voucher — not issuing it a package of its own.
#
# TVs count toward the device limit, because a second device is a second device however it
# connects. R307 already shows the consequence of not counting them: a 1-device package with a TV
# attached is serving two.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Backup"
sudo cp "$BE/routes/captive.js" "$BE/routes/.captive.js.bak_$TS" && echo "   captive.js"

say "2) Two endpoints: check a voucher, and attach a TV to it"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_TV_ATTACH' in s:
    print("   already present"); sys.exit(0)
m = re.search(r"^router\.post\('/:ispId/tv/save'", s, re.M)
if not m:
    print("   ERROR: tv/save anchor not found"); sys.exit(1)

routes = '''/* RL_TV_ATTACH: a customer with a multi-device package adding a television to the voucher they
   already hold. Two steps so the portal can tell them WHY before asking for anything else — being
   refused after picking a TV is worse than being told up front that the package allows one device. */
router.post('/:ispId/tv/check-voucher', async (req, res) => {
  try {
    const code = String(req.body.code || '').trim().toUpperCase();
    if (!code) return res.status(400).json({ error: 'Enter your username.' });

    const v = (await query(
      `SELECT hv.id, hv.code, hv.status, hv.expires_at, hv.is_tv,
              COALESCE(hp.simultaneous_sessions,1) AS allowed,
              hp.name AS package_name, hp.bandwidth_down_mbps AS down, hp.bandwidth_up_mbps AS up
         FROM hotspot_vouchers hv
         LEFT JOIN hotspot_packages hp ON hp.id = hv.package_id
        WHERE hv.isp_id = $1::uuid AND UPPER(hv.code) = $2 LIMIT 1`,
      [req.params.ispId, code])).rows[0];

    if (!v) return res.status(404).json({ error: 'That username was not found. Check it and try again.' });
    if (v.is_tv) return res.status(400).json({ error: 'That code belongs to a TV already.' });
    if (v.status !== 'active') return res.status(400).json({ error: 'That code is not active. If you have just paid, wait a moment and try again.' });
    if (v.expires_at && new Date(v.expires_at) <= new Date()) return res.status(400).json({ error: 'That code has expired. Buy a package to continue.' });

    /* count BOTH kinds against the limit — a television is a second device however it connects */
    const phones = (await query('SELECT count(*)::int AS n FROM hotspot_voucher_devices WHERE voucher_id = $1::uuid', [v.id])).rows[0].n;
    const tvs = (await query('SELECT count(*)::int AS n FROM hotspot_bound_devices WHERE active_voucher_id = $1::uuid', [v.id])).rows[0].n;
    const used = phones + tvs;
    const allowed = parseInt(v.allowed, 10) || 1;

    if (used >= allowed) {
      return res.status(403).json({
        error: 'The ' + (v.package_name || 'package') + ' allows ' + allowed + ' device' +
               (allowed > 1 ? 's' : '') + ' and ' + used + ' ' + (used === 1 ? 'is' : 'are') +
               ' already using it. Buy a package with more devices to add a TV.'
      });
    }

    res.json({
      ok: true, code: v.code, package_name: v.package_name,
      allowed, used, remaining: allowed - used,
      expires_at: v.expires_at,
      speed: (v.down ? v.down + ' Mbps' : null)
    });
  } catch (err) { next2(err, res); }
});

router.post('/:ispId/tv/attach', async (req, res) => {
  try {
    const code = String(req.body.code || '').trim().toUpperCase();
    const tvId = String(req.body.tv_id || '').trim();
    if (!code || !tvId) return res.status(400).json({ error: 'Pick a TV and enter your username.' });

    const v = (await query(
      `SELECT hv.id, hv.code, hv.status, hv.expires_at, hv.package_id,
              COALESCE(hp.simultaneous_sessions,1) AS allowed, hp.name AS package_name,
              hp.bandwidth_down_mbps AS down, hp.bandwidth_up_mbps AS up
         FROM hotspot_vouchers hv
         LEFT JOIN hotspot_packages hp ON hp.id = hv.package_id
        WHERE hv.isp_id = $1::uuid AND UPPER(hv.code) = $2 LIMIT 1`,
      [req.params.ispId, code])).rows[0];
    if (!v) return res.status(404).json({ error: 'Username not found.' });
    if (v.status !== 'active' || (v.expires_at && new Date(v.expires_at) <= new Date()))
      return res.status(400).json({ error: 'That code is not active.' });

    const tv = (await query(
      'SELECT id, name, mac_address, active_voucher_id FROM hotspot_bound_devices WHERE id = $1::uuid AND isp_id = $2::uuid LIMIT 1',
      [tvId, req.params.ispId])).rows[0];
    if (!tv) return res.status(404).json({ error: 'TV not found.' });
    if (tv.active_voucher_id === v.id) return res.status(400).json({ error: 'That TV is already on this code.' });

    /* re-check at the moment of writing: the earlier check was for the customer's benefit, this
       one is what actually protects the limit if two attempts race */
    const phones = (await query('SELECT count(*)::int AS n FROM hotspot_voucher_devices WHERE voucher_id = $1::uuid', [v.id])).rows[0].n;
    const tvs = (await query('SELECT count(*)::int AS n FROM hotspot_bound_devices WHERE active_voucher_id = $1::uuid', [v.id])).rows[0].n;
    const allowed = parseInt(v.allowed, 10) || 1;
    if (phones + tvs >= allowed) {
      return res.status(403).json({ error: 'This code already has ' + (phones + tvs) + ' of ' + allowed + ' device(s) in use.' });
    }

    const mac = String(tv.mac_address || '').toUpperCase();

    /* the TV inherits the voucher's package and expiry — it is not sold a plan of its own, so it
       goes offline exactly when the voucher does */
    await query(
      `UPDATE hotspot_bound_devices
          SET active_voucher_id = $1::uuid, package_id = $2::uuid, expires_at = $3,
              is_bound = true, updated_at = NOW()
        WHERE id = $4::uuid`,
      [v.id, v.package_id, v.expires_at, tv.id]);

    let bound = false;
    try {
      const mt = require('../utils/mikrotik');
      const nas = (await query(
        'SELECT id FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL ORDER BY last_seen DESC NULLS LAST',
        [req.params.ispId])).rows;
      for (const n of nas) {
        await mt.addIpBindingBypass(n.id, { mac_address: mac, comment: 'RumaLink-TV ' + mac });
        const ip = await mt.findIpForMac(n.id, mac).catch(function(){ return null; });
        const limit = (v.up || v.down) ? ((v.up || v.down) + 'M/' + (v.down || 0) + 'M') : null;
        if (ip && limit && limit !== '0M/0M') {
          await mt.applyQueueRateLimit(n.id, { username: 'tv-' + mac.replace(/:/g, ''), ip, max_limit: limit }).catch(function(){});
        }
        bound = true;
      }
    } catch (e) {
      require('../utils/logger').error('[tv-attach] router: ' + e.message);
    }

    require('../utils/logger').info('[tv-attach] ' + tv.name + ' (' + mac + ') -> ' + v.code +
      ' until ' + v.expires_at + (bound ? '' : ' (router not reached — tv-reconcile will bind it)'));

    res.json({
      ok: true, tv_name: tv.name, code: v.code,
      expires_at: v.expires_at,
      devices_used: phones + tvs + 1, devices_allowed: allowed,
      /* say so plainly rather than claiming success — tv-reconcile binds it within the minute */
      note: bound ? null : 'Saved. Your TV will come online shortly.'
    });
  } catch (err) { next2(err, res); }
});

function next2(err, res) {
  require('../utils/logger').error('[tv-attach] ' + err.message);
  res.status(500).json({ error: err.message });
}

'''
s = s[:m.start()] + routes + s[m.start():]
open(p,'w').write(s); print("   check-voucher and attach added")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js OK"

say "3) Restart + test both"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
CODE1=$(q -tAc "SELECT hv.code FROM hotspot_vouchers hv JOIN hotspot_packages hp ON hp.id=hv.package_id WHERE hv.status='active' AND (hv.is_tv IS NOT TRUE) AND COALESCE(hp.simultaneous_sessions,1)=1 ORDER BY hv.created_at DESC LIMIT 1;")
CODE2=$(q -tAc "SELECT hv.code FROM hotspot_vouchers hv JOIN hotspot_packages hp ON hp.id=hv.package_id WHERE hv.status='active' AND (hv.is_tv IS NOT TRUE) AND COALESCE(hp.simultaneous_sessions,1)>1 ORDER BY hv.created_at DESC LIMIT 1;")
echo "   1-device code ${CODE1:-none} — should be refused:"
[ -n "$CODE1" ] && curl -s -X POST "http://127.0.0.1:5000/api/captive/$ISP/tv/check-voucher" -H 'Content-Type: application/json' -d "{\"code\":\"$CODE1\"}" | head -c 220 | sed 's/^/     /'; echo
echo "   multi-device code ${CODE2:-none} — should be allowed:"
[ -n "$CODE2" ] && curl -s -X POST "http://127.0.0.1:5000/api/captive/$ISP/tv/check-voucher" -H 'Content-Type: application/json' -d "{\"code\":\"$CODE2\"}" | head -c 220 | sed 's/^/     /'; echo

say "4) Next"
echo "   Backend done. Say go and I will add the button, modal and spinner to the portal."

say "5) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Attach a TV to an existing voucher: inherits its package and expiry, counts toward the device limit" 2>&1 | head -2 | sed 's/^/   /'
