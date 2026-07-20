require("dotenv").config();
const { query } = require("./config/database");
const mw = require("./utils/mwan-applier");
(async()=>{
  const d=(await query("SELECT id FROM nas_devices WHERE is_online=true LIMIT 1")).rows[0];
  const fn = mw.linkStatus || mw.getLinkStatus || mw.statusFor || mw.deviceStatus || mw.mwanStatus;
  if(!fn){ console.log("  exports: "+Object.keys(mw).join(", ")); process.exit(0); }
  const r = await fn(d.id);
  const arr = (r && r.statuses) || (Array.isArray(r) ? r : []);
  if(!arr.length){ console.log("  no statuses returned"); process.exit(0); }
  arr.forEach(s=>{
    const b = Number(s.bytes_carried||0);
    const mb = b ? (b/1048576).toFixed(1)+" MB" : "MISSING";
    console.log("  WAN"+s.position+" ("+s.interface+")  bytes_carried="+mb+"   probe="+s.probe_verdict);
  });
  process.exit(0);
})();
