#!/usr/bin/env bash
#
# build_voucher_login.sh — let a SECOND device use a multi-device voucher.
#
# WHY THE THIRD PIECE WAS MISSING: Simultaneous-Use is written correctly and FreeRADIUS would
# permit N sessions — but radpostauth shows the second device never reached RADIUS. A new device
# opens the portal with no MAC binding and no session, so it is shown the purchase page; there is
# no "I already have a code" path. The limit was enforceable but unreachable.
#
# ADDS:
#   1. hotspot_voucher_devices — which devices a voucher currently serves. "Which device bought
#      this" (purchased_by_mac) and "which devices may use it" are different facts; overloading
#      one column is what caused several earlier bugs.
#   2. POST /api/captive/:ispId/voucher-login — validates the code, admits the device if the
#      voucher is under its package limit, registers MAC auth, and returns RADIUS credentials.
#   3. A "Already have a code?" form on the portal.
#
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "0) Does the portal already have a code-entry form?"
grep -nE "voucher|have a code|redeem" "$CP/classic.html" | grep -iE "input|form|button|placeholder" | head -8 | sed 's/^/   /' || echo "   ${Y}none — this is the gap${N}"
grep -n 'id="pay-section"' "$CP/classic.html" | sed 's/^/   /'

say "1) Table for the devices a voucher serves"
q -c "CREATE TABLE IF NOT EXISTS hotspot_voucher_devices (
        id bigserial PRIMARY KEY,
        voucher_id uuid NOT NULL REFERENCES hotspot_vouchers(id) ON DELETE CASCADE,
        mac varchar NOT NULL,
        first_seen timestamptz NOT NULL DEFAULT now(),
        last_seen  timestamptz NOT NULL DEFAULT now(),
        UNIQUE (voucher_id, mac));"
q -c "CREATE INDEX IF NOT EXISTS idx_hvd_voucher ON hotspot_voucher_devices(voucher_id);"
echo "   seed from the device that already holds each voucher:"
q -c "INSERT INTO hotspot_voucher_devices (voucher_id, mac)
      SELECT id, UPPER(used_by_mac) FROM hotspot_vouchers
       WHERE used_by_mac IS NOT NULL AND used_by_mac <> ''
      ON CONFLICT (voucher_id, mac) DO NOTHING;"
q -c "SELECT v.code, d.mac, d.first_seen FROM hotspot_voucher_devices d JOIN hotspot_vouchers v ON v.id=d.voucher_id ORDER BY d.first_seen DESC LIMIT 8;"

say "2) Backups"
sudo cp "$BE/routes/captive.js" "$BE/routes/.captive.js.bak_$TS" && echo "   captive.js"
sudo cp "$CP/classic.html" "$CP/.classic.html.bak_$TS" && echo "   classic.html"

say "3) The voucher-login endpoint"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_VOUCHER_LOGIN' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^module\.exports\s*=', s, re.M)
if not m:
    print("   ERROR: module.exports not found"); sys.exit(1)

