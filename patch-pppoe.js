const fs = require("fs");
const file = "./backend/routes/isp.js";
let code = fs.readFileSync(file, "utf8");

// 1. Intercept the frontend payload and force the password field to be recognized
const routeStart = "router.patch('/:ispId/pppoe-subscriber/:subscriberId', async (req, res) => {";
if (code.includes(routeStart) && !code.includes("req.body.password = req.body.password ||")) {
    code = code.replace(
        routeStart,
        routeStart + "\n  if (req.body) { req.body.password = req.body.password || req.body.pppoe_password || req.body.pppoePassword || req.body.new_password || req.body.secret; }\n"
    );
}

// 2. Replace the strict fields check with one that logs the incoming data if it fails
const regex = /if \(\s*fields\.length === 0\s*\) return res\.status\(400\)\.json\(\{ ok: false, error: 'no fields to update' \}\);/g;
code = code.replace(
    regex,
    "if (fields.length === 0 && !req.body.password && !req.body.package_id) { return res.status(400).json({ ok: false, error: 'Backend received: ' + JSON.stringify(req.body) }); }"
);

fs.writeFileSync(file, code, "utf8");
console.log("✅ Hard-patched PPPoE route!");
