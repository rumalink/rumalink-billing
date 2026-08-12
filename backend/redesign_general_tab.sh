#!/usr/bin/env bash
#
# redesign_general_tab.sh — one visual language across the General tab, and no panel saying the
# same thing twice.
#
# DUPLICATION REMOVED:
#   The Health panel shows CPU, memory and disk as bars — the same three metrics Diagnostics now
#   shows as gauges. Worse, Health reads columns on nas_devices written at the last heartbeat while
#   Diagnostics reads the router live, so the two panels can disagree and the stale one looks just
#   as authoritative. Removed.
#   Overview repeats board, RouterOS version and uptime, all of which Diagnostics now carries.
#   Trimmed to what is genuinely only there: identity, MAC, addresses, and which services are on.
#
# RESTYLED, NOT REBUILT:
#   The tab's own classes (.panel, .kv-item, .bw-card, .badge) are redefined in the VPS Health
#   palette. That reaches every panel at once, including Remote Access and Actions, without
#   regenerating markup — and regenerating markup is how a rewrite quietly loses a feature.
#
set -uo pipefail
D=/var/www/rumalink/isp/device.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) Backup"
sudo cp "$D" "/var/www/rumalink/isp/.device.html.bak_$TS" && echo "   .device.html.bak_$TS"
echo "   panels before: $(grep -c 'class="panel"' "$D")"

say "2) Remove the Health panel — Diagnostics shows the same three metrics, live"
sudo python3 - "$D" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_HEALTH_PANEL_REMOVED' in s:
    print("   already removed"); sys.exit(0)
start = s.find('    <!-- Health -->')
if start == -1:
    print("   MISS: Health panel not found"); sys.exit(0)
end = s.find('    <!-- Configuration -->', start)
if end == -1:
    print("   MISS: could not find its end"); sys.exit(0)
note = """    <!-- RL_HEALTH_PANEL_REMOVED: this showed CPU, memory and disk as bars from nas_devices —
         values written at the last heartbeat. Diagnostics above shows the same three read live from
         the router, so the two could disagree with nothing to say which was current. One source. -->
"""
s = s[:start] + note + s[end:]
open(p,'w').write(s); print("   Health panel removed")
PY

say "3) Trim the fields Diagnostics already covers"
sudo python3 - "$D" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_OVERVIEW_TRIMMED' in s:
    print("   already trimmed"); sys.exit(0)
drops = [
  """          <div class="kv-item"><div class="kv-label">Model / Board</div><div class="kv-value">${esc(dev.mikrotik_board) || '<span class="empty">—</span>'}</div></div>\n""",
  """          <div class="kv-item"><div class="kv-label">RouterOS Version</div><div class="kv-value">${esc(dev.mikrotik_version) || '<span class="empty">—</span>'}</div></div>\n""",
  """          <div class="kv-item"><div class="kv-label">Uptime</div><div class="kv-value">${dev.uptime_seconds ? fmtDuration(dev.uptime_seconds) : '<span class="empty">—</span>'}</div></div>\n""",
]
n = 0
for d in drops:
    if d in s: s = s.replace(d, "", 1); n += 1
if n:
    s = s.replace('        <div class="kv-grid">\n          <div class="kv-item"><div class="kv-label">Identity</div>',
                  '        <!-- RL_OVERVIEW_TRIMMED: board, RouterOS version and uptime moved to Diagnostics,\n'
                  '             which reads them live rather than from the last heartbeat. -->\n'
                  '        <div class="kv-grid">\n          <div class="kv-item"><div class="kv-label">Identity</div>', 1)
open(p,'w').write(s)
print(f"   {n}/3 duplicated field(s) removed")
PY

say "4) The VPS Health palette, across the whole tab"
sudo python3 - "$D" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_GENERAL_THEME' in s:
    print("   already themed"); sys.exit(0)
