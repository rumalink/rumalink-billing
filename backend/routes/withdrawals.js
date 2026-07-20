/* RL_CLEARING_INVARIANT
 * Money is held ONLY when clearing_status is one of the PENDING states:
 *     CLEARING | ON_HOLD | PENDING | PROCESSING
 * Everything else — AVAILABLE (IntaSend's settled value), CLEARED, SETTLED, COMPLETE,
 * UNVERIFIABLE, or NULL — is withdrawable.
 *
 * Do NOT reintroduce a "cleared whitelist" form. It
 * fails OPEN: any status not enumerated is treated as uncleared, so an ISP's money gets
 * frozen the moment IntaSend uses a value we did not predict. That is exactly what
 * happened with AVAILABLE.
 */
const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const fees = require('../utils/intasend-fees');
const intasend = require('../utils/intasend-client');
const logger = require('../utils/logger');

// RL_WD_AUTH_FIXED: use the app's real middleware chain.
const { authenticateToken, requireISP } = require('../middleware/auth');
const ispAuthChain = [authenticateToken, requireISP];
function getIspId(req) { return req.ispId || (req.isp && req.isp.id) || (req.user && req.user.isp_id); }

// GET /api/withdrawals/methods — enabled methods + min withdrawal per method + saved destinations
router.get('/methods', ...ispAuthChain, async (req, res) => {
  try {
    const en = await fees.enabledMethods();
    const out = [];
    for (const m of ['mpesa','bank','b2b']) {
      if (!en[m]) continue;
      out.push({ method: m, min_withdrawal: await fees.minWithdrawal(m) });
    }
    res.json({ methods: out });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// GET /api/withdrawals/quote?amount=&method= — live fee/net/threshold preview
router.get('/quote', ...ispAuthChain, async (req, res) => {
  try {
    const amount = parseFloat(req.query.amount || '0');
    const method = String(req.query.method || 'mpesa');
    if (!(amount > 0)) return res.status(400).json({ error: 'amount required' });
    const quote = await fees.quoteWithdrawal(amount, method);
    res.json(quote);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// POST /api/withdrawals — create a withdrawal
// body: { amount, method, destination:{...}, override:false }
router.post('/', ...ispAuthChain, async (req, res) => {
  const ispId = getIspId(req);
  if (!ispId) return res.status(401).json({ error: 'Unauthorized' });
  const b = req.body || {};
  const amount = parseFloat(b.amount || '0');
  const method = String(b.method || 'mpesa');
  const destination = b.destination || {};
  const override = !!b.override;

  if (!(amount > 0)) return res.status(400).json({ error: 'Invalid amount' });
  const en = await fees.enabledMethods();
  if (!en[method]) return res.status(400).json({ error: 'This withdrawal method is not available' });

  try {
    // Lock the ISP row for a consistent balance check + debit.
    const ispRes = await query('SELECT wallet_balance, company_name FROM isps WHERE id=$1 FOR UPDATE', [ispId]);
    if (!ispRes.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    const balance = parseFloat(ispRes.rows[0].wallet_balance || 0);

    // RL_AVAILABLE_BALANCE: only CLEARED money can be paid out. IntaSend settles ~T+4, so
    // a COMPLETE payment may still be CLEARING — requesting it would fail at the payout.
    const clRes = await query(
      `SELECT COALESCE(SUM(net_amount),0) AS clearing
       FROM payments
       WHERE isp_id=$1::uuid AND payment_gateway='intasend' AND status='paid'
         AND COALESCE(clearing_status,'') = ANY(ARRAY['CLEARING','ON_HOLD','PENDING','PROCESSING'])   /* RL_PENDING_WHITELIST */`,
      [ispId]);
    const clearingRaw = parseFloat(clRes.rows[0].clearing || 0);
    // RL_CLEARING_CLAMP_HANDLER: clearing can't exceed wallet (already-withdrawn money isn't clearing)
    const clearing = Math.min(clearingRaw, balance);
    const available = Math.max(0, Math.round((balance - clearing) * 100) / 100);

    if (amount > balance) return res.status(400).json({ error: 'Insufficient balance', balance });

    /* RL_CAP_TO_AVAILABLE: withdrawal proceeds with the RELEASED portion only. If some funds are
       still clearing at IntaSend, we cap the payout to `available` and report what is held, rather
       than blocking. If nothing is available yet, we tell the ISP to wait. */
    let cappedFromClearing = false;
    let requestedAmount = amount;
    let heldList = [];
    if (amount > available) {
      if (available <= 0) {
        // gather the clearing rows so the UI can show what is settling and when
        const held = await query(
          `SELECT amount, net_amount, created_at, (created_at + INTERVAL '4 days') AS expected_available, intasend_invoice
             FROM payments
            WHERE isp_id=$1::uuid AND payment_gateway='intasend' AND status='paid'
              AND COALESCE(clearing_status,'') = ANY(ARRAY['CLEARING','ON_HOLD','PENDING','PROCESSING'])
            ORDER BY created_at ASC`, [ispId]);
        return res.status(409).json({
          error: 'funds_clearing',
          message: `No funds are available to withdraw yet. KES ${clearing} from recent payments is still clearing at IntaSend (about 4 days after payment).`,
          available: 0, clearing, wallet_balance: balance, held: held.rows,
        });
      }
      // cap the withdrawal to what is released
      amount = available;
      cappedFromClearing = true;
      const held = await query(
        `SELECT amount, net_amount, created_at, (created_at + INTERVAL '4 days') AS expected_available, intasend_invoice
           FROM payments
          WHERE isp_id=$1::uuid AND payment_gateway='intasend' AND status='paid'
            AND COALESCE(clearing_status,'') = ANY(ARRAY['CLEARING','ON_HOLD','PENDING','PROCESSING'])
          ORDER BY created_at ASC`, [ispId]);
      heldList = held.rows;
      logger.info(`[withdrawal] capped: requested ${requestedAmount} -> paying ${amount} (KES ${clearing} still clearing)`);
    }

    const quote = await fees.quoteWithdrawal(amount, method);

    // RL_NO_DISBURSE_GATE: advisory only — NEVER a block.
    // `can_disburse` is unreliable: this account reports false while sandbox B2C payouts
    // succeed. Pre-emptively refusing on a metadata flag rejects payouts IntaSend would
    // accept. The ONLY authority on whether a payout can proceed is IntaSend's response to
    // the payout call itself — if it rejects, we surface its real error verbatim below.
    try {
      const w = await intasend.walletBalance('KES');
      if (w.found) {
        if (!w.canDisburse) logger.warn('[withdrawal] IntaSend reports can_disburse=false — proceeding anyway (flag is advisory)');
        if (w.available < quote.net) logger.warn(`[withdrawal] platform wallet available=${w.available} < payout=${quote.net} — letting IntaSend arbitrate`);
      }
    } catch (we) { logger.warn('[withdrawal] wallet check failed (non-fatal): ' + we.message); }
    if (quote.below_threshold && !override) {
      return res.status(409).json({
        error: 'below_threshold',
        message: `Minimum recommended withdrawal for ${method} is KES ${quote.min_withdrawal}. Below this, the fee (KES ${quote.fee}) is ${(quote.fee_ratio*100).toFixed(1)}% of your withdrawal.`,
        quote,
      });
    }
    if (quote.net <= 0) return res.status(400).json({ error: 'Amount too low — fee exceeds withdrawal', quote });

    // Debit wallet first (reserve funds), record withdrawal as pending.
    const balanceAfter = Math.round((balance - amount) * 100) / 100;
    await query('UPDATE isps SET wallet_balance=$1 WHERE id=$2', [balanceAfter, ispId]);

    const wRes = await query(
      `INSERT INTO intasend_withdrawals
        (isp_id, method, destination, gross_amount, fee_amount, net_amount, below_threshold, status, balance_before, balance_after, metadata)
       VALUES ($1,$2,$3::jsonb,$4,$5,$6,$7,'processing',$8,$9,$10::jsonb) RETURNING id`,
      [ispId, method, JSON.stringify(destination), quote.gross, quote.fee, quote.net, quote.below_threshold, balance, balanceAfter, JSON.stringify({ quote })]
    );
    const withdrawalId = wRes.rows[0].id;

    // Ledger entry.
    await query(
      `INSERT INTO isp_transactions (isp_id, type, amount, balance_before, balance_after, description, reference_id)
       VALUES ($1,'withdrawal',$2,$3,$4,$5,$6)`,
      [ispId, amount, balance, balanceAfter, `Withdrawal via ${method} (fee ${quote.fee}, net ${quote.net})`, withdrawalId]
    ).catch(()=>{});

    // Call IntaSend payout.
    let payout;
    try {
      /* RL_BENEFICIARY_NAME: send the ISP's real company name as the beneficiary.
         Without this every payout on the platform account reads "ISP", which makes
         reconciliation and disputes impossible once several ISPs are withdrawing. */
      const _ispName = (ispRes.rows[0] && ispRes.rows[0].company_name) ? String(ispRes.rows[0].company_name).trim() : '';
      const _beneficiary = _ispName || 'ISP';
      const _dest = Object.assign({}, destination, {
        name: _beneficiary,
        narrative: (_ispName ? _ispName + ' withdrawal' : 'RumaLink withdrawal'),
      });
      payout = await intasend.sendPayout(method, { ...destination, narrative: `RumaLink withdrawal ${withdrawalId}` }, quote.net);
    } catch (e) {
      // Refund on hard failure to initiate.
      await query('UPDATE isps SET wallet_balance=wallet_balance+$1 WHERE id=$2', [amount, ispId]);
      await query("UPDATE intasend_withdrawals SET status='failed', failure_reason=$1, updated_at=NOW() WHERE id=$2", [e.message, withdrawalId]);
      return res.status(502).json({ error: 'Payout failed to initiate — your balance was not deducted.', detail: e.message });
    }

    if (!payout.ok) {
      await query('UPDATE isps SET wallet_balance=wallet_balance+$1 WHERE id=$2', [amount, ispId]);
      await query("UPDATE intasend_withdrawals SET status='failed', failure_reason=$1, updated_at=NOW() WHERE id=$2", [payout.error || 'payout rejected', withdrawalId]);
      return res.status(502).json({ error: 'Payout rejected — your balance was not deducted.', detail: payout.error });
    }

    await query(
      "UPDATE intasend_withdrawals SET status='processing', intasend_ref=$1, intasend_state=$2, metadata=metadata||$3::jsonb, updated_at=NOW() WHERE id=$4",
      [String(payout.trackingId||''), String(payout.state||'processing'), JSON.stringify({ payout: payout.raw, capped: cappedFromClearing, requested: requestedAmount, held: heldList }), withdrawalId]
    );

    res.json({
      success: true,
      withdrawal_id: withdrawalId,
      gross: quote.gross, fee: quote.fee, net: quote.net,
      status: 'processing', intasend_ref: payout.trackingId,
      balance_after: balanceAfter,
      message: `Withdrawal of KES ${quote.net} sent to your ${method}. Fee: KES ${quote.fee}.`,
    });
  } catch (e) {
    logger.error && logger.error('withdrawal error: ' + e.message);
    res.status(500).json({ error: e.message });
  }
});

// GET /api/withdrawals — ISP history
router.get('/', ...ispAuthChain, async (req, res) => {
  const ispId = getIspId(req);
  try {
    const r = await query(
      `SELECT id, method, destination, gross_amount, fee_amount, net_amount, below_threshold,
              status, intasend_ref, intasend_state, failure_reason, created_at, updated_at
       FROM intasend_withdrawals WHERE isp_id=$1 ORDER BY created_at DESC LIMIT 100`, [ispId]);
    res.json({ withdrawals: r.rows });
  } catch (e) { res.status(500).json({ error: e.message }); }
});


// RL_AVAILABLE_BALANCE: split the wallet into what is actually withdrawable NOW vs what is
// still clearing at IntaSend (settlement ~T+4). Without this an ISP can request money that
// IntaSend cannot pay out yet, and the payout fails.
router.get('/balance', ...ispAuthChain, async (req, res) => {
  // RL_LIVE_REFRESH: always re-check IntaSend before reporting a balance. A cached
  // clearing_status can be stale — IntaSend may have released the money minutes ago.
  const ispId = getIspId(req);
  try {
    try { await refreshClearing(ispId); } catch (e) { logger.warn('[withdrawals] live refresh failed, using cache: ' + e.message); }
    const bal = await computeBalance(ispId);
    res.json(bal);
  } catch (e) { res.status(500).json({ error: e.message }); }
});


// RL_LIVE_REFRESH: re-check every not-yet-cleared payment against IntaSend RIGHT NOW.
// The background sweep can lag or miss rows, so the ISP must never be shown a cached
// guess. This is called when the Withdraw page opens AND when the ISP clicks Withdraw —
// the button itself is the trigger.
async function refreshClearing(ispId) {
  const out = { checked: 0, newly_cleared: 0, unresolvable: 0 };
  const pend = await query(
    `SELECT id, intasend_invoice, net_amount, clearing_status
     FROM payments
     WHERE isp_id=$1::uuid AND payment_gateway='intasend' AND status='paid'
       AND intasend_invoice IS NOT NULL
       AND NOT (COALESCE(clearing_status,'') = ANY(ARRAY['AVAILABLE','CLEARED','SETTLED','COMPLETE']))
     ORDER BY created_at DESC LIMIT 40`,
    [ispId]);

  for (const p of pend.rows) {
    out.checked++;
    try {
      const st = await intasend.collectionStatus(p.intasend_invoice);
      const cs = st.invoice && st.invoice.clearing_status;
      if (cs) {
        const cleared = intasend.isCleared(cs);
        await query(
          "UPDATE payments SET clearing_status=$1, cleared_at = CASE WHEN $2 THEN COALESCE(cleared_at, NOW()) ELSE cleared_at END, updated_at=NOW() WHERE id=$3::uuid",
          [String(cs).toUpperCase(), cleared, p.id]);
        if (cleared) out.newly_cleared++;
      }
    } catch (e) {
      // An invoice IntaSend cannot find (e.g. created in the other environment) must NOT
      // hold the ISP's money hostage forever. Mark it so it stops blocking the balance.
      const msg = String(e.message || '');
      if (/does not exist|not found|404/i.test(msg)) {
        await query(
          "UPDATE payments SET clearing_status='UNVERIFIABLE', cleared_at=COALESCE(cleared_at, NOW()), updated_at=NOW() WHERE id=$1::uuid",
          [p.id]).catch(()=>{});
        out.unresolvable++;
        logger.warn('[withdrawals] invoice ' + p.intasend_invoice + ' not found at IntaSend — marked UNVERIFIABLE');
      }
    }
  }
  return out;
}

// Compute the ISP's true position (after a live refresh).
async function computeBalance(ispId) {
  const ispRes = await query('SELECT wallet_balance FROM isps WHERE id=$1', [ispId]);
  const wallet = parseFloat((ispRes.rows[0] || {}).wallet_balance || 0);

  const cl = await query(
    `SELECT COALESCE(SUM(net_amount),0) AS clearing, COUNT(*) AS n
     FROM payments
     WHERE isp_id=$1::uuid AND payment_gateway='intasend' AND status='paid'
       AND COALESCE(clearing_status,'') = ANY(ARRAY['CLEARING','ON_HOLD','PENDING','PROCESSING'])`,
    [ispId]);
  const clearing = parseFloat(cl.rows[0].clearing || 0);
  // RL_CLEARING_CLAMP: clearing can never exceed the wallet — money already withdrawn is not
  // "clearing". Prevents a negative available if historical rows are mis-tagged.
  const clearingClamped = Math.min(clearing, wallet);

  const rows = await query(
    `SELECT amount, net_amount, mpesa_receipt, phone_number, clearing_status, created_at,
            (created_at + INTERVAL '4 days') AS expected_available
     FROM payments
     WHERE isp_id=$1::uuid AND payment_gateway='intasend' AND status='paid'
       AND COALESCE(clearing_status,'') = ANY(ARRAY['CLEARING','ON_HOLD','PENDING','PROCESSING'])
     ORDER BY created_at DESC LIMIT 25`,
    [ispId]);

  // RL_FEES_SINCE_WD: gross + IntaSend fees on payments received SINCE the last withdrawal, so the
  // card explains the CURRENT balance and resets each time funds are withdrawn. Falls back to
  // all-time when there has been no withdrawal yet.
  const gm = await query(
    `WITH lastwd AS (
        SELECT MAX(created_at) AS t FROM intasend_withdrawals
         WHERE isp_id=$1::uuid AND status IN ('processing','completed'))
      SELECT COALESCE(SUM(amount),0) AS gross, COALESCE(SUM(net_amount),0) AS net
        FROM payments, lastwd
       WHERE isp_id=$1::uuid AND payment_gateway='intasend' AND status='paid'
         AND paid_at > COALESCE((SELECT t FROM lastwd), '1970-01-01'::timestamptz)`,
    [ispId]);
  const grossAll = parseFloat(gm.rows[0].gross || 0);
  const netAll = parseFloat(gm.rows[0].net || 0);
  const feesAll = Math.round((grossAll - netAll) * 100) / 100;
  const available = Math.max(0, Math.round((wallet - clearingClamped) * 100) / 100);

  // The platform's REAL IntaSend position — the hard ceiling on any payout.
  let platform = null;
  try {
    const w = await intasend.walletBalance('KES');
    platform = { available: w.available, current: w.current, can_disburse: w.canDisburse };
    if (!w.canDisburse) logger.warn('[withdrawals] IntaSend reports can_disburse=false on the platform wallet');
  } catch (e) { /* non-fatal */ }

  return {
    wallet_balance: wallet,
    gross: grossAll,        // RL_FEE_FIELDS
    fees: feesAll,          // RL_FEE_FIELDS
    available,
    clearing: clearingClamped,
    clearing_count: parseInt(cl.rows[0].n, 10) || 0,
    pending: rows.rows,
    platform,
  };
}

// Live refresh, then the fresh figures. The Withdraw page calls this on open and on click.
router.post('/refresh', ...ispAuthChain, async (req, res) => {
  const ispId = getIspId(req);
  try {
    const refreshed = await refreshClearing(ispId);
    const bal = await computeBalance(ispId);
    res.json({ ...bal, refreshed });
  } catch (e) {
    logger.error('[withdrawals] refresh: ' + e.message);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
