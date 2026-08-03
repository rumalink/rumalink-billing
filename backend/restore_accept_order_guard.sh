#!/usr/bin/env bash
#
# restore_accept_order_guard.sh
#
# B6 reported accept-order=WRONG: the bare `accept established,related` rule sits ABOVE the
# rl-expired reject rules, so an expired customer's already-open connections are accepted
# before reaching the walled garden — the revenue leak we closed on 31 July.
#
# WHY IT CAME BACK: router-harden.js was restored from the backup taken immediately BEFORE the
# RL_ACCEPT_ORDER enforcement was added, so the guard that re-asserted this ordering every two
# minutes was lost. Provisioning still gets new routers right (RL_ACCEPT_LAST passes); nothing
# was watching the existing one.
#
# FIX: re-add the guard, and correct the live router now. Ordering is enforced by DELETE +
# re-ADD (an append reliably lands last), never a positional move — positional moves are what
# previously black-holed every expired user.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) The live forward chain as it stands"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const r=await query('SELECT name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL');
 for(const d of r.rows){
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  try{
   const f=((await axios.get(b+'/ip/firewall/filter',{auth,timeout:20000})).data||[]).filter(x=>x.chain==='forward');
   console.log('   --- '+d.name+' ---');
   f.forEach((x,i)=>console.log('   '+i+' '+x.action+(x['connection-state']?' cs='+x['connection-state']:'')+
     (x['src-address-list']?' srclist='+x['src-address-list']:'')+'  # '+(x.comment||'')));
  }catch(e){console.log('   '+d.name+': '+e.message)}
 }
 process.exit(0);
})();"

say "2) Confirm the guard is missing from router-harden.js"
sudo grep -c "RL_ACCEPT_ORDER" "$BE/utils/router-harden.js" | sed 's/^/   RL_ACCEPT_ORDER occurrences: /'

say "3) Re-add the guard"
sudo cp "$BE/utils/router-harden.js" "$BE/utils/.router-harden.js.bak_$TS" && echo "   backed up"
sudo python3 - "$BE/utils/router-harden.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_ACCEPT_ORDER' in s:
    print("   already present"); sys.exit(0)
anchor = "  // 2) MSS clamp"
if anchor not in s:
    print("   ERROR: anchor '// 2) MSS clamp' not found — unchanged"); sys.exit(1)
BLOCK = """  // 1b) RL_ACCEPT_ORDER — the bare `accept established,related` rule must sit BELOW every
  //     rl-expired rule. Above them, an expired customer's already-open connections are accepted
  //     before reaching the expiry reject, and they keep browsing after their package ends.
  //     Enforced by DELETE + re-ADD (an append reliably lands last) rather than a positional
  //     move: positional moves previously black-holed every expired user. Safe because the
  //     forward chain has no terminal drop — during the sub-millisecond gap traffic falls
  //     through to the chain's default accept.
  try {
    const fwA = await get('/ip/firewall/filter');
    const fwd = fwA.filter(x => x.chain === 'forward');
    const acceptIdx = fwd.findIndex(x =>
      x.action === 'accept' &&
      String(x['connection-state'] || '') === 'established,related' &&
      !x['src-address'] && !x['dst-address'] && !x['src-address-list'] && !x['dst-address-list']);
    const lastExpiredIdx = fwd.map((x, i) =>
      String(x['src-address-list'] || '') === 'rl-expired' ? i : -1)
      .reduce((a, b) => Math.max(a, b), -1);
    if (acceptIdx > -1 && lastExpiredIdx > -1 && acceptIdx < lastExpiredIdx) {
      const rule = fwd[acceptIdx];
      const body = { chain: 'forward', action: 'accept', 'connection-state': 'established,related',
                     comment: rule.comment || 'RL-FASTTRACK accept' };
      try {
        await del('/ip/firewall/filter', rule['.id']);
        await put('/ip/firewall/filter', body);
        logger.warn('[router-harden] ' + d.name +
          ' established/related accept was ABOVE the expiry rules (position ' + acceptIdx +
          ' vs ' + lastExpiredIdx + ') — moved to the bottom; expired users could bypass the walled garden');
      } catch (e) { logger.warn('[router-harden] accept-order: ' + e.message); }
    }
  } catch (e) { logger.warn('[router-harden] accept-order: ' + e.message); }

"""
s = s.replace(anchor, BLOCK + anchor, 1)
open(p,'w').write(s); print("   RL_ACCEPT_ORDER guard re-added")
PY
cd "$BE" && sudo -u www-data node --check utils/router-harden.js && echo "   router-harden.js syntax OK"

say "4) Restart and let the guard correct the live router"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1
echo "   waiting up to 150s for a router-harden pass..."
sleep 130
pm2 logs rumalink-backend --lines 80 --nostream 2>/dev/null | grep -iE "router-harden.*accept|accept-order" | tail -4 | sed 's/^/   /' || echo "   (no correction logged yet)"

say "5) Verify the ordering is now correct"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const axios=require('axios');const {query}=require('$BE/config/database');
(async()=>{
 const r=await query('SELECT name,wireguard_ip,mikrotik_api_user,mikrotik_api_password FROM nas_devices WHERE wireguard_ip IS NOT NULL');
 for(const d of r.rows){
  const b='http://'+d.wireguard_ip+'/rest';const auth={username:d.mikrotik_api_user,password:d.mikrotik_api_password};
  try{
   const f=((await axios.get(b+'/ip/firewall/filter',{auth,timeout:20000})).data||[]).filter(x=>x.chain==='forward');
   const ai=f.findIndex(x=>x.action==='accept'&&String(x['connection-state']||'')==='established,related'&&!x['src-address-list']);
   const li=f.map((x,i)=>String(x['src-address-list']||'')==='rl-expired'?i:-1).reduce((a,b)=>Math.max(a,b),-1);
   console.log('   '+d.name+': accept@'+ai+' lastExpired@'+li+' => '+((li===-1||ai>li)?'CORRECT':'*** STILL WRONG ***'));
   f.forEach((x,i)=>console.log('     '+i+' '+x.action+(x['src-address-list']?' srclist='+x['src-address-list']:'')+'  # '+(x.comment||'')));
  }catch(e){console.log('   '+d.name+': '+e.message)}
 }
 process.exit(0);
})();"

say "6) Confirm PM2 will actually resurrect the app after a reboot"
echo "   processes in the saved dump:"
sudo -u www-data node -e "
const fs=require('fs');
try{ const j=JSON.parse(fs.readFileSync('/root/.pm2/dump.pm2','utf8'));
  (j.data||j).forEach(x=>console.log('     '+(x.name||'?')+'  script='+(x.script||x.pm_exec_path||'?')));
}catch(e){ console.log('     could not parse dump.pm2: '+e.message); }" 2>/dev/null || sudo grep -oE '"name":"[^"]+"' /root/.pm2/dump.pm2 | sed 's/^/     /'

say "7) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Re-add RL_ACCEPT_ORDER guard lost in the restore; stamp activation on Daraja" 2>&1 | head -2 | sed 's/^/   /'
sudo git -C /var/www/rumalink log --oneline | head -2 | sed 's/^/   /'