route = """
/* RL_VOUCHER_LOGIN: a second device could never use a multi-device voucher. It opens the portal
   with no MAC binding and no session, so it was shown the purchase page — Simultaneous-Use was
   written and enforceable, but nothing ever reached RADIUS to be allowed. This admits a device
   when the voucher is still under its package limit, records it, registers MAC auto-login so it
   reconnects on its own, and hands back the RADIUS credentials the portal logs in with. */
router.post('/:ispId/voucher-login', async (req, res, next) => {
  try {
    const code = String(req.body.code || '').trim().toUpperCase();
    const mac  = String(req.body.mac || '').trim().toUpperCase();
    if (!code) return res.status(400).json({ error: 'Enter your code.' });

    const v = (await query(
      `SELECT hv.*, COALESCE(hp.simultaneous_sessions, 1) AS max_devices, hp.name AS package_name
         FROM hotspot_vouchers hv
         LEFT JOIN hotspot_packages hp ON hp.id = hv.package_id
        WHERE hv.isp_id = $1::uuid AND UPPER(hv.code) = $2 LIMIT 1`,
      [req.params.ispId, code])).rows[0];

    if (!v) return res.status(404).json({ error: 'That code was not found. Check it and try again.' });
    if (v.is_tv) return res.status(400).json({ error: 'That code belongs to a TV. It connects automatically.' });
    if (v.expires_at && new Date(v.expires_at) <= new Date())
      return res.status(400).json({ error: 'That code has expired. Buy a package to continue.' });
    if (v.status !== 'active')
      return res.status(400).json({ error: 'That code is not active yet. If you have just paid, wait a moment.' });

    const known = (await query('SELECT mac FROM hotspot_voucher_devices WHERE voucher_id = $1::uuid', [v.id])).rows
                    .map(r => String(r.mac).toUpperCase());
    const limit = parseInt(v.max_devices, 10) || 1;

    if (mac && !known.includes(mac)) {
      if (known.length >= limit) {
        return res.status(403).json({
          error: 'This code already has ' + known.length + ' device' + (known.length > 1 ? 's' : '') +
                 ' connected. The ' + (v.package_name || 'package') + ' allows ' + limit + '.'
        });
      }
      await query('INSERT INTO hotspot_voucher_devices (voucher_id, mac) VALUES ($1::uuid,$2) ON CONFLICT DO NOTHING', [v.id, mac]);
      if (!v.used_by_mac) await query('UPDATE hotspot_vouchers SET used_by_mac=$1 WHERE id=$2::uuid', [mac, v.id]).catch(()=>{});
      try { await require('../utils/macAuth').registerMACAuth(v.id, mac); } catch (e) { logger.warn('[voucher-login] mac auth: ' + e.message); }
      logger.info('[voucher-login] ' + code + ' admitted ' + mac + ' (' + (known.length + 1) + '/' + limit + ')');
    } else if (mac) {
      await query('UPDATE hotspot_voucher_devices SET last_seen=now() WHERE voucher_id=$1::uuid AND mac=$2', [v.id, mac]).catch(()=>{});
    }

    const shortIsp = String(v.isp_id).replace(/-/g, '').slice(0, 8).toLowerCase();
    res.json({
      ok: true,
      voucher_code: v.code,
      radius_username: v.code + '@' + shortIsp,
      radius_password: v.password || v.code,
      devices_used: Math.min(known.length + (mac && !known.includes(mac) ? 1 : 0), limit),
      devices_allowed: limit,
      expires_at: v.expires_at
    });
  } catch (err) { next(err); }
});

"""
s = s[:m.start()] + route + s[m.start():]
open(p,'w').write(s); print("   POST /:ispId/voucher-login added")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js OK"

say "4) Portal: 'Already have a code?'"
sudo python3 - "$CP/classic.html" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_CODE_LOGIN_UI' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)<div[^\n]*id="pay-section"[^\n]*>', s, re.M)
if not m:
    print("   ERROR: pay-section not found — endpoint still usable"); sys.exit(1)
ind = m.group(1)
ui = (
f'{ind}<!-- RL_CODE_LOGIN_UI: lets a SECOND device use a code that allows more than one device. -->\n'
f'{ind}<div id="code-login" style="margin:14px 0;padding:14px;border:1px solid rgba(255,255,255,.18);border-radius:12px">\n'
f'{ind}  <div style="font-weight:600;margin-bottom:8px">Already have a code?</div>\n'
f'{ind}  <div style="display:flex;gap:8px">\n'
f'{ind}    <input id="cl-code" type="text" placeholder="e.g. Q2" autocapitalize="characters"\n'
f'{ind}           style="flex:1;padding:10px;border-radius:8px;border:1px solid rgba(255,255,255,.25);background:transparent;color:inherit"/>\n'
f'{ind}    <button id="cl-btn" type="button" style="padding:10px 16px;border-radius:8px;border:0;font-weight:600;cursor:pointer">Connect</button>\n'
f'{ind}  </div>\n'
f'{ind}  <div id="cl-msg" style="margin-top:8px;font-size:.86rem;opacity:.85"></div>\n'
f'{ind}</div>\n'
)
s = s[:m.start()] + ui + s[m.start():]

