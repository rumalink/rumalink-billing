// RL_INTASEND_POLL: confirms pending IntaSend collections by querying the status API.
// This is the reliable path: it works whether or not the IntaSend dashboard webhook is
// configured, and also catches any webhook that was missed.
const { query } = require('../config/database');
const isc = require('./intasend-client');
const logger = require('./logger');

// Credit an ISP for a confirmed payment (idempotent — only acts on a still-pending row).
async function creditPayment(p, receipt, invoiceId) {
  const upd = await query(
    "UPDATE payments SET status='paid', paid_at=NOW(), transaction_id=COALESCE($2,transaction_id), updated_at=NOW() WHERE id=$1::uuid AND status<>'paid' RETURNING id",
    [p.id, receipt || String(invoiceId || '')]
  );
  if (!upd.rows[0]) return false; // someone else already confirmed it

  // RL_POLL_CREDIT_HELPER: single idempotent credit path (wallet+commission+ledger+notify).
  await require('./wallet-credit').creditWalletOnce(p.id);
  await query("UPDATE hotspot_vouchers SET is_paid=true, amount_paid=$1 WHERE payment_id=$2::uuid", [p.amount, p.id]).catch(()=>{});
  await query("UPDATE mpesa_transactions SET status='completed' WHERE payment_id=$1::uuid", [p.id]).catch(()=>{});
  // RL_ACTIVATE_HOOK: activate the voucher + sync RADIUS so the customer gets online.
  try { await require('./intasend-activate').activateVoucher(p.id); }
  catch (ae) { logger.error('[INTASEND-POLL] activation failed: ' + ae.message); }
  logger.info(`[INTASEND-POLL] CONFIRMED payment=${p.id} isp=${p.isp_id} net=${p.net_amount}`);
  return true;
}

async function pollPending() {
  try {
    await activateSweep();   // RL_ACTIVATE_SWEEP
    await clearingSweep();   // RL_CLEARING_SWEEP
    // Pending IntaSend payments from the last 2 hours (older ones are almost certainly abandoned).
    const r = await query(
      `SELECT * FROM payments
       WHERE payment_gateway='intasend' AND status='pending'
         AND created_at > NOW() - INTERVAL '2 hours'
       ORDER BY created_at ASC LIMIT 50`
    );
    if (!r.rows.length) return;
    for (const p of r.rows) {
      const invoiceId = p.transaction_id || (p.metadata && p.metadata.intasend_invoice);
      if (!invoiceId) continue;
      try {
        const st = await isc.collectionStatus(invoiceId);
        // RL_SPEC_STATES: InvoicesSerStateEnum = PENDING|PROCESSING|FAILED|CANCELED|PARTIAL|COMPLETE|RETRY
        const state = String(st.state || '').toUpperCase();
        if (st.isPaid) {
          await creditPayment(p, st.receipt, invoiceId);
        } else if (st.isDead) {
          await query("UPDATE payments SET status='failed', failure_reason=$1, updated_at=NOW() WHERE id=$2::uuid AND status='pending'",
            [('IntaSend: ' + state + (st.failedReason ? ' - ' + st.failedReason : '')).slice(0,240), p.id]).catch(()=>{});
          logger.info(`[INTASEND-POLL] ${state} payment=${p.id}`);
        } else if (state === 'PARTIAL') {
          logger.warn(`[INTASEND-POLL] PARTIAL payment=${p.id} — underpaid, left pending for review`);
        }
        // PENDING/PROCESSING → leave it; next tick will check again.
      } catch (e) {
        logger.warn(`[INTASEND-POLL] status check failed for ${invoiceId}: ${e.message}`);
      }
    }
  } catch (e) {
    logger.error('[INTASEND-POLL] ' + e.message);
  }
}


// RL_ACTIVATE_SWEEP: creditPayment() returns early when a payment is already 'paid', so
// activation placed after it never ran for payments confirmed by an earlier poll. This
// sweep activates ANY paid IntaSend payment whose voucher still has no expiry.
async function activateSweep() {
  try {
    const r = await query(`
      SELECT p.id
      FROM payments p
      JOIN hotspot_vouchers v ON v.payment_id = p.id
      WHERE p.payment_gateway = 'intasend'
        AND p.status = 'paid'
        AND (v.expires_at IS NULL OR v.expires_at < NOW())
        AND p.created_at > NOW() - INTERVAL '7 days'
      LIMIT 25`);
    if (!r.rows.length) return;
    const act = require('./intasend-activate');
    for (const row of r.rows) {
      await act.activateVoucher(row.id);
    }
  } catch (e) {
    logger.error('[INTASEND-SWEEP] ' + e.message);
  }
}

// RL_CLEARING_SWEEP: refresh clearing_status for paid payments that aren't cleared yet.
// IntaSend settles ~T+4; until clearing_status is CLEARED the money is NOT withdrawable.
async function clearingSweep() {
  try {
    const r = await query(`
      SELECT id, intasend_invoice
      FROM payments
      WHERE payment_gateway='intasend' AND status='paid'
        AND (clearing_status IS NULL OR clearing_status NOT IN ('CLEARED','SETTLED'))
        AND intasend_invoice IS NOT NULL
        AND created_at > NOW() - INTERVAL '30 days'
      ORDER BY created_at DESC LIMIT 25`);
    if (!r.rows.length) return;
    for (const p of r.rows) {
      try {
        const st = await isc.collectionStatus(p.intasend_invoice);
        const cs = st.invoice && st.invoice.clearing_status;
        if (!cs) continue;
        const cleared = isc.isCleared(cs);
        await query(
          "UPDATE payments SET clearing_status=$1, cleared_at=CASE WHEN $2 THEN COALESCE(cleared_at, NOW()) ELSE cleared_at END, updated_at=NOW() WHERE id=$3::uuid",
          [String(cs).toUpperCase(), cleared, p.id]);
        if (cleared) logger.info('[INTASEND-CLEARING] payment ' + p.id + ' CLEARED');
      } catch (e) { /* keep going */ }
    }
  } catch (e) {
    logger.error('[INTASEND-CLEARING] ' + e.message);
  }
}

module.exports = { pollPending, creditPayment, clearingSweep , activateSweep };
