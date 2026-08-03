#!/usr/bin/env bash
#
# fix_sms_isp_id_and_portal.sh
#
# BUG A — "Insufficient SMS balance" while the ISP has 38 credits.
#   sendSMS looks the balance up with `isp.id`. Several callers pass a JOINED row rather than an
#   ISP row: the PPPoE expiry sweep selects ps.id (the SUBSCRIBER's id) alongside i.company_name,
#   and the hotspot voucher expiry selects hv.id (the VOUCHER's id). The lookup then runs
#   `WHERE id = <subscriber/voucher id>`, matches no row, reads the balance as 0 and refuses to
#   send — while the ISP has credits. The renewal SMS worked only because it selected i.*, which
#   carries the real i.id.
#   FIX centrally: resolve the id as `isp.isp_id || isp.id`. A joined row always carries the
#   correct isp_id; a true ISP row carries only id. One change repairs every caller, including
#   ones not yet written.
#
# BUG B — hide "Pay by Paybill" on the PPPoE portal, leaving the M-Pesa prompt.
#
set -uo pipefail
BE=/var/www/rumalink/backend
CP=/var/www/rumalink/captive
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Prove the cause before changing anything"
SUB=$(q -tAc "SELECT id FROM pppoe_subscribers WHERE status='expired' ORDER BY updated_at DESC LIMIT 1;")
ISP=$(q -tAc "SELECT isp_id FROM pppoe_subscribers WHERE status='expired' ORDER BY updated_at DESC LIMIT 1;")
echo "   subscriber id : ${SUB:-none}"
echo "   isp id        : ${ISP:-none}"
if [ -n "$SUB" ]; then
  echo "   balance looked up with the SUBSCRIBER id (what the code does today):"
  q -c "SELECT sms_balance FROM isps WHERE id='$SUB'::uuid;"
  echo "   balance looked up with the ISP id (what it should do):"
  q -c "SELECT sms_balance FROM isps WHERE id='$ISP'::uuid;"
fi
echo "   the balance check in sms.js:"
sudo grep -n "sms_balance FROM isps\|RumaLink SMS requires ISP context\|SMS_BALANCE_EMPTY" "$BE/utils/sms.js" | sed 's/^/     /'

say "2) Backups"
sudo cp "$BE/utils/sms.js" "$BE/utils/.sms.js.bak_$TS" && echo "   sms.js"
sudo cp "$CP/pppoe.html" "$CP/.pppoe.html.bak_$TS" && echo "   pppoe.html"

