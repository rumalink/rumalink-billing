const fs = require("fs");
const file = "./backend/routes/isp.js";
let code = fs.readFileSync(file, "utf8");

// Modify the SELECT query to include the password from radcheck
const searchString = "s.created_at, pkg.name as package_name, pkg.price as package_price /* RL_PPPOE_COL_FIX */";
const replacementString = "s.created_at, pkg.name as package_name, pkg.price as package_price, rc.value as password /* RL_PPPOE_COL_FIX */";

if (code.includes(searchString) && !code.includes("rc.value as password")) {
    code = code.replace(searchString, replacementString);
    
    // Add the JOIN for radcheck
    code = code.replace(
        "LEFT JOIN pppoe_packages pkg ON pkg.id = s.package_id",
        "LEFT JOIN pppoe_packages pkg ON pkg.id = s.package_id\n          LEFT JOIN radcheck rc ON rc.username = s.username AND rc.attribute = 'Cleartext-Password'"
    );

    // Map the fetched password to the users array
    code = code.replace(
        "expires_at: row.expires_at, status: row.status, created_at: row.created_at,",
        "expires_at: row.expires_at, status: row.status, created_at: row.created_at, password: row.password,"
    );

    fs.writeFileSync(file, code, "utf8");
    console.log("✅ Patched GET subscribers route to include PPPoE passwords.");
} else {
    console.log("ℹ️ Route already patched or search string not found.");
}
