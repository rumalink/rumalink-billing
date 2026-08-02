#!/usr/bin/env bash
# restore_health_ui.sh — rebuild the VPS Health page inside the admin dashboard.
# Adds: nav item under Monitoring, the gauge/chart page, and the alerts card.
# Verifies div balance before and after; rolls back automatically if unbalanced.
set -uo pipefail
F=/var/www/rumalink/admin/dashboard.html
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
bal(){ local o c; o=$(grep -o '<div' "$1" | wc -l); c=$(grep -o '</div>' "$1" | wc -l); echo "$((o-c))"; }

say "0) Backup + baseline balance"
sudo cp "$F" "/var/www/rumalink/admin/.dashboard.html.bak_$TS" && echo "   backup: .dashboard.html.bak_$TS"
B0=$(bal "$F"); echo "   div balance before: $B0"
echo "   already present? $(sudo grep -c 'vps-health' "$F" || true)"

say "1) Insert nav item, page markup and loader"
sudo python3 - "$F" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'page-vps-health' in s:
    print("   already present — nothing to do"); sys.exit(0)

# --- nav item, after All Devices ---
m = re.search(r'(<div class="nav-item" data-page="devices">.*?</div>)', s, re.S)
if not m: print("   ERROR: devices nav item not found"); sys.exit(1)
nav = ('\n      <div class="nav-item" data-page="vps-health">'
       '<span class="icon">&#128421;</span> VPS Health '
       '<span id="vh-dot" style="width:8px;height:8px;border-radius:50%;background:#22c55e;'
       'display:inline-block;margin-left:6px;vertical-align:middle"></span></div>')
s = s.replace(m.group(1), m.group(1) + nav, 1)

# --- title mapping ---
if "isps:'All ISPs'" in s:
    s = s.replace("isps:'All ISPs'", "isps:'All ISPs','vps-health':'VPS Health'", 1)

