#!/usr/bin/env bash
# restore_step4.sh — rebuild the health monitor stack (table survived with 2790 rows).
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) utils/health-monitor.js"
sudo tee "$BE/utils/health-monitor.js" > /dev/null <<'JS'
// RL_HEALTH_MONITOR — VPS health sampling, dashboard alerts and email.
// SCOPE: platform/VPS metrics ONLY. Router reachability is deliberately NOT an alert here —
// ISPs already receive SMS when their MikroTik or uplink drops. Edge-triggered: one alert on
// breach, one on recovery, nothing repeated while the condition persists.
const fs = require('fs');
const os = require('os');
const { execSync } = require('child_process');
const { query } = require('../config/database');
const logger = require('./logger');
const INTERVAL = 60 * 1000, RETAIN_DAYS = 7;
const THRESHOLDS = {
  mem_avail_mb:  { op:'<', value:300, sev:'critical', label:'Available memory low', unit:'MB',
                   help:'The instance may start OOM-killing services. Check for a leaking process.' },
  freeradius_mb: { op:'>', value:350, sev:'critical', label:'FreeRADIUS memory high', unit:'MB',
                   help:'FreeRADIUS is capped at 600MB and will auto-restart. Check reload frequency in /var/log/rumalink-clients-sync.log.' },
  disk_pct:      { op:'>', value:80,  sev:'warning',  label:'Disk usage high', unit:'%',
                   help:'Postgres stops accepting writes when the disk fills. Clear logs or old backups.' },
  load1:         { op:'>', value:4,   sev:'warning',  label:'CPU load high', unit:'',
                   help:'Sustained load above the core count means requests are queueing.' },
  cpu_steal:     { op:'>', value:5,   sev:'critical', label:'CPU throttled by AWS', unit:'%',
                   help:'Burst credits are exhausted. Only a plan with more vCPUs resolves this.' },
  swap_used_mb:  { op:'>', value:512, sev:'warning',  label:'Swap in heavy use', unit:'MB',
                   help:'Real memory is exhausted; performance will degrade sharply.' },
  pg_conns:      { op:'>', value:80,  sev:'warning',  label:'Postgres connections high', unit:'',
                   help:'Approaching max_connections (100). Check for a connection pool leak.' },
};
const COL = { critical:'#ef4444', warning:'#f59e0b', ok:'#22c55e' };
function sh(c, fb){ try { return execSync(c,{timeout:5000}).toString().trim(); } catch(e){ return fb; } }
function procRssMb(name){
  try { const pid = sh(`pgrep -x ${name} | head -1`,''); if(!pid) return 0;
    const m = fs.readFileSync(`/proc/${pid}/status`,'utf8').match(/^VmRSS:\s+(\d+)/m);
    return m ? Math.round(parseInt(m[1],10)/1024) : 0; } catch(e){ return 0; }
}
async function sample(){
  const mi_s = fs.readFileSync('/proc/meminfo','utf8');
  const mi = k => { const m = mi_s.match(new RegExp('^'+k+':\\s+(\\d+)','m')); return m ? Math.round(parseInt(m[1],10)/1024) : 0; };
  const memTotal = mi('MemTotal'), memAvail = mi('MemAvailable');
  const swapTotal = mi('SwapTotal'), swapFree = mi('SwapFree');
  let steal = 0;
  try {
    const read = () => fs.readFileSync('/proc/stat','utf8').split('\n')[0].trim().split(/\s+/).slice(1).map(Number);
    const a = read(); await new Promise(r=>setTimeout(r,1000)); const b = read();
    const dt = b.reduce((s,v,i)=>s+(v-a[i]),0);
    steal = dt>0 ? +(((b[7]-a[7])/dt)*100).toFixed(2) : 0;
  } catch(e){}
  const diskPct = parseInt(sh("df / | awk 'NR==2{print $5}' | tr -d '%'",'0'),10) || 0;
  let pgConns = 0;
  try { pgConns = parseInt((await query('SELECT count(*)::int AS c FROM pg_stat_activity')).rows[0].c,10); } catch(e){}
  let rt=0, rd=0;
  try { const r = await query("SELECT count(*)::int AS t, count(*) FILTER (WHERE is_online IS NOT TRUE)::int AS d FROM nas_devices WHERE wireguard_ip IS NOT NULL");
        rt=r.rows[0].t; rd=r.rows[0].d; } catch(e){}
  return { load1:+os.loadavg()[0].toFixed(2), cpu_steal:steal, mem_total_mb:memTotal, mem_avail_mb:memAvail,
           swap_used_mb:swapTotal-swapFree, disk_pct:diskPct, freeradius_mb:procRssMb('freeradius'),
           node_mb:Math.round(process.memoryUsage().rss/1048576), pg_conns:pgConns, routers_total:rt, routers_down:rd };
}
function bar(pct,color){ const w=Math.max(0,Math.min(100,Math.round(pct)));
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:separate;border-radius:3px;background:#242832"><tr><td width="${w}%" style="height:6px;background:${color};border-radius:3px;font-size:0;line-height:0">&nbsp;</td><td style="font-size:0;line-height:0">&nbsp;</td></tr></table>`; }
function metricRow(label,value,unit,pct,color){
  return `<tr><td style="padding:9px 0 3px;color:#e6e8ec;font:600 13px -apple-system,Segoe UI,Roboto,sans-serif">${label}</td><td align="right" style="padding:9px 0 3px;color:${color};font:700 13px -apple-system,Segoe UI,Roboto,sans-serif">${value}<span style="color:#8b93a3;font-weight:500;font-size:11px"> ${unit}</span></td></tr><tr><td colspan="2" style="padding-bottom:8px">${bar(pct,color)}</td></tr>`; }
function buildEmail(o){
  const rec = o.kind==='recovery', accent = rec?COL.ok:(COL[o.sev]||COL.warning);
  const tag = rec?'RESOLVED':(o.sev==='critical'?'CRITICAL':'WARNING');
  const s = o.snapshot||{}, base=(process.env.BASE_URL||'https://rumalinkenterprise.online').replace(/\/$/,'');
  const sev=(v,w,c,inv)=>inv?(v<=c?COL.critical:v<=w?COL.warning:COL.ok):(v>=c?COL.critical:v>=w?COL.warning:COL.ok);
  const rows=[metricRow('Memory free',s.mem_avail_mb,'MB',s.mem_total_mb?(s.mem_avail_mb/s.mem_total_mb)*100:0,sev(s.mem_avail_mb,500,300,true)),
    metricRow('FreeRADIUS',s.freeradius_mb,'MB of 600 cap',(s.freeradius_mb/600)*100,sev(s.freeradius_mb,250,350)),
    metricRow('Disk used',s.disk_pct,'%',s.disk_pct,sev(s.disk_pct,70,80)),
    metricRow('CPU load',s.load1,'(2 vCPU)',(s.load1/2)*100,sev(s.load1,2,4)),
    metricRow('CPU stolen',s.cpu_steal,'%',(s.cpu_steal/20)*100,sev(s.cpu_steal,2,5)),
    metricRow('Swap used',s.swap_used_mb,'MB',(s.swap_used_mb/4096)*100,sev(s.swap_used_mb,128,512)),
    metricRow('DB connections',s.pg_conns,'of 100',s.pg_conns,sev(s.pg_conns,60,80))].join('');
  const detail = rec
    ? `<p style="margin:0;color:#8b93a3;font:14px/1.6 -apple-system,sans-serif">This metric is back inside its threshold. No further action is needed.</p>`
    : `<p style="margin:0 0 14px;color:#c7ccd6;font:14px/1.6 -apple-system,sans-serif">${o.help||''}</p>
       <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>
       <td style="padding:10px 12px;background:#1e222b;border-radius:8px 0 0 8px;border-left:3px solid ${accent}">
       <div style="color:#8b93a3;font:600 10px -apple-system,sans-serif;letter-spacing:.6px">CURRENT</div>
       <div style="color:${accent};font:800 20px -apple-system,sans-serif;margin-top:2px">${o.value}<span style="font-size:11px;font-weight:600;color:#8b93a3"> ${o.unit||''}</span></div></td>
       <td style="padding:10px 12px;background:#1e222b;border-radius:0 8px 8px 0">
       <div style="color:#8b93a3;font:600 10px -apple-system,sans-serif;letter-spacing:.6px">THRESHOLD</div>
       <div style="color:#e6e8ec;font:800 20px -apple-system,sans-serif;margin-top:2px">${o.op||''} ${o.threshold}</div></td></tr></table>`;
  const html = `<!DOCTYPE html><html><body style="margin:0;padding:24px 12px;background:#0b0d11">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#171a21;border:1px solid #242832;border-radius:16px;overflow:hidden">
<tr><td style="height:4px;background:${accent};font-size:0;line-height:0">&nbsp;</td></tr>
<tr><td style="padding:22px 24px 6px">
<span style="display:inline-block;padding:4px 11px;border-radius:20px;background:${accent}22;color:${accent};font:800 10px -apple-system,sans-serif;letter-spacing:.8px">${tag}</span>
<div style="color:#e6e8ec;font:750 21px/1.3 -apple-system,sans-serif;margin-top:12px">${o.label}</div>
<div style="color:#8b93a3;font:13px -apple-system,sans-serif;margin-top:4px">VPS health &middot; ${os.hostname()}</div></td></tr>
<tr><td style="padding:16px 24px 4px">${detail}</td></tr>
<tr><td style="padding:20px 24px 0"><div style="height:1px;background:#242832;margin-bottom:16px"></div>
<div style="color:#8b93a3;font:700 10px -apple-system,sans-serif;letter-spacing:.8px;margin-bottom:6px">SERVER SNAPSHOT</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0">${rows}</table></td></tr>
<tr><td style="padding:20px 24px 24px" align="center">
<a href="${base}/admin/dashboard.html" style="display:inline-block;padding:11px 22px;border-radius:9px;background:${accent};color:#0b0d11;font:700 13px -apple-system,sans-serif;text-decoration:none">Open VPS Health</a></td></tr>
<tr><td style="padding:14px 24px;background:#12151b;border-top:1px solid #242832">
<div style="color:#6b7280;font:11px/1.6 -apple-system,sans-serif">RumaLink Enterprise &middot; ${new Date().toUTCString()}<br>
Platform infrastructure alert. ISP router and uplink events are sent to ISPs by SMS.</div></td></tr>
</table></td></tr></table></body></html>`;
  const text = `[${tag}] ${o.label}\n${o.help||''}\n` + (rec?'':`Current: ${o.value} ${o.unit||''} | Threshold: ${o.op||''} ${o.threshold}\n`) +
    `Snapshot: mem ${s.mem_avail_mb}MB, freeradius ${s.freeradius_mb}MB, disk ${s.disk_pct}%, load ${s.load1}\n${base}/admin/dashboard.html`;
  return { html, text };
}
async function sendAlertEmail(o){
  try {
    const to = process.env.ALERT_EMAIL || process.env.ADMIN_EMAIL || process.env.SMTP_USER;
    if(!to) return;
    const mail = require('./email');
    const fn = mail.sendEmail || mail.send || mail.sendMail;
    if (typeof fn !== 'function') return;
    const { html, text } = buildEmail(o);
    const tag = o.kind==='recovery' ? 'Resolved' : (o.sev==='critical'?'CRITICAL':'Warning');
    await fn({ to, subject:`[VPS ${tag}] ${o.label} — RumaLink`, html, text });
  } catch(e){ logger.warn('[HEALTH] email: ' + e.message); }
}
async function notifyAdmins(title,message,type){
  try { const admins = await query('SELECT id FROM admins');
    for (const a of admins.rows) await query(
      `INSERT INTO notifications (admin_id, type, title, message, link) VALUES ($1::uuid,$2::notification_type,$3,$4,'/admin/dashboard.html')`,
      [a.id, type==='critical'?'error':(type==='ok'?'info':'warning'), title, message]).catch(()=>{});
  } catch(e){ logger.warn('[HEALTH] notify: ' + e.message); }
}
function breached(m,v){ const t=THRESHOLDS[m]; if(!t) return false; return t.op==='<' ? v<t.value : v>t.value; }
async function evaluate(s){
  const openRes = await query('SELECT metric, id FROM system_health_alerts WHERE closed_at IS NULL');
  const open = new Map(openRes.rows.map(r=>[r.metric,r.id]));
  let worst='ok';
  for (const metric of Object.keys(THRESHOLDS)){
    const t=THRESHOLDS[metric], value=s[metric];
    if(value===undefined||value===null) continue;
    const bad=breached(metric,value);
    if(bad) worst = t.sev==='critical' ? 'critical' : (worst==='critical'?'critical':'warning');
    if(bad && !open.has(metric)){
      const msg=`${t.label}: ${value}${t.unit?' '+t.unit:''} (threshold ${t.op} ${t.value}). ${t.help}`;
      await query('INSERT INTO system_health_alerts (metric,severity,value,threshold,message) VALUES ($1,$2,$3,$4,$5)',[metric,t.sev,value,t.value,msg]);
      logger.error('[HEALTH-ALERT] '+msg);
      await notifyAdmins('VPS '+t.sev.toUpperCase()+': '+t.label, msg, t.sev);
      await sendAlertEmail({kind:'alert',sev:t.sev,metric,label:t.label,value,threshold:t.value,op:t.op,unit:t.unit,help:t.help,snapshot:s});
    } else if(!bad && open.has(metric)){
      await query('UPDATE system_health_alerts SET closed_at=now() WHERE id=$1',[open.get(metric)]);
      logger.info('[HEALTH-OK] '+t.label+' recovered ('+value+')');
      await notifyAdmins('VPS recovered: '+t.label, `${t.label} is back to normal (${value}).`, 'ok');
      await sendAlertEmail({kind:'recovery',metric,label:t.label,value,unit:t.unit,snapshot:s});
    }
  }
  return worst;
}
async function pass(){
  try {
    const s = await sample();
    const status = await evaluate(s);
    await query(`INSERT INTO system_health (load1,cpu_steal,mem_total_mb,mem_avail_mb,swap_used_mb,disk_pct,freeradius_mb,node_mb,pg_conns,routers_total,routers_down,status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
      [s.load1,s.cpu_steal,s.mem_total_mb,s.mem_avail_mb,s.swap_used_mb,s.disk_pct,s.freeradius_mb,s.node_mb,s.pg_conns,s.routers_total,s.routers_down,status]);
    if (Math.random()<0.02) await query(`DELETE FROM system_health WHERE sampled_at < now() - interval '${RETAIN_DAYS} days'`).catch(()=>{});
  } catch(e){ logger.warn('[HEALTH] pass: ' + e.message); }
}
function start(){
  pass().catch(()=>{});
  setInterval(()=>pass().catch(()=>{}), INTERVAL);
  logger.info('[HEALTH] Registered (every 60s) — VPS-only alerts (router events go to ISPs by SMS)');
}
module.exports = { start, pass, sample, evaluate, buildEmail, sendAlertEmail, THRESHOLDS };
JS
sudo chown www-data:www-data "$BE/utils/health-monitor.js"
sudo -u www-data node --check "$BE/utils/health-monitor.js" && echo "   health-monitor.js OK"

say "2) routes/health.js"
sudo tee "$BE/routes/health.js" > /dev/null <<'JS'
const express = require('express');
const router = express.Router();
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const { query } = require('../config/database');
const hm = require('../utils/health-monitor');
router.use(authenticateToken, requireAdmin);
router.get('/', async (req, res, next) => {
  try {
    const cur = await hm.sample();
    const alerts = await query('SELECT metric, severity, value, threshold, message, opened_at FROM system_health_alerts WHERE closed_at IS NULL ORDER BY opened_at DESC');
    const hist = await query(`SELECT sampled_at, load1, cpu_steal, mem_avail_mb, swap_used_mb, disk_pct, freeradius_mb, node_mb, pg_conns, routers_down, status
      FROM system_health WHERE sampled_at > now() - interval '24 hours' ORDER BY sampled_at ASC`);
    const status = alerts.rows.some(a=>a.severity==='critical') ? 'critical' : (alerts.rows.length ? 'warning' : 'ok');
    res.json({ status, current: cur, thresholds: hm.THRESHOLDS, alerts: alerts.rows, history: hist.rows });
  } catch (err) { next(err); }
});
module.exports = router;
JS
sudo chown www-data:www-data "$BE/routes/health.js"
sudo -u www-data node --check "$BE/routes/health.js" && echo "   routes/health.js OK"

say "3) Mount + register"
sudo cp "$BE/server.js" "$BE/.server.js.bak_$TS"
sudo python3 - "$BE/server.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if "routes/health" in s: print("   route already mounted"); sys.exit(0)
a = "app.use('/api/admin', require('./routes/admin'));"
if a not in s: print("   ANCHOR NOT FOUND — mount manually"); sys.exit(1)
s = s.replace(a, "app.use('/api/admin/health', require('./routes/health'));\n" + a, 1)
open(p,'w').write(s); print("   mounted /api/admin/health before /api/admin")
PY
sudo cp "$BE/utils/cron.js" "$BE/utils/.cron.js.bak2_$TS"
if sudo grep -q "health-monitor" "$BE/utils/cron.js"; then echo "   already registered"
else echo "try { require('./health-monitor').start(); } catch (e) { require('./logger').warn('[health-monitor] start: ' + e.message); }" | sudo tee -a "$BE/utils/cron.js" >/dev/null; echo "   registered"; fi
sudo -u www-data node --check "$BE/server.js" && sudo -u www-data node --check "$BE/utils/cron.js" && echo "   syntax OK"

say "4) Restart + verify"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 10
pm2 logs rumalink-backend --lines 60 --nostream 2>/dev/null | grep -oE "\[(HEALTH|QUEUE-MONITOR|QUEUE-INTEGRITY|EXPIRED-ENFORCER|router-harden|strand-heal)\][^{]*" | sort -u | sed 's/^/   /'
curl -s -o /dev/null -w "   /api/admin/health -> HTTP %{http_code} (401 = mounted & protected)\n" http://127.0.0.1:5000/api/admin/health
q -c "SELECT count(*) AS rows, max(sampled_at) AS latest FROM system_health;"

say "5) Recovery complete — final state"
q -c "SELECT company_name, id FROM isps;"
q -c "SELECT count(*) AS payments FROM payments;"
q -c "SELECT count(*) AS vouchers FROM hotspot_vouchers;"
q -c "SELECT method_type, label FROM isp_payment_methods;"
(sudo pm2 list 2>/dev/null || pm2 list) | grep rumalink-backend | sed 's/^/   /'
echo
echo "   ${Y}Remaining: the admin dashboard health PAGE (UI only — monitoring itself is live).${N}"
