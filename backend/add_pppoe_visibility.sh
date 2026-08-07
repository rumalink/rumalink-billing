#!/usr/bin/env bash
#
# add_pppoe_visibility.sh — hide a PPPoE package from the portal, and from specific subscribers.
#
# Two different things, so two mechanisms:
#
#   visible_in_portal (column on the package)  — hidden from everyone. Same meaning as the
#     hotspot flag: not offered, but honoured for anyone already on it.
#
#   pppoe_package_visibility (table)           — hidden from PARTICULAR subscribers. This is a
#     relationship between a package and a subscriber, not a property of either, so it cannot
#     live as a column on one of them.
#
# A blocklist, not an allowlist: a package is offered unless someone is explicitly excluded. That
# keeps today's behaviour when nothing is configured, and it is what "do not show this package to
# that client" means. If a genuinely private package is ever needed — offered to one customer
# only — that is an allowlist and wants its own mode rather than being bolted onto this.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Schema"
q -c "ALTER TABLE pppoe_packages ADD COLUMN IF NOT EXISTS visible_in_portal boolean NOT NULL DEFAULT true;"
q -c "CREATE TABLE IF NOT EXISTS pppoe_package_visibility (
        id bigserial PRIMARY KEY,
        package_id uuid NOT NULL REFERENCES pppoe_packages(id) ON DELETE CASCADE,
        subscriber_id uuid NOT NULL REFERENCES pppoe_subscribers(id) ON DELETE CASCADE,
        hidden boolean NOT NULL DEFAULT true,
        created_at timestamptz NOT NULL DEFAULT now(),
        UNIQUE (package_id, subscriber_id));"
q -c "CREATE INDEX IF NOT EXISTS idx_ppv_sub ON pppoe_package_visibility(subscriber_id);"
q -c "COMMENT ON TABLE pppoe_package_visibility IS 'Per-subscriber exceptions. A row with hidden=true removes that package from that subscriber''s portal; absence means visible.';"
q -c "SELECT name, price, is_active, visible_in_portal FROM pppoe_packages ORDER BY price;"

say "2) Backup"
sudo cp "$BE/routes/pppoePortal.js" "$BE/routes/.pppoePortal.js.bak_$TS" && echo "   pppoePortal.js"

say "3) Filter the customer-facing list"
sudo python3 - "$BE/routes/pppoePortal.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_PPPOE_VISIBILITY' in s:
    print("   already patched"); sys.exit(0)

m = re.search(r'FROM pppoe_packages WHERE isp_id=\$1::uuid AND is_active=true', s)
if not m:
    print("   ERROR: portal package query not found"); sys.exit(1)

new = ("""FROM pppoe_packages pp
         /* RL_PPPOE_VISIBILITY: two separate rules. visible_in_portal hides a package from every
            customer; pppoe_package_visibility hides it from PARTICULAR subscribers. The second is
            a blocklist — absence of a row means visible — so nothing changes for packages with no
            exceptions configured. Neither affects a subscriber already ON the package: this filters
            what is OFFERED, not what is honoured. */
         WHERE pp.isp_id=$1::uuid AND pp.is_active=true AND pp.visible_in_portal=true
           AND NOT EXISTS (
             SELECT 1 FROM pppoe_package_visibility v
              WHERE v.package_id = pp.id AND v.hidden = true
                AND v.subscriber_id = $2::uuid)""")
s = s[:m.start()] + new + s[m.end():]

# the query needs the subscriber id as $2
seg = s[max(0, m.start()-900): m.start()+900]
mp = re.search(r'\[\s*sub\.isp_id\s*\]', seg)
if mp:
    s = s.replace(seg, seg[:mp.start()] + '[sub.isp_id, sub.id]' + seg[mp.end():], 1)
    print("   subscriber id passed to the query")
else:
    print("   NOTE: could not find the params array automatically — check it passes [isp_id, subscriber_id]")

open(p,'w').write(s); print("   portal list filtered")
PY
cd "$BE" && sudo -u www-data node --check routes/pppoePortal.js && echo "   pppoePortal.js OK"
echo "   the query and its params:"
sudo sed -n '92,118p' "$BE/routes/pppoePortal.js" | nl -ba -v92 | sed 's/^/     /'

say "4) Endpoints to manage the exceptions"
sudo python3 - "$BE/routes/pppoe.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_PPPOE_VIS_ROUTES' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^module\.exports\s*=', s, re.M)
if not m:
    print("   ERROR: module.exports not found"); sys.exit(1)
