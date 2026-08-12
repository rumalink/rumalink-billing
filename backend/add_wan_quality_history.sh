#!/usr/bin/env bash
#
# add_wan_quality_history.sh — record what each WAN link normally looks like.
#
# nas_wan_links keeps only the LATEST reading, so nothing can say whether 47ms is unusual for this
# link or its ordinary Tuesday. That is why fixed thresholds were the only option, and why they
# misjudge: 150ms is generous for fibre and unreachable for satellite, and a link that normally
# runs at 30ms is in trouble at 90ms while still passing a 150ms test.
#
# This only RECORDS. No thresholds change, no failover behaviour changes, nothing can trip
# differently because of it. In a few days there is enough history to see what normal is, and any
# baseline rule can then be designed against real numbers rather than guesses. Given quality
# failover has been disabled twice already, earning trust with evidence matters more than shipping
# another set of thresholds.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Somewhere to keep it"
q -c "CREATE TABLE IF NOT EXISTS wan_quality_history (
        id bigserial PRIMARY KEY,
        link_id uuid NOT NULL REFERENCES nas_wan_links(id) ON DELETE CASCADE,
        nas_id uuid,
        sampled_at timestamptz NOT NULL DEFAULT now(),
        latency_ms numeric,
        jitter_ms numeric,
        loss_pct numeric,
        fetch_ms integer,
        mbps numeric,
        internet_ok boolean,
        is_active boolean,
        quality_state varchar);"
q -c "CREATE INDEX IF NOT EXISTS idx_wqh_link_time ON wan_quality_history(link_id, sampled_at DESC);"
q -c "COMMENT ON TABLE wan_quality_history IS 'Per-link quality samples. Retained ~14 days; the point is to know what NORMAL looks like for each link so thresholds can be relative rather than guessed.';"
echo "   created"

say "2) Record a sample on every monitor pass"
sudo cp "$BE/utils/mwan-applier.js" "$BE/utils/.mwan-applier.js.bak_$TS" && echo "   backed up"
sudo python3 - "$BE/utils/mwan-applier.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_QUALITY_HISTORY' in s:
    print("   already patched"); sys.exit(0)

m = re.search(r"^([ \t]*)`UPDATE nas_wan_links SET current_status=\$1, resolved_ip=\$2", s, re.M)
if not m:
    print("   ERROR: status update not found"); sys.exit(1)
line_end = s.find(';', m.end())
if line_end == -1:
    print("   ERROR: statement end not found"); sys.exit(1)
ind = m.group(1).replace('`','')[:-2] if False else re.match(r'^[ \t]*', m.group(1)).group(0)

blk = (
f"\n{ind}/* RL_QUALITY_HISTORY: nas_wan_links holds only the latest reading, so nothing could tell a\n"
f"{ind}   link's normal from its bad day — which is why the thresholds had to be absolute, and why\n"
f"{ind}   they misjudged links whose normal differs. Keep a sample per pass. Recording only: no\n"
f"{ind}   threshold reads this yet. */\n"
f"{ind}try {{\n"
f"{ind}  await query(\n"
f"{ind}    `INSERT INTO wan_quality_history (link_id, nas_id, latency_ms, jitter_ms, loss_pct, fetch_ms, mbps, internet_ok, is_active, quality_state)\n"
f"{ind}     VALUES ($1::uuid,$2::uuid,$3,$4,$5,$6,$7,$8,$9,$10)`,\n"
f"{ind}    [link.id, dev.id,\n"
f"{ind}     (q && q.latencyMs != null) ? q.latencyMs : link.last_latency_ms,\n"
f"{ind}     (q && q.jitterMs  != null) ? q.jitterMs  : link.last_jitter_ms,\n"
f"{ind}     (q && q.lossPct   != null) ? q.lossPct   : link.last_loss_pct,\n"
f"{ind}     link.fetch_ms || null, link.last_mbps || null,\n"
f"{ind}     s.internetOk === true, s.isActive === true, link.quality_state || null]);\n"
f"{ind}  /* prune rarely; a full scan on every pass would cost more than the data is worth */\n"
f"{ind}  if (Math.random() < 0.01) {{\n"
f"{ind}    await query(\"DELETE FROM wan_quality_history WHERE sampled_at < now() - interval '14 days'\").catch(function(){{}});\n"
f"{ind}  }}\n"
f"{ind}}} catch (e) {{ /* recording must never disturb monitoring */ }}\n"
)
s = s[:line_end+1] + blk + s[line_end+1:]
open(p,'w').write(s); print("   sampling added after the status update")
PY
cd "$BE" && sudo -u www-data node --check utils/mwan-applier.js && echo "   mwan-applier.js OK"

say "3) Restart and let a few passes run"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1
echo "   waiting 100s..."
sleep 100
q -c "SELECT count(*) AS samples, min(sampled_at) AS first, max(sampled_at) AS latest FROM wan_quality_history;"

say "4) What it will tell you, once there is a day of it"
q -c "SELECT l.position, l.name,
             count(*) AS samples,
             round(avg(h.latency_ms)::numeric,1)  AS avg_latency,
             round(percentile_cont(0.5) WITHIN GROUP (ORDER BY h.latency_ms)::numeric,1) AS median_latency,
             round(percentile_cont(0.95) WITHIN GROUP (ORDER BY h.latency_ms)::numeric,1) AS p95_latency,
             round(avg(h.jitter_ms)::numeric,1)   AS avg_jitter,
             round(max(h.loss_pct)::numeric,1)    AS worst_loss,
             round(avg(h.fetch_ms)::numeric,0)    AS avg_fetch
      FROM wan_quality_history h JOIN nas_wan_links l ON l.id = h.link_id
      GROUP BY l.position, l.name ORDER BY l.position;"
echo "   ${Y}with a week of this, a rule like 'trip at 2.5x the median, sustained' can be set from${N}"
echo "   ${Y}evidence — and you can see whether it would have fired before enabling it${N}"

say "5) Worth watching"
cat <<'EOS'
   Link 1 measured 36ms / 7.3ms jitter earlier and 47ms / 22.7ms twenty minutes later. Jitter
   tripling is the shape quality failover exists to catch — but with one reading before and after,
   there is no way to know whether that is this link's normal variation or the start of something.
   A few days of samples answers that.

   Check the spread whenever you like:
     sudo -u postgres psql -d rumalink_db -c "SELECT date_trunc('hour',sampled_at) AS hour, round(avg(latency_ms)::numeric,1) AS lat, round(avg(jitter_ms)::numeric,1) AS jit, round(avg(fetch_ms)::numeric,0) AS fetch FROM wan_quality_history WHERE link_id=(SELECT id FROM nas_wan_links WHERE position=1) GROUP BY 1 ORDER BY 1 DESC LIMIT 24;"
EOS

say "6) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Record per-link WAN quality history so thresholds can be based on each link's own normal" 2>&1 | head -2 | sed 's/^/   /'