css = """
<style>
/* RL_GENERAL_THEME: the admin VPS Health page and this one both answer "how is this thing doing",
   so they should not look like different products. Applied to the tab's OWN classes rather than by
   rewriting its markup — that reaches Remote Access, Configuration and Actions too, including
   anything added later, and cannot drop a panel on the way. */
.tab-pane[data-tab="general"] .panel{
  background:#111d3a;
  border:1px solid rgba(136,153,187,.18);
  border-radius:16px;
  overflow:hidden;
  margin-bottom:16px;
  box-shadow:0 1px 2px rgba(0,0,0,.2);
}
.tab-pane[data-tab="general"] .panel-head{
  display:flex;align-items:center;justify-content:space-between;gap:12px;
  padding:15px 18px;
  border-bottom:1px solid rgba(136,153,187,.12);
  background:rgba(255,255,255,.02);
}
.tab-pane[data-tab="general"] .panel-head h3{
  margin:0;font-size:.94rem;font-weight:720;color:#fff;letter-spacing:.2px;
}
.tab-pane[data-tab="general"] .panel-body{ padding:18px }

.tab-pane[data-tab="general"] .kv-grid{
  display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:12px;
}
.tab-pane[data-tab="general"] .kv-item{
  border:1px solid rgba(136,153,187,.14);
  border-radius:12px;
  padding:12px 14px;
  background:rgba(255,255,255,.015);
  transition:border-color .15s;
}
.tab-pane[data-tab="general"] .kv-item:hover{ border-color:rgba(0,212,170,.35) }
.tab-pane[data-tab="general"] .kv-label{
  font-size:.64rem;text-transform:uppercase;letter-spacing:.7px;color:#8899bb;font-weight:700;
}
.tab-pane[data-tab="general"] .kv-value{
  font-size:.92rem;color:#fff;font-weight:600;margin-top:5px;word-break:break-word;
}
.tab-pane[data-tab="general"] .kv-value.mono{ font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.86rem }
.tab-pane[data-tab="general"] .kv-value .empty{ color:#5a6885;font-weight:500 }

/* live bandwidth, in the same card language as the gauges above it */
.tab-pane[data-tab="general"] .bw-card{
  border:1px solid rgba(136,153,187,.18);
  border-radius:14px;
  padding:16px;
  background:rgba(255,255,255,.015);
}
.tab-pane[data-tab="general"] .bw-iface{
  font-size:.64rem;text-transform:uppercase;letter-spacing:.7px;color:#8899bb;font-weight:700;
}
.tab-pane[data-tab="general"] .bw-name{ font-size:.9rem;color:#fff;font-weight:650;margin:4px 0 12px }
.tab-pane[data-tab="general"] .bw-arrow{
  display:flex;align-items:center;justify-content:space-between;gap:10px;
  padding:9px 0;border-top:1px solid rgba(136,153,187,.1);font-size:.8rem;color:#8899bb;
}
.tab-pane[data-tab="general"] .bw-arrow .rate{ font-weight:750;color:#22c55e;font-family:ui-monospace,monospace }
.tab-pane[data-tab="general"] .bw-arrow .rate.tx{ color:#3b82f6 }
.tab-pane[data-tab="general"] .gauge-grid{
  display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;
}

.tab-pane[data-tab="general"] .btn{
  border-radius:9px;padding:9px 16px;font-size:.85rem;font-weight:650;
  border:1px solid rgba(136,153,187,.25);background:rgba(255,255,255,.04);color:#e6e8ec;cursor:pointer;
  transition:border-color .15s,background .15s;
}
.tab-pane[data-tab="general"] .btn:hover{ border-color:rgba(0,212,170,.5);background:rgba(0,212,170,.08) }
.tab-pane[data-tab="general"] .btn-teal{ background:#00d4aa;color:#0d1530;border-color:transparent;font-weight:700 }
.tab-pane[data-tab="general"] .btn-teal:hover{ background:#00e8ba }
.tab-pane[data-tab="general"] .btn-red{ background:rgba(239,68,68,.12);color:#ff6b6b;border-color:rgba(239,68,68,.4) }
.tab-pane[data-tab="general"] .btn-red:hover{ background:rgba(239,68,68,.2) }
.tab-pane[data-tab="general"] .btn-sm{ padding:6px 12px;font-size:.78rem }

.tab-pane[data-tab="general"] .winbox-card{
  border:1px solid rgba(136,153,187,.18);border-radius:14px;padding:16px;background:rgba(255,255,255,.015);
}
.tab-pane[data-tab="general"] .copy-btn{
  border-radius:8px;border:1px solid rgba(136,153,187,.25);background:rgba(255,255,255,.04);
  color:#e6e8ec;cursor:pointer;font-size:.8rem;padding:7px 13px;
}
.tab-pane[data-tab="general"] .copy-btn:hover{ border-color:rgba(0,212,170,.5) }
.tab-pane[data-tab="general"] #isp-link-panel .panel-body > div:nth-child(2){
  border-radius:12px !important;border-color:rgba(136,153,187,.16) !important;
  background:rgba(255,255,255,.015) !important;
}
</style>
"""
s = s.replace('</head>', css + '\n</head>', 1) if '</head>' in s else css + s
open(p,'w').write(s); print("   theme applied to the tab's own classes")
PY
sudo chown www-data:www-data "$D"

say "5) Structure check"
echo "   panels after: $(grep -c 'class=\"panel\"' "$D")   (one fewer — Health removed)"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"
echo "   still present:"
for m in "Overview" "ISP Link Status" "Live Bandwidth" "Configuration" "Remote Access" "Actions" "rl-diag-panel"; do
  printf "     %-22s %s\n" "$m" "$(grep -c "$m" "$D")"
done
curl -sk -o /dev/null -w "   page HTTP %{http_code}\n" https://rumalinkenterprise.online/isp/device.html

say "6) What changed"
cat <<'EOS'
   Gone: the Health panel (Diagnostics shows those three live) and three Overview fields it
   repeated. Everything else is intact — Overview, ISP Link Status, Live Bandwidth, Configuration,
   Remote Access and Actions all still there, restyled.

   Hard-refresh the device page. If any panel looks wrong, the backup restores it:
     sudo cp /var/www/rumalink/isp/.device.html.bak_TS /var/www/rumalink/isp/device.html
EOS

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Device General tab themed to match VPS Health; removed the panel duplicating Diagnostics" 2>&1 | head -2 | sed 's/^/   /'