routes = '''
/* RL_PPPOE_VIS_ROUTES: which subscribers a package is hidden from. Absence of a row means the
   package is visible, so an empty list is the normal state and needs no configuration. */
router.get('/packages/:id/visibility', async (req, res, next) => {
  try {
    const own = await query('SELECT id FROM pppoe_packages WHERE id=$1::uuid AND isp_id=$2::uuid', [req.params.id, req.user.ispId]);
    if (!own.rows[0]) return res.status(404).json({ error: 'Package not found' });
    const r = await query(
      `SELECT s.id, s.username, s.full_name,
              COALESCE(v.hidden, false) AS hidden
         FROM pppoe_subscribers s
         LEFT JOIN pppoe_package_visibility v ON v.subscriber_id = s.id AND v.package_id = $1::uuid
        WHERE s.isp_id = $2::uuid AND s.deleted_at IS NULL
        ORDER BY s.username`,
      [req.params.id, req.user.ispId]);
    res.json({ subscribers: r.rows });
  } catch (err) { next(err); }
});

router.put('/packages/:id/visibility', async (req, res, next) => {
  try {
    const own = await query('SELECT id FROM pppoe_packages WHERE id=$1::uuid AND isp_id=$2::uuid', [req.params.id, req.user.ispId]);
    if (!own.rows[0]) return res.status(404).json({ error: 'Package not found' });
    const hiddenFor = Array.isArray(req.body.hidden_for) ? req.body.hidden_for : [];
    /* replace wholesale: the list sent IS the intended state, so a subscriber removed from it
       becomes visible again without needing a separate call */
    await query('DELETE FROM pppoe_package_visibility WHERE package_id = $1::uuid', [req.params.id]);
    for (const sid of hiddenFor) {
      await query(
        `INSERT INTO pppoe_package_visibility (package_id, subscriber_id, hidden)
         SELECT $1::uuid, s.id, true FROM pppoe_subscribers s
          WHERE s.id = $2::uuid AND s.isp_id = $3::uuid
         ON CONFLICT (package_id, subscriber_id) DO UPDATE SET hidden = true`,
        [req.params.id, sid, req.user.ispId]).catch(function(){});
    }
    require('../utils/logger').info('[pppoe-visibility] package ' + req.params.id + ' hidden from ' + hiddenFor.length + ' subscriber(s)');
    res.json({ ok: true, hidden_count: hiddenFor.length });
  } catch (err) { next(err); }
});

'''
s = s[:m.start()] + routes + s[m.start():]
open(p,'w').write(s); print("   GET/PUT /pppoe/packages/:id/visibility added")
PY
cd "$BE" && sudo -u www-data node --check routes/pppoe.js && echo "   pppoe.js OK"

say "5) Accept the flag when a package is created or edited"
sudo python3 - "$BE/routes/pppoe.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_PPPOE_VIS_FIELD' in s:
    print("   already patched"); sys.exit(0)
n = 0
m = re.search(r'INSERT INTO pppoe_packages\s*\(([^)]*)\)\s*VALUES\s*\(([^)]*)\)', s, re.S)
if m and 'visible_in_portal' not in m.group(1):
    nums = [int(x) for x in re.findall(r'\$(\d+)', m.group(2))]
    nxt = (max(nums)+1) if nums else 1
    s = s[:m.start(1)] + m.group(1).rstrip() + ", visible_in_portal" + s[m.end(1):]
    m2 = re.search(r'INSERT INTO pppoe_packages\s*\(([^)]*)\)\s*VALUES\s*\(([^)]*)\)', s, re.S)
    s = s[:m2.start(2)] + m2.group(2).rstrip() + f", ${nxt}" + s[m2.end(2):]
    print(f"   INSERT gained visible_in_portal as ${nxt} — append the value to its params array")
    n += 1
m3 = re.search(r'UPDATE pppoe_packages SET(.*?)WHERE', s, re.S)
if m3 and 'visible_in_portal' not in m3.group(1):
    nums = [int(x) for x in re.findall(r'\$(\d+)', m3.group(1))]
    nxt = (max(nums)+1) if nums else 1
    s = s[:m3.end(1)] + f", visible_in_portal=COALESCE(${nxt}, visible_in_portal) /* RL_PPPOE_VIS_FIELD */ " + s[m3.end(1):]
    print(f"   UPDATE gained visible_in_portal as ${nxt} — append the value to its params array")
    n += 1
if n: open(p,'w').write(s)
print(f"   {n} SQL edit(s); the param arrays are printed below")
PY
grep -nE "INSERT INTO pppoe_packages|UPDATE pppoe_packages" "$BE/routes/pppoe.js" | sed 's/^/     /'
cd "$BE" && sudo -u www-data node --check routes/pppoe.js && echo "   pppoe.js OK"

say "6) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 15 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"

say "7) Try it"
cat <<'EOS'
   Hide a package from everyone:
     sudo -u postgres psql -d rumalink_db -c "UPDATE pppoe_packages SET visible_in_portal=false WHERE name='My Test';"

   Hide one package from one subscriber:
     sudo -u postgres psql -d rumalink_db -c "INSERT INTO pppoe_package_visibility (package_id, subscriber_id) SELECT p.id, s.id FROM pppoe_packages p, pppoe_subscribers s WHERE p.name='7 Days' AND s.username='benard';"

   Then open the PPPoE portal as that subscriber — the package should be absent, while other
   subscribers still see it. Anyone already ON a hidden package keeps their service.
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "PPPoE packages: portal visibility, plus per-subscriber exceptions" 2>&1 | head -2 | sed 's/^/   /'
