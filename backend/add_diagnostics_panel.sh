#!/usr/bin/env bash
#
# add_diagnostics_panel.sh — the Diagnostics panel, in the VPS Health visual language.
#
# Sits above Overview and leaves everything already on the page untouched. Radial gauges for CPU,
# memory, disk and temperature; metric cards for sessions, queues and interfaces; and the five
# configuration checks as a pass/fail row.
#
# The checks are the reason this panel exists. "Online" only says the router answers. Every
# expensive fault today was a router that answered perfectly while quietly doing the wrong thing —
# fasttrack bypassing the queues, shared-users overriding RADIUS, an accept rule above the expiry
# rules. Those are now visible on the page instead of requiring somebody to go and ask the API.
#
set -uo pipefail
D=/var/www/rumalink/isp/device.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }

say "1) Backup"
sudo cp "$D" "/var/www/rumalink/isp/.device.html.bak_$TS" && echo "   .device.html.bak_$TS"

say "2) Insert the panel above Overview"
sudo python3 - "$D" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'rl-diag' in s:
    print("   already present"); sys.exit(0)
anchor = """    <div class="tab-pane active" data-tab="general">
    <!-- Overview -->"""
if anchor not in s:
    print("   ERROR: general tab anchor not found"); sys.exit(1)
panel = """    <div class="tab-pane active" data-tab="general">

    <!-- RL_DIAG: live health, read from the router rather than from what we stored about it -->
    <div class="panel" id="rl-diag-panel">
      <div class="panel-head">
        <h3>🩺 Diagnostics</h3>
        <div style="display:flex;align-items:center;gap:10px">
          <span id="rl-diag-when" style="font-size:.72rem;color:#8899bb"></span>
          <button class="btn btn-sm btn-outline" onclick="loadDiag(true)">↻ Refresh</button>
        </div>
      </div>
      <div class="panel-body">
        <div id="rl-diag-hero" class="rl-diag-hero">
          <div class="rl-diag-pulse"></div>
          <div>
            <div class="rl-diag-title" id="rl-diag-title">Reading router…</div>
            <div class="rl-diag-sub" id="rl-diag-sub">Asking the device how it is doing</div>
          </div>
          <div class="rl-diag-right" id="rl-diag-right"></div>
        </div>
        <div class="rl-diag-gauges" id="rl-diag-gauges"></div>
        <div class="rl-diag-mini" id="rl-diag-mini"></div>
        <div class="rl-diag-checks" id="rl-diag-checks"></div>
      </div>
    </div>

    <!-- Overview -->"""
s = s.replace(anchor, panel, 1)
open(p,'w').write(s); print("   panel markup inserted")
PY

say "3) Styling, matched to VPS Health"
sudo python3 - "$D" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_DIAG_CSS' in s:
    print("   already present"); sys.exit(0)
