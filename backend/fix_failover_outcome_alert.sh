#!/usr/bin/env bash
#
# fix_failover_outcome_alert.sh — alert on the OUTCOME of a failover, not on one decision branch.
#
# WHY THE REAL FLIP WAS SILENT: the notify was wired into the QUALITY path (park a degraded
# primary). The actual event was a HARD DOWN — WAN1 lost its PPPoE address entirely
# ("Offline · no IP on interface"), which RL_HARDDOWN handles in a different branch that never
# reaches that code. Netwatch and manual changes are further branches again.
#
# FIX: after each device is monitored, read which link is actually CARRYING TRAFFIC from
# nas_wan_links and alert when that changes. One check covers every cause of a flip, present or
# future, because it observes the result rather than each path that can produce it.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Current link state — this is what the check will read"
q -c "SELECT n.name AS router, w.position, w.interface, w.role, w.current_status,
             w.is_active, w.internet_ok, w.quality_parked
      FROM nas_wan_links w JOIN nas_devices n ON n.id=w.nas_id WHERE w.enabled=true ORDER BY w.position;"

say "2) Backup"
sudo cp "$BE/utils/mwan-applier.js" "$BE/utils/.mwan-applier.js.bak_$TS" && echo "   mwan-applier.js"

say "3) Add the outcome check to monitorAll"
sudo python3 - "$BE/utils/mwan-applier.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_FAILOVER_OUTCOME' in s:
    print("   already patched"); sys.exit(0)

pat = re.compile(r'([ \t]*)try \{ await monitorDevice\(row\.id\); \} catch \(e\) \{ logger\.warn\(`\[mwan-monitor\] device \$\{row\.id\}: \$\{e\.message\}`\); \}')
m = pat.search(s)
if not m:
    print("   ERROR: monitorAll anchor not found — unchanged"); sys.exit(1)
ind = m.group(1)

NEW = (
f"{ind}try {{ await monitorDevice(row.id); }} catch (e) {{ logger.warn(`[mwan-monitor] device ${{row.id}}: ${{e.message}}`); }}\n"
f"{ind}/* RL_FAILOVER_OUTCOME: alert on WHICH LINK IS CARRYING TRAFFIC, not on one decision branch.\n"
f"{ind}   The first attempt hooked the quality path (park a degraded primary) and stayed silent on a\n"
f"{ind}   real flip, because that one was a hard down — the primary lost its address entirely and\n"
f"{ind}   RL_HARDDOWN handles it elsewhere. Netwatch and manual changes are further branches again.\n"
f"{ind}   Reading the outcome covers every cause, including ones not yet written. */\n"
f"{ind}try {{\n"
f"{ind}  const _ls = await query(\n"
f"{ind}    \"SELECT position, interface, role, current_status, is_active, internet_ok \" +\n"
f"{ind}    \"FROM nas_wan_links WHERE nas_id=$1::uuid AND enabled=true ORDER BY position ASC\", [row.id]);\n"
f"{ind}  const _links = _ls.rows || [];\n"
f"{ind}  const _carrying = _links.filter(l => l.is_active === true || String(l.current_status) === 'online');\n"
f"{ind}  const _primary  = _links.find(l => String(l.role) === 'failover_primary');\n"
f"{ind}  const _state = _carrying.length ? _carrying.map(l => 'wan' + l.position).join('+') : 'none';\n"
f"{ind}  if (_links.length > 1 && _state !== 'none') {{\n"
f"{ind}    const _onPrimary = !!(_primary && _carrying.some(l => l.position === _primary.position));\n"
f"{ind}    const _dv = await query('SELECT name, isp_id FROM nas_devices WHERE id=$1::uuid', [row.id]);\n"
f"{ind}    const _d = _dv.rows[0];\n"
f"{ind}    if (_d) {{\n"
f"{ind}      const _names = _carrying.map(l => 'WAN' + l.position + ' (' + l.interface + ')').join(' + ');\n"
f"{ind}      await require('./ispAlert').notify({{\n"
f"{ind}        nasId: row.id, ispId: _d.isp_id, kind: 'wan_carrying', state: _state,\n"
f"{ind}        eventType: _onPrimary ? 'wan_quality_recovered' : 'wan_quality_degraded',\n"
f"{ind}        message: _onPrimary\n"
f"{ind}          ? '\\u2705 RumaLink: \"' + _d.name + '\" is back on its MAIN link \\u2014 ' + _names\n"
f"{ind}            + '. The backup uplink is no longer carrying traffic.'\n"
f"{ind}          : '\\u26a0\\ufe0f RumaLink: \"' + _d.name + '\" has switched to the BACKUP link \\u2014 now on '\n"
f"{ind}            + _names + '. The main link is down or degraded. Your customers stay online on the '\n"
f"{ind}            + 'backup; we will text you when the main link returns.'\n"
f"{ind}      }});\n"
f"{ind}    }}\n"
f"{ind}  }}\n"
f"{ind}}} catch (e) {{ logger.warn('[mwan-monitor] failover alert: ' + e.message); }}"
)
s = s[:m.start()] + NEW + s[m.end():]
open(p,'w').write(s); print("   outcome-based failover alert added to monitorAll")
PY
cd "$BE" && sudo -u www-data node --check utils/mwan-applier.js && echo "   mwan-applier.js syntax OK"
sudo grep -n "RL_FAILOVER_OUTCOME" "$BE/utils/mwan-applier.js" | sed 's/^/   /'

say "4) Restart and let one pass establish the baseline"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1
echo "   waiting 70s for a monitor pass..."
sleep 70
pm2 logs rumalink-backend --lines 60 --nostream 2>/dev/null | grep -iE "isp-alert|mwan-monitor|failover" | tail -6 | sed 's/^/   /' || echo "   (baseline set, nothing to report — correct)"

say "5) Current state after the baseline pass"
q -c "SELECT position, interface, role, current_status, is_active, internet_ok FROM nas_wan_links WHERE enabled=true ORDER BY position;"
q -c "SELECT event_type, message, created_at FROM nas_events ORDER BY created_at DESC LIMIT 5;"

say "6) How to test for real"
cat <<'EOS'
   The baseline is now whichever link is carrying traffic. To test:
     unplug / disable the link that is currently ACTIVE, wait ~1-2 monitor passes
       -> SMS: switched to the BACKUP link
     plug it back in, wait for it to recover
       -> SMS: back on its MAIN link

   Watch live:
     pm2 logs rumalink-backend | grep -iE "isp-alert|mwan-monitor"
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Failover SMS: alert on which link carries traffic, covering hard-down and netwatch flips" 2>&1 | head -2 | sed 's/^/   /'