say "3) FIX A — resolve the ISP id correctly inside sendSMS"
sudo python3 - "$BE/utils/sms.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_SMS_ISP_ID' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r"^([ \t]*)if \(gateway === 'rumalink'\) \{", s, re.M)
if not m:
    print("   ERROR: rumalink balance block not found — unchanged"); sys.exit(1)
ind = m.group(1)
decl = (
f"{ind}/* RL_SMS_ISP_ID: the balance was looked up with isp.id, but several callers pass a JOINED\n"
f"{ind}   row rather than an ISP row — the PPPoE expiry sweep selects ps.id (the SUBSCRIBER's id)\n"
f"{ind}   and the hotspot expiry selects hv.id (the VOUCHER's id), both alongside i.company_name.\n"
f"{ind}   The lookup matched nothing, read the balance as 0 and refused to send while the ISP had\n"
f"{ind}   credits on file. A joined row always carries the correct isp_id; a true ISP row carries\n"
f"{ind}   only id. Resolving both here fixes every caller at once. */\n"
f"{ind}const _rlIspId = (isp && (isp.isp_id || isp.id)) || null;\n"
)
s = s[:m.start()] + decl + s[m.start():]

pairs = [
 ("if (!isp || !isp.id) throw new Error('RumaLink SMS requires ISP context');",
  "if (!_rlIspId) throw new Error('RumaLink SMS requires ISP context');"),
 ('const balRes = await query("SELECT sms_balance FROM isps WHERE id=$1::uuid", [isp.id]);',
  'const balRes = await query("SELECT sms_balance FROM isps WHERE id=$1::uuid", [_rlIspId]);'),
 ("if (gateway === 'rumalink' && isp && isp.id) {",
  "if (gateway === 'rumalink' && _rlIspId) {"),
 ('const upd = await query("UPDATE isps SET sms_balance = GREATEST(sms_balance - 1, 0) WHERE id=$1::uuid RETURNING sms_balance", [isp.id]);',
  'const upd = await query("UPDATE isps SET sms_balance = GREATEST(sms_balance - 1, 0) WHERE id=$1::uuid RETURNING sms_balance", [_rlIspId]);'),
 ("VALUES ($1::uuid, 'consumption', -1, $2, 'completed', 'SMS sent')`, [isp.id, after]);",
  "VALUES ($1::uuid, 'consumption', -1, $2, 'completed', 'SMS sent')`, [_rlIspId, after]);"),
]
n = 0
for old, new in pairs:
    if old in s:
        s = s.replace(old, new, 1); n += 1
    else:
        print("   note: pattern not present -> " + old[:58])
open(p,'w').write(s)
print(f"   {n}/{len(pairs)} reference(s) switched to the resolved ISP id")
PY
cd "$BE" && sudo -u www-data node --check utils/sms.js && echo "   sms.js syntax OK"

say "4) sms_logs should also record the real ISP id"
sudo python3 - "$BE/utils/sms.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
old = "[isp.id || null, String(to),"
new = "[(isp.isp_id || isp.id) || null, String(to),"
if old in s:
    s = s.replace(old, new, 1); open(p,'w').write(s); print("   sms_logs isp_id corrected")
else:
    print("   (log line already correct or shaped differently)")
PY
cd "$BE" && sudo -u www-data node --check utils/sms.js && echo "   sms.js syntax OK"
sudo grep -n "_rlIspId" "$BE/utils/sms.js" | sed 's/^/   /'

say "5) FIX B — hide Pay by Paybill, default to the M-Pesa prompt"
sudo python3 - "$CP/pppoe.html" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_PAYBILL_HIDDEN' in s:
    print("   already patched"); sys.exit(0)
edits = [
 ("""<div class="tab active" id="tab-paybill" onclick="showTab('paybill')">Pay by Paybill</div>""",
  """<!-- RL_PAYBILL_HIDDEN: the paybill flow is not configured yet, so the tab is hidden rather
           than deleted. To restore it: remove style="display:none" here, drop the "hide" class from
           #pane-paybill, and move "active" back to this tab from #tab-stk. -->
      <div class="tab" id="tab-paybill" style="display:none" onclick="showTab('paybill')">Pay by Paybill</div>"""),
 ("""<div class="tab" id="tab-stk" onclick="showTab('stk')">M-Pesa Prompt</div>""",
  """<div class="tab active" id="tab-stk" onclick="showTab('stk')">M-Pesa Prompt</div>"""),
 ("""<div id="pane-paybill">""", """<div id="pane-paybill" class="hide">"""),
 ("""<div id="pane-stk" class="hide">""", """<div id="pane-stk">"""),
]
n=0
for old,new in edits:
    if old in s: s = s.replace(old,new,1); n+=1
    else: print("   MISS: " + old[:58])
open(p,'w').write(s); print(f"   {n}/4 edits applied")
PY
sudo chown www-data:www-data "$CP/pppoe.html"
echo "   result:"
sudo grep -nE 'id="tab-paybill"|id="tab-stk"|id="pane-paybill"|id="pane-stk"' "$CP/pppoe.html" | sed 's/^/     /'

say "6) Restart, then send through a JOINED row exactly as the sweep does"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
q -c "SELECT company_name, sms_balance FROM isps;"
read -r -p "   Send one real test SMS to an expired subscriber? (y/N): " GO || true
if [ "${GO:-n}" = "y" ] || [ "${GO:-n}" = "Y" ]; then
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const {query}=require('$BE/config/database');
(async()=>{
  const sub=(await query(\"SELECT ps.id, ps.isp_id, ps.phone, ps.full_name, i.company_name, i.sms_gateway FROM pppoe_subscribers ps JOIN isps i ON i.id=ps.isp_id WHERE ps.status='expired' AND ps.phone IS NOT NULL ORDER BY ps.updated_at DESC LIMIT 1\")).rows[0];
  if(!sub){console.log('   no expired subscriber with a phone');process.exit(0);}
  console.log('   sub.id (subscriber) = '+sub.id);
  console.log('   sub.isp_id (ISP)    = '+sub.isp_id);
  try{
    await require('$BE/utils/sms').sendSMS({to: sub.phone,
      message:'Dear '+(sub.full_name||'Customer')+', your '+sub.company_name+' internet has expired. Pay to reconnect.',
      isp: sub});
    console.log('   SENT — the balance now resolves via isp_id');
  }catch(e){ console.log('   FAILED: '+e.message); }
  process.exit(0);
})();" 2>&1 | grep -vE "^info: SMS" | sed 's/^/  /'
else echo "   skipped"; fi
q -c "SELECT recipient, status, LEFT(message,44) AS msg, to_char(sent_at,'HH24:MI:SS') AS at FROM sms_logs ORDER BY sent_at DESC LIMIT 3;"
curl -sk -o /dev/null -w "   pppoe portal HTTP %{http_code}\n" https://rumalinkenterprise.online/captive/pppoe.html

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "SMS: resolve ISP id from joined rows (balance read as 0 despite credits); hide paybill on PPPoE portal" 2>&1 | head -2 | sed 's/^/   /'
echo
echo "   Rollback: sudo cp $BE/utils/.sms.js.bak_$TS $BE/utils/sms.js"
echo "             sudo cp $CP/.pppoe.html.bak_$TS $CP/pppoe.html"