PAGE = """<div class="page" id="page-vps-health">
<style>
#page-vps-health{--ok:#22c55e;--warn:#f59e0b;--crit:#ef4444;--ring:rgba(148,163,184,.14);--sub:rgba(148,163,184,.75)}
#page-vps-health .vh-hero{display:flex;align-items:center;gap:18px;padding:20px 22px;border-radius:16px;margin-bottom:18px;border:1px solid var(--ring);background:linear-gradient(135deg,rgba(34,197,94,.07),transparent 60%)}
#page-vps-health .vh-hero.warning{background:linear-gradient(135deg,rgba(245,158,11,.10),transparent 60%);border-color:rgba(245,158,11,.45)}
#page-vps-health .vh-hero.critical{background:linear-gradient(135deg,rgba(239,68,68,.12),transparent 60%);border-color:rgba(239,68,68,.5)}
#page-vps-health .vh-pulse{width:14px;height:14px;border-radius:50%;background:var(--ok);flex:0 0 auto;animation:vhp 2.4s infinite}
#page-vps-health .vh-hero.warning .vh-pulse{background:var(--warn)}
#page-vps-health .vh-hero.critical .vh-pulse{background:var(--crit);animation-duration:1.1s}
@keyframes vhp{0%{opacity:1}70%{opacity:.5}100%{opacity:1}}
#page-vps-health .vh-hero-t{font-size:1.15rem;font-weight:750}
#page-vps-health .vh-hero-s{font-size:.82rem;color:var(--sub);margin-top:3px}
#page-vps-health .vh-hero-r{margin-left:auto;text-align:right;font-size:.75rem;color:var(--sub);line-height:1.7}
#page-vps-health .vh-gauges{display:grid;grid-template-columns:repeat(auto-fit,minmax(168px,1fr));gap:14px;margin-bottom:18px}
#page-vps-health .vh-g{border:1px solid var(--ring);border-radius:16px;padding:16px 12px 14px;text-align:center}
#page-vps-health .vh-g.warning{border-color:rgba(245,158,11,.5)}
#page-vps-health .vh-g.critical{border-color:rgba(239,68,68,.55)}
#page-vps-health .vh-g-wrap{position:relative;width:126px;height:126px;margin:0 auto 8px}
#page-vps-health .vh-g svg{width:126px;height:126px;transform:rotate(-90deg)}
#page-vps-health .vh-g circle{fill:none;stroke-width:9;stroke-linecap:round}
#page-vps-health .vh-g .bg{stroke:var(--ring)}
#page-vps-health .vh-g-c{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
#page-vps-health .vh-g-v{font-size:1.55rem;font-weight:780;line-height:1}
#page-vps-health .vh-g-v span{font-size:.68rem;font-weight:600;opacity:.6;margin-left:2px}
#page-vps-health .vh-g-p{font-size:.66rem;color:var(--sub);margin-top:3px;font-weight:600}
#page-vps-health .vh-g-l{font-size:.8rem;font-weight:700;margin-top:2px}
#page-vps-health .vh-g-s{font-size:.68rem;color:var(--sub);margin-top:2px}
#page-vps-health .vh-mini{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin-bottom:18px}
#page-vps-health .vh-m{border:1px solid var(--ring);border-radius:13px;padding:13px 14px}
#page-vps-health .vh-m-k{font-size:.64rem;text-transform:uppercase;letter-spacing:.7px;color:var(--sub);font-weight:700}
#page-vps-health .vh-m-v{font-size:1.35rem;font-weight:750;margin-top:5px}
#page-vps-health .vh-m-v small{font-size:.66rem;opacity:.55;font-weight:600;margin-left:2px}
#page-vps-health .vh-m-bar{height:3px;border-radius:2px;background:var(--ring);margin-top:9px;overflow:hidden}
#page-vps-health .vh-m-bar i{display:block;height:100%;border-radius:2px;transition:width .5s}
#page-vps-health .vh-charts{display:grid;grid-template-columns:1fr 1fr;gap:14px}
@media(max-width:900px){#page-vps-health .vh-charts{grid-template-columns:1fr}}
#page-vps-health .vh-ch{border:1px solid var(--ring);border-radius:16px;padding:16px}
#page-vps-health .vh-ch-h{display:flex;align-items:baseline;gap:8px;margin-bottom:10px}
#page-vps-health .vh-ch-t{font-size:.86rem;font-weight:700}
#page-vps-health .vh-ch-n{font-size:.68rem;color:var(--sub);margin-left:auto}
#page-vps-health .vh-ch svg{width:100%;height:150px;display:block}
#page-vps-health .vh-acard{border:1px solid var(--ring);border-radius:16px;padding:16px;margin-top:18px}
#page-vps-health .vh-ahead{display:flex;align-items:center;gap:10px;margin-bottom:14px}
#page-vps-health .vh-atitle{font-size:.86rem;font-weight:700}
#page-vps-health .vh-badge{font-size:.62rem;font-weight:800;padding:3px 9px;border-radius:20px;background:rgba(34,197,94,.16);color:var(--ok)}
#page-vps-health .vh-badge.has{background:rgba(239,68,68,.16);color:var(--crit)}
#page-vps-health .vh-badge.warn{background:rgba(245,158,11,.16);color:var(--warn)}
#page-vps-health .vh-anote{margin-left:auto;font-size:.68rem;color:var(--sub)}
#page-vps-health .vh-a{display:flex;gap:13px;padding:14px;border-radius:13px;margin-bottom:10px;border:1px solid var(--ring);position:relative;overflow:hidden}
#page-vps-health .vh-a:before{content:'';position:absolute;left:0;top:0;bottom:0;width:3px}
#page-vps-health .vh-a.critical:before{background:var(--crit)}
#page-vps-health .vh-a.warning:before{background:var(--warn)}
#page-vps-health .vh-a-ic{width:32px;height:32px;border-radius:9px;display:flex;align-items:center;justify-content:center;font-weight:800;flex:0 0 auto}
#page-vps-health .vh-a.critical .vh-a-ic{background:rgba(239,68,68,.15);color:var(--crit)}
#page-vps-health .vh-a.warning .vh-a-ic{background:rgba(245,158,11,.15);color:var(--warn)}
#page-vps-health .vh-a-body{flex:1;min-width:0}
#page-vps-health .vh-a-top{display:flex;align-items:center;gap:9px;flex-wrap:wrap}
#page-vps-health .vh-a-name{font-size:.86rem;font-weight:700}
#page-vps-health .vh-a-time{margin-left:auto;font-size:.66rem;color:var(--sub)}
#page-vps-health .vh-a-msg{font-size:.78rem;color:var(--sub);margin-top:5px;line-height:1.5}
#page-vps-health .vh-a-meter{display:flex;align-items:center;gap:9px;margin-top:9px}
#page-vps-health .vh-a-track{flex:1;height:4px;border-radius:2px;background:var(--ring);overflow:hidden}
#page-vps-health .vh-a-track i{display:block;height:100%;border-radius:2px}
#page-vps-health .vh-a-nums{font-size:.66rem;color:var(--sub)}
#page-vps-health .vh-sev{padding:3px 9px;border-radius:20px;font-size:.62rem;font-weight:800;text-transform:uppercase}
#page-vps-health .vh-sev.critical{background:rgba(239,68,68,.16);color:var(--crit)}
#page-vps-health .vh-sev.warning{background:rgba(245,158,11,.16);color:var(--warn)}
#page-vps-health .vh-clear{text-align:center;padding:26px 16px}
#page-vps-health .vh-clear-ic{width:46px;height:46px;margin:0 auto 11px;border-radius:50%;background:rgba(34,197,94,.13);color:var(--ok);display:flex;align-items:center;justify-content:center;font-size:1.4rem}
#page-vps-health .vh-clear-t{font-size:.95rem;font-weight:750}
#page-vps-health .vh-clear-s{font-size:.76rem;color:var(--sub);margin-top:4px}
#page-vps-health .vh-chips{display:flex;flex-wrap:wrap;gap:7px;margin-top:15px;padding-top:14px;border-top:1px solid var(--ring)}
#page-vps-health .vh-chip{display:flex;align-items:center;gap:6px;padding:5px 10px;border-radius:20px;border:1px solid var(--ring);font-size:.68rem;color:var(--sub)}
#page-vps-health .vh-chip b{width:6px;height:6px;border-radius:50%;background:var(--ok);display:inline-block}
#page-vps-health .vh-chip.warning b{background:var(--warn)}
#page-vps-health .vh-chip.critical b{background:var(--crit)}
</style>
<div class="vh-hero" id="vh-hero">
  <div class="vh-pulse" id="vh-pulse"></div>
  <div><div class="vh-hero-t" id="vh-hero-t">Loading server health...</div>
  <div class="vh-hero-s" id="vh-hero-s">Reading metrics from the host</div></div>
  <div class="vh-hero-r" id="vh-hero-r"></div>
</div>
<div class="vh-gauges" id="vh-gauges"></div>
<div class="vh-mini" id="vh-mini"></div>
<div class="vh-charts">
  <div class="vh-ch"><div class="vh-ch-h"><div class="vh-ch-t">Available memory</div><div class="vh-ch-n" id="vh-n1">24h</div></div><div id="vh-c1"></div></div>
  <div class="vh-ch"><div class="vh-ch-h"><div class="vh-ch-t">FreeRADIUS memory</div><div class="vh-ch-n" id="vh-n2">24h</div></div><div id="vh-c2"></div></div>
</div>
<div class="vh-acard">
  <div class="vh-ahead"><div class="vh-atitle">Active alerts</div><div class="vh-badge" id="vh-badge">none</div><div class="vh-anote" id="vh-anote"></div></div>
  <div id="vh-alerts"></div>
  <div class="vh-chips" id="vh-chips"></div>
</div>
</div>
"""
anchor = '<div class="page" id="page-isps">'
if anchor not in s: print("   ERROR: page-isps anchor not found"); sys.exit(1)
s = s.replace(anchor, PAGE + anchor, 1)

