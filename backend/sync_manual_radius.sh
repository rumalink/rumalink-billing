#!/usr/bin/env bash
#
# sync_manual_radius.sh — manually created users still cannot log in.
#
# "Already Paid? Login" authenticates straight against RADIUS, so a voucher needs a radcheck
# entry. syncRadiusForVoucher refuses to write one when the voucher has no payment and
# created_by_isp is unset (captive.js:1364) — which was the case when these were created. The
# flag is set now, but the credentials were never written, so R89/R43/R42/R41 have nothing to
# authenticate against.
#
# This writes them, using the same sync the purchase path uses, so the entries are identical in
# shape to a paid voucher's (password, Session-Timeout, rate limit, Simultaneous-Use).
#
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Who is missing credentials"
q -c "SELECT hv.code, hv.status, hv.expires_at IS NOT NULL AS dated,
             EXISTS (SELECT 1 FROM radcheck rc
                     WHERE rc.username = hv.code || '@' || lower(left(replace(hv.isp_id::text,'-',''),8))
                       AND rc.attribute='Cleartext-Password') AS has_radius
      FROM hotspot_vouchers hv
      WHERE hv.created_by_isp = true AND (hv.is_tv IS NOT TRUE)
      ORDER BY hv.created_at DESC LIMIT 20;"

say "2) Does each have a password to publish?"
q -c "SELECT code, (password IS NOT NULL AND password <> '') AS has_password, status
      FROM hotspot_vouchers WHERE created_by_isp = true AND (is_tv IS NOT TRUE)
      ORDER BY created_at DESC LIMIT 10;"
echo "   ${Y}a voucher with no password cannot be published — one is generated below if missing${N}"

say "3) Give any that lack one a password"
q -c "UPDATE hotspot_vouchers
      SET password = COALESCE(NULLIF(password,''), upper(substr(md5(random()::text), 1, 6)))
      WHERE created_by_isp = true AND (is_tv IS NOT TRUE)
        AND (password IS NULL OR password = '');"

say "4) Publish them to RADIUS using the normal sync"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const {query}=require('$BE/config/database');
(async()=>{
  const cap = require('$BE/routes/captive');
  const fn = cap.syncRadiusForVoucher || (cap.default && cap.default.syncRadiusForVoucher);
  const rows = (await query(
    \"SELECT hv.id, hv.code FROM hotspot_vouchers hv \" +
    \"WHERE hv.created_by_isp = true AND (hv.is_tv IS NOT TRUE) \" +
    \"AND NOT EXISTS (SELECT 1 FROM radcheck rc WHERE rc.username = hv.code || '@' || lower(left(replace(hv.isp_id::text,'-',''),8)) AND rc.attribute='Cleartext-Password')\"
  )).rows;
  console.log('   ' + rows.length + ' voucher(s) to publish');
  if (typeof fn !== 'function') {
    console.log('   syncRadiusForVoucher is not exported — writing the entries directly instead');
    for (const r of rows) {
      const v = (await query(
        'SELECT v.code, v.password, v.isp_id, v.expires_at, COALESCE(hp.simultaneous_sessions,1) AS simul, ' +
        'hp.bandwidth_up_mbps AS up, hp.bandwidth_down_mbps AS down ' +
        'FROM hotspot_vouchers v LEFT JOIN hotspot_packages hp ON hp.id=v.package_id WHERE v.id=\$1::uuid', [r.id])).rows[0];
      if (!v) continue;
      const user = v.code + '@' + String(v.isp_id).replace(/-/g,'').slice(0,8).toLowerCase();
      await query(\"DELETE FROM radcheck WHERE username=\$1\", [user]).catch(()=>{});
      await query(\"DELETE FROM radreply WHERE username=\$1\", [user]).catch(()=>{});
      await query(\"INSERT INTO radcheck (username,attribute,op,value) VALUES (\$1,'Cleartext-Password',':=',\$2)\", [user, v.password || v.code]);
      await query(\"INSERT INTO radcheck (username,attribute,op,value) VALUES (\$1,'Simultaneous-Use',':=',\$2)\", [user, String(v.simul||1)]);
      if (v.up || v.down) {
        await query(\"INSERT INTO radreply (username,attribute,op,value) VALUES (\$1,'Mikrotik-Rate-Limit',':=',\$2)\",
          [user, (v.up||v.down||0)+'M/'+(v.down||0)+'M']);
      }
      if (v.expires_at) {
        const secs = Math.max(60, Math.floor((new Date(v.expires_at) - new Date())/1000));
        await query(\"INSERT INTO radreply (username,attribute,op,value) VALUES (\$1,'Session-Timeout',':=',\$2)\", [user, String(secs)]);
      }
      console.log('     published ' + user);
    }
  } else {
    for (const r of rows) { try { await fn(r.id); console.log('     synced ' + r.code); } catch(e){ console.log('     ' + r.code + ': ' + e.message); } }
  }
  process.exit(0);
})();" 2>&1 | grep -vE "^info:" | sed 's/^/  /'

say "5) Confirm"
q -c "SELECT hv.code,
             EXISTS (SELECT 1 FROM radcheck rc
                     WHERE rc.username = hv.code || '@' || lower(left(replace(hv.isp_id::text,'-',''),8))
                       AND rc.attribute='Cleartext-Password') AS has_radius,
             hv.password
      FROM hotspot_vouchers hv WHERE hv.created_by_isp = true AND (hv.is_tv IS NOT TRUE)
      ORDER BY hv.created_at DESC LIMIT 10;"

say "6) The credentials to give those customers"
q -c "SELECT code AS username, password, status, expires_at
      FROM hotspot_vouchers WHERE created_by_isp = true AND (is_tv IS NOT TRUE) AND status='active'
      ORDER BY created_at DESC LIMIT 10;"
echo "   ${Y}they enter the CODE and this PASSWORD in 'Already Paid? Login'${N}"

say "7) The delete route the buttons will call"
sudo sed -n '1207,1250p' "$BE/routes/isp.js" | nl -ba -v1207 | sed 's/^/   /'
