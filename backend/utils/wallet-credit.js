// utils/wallet-credit.js
// RL_WALLET_CREDIT: credit an ISP's wallet for a paid payment EXACTLY once, no matter which path
// (IPN, poll, cron sweep, onPaid) confirms it. Idempotency is structural: we insert the commission
// row first with ON CONFLICT (payment_id) DO NOTHING; the wallet is credited ONLY if that insert
// created a new row. Two racing callers -> one insert wins -> one credit.
const { query } = require('../config/database');
const logger = require('./logger');

async function creditWalletOnce(paymentId) {
  const pr = await query("SELECT * FROM payments WHERE id=$1::uuid", [paymentId]);
  const p = pr.rows[0];
  if (!p) return { ok: false, reason: 'no payment' };
  if (p.status !== 'paid') return { ok: false, reason: 'not paid' };

  // Attempt to claim the credit by inserting the commission row. If it already exists, we already
  // credited this payment — do nothing.
  const ins = await query(
    `INSERT INTO commissions (isp_id, payment_id, amount, rate)
     VALUES ($1::uuid,$2::uuid,$3,$4)
     ON CONFLICT (payment_id) DO NOTHING
     RETURNING id`,
    [p.isp_id, p.id, p.commission_amount || 0, p.commission_rate || 0]
  );
  if (!ins.rows[0]) return { ok: true, already: true };  // someone already credited it

  // We own the credit. Apply it.
  await query(
    `UPDATE isps SET wallet_balance = wallet_balance + $1,
                     total_earned = total_earned + $2,
                     total_commission_paid = total_commission_paid + $3
     WHERE id = $4::uuid`,
    [p.net_amount, p.amount, p.commission_amount || 0, p.isp_id]
  );
  const bal = await query('SELECT wallet_balance FROM isps WHERE id=$1::uuid', [p.isp_id]);
  await query(
    `INSERT INTO isp_transactions (isp_id, type, amount, balance_after, description, reference_id)
     VALUES ($1::uuid,'payment',$2,$3,$4,$5)`,
    [p.isp_id, p.net_amount, bal.rows[0] && bal.rows[0].wallet_balance,
     'IntaSend payment - ' + (p.transaction_id || p.gateway_reference || p.id), p.id]
  ).catch(()=>{});
  // RL_CREDIT_NOTIFY: one success notification per credited payment (idempotent by construction —
  // we only reach here when this call claimed the credit).
  await query("INSERT INTO notifications (isp_id, type, title, message) VALUES ($1::uuid,'success','Payment Received',$2)",
    [p.isp_id, 'KES ' + p.net_amount + ' credited to your wallet (IntaSend).']).catch(function(){});
  logger.info('[wallet-credit] ' + p.id + ' credited net=' + p.net_amount + ' isp=' + p.isp_id);
  return { ok: true, credited: p.net_amount };
}

module.exports = { creditWalletOnce };
