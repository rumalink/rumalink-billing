require("dotenv").config();
const { query } = require("./config/database");
const { creditWalletOnce } = require("./utils/wallet-credit");
(async()=>{
  const isp = process.argv[2];
  const rows = (await query(
    `SELECT p.id, p.net_amount FROM payments p
       LEFT JOIN commissions c ON c.payment_id=p.id
      WHERE p.isp_id=$1::uuid AND p.status='paid' AND p.payment_gateway='intasend' AND c.id IS NULL
      ORDER BY p.paid_at ASC`, [isp])).rows;
  console.log("   backfilling " + rows.length + " payment(s)...");
  let total = 0;
  for (const r of rows) {
    const res = await creditWalletOnce(r.id);
    console.log("     " + r.id.slice(0,8) + " net=" + r.net_amount + " -> " + JSON.stringify(res));
    if (res.credited) total += parseFloat(res.credited);
  }
  const w = (await query("SELECT wallet_balance, total_earned FROM isps WHERE id=$1::uuid",[isp])).rows[0];
  console.log("   credited this run : " + total.toFixed(2));
  console.log("   wallet_balance now: " + w.wallet_balance);
  console.log("   total_earned now  : " + w.total_earned);
  process.exit(0);
})();