css = """
<style>
/* RL_DIAG_CSS: same visual language as the admin VPS Health page — one look for "how is this
   thing doing", whether the thing is the server or a router. */
.rl-diag-hero{display:flex;align-items:center;gap:16px;padding:16px 18px;border-radius:14px;margin-bottom:16px;
  border:1px solid rgba(136,153,187,.18);background:linear-gradient(135deg,rgba(34,197,94,.07),transparent 60%)}
.rl-diag-hero.warning{background:linear-gradient(135deg,rgba(245,158,11,.10),transparent 60%);border-color:rgba(245,158,11,.45)}
.rl-diag-hero.critical{background:linear-gradient(135deg,rgba(239,68,68,.12),transparent 60%);border-color:rgba(239,68,68,.5)}
.rl-diag-pulse{width:13px;height:13px;border-radius:50%;background:#22c55e;flex:0 0 auto;animation:rlp 2.4s infinite}
.rl-diag-hero.warning .rl-diag-pulse{background:#f59e0b}
.rl-diag-hero.critical .rl-diag-pulse{background:#ef4444;animation-duration:1.1s}
@keyframes rlp{0%{opacity:1}70%{opacity:.45}100%{opacity:1}}
.rl-diag-title{font-size:1.05rem;font-weight:750;color:#fff}
.rl-diag-sub{font-size:.8rem;color:#8899bb;margin-top:3px}
.rl-diag-right{margin-left:auto;text-align:right;font-size:.74rem;color:#8899bb;line-height:1.7}
.rl-diag-gauges{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin-bottom:16px}
.rl-diag-g{border:1px solid rgba(136,153,187,.18);border-radius:14px;padding:14px 10px 12px;text-align:center}
.rl-diag-g.warning{border-color:rgba(245,158,11,.5)}
.rl-diag-g.critical{border-color:rgba(239,68,68,.55)}
.rl-diag-g-wrap{position:relative;width:112px;height:112px;margin:0 auto 6px}
.rl-diag-g svg{width:112px;height:112px;transform:rotate(-90deg)}
.rl-diag-g circle{fill:none;stroke-width:8;stroke-linecap:round}
.rl-diag-g .bg{stroke:rgba(136,153,187,.16)}
.rl-diag-g-c{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
.rl-diag-g-v{font-size:1.35rem;font-weight:780;line-height:1}
.rl-diag-g-v small{font-size:.62rem;font-weight:600;opacity:.6;margin-left:2px}
.rl-diag-g-l{font-size:.76rem;font-weight:700;margin-top:2px;color:#fff}
.rl-diag-g-s{font-size:.66rem;color:#8899bb;margin-top:2px}
.rl-diag-mini{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:10px;margin-bottom:16px}
.rl-diag-m{border:1px solid rgba(136,153,187,.18);border-radius:12px;padding:11px 13px}
.rl-diag-m-k{font-size:.62rem;text-transform:uppercase;letter-spacing:.6px;color:#8899bb;font-weight:700}
.rl-diag-m-v{font-size:1.25rem;font-weight:750;margin-top:4px;color:#fff}
.rl-diag-m-v small{font-size:.62rem;opacity:.55;font-weight:600;margin-left:3px}
.rl-diag-checks{display:flex;flex-direction:column;gap:7px}
.rl-diag-c{display:flex;align-items:flex-start;gap:10px;padding:10px 12px;border-radius:10px;
  border:1px solid rgba(136,153,187,.16);font-size:.84rem}
.rl-diag-c.bad{border-color:rgba(239,68,68,.45);background:rgba(239,68,68,.06)}
.rl-diag-c-ic{flex:0 0 auto;font-weight:800}
.rl-diag-c.ok .rl-diag-c-ic{color:#22c55e}
.rl-diag-c.bad .rl-diag-c-ic{color:#ef4444}
.rl-diag-c-l{font-weight:650;color:#fff}
.rl-diag-c-d{font-size:.76rem;color:#8899bb;margin-top:2px}
</style>
"""
s = s.replace('</head>', css + '\n</head>', 1) if '</head>' in s else css + s
open(p,'w').write(s); print("   styles added")
PY

say "4) The loader"
sudo python3 - "$D" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_DIAG_JS' in s:
    print("   already present"); sys.exit(0)
