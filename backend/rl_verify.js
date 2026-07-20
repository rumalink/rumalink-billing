require("dotenv").config();
const { query } = require("./config/database");
const mw = require("./utils/mwan-applier");
(async () => {
  const d = (await query("SELECT id FROM nas_devices WHERE is_online=true LIMIT 1")).rows[0];
  const fn = mw.linkStatus || mw.getLinkStatus || mw.statusFor || mw.deviceStatus;
  if (!fn) { console.log("  status fn not exported:", Object.keys(mw).join(",")); process.exit(0); }
  const r = await fn(d.id);
  const arr = (r && r.statuses) || (Array.isArray(r) ? r : []);
  arr.forEach(s => {
    console.log("  WAN" + s.position + " (" + s.interface + ")");
    console.log("     probe_verdict : " + s.probe_verdict);
    console.log("     probe_stage   : " + s.probe_stage);
    console.log("     fetch_ms      : " + s.fetch_ms);
    console.log("     external_ping : " + s.external_ping_ok);
  });
  process.exit(0);
})();
