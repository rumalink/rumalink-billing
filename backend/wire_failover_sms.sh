#!/usr/bin/env bash
#
# wire_failover_sms.sh — SMS the ISP owner when the router flips to the backup link and when
# the main link is restored.
#
# WHERE: mwan-applier.js already decides this (doPark = leave the degraded/dead primary for the
# backup; doUnpark = primary healthy again) and writes a nas_event. That INSERT sits OUTSIDE the
# `if (patched || doPark || doUnpark)` guard, so it fires on EVERY monitor pass — hence three
# identical wan_quality_recovered rows inside 40 seconds. Routing it through ispAlert.notify
# fixes both problems: the event is recorded only when the state actually changes, and the ISP
# is texted on that same transition.
#
# Total outage is NOT duplicated here — isp-monitor already owns isp_link_down / isp_link_up.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Backup"
sudo cp "$BE/utils/mwan-applier.js" "$BE/utils/.mwan-applier.js.bak_$TS" && echo "   mwan-applier.js"

say "2) Replace the spammy event INSERT with an edge-triggered notify"
sudo python3 - "$BE/utils/mwan-applier.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_FAILOVER_SMS' in s:
    print("   already patched"); sys.exit(0)

pat = re.compile(
  r'([ \t]*)try \{\s*\n\s*await query\(\s*\n\s*`INSERT INTO nas_events \(nas_id, isp_id, event_type, message, created_at\)'
  r'.*?\} catch\(e\)\{ /\* nas_events may differ; ignore \*/ \}', re.S)
m = pat.search(s)
if not m:
    print("   ERROR: nas_events insert block not matched — unchanged"); sys.exit(1)
ind = m.group(1)

NEW = (
f"{ind}/* RL_FAILOVER_SMS: this used to INSERT a nas_event on EVERY pass — three identical\n"
f"{ind}   'wan_quality_recovered' rows inside 40 seconds — and told the ISP nothing. A link could\n"
f"{ind}   flip to the backup uplink (often metered or slower) and the owner would only find out\n"
f"{ind}   from the bill or a customer. ispAlert.notify is edge-triggered: it records the event and\n"
f"{ind}   texts the account owner ONLY when the state actually changes. Total outage is not sent\n"
f"{ind}   from here — isp-monitor already owns isp_link_down / isp_link_up. */\n"
f"{ind}try {{\n"
f"{ind}  const _wanN = 'WAN' + link.position;\n"
f"{ind}  const _lat = Math.round(q.latencyMs || 0), _jit = Math.round(q.jitterMs || 0);\n"
f"{ind}  await require('./ispAlert').notify({{\n"
f"{ind}    nasId: dev.id, ispId: dev.isp_id,\n"
f"{ind}    kind: 'wan_failover_' + link.position,\n"
f"{ind}    state: doPark ? 'backup' : 'primary',\n"
f"{ind}    eventType: doPark ? 'wan_quality_degraded' : 'wan_quality_recovered',\n"
f"{ind}    message: doPark\n"
f"{ind}      ? '\\u26a0\\ufe0f RumaLink: \"' + dev.name + '\" switched to the BACKUP link. '\n"
f"{ind}        + _wanN + ' degraded (latency ' + _lat + 'ms, jitter ' + _jit + 'ms, loss ' + q.lossPct + '%). '\n"
f"{ind}        + 'Your customers stay online on the backup. We will text you when the main link returns.'\n"
f"{ind}      : '\\u2705 RumaLink: \"' + dev.name + '\" is back on its MAIN link (' + _wanN + '). '\n"
f"{ind}        + 'The backup uplink is no longer carrying traffic.'\n"
f"{ind}  }});\n"
f"{ind}}} catch(e) {{ logger.warn('[mwan-quality] failover alert: ' + e.message); }}"
)
s = s[:m.start()] + NEW + s[m.end():]
open(p,'w').write(s); print("   wired ispAlert into the failover transition")
PY
cd "$BE" && sudo -u www-data node --check utils/mwan-applier.js && echo "   mwan-applier.js syntax OK"
sudo grep -n "RL_FAILOVER_SMS" "$BE/utils/mwan-applier.js" | sed 's/^/   /'

say "3) Restart"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
pm2 logs rumalink-backend --lines 25 --nostream 2>/dev/null | grep -iE "error|mwan" | tail -4 | sed 's/^/   /' || echo "   clean"

say "4) Confirm the alert path works end to end (sends ONE real SMS)"
q -c "SELECT company_name, owner_name, phone FROM isps;"
read -r -p "   Send a test failover alert to the ISP owner's phone? (y/N): " GO || true
if [ "${GO:-n}" = "y" ] || [ "${GO:-n}" = "Y" ]; then
  sudo -u www-data node -e "
  require('dotenv').config({path:'$BE/.env'});
  const {query}=require('$BE/config/database');
  const alert=require('$BE/utils/ispAlert');
  (async()=>{
    const d=(await query('SELECT id, isp_id, name FROM nas_devices LIMIT 1')).rows[0];
    if(!d){console.log('   no device');process.exit(0);}
    // seed a baseline, then flip it so the edge trigger fires exactly once
    alert.seed(d.id,'wan_test','primary');
    const sent=await alert.notify({nasId:d.id,ispId:d.isp_id,kind:'wan_test',state:'backup',
      eventType:'wan_quality_degraded',
      message:'\u26a0\ufe0f RumaLink TEST: \"'+d.name+'\" switched to the BACKUP link. This is a test of your failover alerts.'});
    console.log('   sent: '+sent);
    const again=await alert.notify({nasId:d.id,ispId:d.isp_id,kind:'wan_test',state:'backup',
      eventType:'wan_quality_degraded',message:'duplicate that must NOT send'});
    console.log('   duplicate suppressed: '+(again===false));
    process.exit(0);
  })();" 2>&1 | grep -vE "^info: SMS" | sed 's/^/  /'
else echo "   skipped"; fi

say "5) Event noise should stop (was 3 identical rows in 40s)"
q -c "SELECT event_type, count(*), max(created_at) AS latest FROM nas_events
      WHERE created_at > now() - interval '1 hour' GROUP BY event_type ORDER BY 2 DESC;"
echo "   watch for a minute:"
sleep 60
q -c "SELECT event_type, count(*) FROM nas_events WHERE created_at > now() - interval '90 seconds' GROUP BY event_type;"
echo "   ${Y}0 rows here is correct — nothing changed, so nothing is recorded.${N}"

say "6) What each event means now"
cat <<'EOS'
   isp_link_down / isp_link_up      total internet loss + restore   (isp-monitor, already live)
   wan_quality_degraded             flipped to the BACKUP link      (new SMS)
   wan_quality_recovered            back on the MAIN link           (new SMS)
   All three go to the ISP account owner's phone from the isps table.
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "SMS the ISP owner on WAN failover and restore; stop per-pass nas_event spam" 2>&1 | head -2 | sed 's/^/   /'
