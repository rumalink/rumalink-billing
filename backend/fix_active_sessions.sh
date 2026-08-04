#!/usr/bin/env bash
#
# fix_active_sessions.sh — Active Sessions sits on "Loading…".
#
# The handler makes about 65 round trips for 47 sessions:
#   - one voucher query per hotspot session (29)
#   - one router request per PPPoE session to read interface bytes (18)
#   - one subscriber query per PPPoE session (18)
# and it collects PPPoE twice — from the pppoe_sessions table AND from /ppp/active — which is
# why All reads 51 while Hotspot 29 + PPPoE 18 = 47.
#
# Rewritten to: pull each router's data once (hotspot sessions, ppp/active, interfaces), then
# resolve every voucher and subscriber in ONE query each, and de-duplicate PPPoE by username.
# Same response shape, same fields.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) What the route returns today, and what the page reads"
sudo awk '/router.get\(.\/sessions\/active./,0' "$BE/routes/isp.js" | grep -nE "res\.json|^\}\);" | head -5 | sed 's/^/   /'
sudo sed -n '4240,4256p' /var/www/rumalink/isp/dashboard.html | nl -ba -v4240 | sed 's/^/   /'

say "2) Backup"
sudo cp "$BE/routes/isp.js" "$BE/routes/.isp.js.bak_$TS" && echo "   isp.js"

say "3) Replace the handler"
sudo python3 - "$BE/routes/isp.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SESSIONS_BATCHED' in s:
    print("   already patched"); sys.exit(0)

start = s.find("router.get('/sessions/active'")
if start == -1:
    print("   ERROR: route not found"); sys.exit(1)
# find the terminating "});" at column 0
m = re.compile(r'^\}\);\s*$', re.M).search(s, start)
if not m:
    print("   ERROR: route end not found"); sys.exit(1)
end = m.end()
old = s[start:end]

# preserve the response key the page expects
key = 'sessions'
mk = re.search(r'res\.json\(\s*\{\s*([A-Za-z_]+)', old)
if mk: key = mk.group(1)