js = """
<script>
/* RL_CODE_LOGIN_UI */
(function(){
  var btn = document.getElementById('cl-btn');
  if (!btn) return;
  btn.addEventListener('click', function(){
    var code = (document.getElementById('cl-code').value || '').trim();
    var msg  = document.getElementById('cl-msg');
    if (!code) { msg.textContent = 'Enter your code.'; return; }
    msg.textContent = 'Checking...';
    var mac = (typeof rlClientMac === 'function' ? rlClientMac() : (window.RL_MAC || ''));
    fetch((window.API || '/api') + '/captive/' + window.ISP_ID + '/voucher-login', {
      method: 'POST', headers: {'Content-Type':'application/json'},
      body: JSON.stringify({ code: code, mac: mac })
    }).then(function(r){ return r.json().then(function(j){ return { ok: r.ok, j: j }; }); })
      .then(function(o){
        if (!o.ok) { msg.textContent = o.j.error || 'Could not connect.'; return; }
        msg.textContent = 'Connecting... (' + o.j.devices_used + ' of ' + o.j.devices_allowed + ' devices)';
        if (typeof rlHotspotLogin === 'function') rlHotspotLogin(o.j.radius_username, o.j.radius_password);
        else msg.textContent = 'Connected. Reload the page.';
      })
      .catch(function(e){ msg.textContent = 'Network error: ' + e.message; });
  });
})();
</script>
"""
s = s.replace('</body>', js + '\n</body>', 1) if '</body>' in s else s + js
open(p,'w').write(s); print("   code-entry form added")
PY
sudo chown www-data:www-data "$CP/classic.html"
echo "   div balance: $(( $(grep -o '<div' "$CP/classic.html" | wc -l) - $(grep -o '</div>' "$CP/classic.html" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$CP/classic.html" | wc -l) / $(grep -o '</script>' "$CP/classic.html" | wc -l)"

say "5) Restart + test the endpoint"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
ISP=$(q -tAc "SELECT id FROM isps LIMIT 1;")
CODE=$(q -tAc "SELECT code FROM hotspot_vouchers WHERE status='active' AND (is_tv IS NOT TRUE) ORDER BY created_at DESC LIMIT 1;")
echo "   voucher $CODE, second device AA:BB:CC:DD:EE:01"
curl -s -X POST "http://127.0.0.1:5000/api/captive/$ISP/voucher-login" \
  -H 'Content-Type: application/json' -d "{\"code\":\"$CODE\",\"mac\":\"AA:BB:CC:DD:EE:01\"}" | sed 's/^/     /'; echo
echo "   a third device (should be refused if the package allows 2):"
curl -s -X POST "http://127.0.0.1:5000/api/captive/$ISP/voucher-login" \
  -H 'Content-Type: application/json' -d "{\"code\":\"$CODE\",\"mac\":\"AA:BB:CC:DD:EE:02\"}" | sed 's/^/     /'; echo
q -c "SELECT v.code, d.mac FROM hotspot_voucher_devices d JOIN hotspot_vouchers v ON v.id=d.voucher_id ORDER BY d.first_seen DESC LIMIT 6;"
echo "   ${Y}clean up the fake test devices:${N}"
q -c "DELETE FROM hotspot_voucher_devices WHERE mac LIKE 'AA:BB:CC:DD:EE:%';"
q -c "DELETE FROM radcheck WHERE username LIKE 'AA:BB:CC:DD:EE:%';"

say "6) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Voucher login for additional devices, bounded by the package device limit" 2>&1 | head -2 | sed 's/^/   /'