JS = r"""
<script>
/* RL_VPS_HEALTH_JS — inline VPS health, hand-drawn SVG. No library, no redirect. */
(function(){
  var C=2*Math.PI*54, COL={ok:'#22c55e',warning:'#f59e0b',critical:'#ef4444'};
  function tok(){var ks=['rl_admin_token','rl_admin','adminToken','rl_token','token'];
    for(var i=0;i<ks.length;i++){var v=localStorage.getItem(ks[i]);if(v&&v.split('.').length===3)return v;}
    for(var k in localStorage){var x=localStorage.getItem(k);if(x&&typeof x==='string'&&x.split('.').length===3&&x.length>40)return x;}return '';}
  function sev(v,w,c,inv){return inv?(v<=c?'critical':v<=w?'warning':'ok'):(v>=c?'critical':v>=w?'warning':'ok');}
  function gauge(o){var pct=Math.max(0,Math.min(1,o.pct)),col=COL[o.sev]||'#3b82f6';
    return '<div class="vh-g '+o.sev+'"><div class="vh-g-wrap"><svg viewBox="0 0 126 126">'+
      '<circle class="bg" cx="63" cy="63" r="54"></circle>'+
      '<circle cx="63" cy="63" r="54" stroke="'+col+'" stroke-dasharray="'+C.toFixed(1)+'" stroke-dashoffset="'+(C*(1-pct)).toFixed(1)+'"></circle></svg>'+
      '<div class="vh-g-c"><div class="vh-g-v" style="color:'+col+'">'+o.val+'<span>'+o.unit+'</span></div>'+
      '<div class="vh-g-p">'+Math.round(pct*100)+'%</div></div></div>'+
      '<div class="vh-g-l">'+o.label+'</div><div class="vh-g-s">'+o.sub+'</div></div>';}
  function spark(rows,key,color,elId,noteId){var el=document.getElementById(elId);if(!el)return;
    var W=600,H=150,P=6;
    if(!rows||rows.length<2){el.innerHTML='<div style="height:150px;display:flex;align-items:center;justify-content:center;color:rgba(148,163,184,.7);font-size:.8rem">collecting data...</div>';return;}
    var v=rows.map(function(r){return +r[key]||0}),mx=Math.max.apply(null,v),mn=Math.min.apply(null,v);
    var pad=(mx-mn)*0.15||1;mx+=pad;mn=Math.max(0,mn-pad);
    var pts=v.map(function(y,i){return [P+i/(v.length-1)*(W-2*P),H-P-((y-mn)/((mx-mn)||1))*(H-2*P)];});
    var d=pts.map(function(pt,i){return (i?'L':'M')+pt[0].toFixed(1)+' '+pt[1].toFixed(1)}).join(' ');
    var gid='g'+elId,grid='';
    for(var i=1;i<4;i++){var y=P+(H-2*P)*i/4;grid+='<line x1="'+P+'" y1="'+y.toFixed(1)+'" x2="'+(W-P)+'" y2="'+y.toFixed(1)+'" stroke="rgba(148,163,184,.10)" stroke-width="1"/>';}
    el.innerHTML='<svg viewBox="0 0 '+W+' '+H+'" preserveAspectRatio="none"><defs><linearGradient id="'+gid+'" x1="0" y1="0" x2="0" y2="1">'+
      '<stop offset="0%" stop-color="'+color+'" stop-opacity=".38"/><stop offset="100%" stop-color="'+color+'" stop-opacity="0"/></linearGradient></defs>'+grid+
      '<path d="'+d+' L'+(W-P)+' '+(H-P)+' L'+P+' '+(H-P)+' Z" fill="url(#'+gid+')"/>'+
      '<path d="'+d+'" fill="none" stroke="'+color+'" stroke-width="2.2" stroke-linejoin="round"/>'+
      '<circle cx="'+pts[pts.length-1][0].toFixed(1)+'" cy="'+pts[pts.length-1][1].toFixed(1)+'" r="3.5" fill="'+color+'"/></svg>';
    var n=document.getElementById(noteId);
    if(n)n.textContent='now '+Math.round(v[v.length-1])+' \u00b7 min '+Math.round(Math.min.apply(null,v))+' \u00b7 max '+Math.round(Math.max.apply(null,v));}
  function ago(t){var s=Math.max(1,Math.round((Date.now()-new Date(t).getTime())/1000));
    if(s<60)return s+'s ago';var m=Math.round(s/60);if(m<60)return m+' min ago';
    var h=Math.round(m/60);if(h<24)return h+'h ago';return Math.round(h/24)+'d ago';}
  function render(d){
    var c=d.current,st=d.status;
    var hero=document.getElementById('vh-hero');if(hero)hero.className='vh-hero '+st;
    document.getElementById('vh-hero-t').textContent = st==='ok'?'All systems normal':(st==='critical'?'Critical - action needed':'Warning - needs attention');
    document.getElementById('vh-hero-s').textContent = d.alerts.length?d.alerts.map(function(a){return a.message}).join('  \u2022  '):'Memory, CPU, disk and FreeRADIUS are all within thresholds.';
    document.getElementById('vh-hero-r').innerHTML='Updated '+new Date().toLocaleTimeString()+'<br>'+(c.routers_total-c.routers_down)+' of '+c.routers_total+' routers online';
    document.getElementById('vh-gauges').innerHTML=[
      gauge({pct:(c.mem_total_mb-c.mem_avail_mb)/(c.mem_total_mb||1),val:c.mem_avail_mb,unit:'MB',label:'Memory free',sub:'of '+c.mem_total_mb+' MB total',sev:sev(c.mem_avail_mb,500,300,true)}),
      gauge({pct:c.freeradius_mb/600,val:c.freeradius_mb,unit:'MB',label:'FreeRADIUS',sub:'cap 600 MB',sev:sev(c.freeradius_mb,250,350)}),
      gauge({pct:c.disk_pct/100,val:c.disk_pct,unit:'%',label:'Disk used',sub:'root filesystem',sev:sev(c.disk_pct,70,80)}),
      gauge({pct:c.load1/2,val:c.load1,unit:'',label:'CPU load',sub:'2 vCPU',sev:sev(c.load1,2,4)}),
      gauge({pct:c.pg_conns/100,val:c.pg_conns,unit:'',label:'DB connections',sub:'of 100 max',sev:sev(c.pg_conns,60,80)})].join('');
    document.getElementById('vh-mini').innerHTML=[
      {k:'Backend (node)',v:c.node_mb,u:'MB',pct:c.node_mb/500,s:sev(c.node_mb,300,400)},
      {k:'Swap used',v:c.swap_used_mb,u:'MB',pct:c.swap_used_mb/4096,s:sev(c.swap_used_mb,128,512)},
      {k:'CPU stolen (AWS)',v:c.cpu_steal,u:'%',pct:c.cpu_steal/20,s:sev(c.cpu_steal,2,5)},
      {k:'Routers offline',v:c.routers_down,u:'of '+c.routers_total,pct:c.routers_total?c.routers_down/c.routers_total:0,s:c.routers_down>0?'critical':'ok'}
    ].map(function(m){return '<div class="vh-m '+m.s+'"><div class="vh-m-k">'+m.k+'</div><div class="vh-m-v" style="color:'+COL[m.s]+'">'+m.v+'<small>'+m.u+'</small></div>'+
      '<div class="vh-m-bar"><i style="width:'+Math.min(100,m.pct*100).toFixed(0)+'%;background:'+COL[m.s]+'"></i></div></div>';}).join('');
    spark(d.history,'mem_avail_mb','#3b82f6','vh-c1','vh-n1');
    spark(d.history,'freeradius_mb','#22c55e','vh-c2','vh-n2');
    var thr=d.thresholds||{},keys=Object.keys(thr),bySev={};
    d.alerts.forEach(function(a){bySev[a.metric]=a.severity});
    var badge=document.getElementById('vh-badge');
    if(badge){var nc=d.alerts.filter(function(a){return a.severity==='critical'}).length;
      badge.textContent=d.alerts.length?(d.alerts.length+' active'):'none';
      badge.className='vh-badge'+(nc?' has':(d.alerts.length?' warn':''));}
    var note=document.getElementById('vh-anote');
    if(note)note.textContent='monitoring '+keys.length+' metrics \u00b7 every 60s';
    document.getElementById('vh-alerts').innerHTML=d.alerts.length?d.alerts.map(function(a){
      var t=thr[a.metric]||{},lim=+a.threshold||0,val=+a.value||0;
      var pct=Math.max(0,Math.min(100,(val/(lim||1))*100)),col=a.severity==='critical'?'#ef4444':'#f59e0b';
      return '<div class="vh-a '+a.severity+'"><div class="vh-a-ic">!</div><div class="vh-a-body">'+
        '<div class="vh-a-top"><span class="vh-a-name">'+(t.label||a.metric)+'</span>'+
        '<span class="vh-sev '+a.severity+'">'+a.severity+'</span><span class="vh-a-time">'+ago(a.opened_at)+'</span></div>'+
        '<div class="vh-a-msg">'+(t.help||a.message||'')+'</div>'+
        '<div class="vh-a-meter"><div class="vh-a-track"><i style="width:'+pct.toFixed(0)+'%;background:'+col+'"></i></div>'+
        '<div class="vh-a-nums">'+val+' vs '+(t.op||'')+' '+lim+'</div></div></div></div>';}).join('')
      :'<div class="vh-clear"><div class="vh-clear-ic">&#10003;</div><div class="vh-clear-t">All clear</div>'+
       '<div class="vh-clear-s">Every monitored metric is inside its threshold.</div></div>';
    var chips=document.getElementById('vh-chips');
    if(chips)chips.innerHTML=keys.map(function(k){var sv=bySev[k]||'ok',t=thr[k]||{};
      var cur=(c[k]===undefined||c[k]===null)?'\u2014':c[k];
      return '<span class="vh-chip '+sv+'"><b></b>'+(t.label||k)+' <span style="opacity:.65">'+cur+'</span></span>';}).join('');
    var dot=document.getElementById('vh-dot');if(dot)dot.style.background=COL[st]||COL.ok;
  }
  window.loadVpsHealth=function(){
    fetch('/api/admin/health',{headers:{Authorization:'Bearer '+tok()}})
      .then(function(r){if(!r.ok)throw new Error('HTTP '+r.status);return r.json()})
      .then(render).catch(function(e){var t=document.getElementById('vh-hero-s');if(t)t.textContent='Could not load metrics: '+e.message;});
  };
  function dotOnly(){fetch('/api/admin/health',{headers:{Authorization:'Bearer '+tok()}})
    .then(function(r){return r.ok?r.json():null}).then(function(d){if(!d)return;
      var dot=document.getElementById('vh-dot');if(dot)dot.style.background=COL[d.status]||COL.ok;}).catch(function(){});}
  document.addEventListener('DOMContentLoaded',function(){
    var nav=document.querySelector('.nav-item[data-page="vps-health"]');
    if(nav)nav.addEventListener('click',function(){setTimeout(window.loadVpsHealth,60)});
    dotOnly();
    setInterval(function(){var pg=document.getElementById('page-vps-health');
      if(pg&&pg.classList.contains('active'))window.loadVpsHealth();else dotOnly();},30000);
  });
})();
</script>
"""
s = s.replace('</body>', JS + '\n</body>', 1) if '</body>' in s else s + JS
open(p,'w').write(s)
print("   nav item, page and loader inserted")
PY