NEW = '''router.get('/sessions/active', async (req, res) => {
  const _logger = require('../utils/logger');
  try {
    /* RL_SESSIONS_BATCHED: this used to run ~65 round trips for ~47 sessions — a voucher query per
       hotspot session, and for every PPPoE session both a router request for interface bytes and a
       subscriber query. It also collected PPPoE twice, from the pppoe_sessions table and again from
       /ppp/active, so the totals disagreed with the tabs. Now each router is read once and every
       lookup is resolved in a single query. */
    const _rawT = req.query.type;
    const type = (Array.isArray(_rawT) ? _rawT[_rawT.length - 1] : _rawT) || 'all';
    const axios = require('axios');
    const mt = require('../utils/mikrotik');
    let sessions = [];

    const nasList = await query(
      `SELECT id, name, wireguard_ip, mikrotik_api_user, mikrotik_api_password
         FROM nas_devices
        WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL
          AND (last_seen IS NULL OR last_seen > NOW() - INTERVAL '10 minutes')`,
      [req.user.ispId]);

    /* every router in parallel; one slow router cannot hold up the rest */
    const perRouter = await Promise.allSettled(nasList.rows.map(async (nas) => {
      const baseURL = 'http://' + nas.wireguard_ip + '/rest';
      const auth = { username: nas.mikrotik_api_user, password: nas.mikrotik_api_password };
      const out = { nas, hotspot: [], ppp: [], ifaces: [] };
      if (type === 'all' || type === 'hotspot') {
        try { out.hotspot = await mt.liveHotspotSessions(nas.id); } catch (e) {}
      }
      if (type === 'all' || type === 'pppoe') {
        try {
          const r = await axios.get(baseURL + '/ppp/active', { auth, timeout: 8000, validateStatus: () => true });
          if (r.status === 200 && Array.isArray(r.data)) out.ppp = r.data;
        } catch (e) {}
        /* one call for ALL interfaces instead of one per session */
        try {
          const r2 = await axios.get(baseURL + '/interface', { auth, timeout: 8000, validateStatus: () => true });
          if (r2.status === 200 && Array.isArray(r2.data)) out.ifaces = r2.data;
        } catch (e) {}
      }
      return out;
    }));

    const routers = perRouter.filter(r => r.status === 'fulfilled').map(r => r.value);

    /* ---- resolve every hotspot session in one pass ---- */
    const codes = new Set(), macs = new Set();
    routers.forEach(r => r.hotspot.forEach(sn => {
      const u = String(sn.user || '');
      if (/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/i.test(u)) macs.add(u.toUpperCase());
      else codes.add(u.split('@')[0].toUpperCase());
    }));

    const byCode = new Map(), byMac = new Map();
    if (codes.size || macs.size) {
      const vr = await query(
        `SELECT v.code, v.buyer_phone, v.expires_at, v.used_by_mac, hp.name AS package_name
           FROM hotspot_vouchers v
           LEFT JOIN hotspot_packages hp ON hp.id = v.package_id
          WHERE v.isp_id = $1::uuid
            AND (v.is_tv IS NOT TRUE OR v.is_tv IS NULL)
            AND (UPPER(v.code) = ANY($2::text[]) OR UPPER(v.used_by_mac) = ANY($3::text[]))
          ORDER BY (v.status = 'active') DESC, v.expires_at DESC NULLS LAST`,
        [req.user.ispId, Array.from(codes), Array.from(macs)]);
      for (const row of vr.rows) {
        const c = String(row.code || '').toUpperCase();
        if (c && !byCode.has(c)) byCode.set(c, row);
        const m2 = String(row.used_by_mac || '').toUpperCase();
        if (m2 && !byMac.has(m2)) byMac.set(m2, row);
      }
    }

    routers.forEach(r => r.hotspot.forEach(sn => {
      const raw = String(sn.user || '');
      const isMac = /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/i.test(raw);
      const info = isMac ? (byMac.get(raw.toUpperCase()) || {})
                         : (byCode.get(raw.split('@')[0].toUpperCase()) || {});
      sessions.push({
        type: 'hotspot',
        id: sn.id,
        username: info.code || raw.split('@')[0],
        phone: info.buyer_phone || null,
        mac_address: sn.mac_address,
        ip_address: sn.address,
        start_time: null,
        uptime: sn.uptime,
        bytes_in: sn.bytes_in,
        bytes_out: sn.bytes_out,
        package_name: info.package_name || null,
        expires_at: info.expires_at || null,
        source: 'router',
        router_name: r.nas.name
      });
    }));

    /* ---- PPPoE, from the router only, resolved in one query ---- */
    if (type === 'all' || type === 'pppoe') {
      const names = new Set();
      routers.forEach(r => r.ppp.forEach(sn => { if (sn.name) names.add(String(sn.name)); }));

      const subs = new Map();
      if (names.size) {
        const sr = await query(
          `SELECT ps.username, ps.full_name, ps.phone, ps.next_billing_date, pp.name AS package_name
             FROM pppoe_subscribers ps
             LEFT JOIN pppoe_packages pp ON pp.id = ps.package_id
            WHERE ps.isp_id = $1::uuid AND ps.username = ANY($2::text[])`,
          [req.user.ispId, Array.from(names)]);
        for (const row of sr.rows) subs.set(String(row.username), row);
      }

      const seen = new Set();   /* the table and the router used to both contribute the same person */
      routers.forEach(r => {
        const ifMap = new Map();
        r.ifaces.forEach(i => ifMap.set(String(i.name || ''), i));
        r.ppp.forEach(sn => {
          const uname = String(sn.name || '');
          if (!uname || seen.has(uname)) return;
          seen.add(uname);
          const info = subs.get(uname) || {};
          const iface = ifMap.get('<pppoe-' + uname + '>') || {};
          sessions.push({
            type: 'pppoe',
            id: sn['.id'] || uname,
            username: uname,
            phone: info.phone || '',
            full_name: info.full_name || '',
            mac_address: sn['caller-id'] || '',
            ip_address: sn.address || '',
            start_time: null,
            uptime: sn.uptime || '',
            bytes_in: Number(iface['rx-byte']) || 0,
            bytes_out: Number(iface['tx-byte']) || 0,
            package_name: info.package_name || '',
            expires_at: info.next_billing_date || null,
            source: 'router',
            router_name: r.nas.name
          });
        });
      });
    }

    _logger.info('[ACTIVE-SESS] returning ' + sessions.length + ' session(s) from ' + routers.length + ' router(s)');
    res.json({
      KEYNAME: sessions,
      total: sessions.length,
      counts: {
        all: sessions.length,
        hotspot: sessions.filter(x => x.type === 'hotspot').length,
        pppoe: sessions.filter(x => x.type === 'pppoe').length
      }
    });
  } catch (err) {
    require('../utils/logger').error('sessions/active:', err.message);
    res.status(500).json({ error: err.message });
  }
});'''.replace('KEYNAME', key)

s = s[:start] + NEW + s[end:]
open(p,'w').write(s)
print(f"   handler replaced (response key: {key})")
PY
cd "$BE" && sudo -u www-data node --check routes/isp.js && echo "   isp.js OK"

say "4) Restart + measure"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 25 --nostream 2>/dev/null | grep -iE "ACTIVE-SESS|error" | tail -5 | sed 's/^/   /'
q -c "SELECT count(*) AS open_in_radacct FROM radacct WHERE acctstoptime IS NULL;"

say "5) Check in the browser"
cat <<'EOS'
   Hard-refresh, open Active Sessions:
     the table should fill in about a second instead of sitting on "Loading…"
     All should equal Hotspot + PPPoE (no more double-counted PPPoE)
     the tabs should filter the list
   The log line "[ACTIVE-SESS] returning N session(s)" shows what the server sent.
EOS

say "6) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Active Sessions: batch the lookups (was ~65 round trips) and stop counting PPPoE twice" 2>&1 | head -2 | sed 's/^/   /'
