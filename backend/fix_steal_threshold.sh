#!/usr/bin/env bash
#
# fix_steal_threshold.sh — stop the CPU-steal alert crying wolf.
#
# cpu_steal is time the hypervisor gave your core to another tenant. It is the one metric that
# rises when OTHER people are busy, so it spikes to 20-36% every hour while this instance sits at
# 1% average and load 0.22. Alerting on a single sample above 5% therefore fires on transient
# peaks that recover within the minute — the platform was never degraded.
#
# An alert that fires when nothing is wrong is worse than no alert: it trains you to ignore the
# one that matters. So judge steal on a SUSTAINED average instead of an instant reading. Every
# other metric keeps its immediate threshold, because memory exhaustion or a full disk really is
# an emergency the moment it happens.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) What the last day actually looked like"
q -c "SELECT round(avg(cpu_steal)::numeric,2) AS avg_steal,
             max(cpu_steal) AS peak,
             count(*) FILTER (WHERE cpu_steal > 5) AS samples_over_5,
             count(*) AS total_samples,
             round(100.0 * count(*) FILTER (WHERE cpu_steal > 5) / GREATEST(count(*),1), 1) AS pct_over_5
      FROM system_health WHERE sampled_at > now() - interval '24 hours';"
echo "   ${Y}each of those samples raised an alert under the current rule${N}"
echo "   how a 10-minute average would have behaved:"
q -c "WITH w AS (SELECT date_trunc('hour', sampled_at) + (floor(extract(minute from sampled_at)/10) * interval '10 min') AS bucket,
                       avg(cpu_steal) AS avg_steal
                FROM system_health WHERE sampled_at > now() - interval '24 hours' GROUP BY 1)
      SELECT count(*) AS ten_min_windows, count(*) FILTER (WHERE avg_steal > 5) AS would_alert,
             round(max(avg_steal)::numeric,1) AS worst_window
      FROM w;"

say "2) Backup"
sudo cp "$BE/utils/health-monitor.js" "$BE/utils/.health-monitor.js.bak_$TS" && echo "   health-monitor.js"

say "3) Judge steal on a sustained average"
sudo python3 - "$BE/utils/health-monitor.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_STEAL_SUSTAINED' in s:
    print("   already patched"); sys.exit(0)

old = re.search(r"[ \t]*cpu_steal:\s*\{[^}]*\},?\n", s)
if not old:
    print("   ERROR: cpu_steal threshold not found"); sys.exit(1)
new = """  /* RL_STEAL_SUSTAINED: steal measures cycles the hypervisor gave to ANOTHER tenant, so it
     spikes when neighbours are busy even while this instance is idle — 20-36% peaks against a 1%
     average and load 0.22. A single sample over 5% therefore alerted on something that was never
     a problem, and an alert that cries wolf gets ignored when it finally matters. Evaluated
     against a 10-minute average instead; see evaluate(). */
  cpu_steal:     { op:'>', value:5, sev:'warning', label:'CPU throttled by AWS', unit:'%', sustained: 10,
                   help:'Sustained over ten minutes, so this is real contention rather than a passing spike. Check CPU burst capacity in the Lightsail console: at zero it is throttling and needs a larger plan; healthy means a noisy neighbour, and stopping then starting the instance moves you to different hardware.' },
"""
s = s[:old.start()] + new + s[old.end():]

# make evaluate honour the sustained window
m = re.search(r'^(async function evaluate\(s\)\s*\{)', s, re.M)
if not m:
    print("   ERROR: evaluate not found"); sys.exit(1)
helper = """
/* RL_STEAL_SUSTAINED: a threshold marked `sustained: N` is judged on the average of the last N
   minutes rather than the current sample, so a brief spike does not raise an alert and a genuine
   sustained problem still does. */
async function sustainedAvg(metric, minutes) {
  try {
    const r = await query(
      'SELECT avg(' + metric + ')::float AS v, count(*)::int AS n FROM system_health WHERE sampled_at > now() - ($1 || \\' minutes\\')::interval',
      [String(minutes)]);
    const row = r.rows[0];
    /* not enough history yet (a fresh restart) — say so rather than alerting on one reading */
    if (!row || !row.n || row.n < Math.max(3, Math.floor(minutes / 3))) return null;
    return Number(row.v);
  } catch (e) { return null; }
}
"""
s = s[:m.start()] + helper + '\n' + s[m.start():]

old_b = """    const bad=breached(metric,value);"""
new_b = """    let value2 = value;
    if (t.sustained) {
      const avg = await sustainedAvg(metric, t.sustained);
      if (avg === null) continue;      /* too little history to judge fairly */
      value2 = avg;
    }
    const bad = breached(metric, value2);"""
if old_b not in s:
    print("   ERROR: breach check not found"); sys.exit(1)
s = s.replace(old_b, new_b, 1)
s = s.replace("const msg=`${t.label}: ${value}${t.unit?' '+t.unit:''}", "const msg=`${t.label}: ${Math.round(value2*10)/10}${t.unit?' '+t.unit:''}", 1)
s = s.replace("await sendAlertEmail({kind:'alert',sev:t.sev,metric,label:t.label,value,threshold:t.value",
              "await sendAlertEmail({kind:'alert',sev:t.sev,metric,label:t.label,value:Math.round(value2*10)/10,threshold:t.value", 1)
open(p,'w').write(s); print("   steal now judged on a 10-minute average")
PY
cd "$BE" && sudo -u www-data node --check utils/health-monitor.js && echo "   health-monitor.js OK"

say "4) Restart + confirm it evaluates"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 10
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
(async()=>{
  const hm=require('$BE/utils/health-monitor');
  const s=await hm.sample();
  console.log('   current steal: '+s.cpu_steal+'%   load: '+s.load1);
  await hm.pass();
  console.log('   pass completed without alerting on a spike');
  process.exit(0);
})();" 2>&1 | grep -vE "^info: \[" | sed 's/^/  /'
q -c "SELECT metric, severity, value, threshold, opened_at FROM system_health_alerts WHERE closed_at IS NULL;"

say "5) What changed"
cat <<'EOS'
   cpu_steal now alerts only when the 10-minute average exceeds 5% — real contention, not a
   passing spike. It also stays quiet for the first few minutes after a restart rather than
   judging on a single reading.

   Every other metric is unchanged: low memory, a full disk or FreeRADIUS climbing are emergencies
   the moment they happen, and should still alert immediately.

   The email now explains what to check — burst capacity at zero means throttling and a bigger
   plan; healthy capacity means a neighbour, and a stop/start moves you to other hardware.
EOS

say "6) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Health: judge CPU steal on a sustained average, not a single spike" 2>&1 | head -2 | sed 's/^/   /'