say "2) Verify structure"
B1=$(bal "$F"); echo "   div balance after: $B1  (before: $B0)"
if [ "$B0" != "$B1" ]; then
  echo "   ${R}UNBALANCED — rolling back${N}"
  sudo cp "/var/www/rumalink/admin/.dashboard.html.bak_$TS" "$F"
  echo "   restored"; exit 1
fi
echo "   nav item     : $(sudo grep -c 'data-page="vps-health"' "$F")"
echo "   page div     : $(sudo grep -c 'id="page-vps-health"' "$F")"
echo "   loader       : $(sudo grep -c 'RL_VPS_HEALTH_JS' "$F")"
echo "   script pairs : $(grep -o '<script' "$F" | wc -l) / $(grep -o '</script>' "$F" | wc -l)"
sudo chown www-data:www-data "$F"

say "3) Serve check"
curl -sk -o /dev/null -w "   dashboard HTTP %{http_code}\n" https://rumalinkenterprise.online/admin/dashboard.html
sudo -u postgres psql -d rumalink_db -tAc "SELECT count(*)||' samples, latest '||max(sampled_at) FROM system_health;" | sed 's/^/   /'
echo
echo "   ${Y}Hard-refresh the dashboard (Ctrl-Shift-R). 'VPS Health' sits under Monitoring.${N}"
echo "   Rollback: sudo cp /var/www/rumalink/admin/.dashboard.html.bak_$TS $F"
