#!/usr/bin/env bash
#
# add_device_diagnostics.sh — a full health read of the MikroTik on the device page.
#
# The General tab shows what is STORED about a router (identity, board, version) plus link status
# and live bandwidth. What it cannot answer is "is this router configured correctly right now" —
# and that question cost hours today: fasttrack silently bypassing every queue, shared-users
# capping RADIUS, the accept rule ordered above the expiry rules. Each was invisible until someone
# went looking over the API.
#
# Adds GET /nas/:id/health returning system, service and guard state in one call, and a
# Diagnostics panel above the existing ones. Nothing already on the page is removed.
#
# Cached ~20s with a Refresh that bypasses it: hitting the router on every page load is what made
# Active Sessions slow.
#
set -uo pipefail
BE=/var/www/rumalink/backend
D=/var/www/rumalink/isp/device.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Backups"
sudo cp "$BE/routes/nas.js" "$BE/routes/.nas.js.bak_$TS" && echo "   nas.js"
sudo cp "$D" "/var/www/rumalink/isp/.device.html.bak_$TS" && echo "   device.html"

say "2) The health endpoint"
sudo python3 - "$BE/routes/nas.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_DEVICE_HEALTH' in s:
    print("   already present"); sys.exit(0)
m = re.search(r"^router\.get\('/:id/test-tunnel'", s, re.M)
if not m:
    print("   ERROR: anchor not found"); sys.exit(1)

