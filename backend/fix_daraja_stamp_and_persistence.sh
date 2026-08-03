#!/usr/bin/env bash
#
# PART A — the ping-pong fix relies on payments.voucher_activated_at, but only
#   intasend-activate.activateVoucher stamps it. The Daraja callback activates the voucher with
#   its own inline SQL, so Daraja payments would still look unfulfilled after a later top-up
#   re-points the voucher — the same duplicate-SMS / extra-hour loop, just on the other gateway.
#
# PART B — verify everything currently working survives a VPS reboot and a fresh MikroTik.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
ok(){ echo "   ${G}PASS${N}  $*"; }
bad(){ echo "   ${R}FAIL${N}  $*"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "A1) Does the Daraja callback stamp voucher_activated_at?"
sudo grep -n "voucher_activated_at" "$BE/routes/captive.js" | sed 's/^/   /' || echo "   ${Y}NOT stamped anywhere in captive.js${N}"
echo "   Daraja payments and their stamp:"
q -c "SELECT LEFT(id::text,8) AS pay, payment_gateway, status, voucher_activated_at IS NOT NULL AS stamped
      FROM payments WHERE status='paid' ORDER BY created_at DESC LIMIT 6;"

say "A2) Stamp it in the Daraja callback"
sudo cp "$BE/routes/captive.js" "$BE/routes/.captive.js.bak_$TS"
sudo python3 - "$BE/routes/captive.js" <<'PY'
import sys, re
p=sys.argv[1]; s=open(p).read()
if 'RL_DARAJA_ACTIVATE_STAMP' in s:
    print("   already patched"); sys.exit(0)
m = re.search(r'^([ \t]*)await syncRadiusForVoucher\(voucher\.id\)\.catch\(\(\)=>\{\}\);\s*$', s, re.M)
if not m:
    print("   ERROR: syncRadiusForVoucher anchor not found — unchanged"); sys.exit(1)
ind = m.group(1)
add = ("\n" + ind + "/* RL_DARAJA_ACTIVATE_STAMP: strand-heal skips payments whose voucher was already\n"
       + ind + "   activated (RL_SKIP_ACTIVATED), but only the IntaSend activator stamped this column.\n"
       + ind + "   Without it a Daraja payment looks unfulfilled once a later top-up re-points the\n"
       + ind + "   voucher, and gets 'healed' — duplicate SMS and a second period of access. */\n"
       + ind + "await query(\"UPDATE payments SET voucher_activated_at = COALESCE(voucher_activated_at, NOW()) WHERE id = $1::uuid\", [req.params.paymentId]).catch(()=>{});")
s = s[:m.end()] + add + s[m.end():]
open(p,'w').write(s); print("   stamp added to the Daraja callback")
PY
cd "$BE" && sudo -u www-data node --check routes/captive.js && echo "   captive.js syntax OK"

say "A3) Backfill any paid payment that has a voucher but no stamp"
q -c "UPDATE payments p SET voucher_activated_at = COALESCE(p.voucher_activated_at, p.paid_at, NOW())
      WHERE p.status='paid' AND p.voucher_activated_at IS NULL
        AND EXISTS (SELECT 1 FROM hotspot_vouchers v WHERE v.payment_id = p.id);"
q -c "UPDATE payments SET metadata = COALESCE(metadata,'{}'::jsonb) || jsonb_build_object('rl_healed','served')
      WHERE voucher_activated_at IS NOT NULL AND (metadata->>'rl_healed') IS NULL;"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8

say "B1) Will the stack come back after a reboot?"
systemctl is-enabled pm2-root.service 2>/dev/null | sed 's/^/   pm2-root.service: /'
for s in postgresql nginx freeradius; do printf "   %-12s " "$s"; systemctl is-enabled "$s" 2>/dev/null || echo "unknown"; done
sudo pm2 save >/dev/null 2>&1 && echo "   pm2 process list saved"
echo "   saved processes:"; sudo cat /root/.pm2/dump.pm2 2>/dev/null | grep -oE '"name":"[^"]+"' | sort -u | sed 's/^/     /'
grep -q '^/swapfile' /etc/fstab && ok "swap persists via /etc/fstab" || bad "swap not in /etc/fstab"

say "B2) Cron jobs that keep things healthy"
sudo crontab -l 2>/dev/null | grep -v '^#' | sed 's/^/   /'

say "B3) Guards that self-heal the routers (survive reboot + reprovision)"
pm2 logs rumalink-backend --lines 80 --nostream 2>/dev/null \
  | grep -oE "\[(HEALTH|QUEUE-MONITOR|QUEUE-INTEGRITY|EXPIRED-ENFORCER|router-harden|strand-heal)\][^{]*" | sort -u | sed 's/^/   /'

say "B4) A NEW MikroTik: what does the provisioning script contain?"
TOKEN=$(q -tAc "SELECT provision_token FROM nas_devices WHERE provision_token IS NOT NULL ORDER BY created_at DESC LIMIT 1;")
curl -s "http://127.0.0.1:5000/api/provision/$TOKEN/script" > /tmp/prov.txt 2>/dev/null || true
echo "   rendered $(wc -l < /tmp/prov.txt) lines"
grep -q "action=fasttrack-connection" /tmp/prov.txt && bad "fasttrack IS provisioned" || ok "no fasttrack rule"
grep -q "require-message-auth=no" /tmp/prov.txt && ok "router asks for no Message-Authenticator" || bad "message-auth flag missing"
grep -q "reject reject-with=icmp-admin-prohibited" /tmp/prov.txt && ok "walled garden rejects (fails fast)" || bad "walled garden still drops"
grep -q 'RL_ACCEPT_LAST' /tmp/prov.txt && ok "accept rule re-asserted last" || bad "accept-last block missing"
echo "   forward-chain order:"
grep -n "ip firewall filter add chain=forward" /tmp/prov.txt | sed 's/^/     /'

say "B5) RADIUS client sync — a new router must authenticate"
sudo grep -c "require_message_authenticator = no" /usr/local/bin/rumalink-radius-clients-sync.sh 2>/dev/null | sed 's/^/   msg-auth off in sync script: /'
sudo grep -c "RL_SECRET_CONVERGE_CRON" /usr/local/bin/rumalink-radius-clients-sync.sh 2>/dev/null | sed 's/^/   secret convergence in sync: /'
sudo grep -c "RL_SECRET_CONVERGE" "$BE/routes/provision.js" | sed 's/^/   secret convergence in provisioning: /'
sudo cat /etc/freeradius/3.0/clients-rumalink.conf 2>/dev/null | sed 's/^/     /'

say "B6) Live router state"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const r=await query('SELECT name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL');
 for(const d of r.rows){
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  try{
   const f=(await axios.get(b+'/ip/firewall/filter',{auth,timeout:20000})).data||[];
   const st=(await axios.get(b+'/ip/settings',{auth,timeout:20000})).data||{};
   const qs=(await axios.get(b+'/queue/simple',{auth,timeout:20000})).data||[];
   const fwd=f.filter(x=>x.chain==='forward');
   const ai=fwd.findIndex(x=>x.action==='accept'&&String(x['connection-state']||'')==='established,related'&&!x['src-address-list']);
   const li=fwd.map((x,i)=>String(x['src-address-list']||'')==='rl-expired'?i:-1).reduce((a,b)=>Math.max(a,b),-1);
   console.log('   '+d.name+': fasttrack='+f.filter(x=>x.action==='fasttrack-connection').length+
     ' active='+st['ipv4-fasttrack-active']+' queues='+qs.length+
     ' accept-order='+((li===-1||ai>li)?'ok':'WRONG'));
  }catch(e){console.log('   '+d.name+': '+e.message)}
 }
 process.exit(0);
})();"

say "B7) Commit this working state to git"
if [ -d /var/www/rumalink/.git ]; then
  sudo git -C /var/www/rumalink add -A
  sudo git -C /var/www/rumalink commit -qm "IntaSend parity: autologin, purchase SMS, heal ping-pong fixed ($(date +%F' '%H:%M))" 2>&1 | head -2 | sed 's/^/   /'
  sudo git -C /var/www/rumalink log --oneline | head -3 | sed 's/^/   /'
else
  echo "   ${Y}no git repo yet — run setup_git_safety.sh${N}"
fi
