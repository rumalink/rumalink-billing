#!/usr/bin/env bash
#
# fix_quality_park_release.sh — turning quality failover OFF must release links it had parked.
#
# WAN1 sat parked with quality_state='degraded' and consec_degraded=76 while measuring 36ms, 7.3ms
# jitter and 0% loss — because quality failover parked it legitimately, was then switched off, and
# the flag froze. Line 1085 skips the whole quality block when the feature is disabled, so nothing
# re-evaluates that link and nothing can un-park it. Customers ran on the backup while a healthy
# 233 Mbps primary sat in standby.
#
# Skipping a disabled feature is right; leaving its side effects behind is not. Disabling it must
# also undo what it did — otherwise the natural reaction to a failover problem (turn it off) is
# exactly what strands the link. The comments at lines 1169 and 1256 record two earlier rounds of
# the same symptom, so this is the third.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) State before"
q -c "SELECT position, name, current_status, is_active, quality_parked, quality_state, consec_degraded, consec_good FROM nas_wan_links ORDER BY position;"
q -c "SELECT name, wan_quality_enabled FROM nas_devices;"

say "2) The guard as it stands"
sudo sed -n '1080,1090p' "$BE/utils/mwan-applier.js" | nl -ba -v1080 | sed 's/^/   /'

say "3) Backup"
sudo cp "$BE/utils/mwan-applier.js" "$BE/utils/.mwan-applier.js.bak_$TS" && echo "   mwan-applier.js"

say "4) Release parked links when the feature is off"
sudo python3 - "$BE/utils/mwan-applier.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_QUALITY_RELEASE' in s:
    print("   already patched"); sys.exit(0)

m = re.search(r'^([ \t]*)if \(dev\.wan_quality_enabled !== false && !_lbOnly\) \{', s, re.M)
if not m:
    print("   ERROR: quality guard not found"); sys.exit(1)
ind = m.group(1)

release = (
f"{ind}/* RL_QUALITY_RELEASE: skipping the quality block when the feature is disabled is correct, but\n"
f"{ind}   it left behind whatever the feature had already done. A link parked while quality failover\n"
f"{ind}   was on stayed parked forever once it was switched off, because nothing re-evaluated it —\n"
f"{ind}   WAN1 sat in standby at 36ms and 0% loss while customers used the backup. Turning a feature\n"
f"{ind}   off has to undo its effects, or the obvious response to a failover problem is the thing\n"
f"{ind}   that strands the link. */\n"
f"{ind}if (dev.wan_quality_enabled === false) {{\n"
f"{ind}  try {{\n"
f"{ind}    const stuck = await query(\n"
f"{ind}      \"SELECT id, name FROM nas_wan_links WHERE nas_id = $1::uuid AND quality_parked = true\",\n"
f"{ind}      [dev.id]);\n"
f"{ind}    for (const l of stuck.rows) {{\n"
f"{ind}      await query(\n"
f"{ind}        \"UPDATE nas_wan_links SET quality_parked=false, quality_state='good', \" +\n"
f"{ind}        \"consec_degraded=0, consec_good=0, sample_history='' WHERE id=$1::uuid\", [l.id]);\n"
f"{ind}      logger.info('[mwan] ' + dev.name + ': released ' + l.name +\n"
f"{ind}        ' from quality park — quality failover is disabled, so the link returns to normal routing');\n"
f"{ind}    }}\n"
f"{ind}  }} catch (e) {{ logger.warn('[mwan] quality release: ' + e.message); }}\n"
f"{ind}}}\n\n"
)
s = s[:m.start()] + release + s[m.start():]
open(p,'w').write(s); print("   disabling the feature now releases parked links")
PY
cd "$BE" && sudo -u www-data node --check utils/mwan-applier.js && echo "   mwan-applier.js OK"

say "5) Release the one that is stuck now"
q -c "UPDATE nas_wan_links SET quality_parked=false, quality_state='good', consec_degraded=0, consec_good=0, sample_history=''
      WHERE quality_parked = true RETURNING name, quality_parked, quality_state;"

say "6) Restart and let the applier reconcile"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1
echo "   waiting 100s for a monitor pass..."
sleep 100
pm2 logs rumalink-backend --lines 60 --nostream 2>/dev/null | grep -iE "mwan|released|park" | tail -8 | sed 's/^/   /' || echo "   (no mwan activity logged)"

say "7) State after"
q -c "SELECT position, name, current_status, is_active, quality_parked, quality_state, last_latency_ms, last_loss_pct FROM nas_wan_links ORDER BY position;"
echo "   ${Y}is_active should now be true on position 1 — the primary carrying traffic again${N}"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{const d=(await query('SELECT wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE is_online=true LIMIT 1')).rows[0];
const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
const r=(await axios.get(b+'/ip/route',{auth,timeout:15000})).data||[];
console.log('   default routes on the router:');
r.filter(x=>String(x['dst-address']||'')==='0.0.0.0/0').forEach(x=>
  console.log('     gw='+(x.gateway||'?')+' distance='+(x.distance||'?')+' active='+(x.active||'false')+' '+(x.comment||'')));
process.exit(0)})();" 2>&1 | grep -v "^info:"

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Disabling quality failover releases links it had parked, instead of stranding them in standby" 2>&1 | head -2 | sed 's/^/   /'