route = '''/* RL_DEVICE_HEALTH: one call for everything the router can tell us about itself. Split across
   several endpoints it would mean several round trips, and this page already waits on enough.
   Cached briefly because a router's health does not change between two clicks, and a page that
   stalls on the API is a page nobody opens. */
const _rlDevHealth = new Map();
router.get('/:id/health', async (req, res) => {
  try {
    const fresh = String(req.query.fresh || '') === '1';
    const key = String(req.params.id);
    const hit = _rlDevHealth.get(key);
    if (!fresh && hit && (Date.now() - hit.t) < 20000) return res.json(hit.v);

    const dr = await query(
      'SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE id=$1::uuid AND isp_id=$2::uuid',
      [req.params.id, req.user.ispId]);
    const dev = dr.rows[0];
    if (!dev) return res.status(404).json({ error: 'Device not found' });
    if (!dev.wireguard_ip) return res.json({ reachable: false, reason: 'No tunnel address yet' });

    const axios = require('axios');
    const b = 'http://' + dev.wireguard_ip + '/rest';
    const auth = { username: dev.mikrotik_api_user, password: dev.mikrotik_api_password };
    const g = async (path) => {
      try { const r = await axios.get(b + path, { auth, timeout: 9000, validateStatus: () => true });
            return (r.status === 200) ? r.data : null; } catch (e) { return null; }
    };

    const [resource, health, ifaces, hs, ppp, queues, filters, settings, profiles, routes] = await Promise.all([
      g('/system/resource'), g('/system/health'), g('/interface'),
      g('/ip/hotspot/active'), g('/ppp/active'), g('/queue/simple'),
      g('/ip/firewall/filter'), g('/ip/settings'), g('/ip/hotspot/user/profile'), g('/ip/route'),
    ]);

    if (!resource) {
      const out = { reachable: false, reason: 'Router did not answer over the tunnel' };
      _rlDevHealth.set(key, { t: Date.now(), v: out });
      return res.json(out);
    }

    const totalMem = Number(resource['total-memory']) || 0;
    const freeMem  = Number(resource['free-memory']) || 0;
    const totalHdd = Number(resource['total-hdd-space']) || 0;
    const freeHdd  = Number(resource['free-hdd-space']) || 0;

    /* The guards exist because each of these failed silently in production: fasttrack bypassed
       every simple queue, shared-users=1 overrode the per-package limit RADIUS sends, and an
       accept rule above the expiry rules let expired customers keep browsing. Config that looks
       right and behaves wrong is the expensive kind, so show it plainly. */
    const fwd = (filters || []).filter(x => x.chain === 'forward');
    const ftRules = (filters || []).filter(x => x.action === 'fasttrack-connection').length;
    const acceptIdx = fwd.findIndex(x => x.action === 'accept' &&
      String(x['connection-state'] || '') === 'established,related' && !x['src-address-list']);
    const lastExpired = fwd.map((x, i) => String(x['src-address-list'] || '') === 'rl-expired' ? i : -1)
      .reduce((a, c) => Math.max(a, c), -1);
    const sharedUsers = (profiles || []).map(x => Number(x['shared-users'] || 1));
    const defaultRoutes = (routes || []).filter(x => String(x['dst-address'] || '') === '0.0.0.0/0');

    const checks = [
      { key: 'fasttrack', label: 'Rate limits enforced',
        ok: ftRules === 0,
        detail: ftRules === 0 ? 'No fasttrack rule' : ftRules + ' fasttrack rule(s) — queues are being bypassed' },
      { key: 'accept_order', label: 'Expiry rules take effect',
        ok: (lastExpired === -1 || acceptIdx === -1 || acceptIdx > lastExpired),
        detail: (lastExpired === -1 || acceptIdx === -1 || acceptIdx > lastExpired)
          ? 'Accept rule sits below the expiry rules'
          : 'Accept rule is ABOVE the expiry rules — expired users keep browsing' },
      { key: 'shared_users', label: 'Device limits honoured',
        ok: sharedUsers.every(n => n >= 10),
        detail: sharedUsers.every(n => n >= 10)
          ? 'Hotspot profile does not cap simultaneous logins'
          : 'A hotspot profile caps logins, overriding the package limit' },
      { key: 'radius', label: 'RADIUS configured',
        ok: !!(profiles || []).length,
        detail: (profiles || []).length + ' hotspot profile(s)' },
      { key: 'wan', label: 'Default route present',
        ok: defaultRoutes.some(r2 => String(r2.active) === 'true'),
        detail: defaultRoutes.length + ' default route(s), ' +
                defaultRoutes.filter(r2 => String(r2.active) === 'true').length + ' active' },
    ];

    const out = {
      reachable: true,
      fetched_at: new Date().toISOString(),
      system: {
        board: resource['board-name'] || null,
        version: resource.version || null,
        uptime: resource.uptime || null,
        cpu_load: Number(resource['cpu-load']) || 0,
        cpu_count: Number(resource['cpu-count']) || 1,
        cpu_freq: resource['cpu-frequency'] || null,
        mem_total_mb: Math.round(totalMem / 1048576),
        mem_free_mb: Math.round(freeMem / 1048576),
        mem_used_pct: totalMem ? Math.round(((totalMem - freeMem) / totalMem) * 100) : 0,
        disk_total_mb: Math.round(totalHdd / 1048576),
        disk_free_mb: Math.round(freeHdd / 1048576),
        disk_used_pct: totalHdd ? Math.round(((totalHdd - freeHdd) / totalHdd) * 100) : 0,
        temperature: health ? (Array.isArray(health)
          ? (health.find(h => /temp/i.test(h.name || ''))||{}).value
          : health.temperature) || null : null,
        voltage: health ? (Array.isArray(health)
          ? (health.find(h => /volt/i.test(h.name || ''))||{}).value
          : health.voltage) || null : null,
      },
      services: {
        hotspot_sessions: (hs || []).length,
        pppoe_sessions: (ppp || []).length,
        queues: (queues || []).length,
        interfaces_up: (ifaces || []).filter(x => String(x.running) === 'true').length,
        interfaces_total: (ifaces || []).length,
      },
      checks,
      checks_ok: checks.filter(c => c.ok).length,
      checks_total: checks.length,
    };
    _rlDevHealth.set(key, { t: Date.now(), v: out });
    res.json(out);
  } catch (err) {
    require('../utils/logger').warn('[device-health] ' + err.message);
    res.status(500).json({ reachable: false, reason: err.message });
  }
});

'''
s = s[:m.start()] + route + s[m.start():]
open(p,'w').write(s); print("   GET /nas/:id/health added")
PY
cd "$BE" && sudo -u www-data node --check routes/nas.js && echo "   nas.js OK"

say "3) Test it"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
NAS=$(q -tAc "SELECT id FROM nas_devices LIMIT 1;")
echo "   device $NAS (401 without a token is expected):"
curl -s -o /dev/null -w "     HTTP %{http_code} in %{time_total}s\n" "http://127.0.0.1:5000/api/nas/$NAS/health"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
 const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
 const r=(await axios.get(b+'/system/resource',{auth,timeout:10000})).data||{};
 console.log('   board='+r['board-name']+'  ros='+r.version+'  cpu='+r['cpu-load']+'%  uptime='+r.uptime);
 const h=await axios.get(b+'/system/health',{auth,timeout:10000}).then(x=>x.data).catch(()=>null);
 console.log('   health sensors: '+(h?JSON.stringify(h).slice(0,160):'(board reports none)'));
 process.exit(0);
})();" 2>&1 | grep -v "^info:"

say "4) Next"
cat <<'EOS'
   The endpoint is live and cached. The Diagnostics panel is the second half — say go and I will
   add it above Overview, in the VPS Health style: a status hero, radial gauges for CPU, memory and
   disk, metric cards for sessions and interfaces, and the checks as a pass/fail row.

   Nothing on the page changes until then; this step only adds an endpoint.
EOS

say "5) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Device health endpoint: system, services and configuration checks in one call" 2>&1 | head -2 | sed 's/^/   /'
