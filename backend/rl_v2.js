require("dotenv").config();
const { query } = require("./config/database");
const mw = require("./utils/mwan-applier");
(async()=>{
  const d=(await query(
    "SELECT id FROM nas_devices WHERE is_online=true AND multi_wan_applied_at IS NOT NULL LIMIT 1")).rows[0];
  if(!d){ console.log("  no applied device"); process.exit(0); }
  const fn = mw.getLinkStatus || mw.linkStatus;
  const r = await fn(d.id);
  const arr=(r&&r.statuses)||[];
  let ok=0;
  arr.forEach(s=>{
    const has = s.in_load_balance !== undefined;
    if(has && s.in_load_balance) ok++;
    console.log("  WAN"+s.position+"  in_load_balance="+s.in_load_balance+
                "  lb_weight="+s.lb_weight+
                "  bytes="+(s.bytes_carried?(Number(s.bytes_carried)/1048576).toFixed(0)+"MB":"-")+
                (has?"":"   <-- STILL MISSING"));
  });
  console.log("  links passing the filter: "+ok+(ok>=2 ? "   -> the visual will render" : "   -> needs 2+"));
  process.exit(0);
})();