JS = """
<script>
/* RL_DIAG_JS: reads /nas/:id/health. Refresh asks for a fresh read; otherwise the server answers
   from a short cache, because a router's health does not change between two clicks and a page
   that waits on the API is a page nobody opens. */
(function(){
  var C = 2 * Math.PI * 48;
  function sev(v, warn, crit){ return v >= crit ? 'critical' : v >= warn ? 'warning' : 'ok'; }
  function col(s2){ return s2 === 'critical' ? '#ef4444' : s2 === 'warning' ? '#f59e0b' : '#22c55e'; }
  function gauge(o){
    var pct = Math.max(0, Math.min(1, o.pct)), c = col(o.sev);
    return '<div class="rl-diag-g ' + o.sev + '"><div class="rl-diag-g-wrap"><svg viewBox="0 0 112 112">' +
      '<circle class="bg" cx="56" cy="56" r="48"></circle>' +
      '<circle cx="56" cy="56" r="48" stroke="' + c + '" stroke-dasharray="' + C.toFixed(1) +
      '" stroke-dashoffset="' + (C * (1 - pct)).toFixed(1) + '"></circle></svg>' +
      '<div class="rl-diag-g-c"><div class="rl-diag-g-v" style="color:' + c + '">' + o.val +
      '<small>' + (o.unit || '') + '</small></div></div></div>' +
      '<div class="rl-diag-g-l">' + o.label + '</div><div class="rl-diag-g-s">' + o.sub + '</div></div>';
  }
  window.loadDiag = async function(fresh){
    var hero = document.getElementById('rl-diag-hero');
    if (!hero) return;
    try {
      var d = await api('/nas/' + encodeURIComponent(deviceId) + '/health' + (fresh ? '?fresh=1' : ''));
      if (!d.reachable) {
        hero.className = 'rl-diag-hero critical';
        document.getElementById('rl-diag-title').textContent = 'Router not answering';
        document.getElementById('rl-diag-sub').textContent = d.reason || 'No response over the tunnel';
        document.getElementById('rl-diag-gauges').innerHTML = '';
        document.getElementById('rl-diag-mini').innerHTML = '';
        document.getElementById('rl-diag-checks').innerHTML = '';
        return;
      }
      var sy = d.system, sv = d.services, failed = (d.checks || []).filter(function(c){ return !c.ok; });
      hero.className = 'rl-diag-hero ' + (failed.length ? 'warning' : 'ok');
      document.getElementById('rl-diag-title').textContent =
        failed.length ? (failed.length + ' configuration issue' + (failed.length > 1 ? 's' : '')) : 'Router healthy';
      /* name what is wrong rather than saying "issues found" — the point is to act on it */
      document.getElementById('rl-diag-sub').textContent =
        failed.length ? failed.map(function(c){ return c.label; }).join(' · ')
                      : 'All checks passed. ' + (sy.board || 'Router') + ' on RouterOS ' + (sy.version || '?');
      document.getElementById('rl-diag-right').innerHTML =
        'Uptime ' + (sy.uptime || '—') + '<br>' + sv.interfaces_up + ' of ' + sv.interfaces_total + ' interfaces up';
      document.getElementById('rl-diag-when').textContent =
        'read ' + new Date(d.fetched_at).toLocaleTimeString();

      var g = [
        gauge({ pct: sy.cpu_load / 100, val: sy.cpu_load, unit: '%', label: 'CPU', sub: (sy.cpu_count || 1) + ' core(s)', sev: sev(sy.cpu_load, 60, 85) }),
        gauge({ pct: sy.mem_used_pct / 100, val: sy.mem_free_mb, unit: 'MB', label: 'Memory free', sub: 'of ' + sy.mem_total_mb + ' MB', sev: sev(sy.mem_used_pct, 75, 90) }),
        gauge({ pct: sy.disk_used_pct / 100, val: sy.disk_used_pct, unit: '%', label: 'Disk used', sub: sy.disk_free_mb + ' MB free', sev: sev(sy.disk_used_pct, 75, 90) })
      ];
      if (sy.temperature != null) {
        var t = Number(sy.temperature);
        g.push(gauge({ pct: t / 90, val: t, unit: '°C', label: 'Temperature', sub: 'CPU', sev: sev(t, 65, 80) }));
      }
      document.getElementById('rl-diag-gauges').innerHTML = g.join('');

      document.getElementById('rl-diag-mini').innerHTML = [
        { k: 'Hotspot sessions', v: sv.hotspot_sessions },
        { k: 'PPPoE sessions', v: sv.pppoe_sessions },
        { k: 'Active queues', v: sv.queues },
        { k: 'RouterOS', v: sy.version || '—' }
      ].map(function(m){
        return '<div class="rl-diag-m"><div class="rl-diag-m-k">' + m.k + '</div>' +
               '<div class="rl-diag-m-v">' + m.v + '</div></div>';
      }).join('');

      document.getElementById('rl-diag-checks').innerHTML = (d.checks || []).map(function(c){
        return '<div class="rl-diag-c ' + (c.ok ? 'ok' : 'bad') + '">' +
               '<span class="rl-diag-c-ic">' + (c.ok ? '✓' : '!') + '</span>' +
               '<div><div class="rl-diag-c-l">' + c.label + '</div>' +
               '<div class="rl-diag-c-d">' + c.detail + '</div></div></div>';
      }).join('');
    } catch (e) {
      hero.className = 'rl-diag-hero critical';
      document.getElementById('rl-diag-title').textContent = 'Could not read the router';
      document.getElementById('rl-diag-sub').textContent = e.message;
    }
  };
})();
</script>
"""
s = s.replace('</body>', JS + '\n</body>', 1) if '</body>' in s else s + JS
old = "    startBwPolling();"
if old in s:
    s = s.replace(old, old + "\n    if (typeof loadDiag === 'function') loadDiag(false);", 1)
    print("   wired into loadDevice")
open(p,'w').write(s); print("   loader added")
PY
sudo chown www-data:www-data "$D"
echo "   div balance: $(( $(grep -o '<div' "$D" | wc -l) - $(grep -o '</div>' "$D" | wc -l) ))"
echo "   script pairs: $(grep -o '<script' "$D" | wc -l) / $(grep -o '</script>' "$D" | wc -l)"
echo "   markers: $(grep -c 'RL_DIAG_CSS' "$D") css | $(grep -c 'RL_DIAG_JS' "$D") js | $(grep -c 'rl-diag-panel' "$D") panel"

say "5) Check"
curl -sk -o /dev/null -w "   device page HTTP %{http_code}\n" https://rumalinkenterprise.online/isp/device.html
cat <<'EOS'
   Open a MikroTik from the ISP dashboard. Diagnostics sits above Overview:
     gauges for CPU, memory, disk and temperature (your RB5009 reports 44°C)
     sessions, queues and RouterOS version
     the five checks, each green or flagged with what is wrong
   Refresh forces a live read; otherwise it comes from a 20s cache.
EOS

say "6) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Device page: Diagnostics panel with live router health and configuration checks" 2>&1 | head -2 | sed 's/^/   /'
