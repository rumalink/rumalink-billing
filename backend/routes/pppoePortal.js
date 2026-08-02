// routes/pppoePortal.js — PUBLIC subscriber self-service (reachable through the walled garden).
const express = require('express');
const axios = require('axios');
const router = express.Router();
const { query } = require('../config/database');
const walledGarden = require('../utils/walledGarden');
const { rlConfirmWithIntasend } = require('../utils/intasend-selfheal'); // RL_POLL_SELFHEAL
const logger = require('../utils/logger');

function maskPhone(p){ if(!p) return ''; const s=String(p); return s.length>=4 ? s.slice(0,4)+'***'+s.slice(-2) : s; }
function normPhone(p){ return String(p||'').replace(/\D/g,'').replace(/^0/,'254').replace(/^\+/,''); }

// Look up a subscriber by username (case-insensitive) and join package + isp + payment method.
async function findSub(username){
  const r = await query(
    `SELECT ps.*, pp.name AS pkg_name, pp.price, pp.billing_cycle, pp.mikrotik_profile,
            i.company_name, i.id AS isp_id,
            pm.method_type, pm.paybill_number, pm.till_number, pm.account_number, pm.account_reference, pm.provider
       FROM pppoe_subscribers ps
       JOIN pppoe_packages pp ON pp.id = ps.package_id
       JOIN isps i ON i.id = ps.isp_id
       LEFT JOIN isp_payment_methods pm ON pm.isp_id = i.id AND pm.is_default=true AND pm.is_active=true
      -- RL_PPPOE_INTASEND: accept a USERNAME or a PHONE NUMBER. A subscriber who remembers
      -- their phone but not their PPPoE username could not pay at all before this.
      -- The phone is normalised both sides so 0712..., +254712... and 254712... all match.
      WHERE LOWER(ps.username) = LOWER($1)
         OR ( /* RL_FINDSUB_GUARD: only match by phone when input has >=9 digits and subscriber has a phone */
              LENGTH(regexp_replace($1, '[^0-9]', '', 'g')) >= 9
              AND COALESCE(ps.phone,'') <> ''
              AND (
                regexp_replace(COALESCE(ps.phone,''), '[^0-9]', '', 'g') = regexp_replace($1, '[^0-9]', '', 'g')
                OR regexp_replace(COALESCE(ps.phone,''), '^(0|254|\+254)', '254', 'g') = regexp_replace(regexp_replace($1, '[^0-9]', '', 'g'), '^0', '254', 'g')
              )
            )
      LIMIT 1`,
    [username]
  );
  return r.rows[0] || null;
}

function payInstructions(sub){
  // What the subscriber should do on their phone (any phone). Account = their username.
  const acct = sub.username;
  if (sub.method_type === 'paybill' && sub.paybill_number) {
    return { type:'paybill', paybill: sub.paybill_number, account: sub.account_reference || acct };
  }
  if (sub.method_type === 'till' && sub.till_number) {
    return { type:'till', till: sub.till_number };
  }
  // Default / platform paybill fallback (account encodes the subscriber).
  return { type:'paybill', paybill: process.env.PLATFORM_PAYBILL || null, account: acct };
}

// GET /api/pppoe-portal/:username — status + amount + pay instructions
router.get('/:username', async (req, res) => {
  try {
    const sub = await findSub(req.params.username);
    if (!sub) return res.status(404).json({ error: 'Subscriber not found. Check your username.' });
    const now = new Date();
    const nextBilling = sub.next_billing_date ? new Date(sub.next_billing_date) : null;
    const expired = (sub.status === 'expired') || (nextBilling && nextBilling.getTime() <= now.getTime());
    res.json({
      username: sub.username,
      full_name: sub.full_name,
      company_name: sub.company_name,
      package: sub.pkg_name,
      price: Number(sub.price),
      billing_cycle: sub.billing_cycle,
      status: sub.status,
      expired: !!expired,
      next_billing_date: sub.next_billing_date,
      phone_masked: maskPhone(sub.phone),
      pay: payInstructions(sub)
    });
  } catch (e) { logger.error('[PPPoE-portal] status: ' + e.message); res.status(500).json({ error: 'Server error' }); }
});

// GET /api/pppoe-portal/:username/status — lightweight polling
router.get('/:username/status', async (req, res) => {
  try {
    const sub = await findSub(req.params.username);
    if (!sub) return res.status(404).json({ error: 'not_found' });
    const now = new Date();
    const nextBilling = sub.next_billing_date ? new Date(sub.next_billing_date) : null;
    const expired = (sub.status === 'expired') || (nextBilling && nextBilling.getTime() <= now.getTime());
    res.json({ status: sub.status, expired: !!expired, next_billing_date: sub.next_billing_date });
  } catch (e) { res.status(500).json({ error: 'error' }); }
});

// POST /api/pppoe-portal/:username/stk — STK push for smartphone users (via ISP method or platform Daraja)
// GET /api/pppoe-portal/:username/plans — list the ISP's active PPPoE packages
router.get('/:username/plans', async (req, res) => {
  try {
    const sub = await findSub(req.params.username);
    if (!sub) return res.status(404).json({ error: 'Subscriber not found' });
    const pks = await query(
      `SELECT id, name, price, billing_cycle, bandwidth_down_mbps, bandwidth_up_mbps
         FROM pppoe_packages WHERE isp_id=$1::uuid AND is_active=true
        ORDER BY price ASC`,
      [sub.isp_id]
    );
    res.json({
      current_package_id: sub.package_id,
      plans: pks.rows.map(p => ({
        id: p.id, name: p.name, price: Number(p.price), billing_cycle: p.billing_cycle,
        down: p.bandwidth_down_mbps, up: p.bandwidth_up_mbps,
        current: p.id === sub.package_id
      }))
    });
  } catch (e) { logger.error('[PPPoE-portal] plans: ' + e.message); res.status(500).json({ error: 'Server error' }); }
});

router.post('/:username/stk', async (req, res) => {
  try {
    const sub = await findSub(req.params.username);
    if (!sub) return res.status(404).json({ error: 'Subscriber not found' });
    const phone = normPhone(req.body.phone || sub.phone);
    if (!/^254[17]\d{8}$/.test(phone)) return res.status(400).json({ error: 'Invalid phone number' });
    // Optional plan change: if a (valid, same-ISP) package_id is sent, charge & switch to that plan.
    let chosenPkgId = null, chosenPrice = Number(sub.price), chosenName = sub.pkg_name;
    if (req.body.package_id && req.body.package_id !== sub.package_id) {
      const np = await query("SELECT id, name, price FROM pppoe_packages WHERE id=$1::uuid AND isp_id=$2::uuid AND is_active=true LIMIT 1", [req.body.package_id, sub.isp_id]);
      if (!np.rows[0]) return res.status(400).json({ error: 'Selected plan not available.' });
      chosenPkgId = np.rows[0].id; chosenPrice = Number(np.rows[0].price); chosenName = np.rows[0].name;
    }
    const amount = Math.max(Math.ceil(chosenPrice), 1);

    // Equity (Jenga) path — money straight to ISP's Equity account.
    if (sub.provider === 'equity_jenga' || sub.method_type === 'equity') {
      const pmRow = await query("SELECT account_number, account_name FROM isp_payment_methods WHERE isp_id=$1::uuid AND is_active=true AND (provider='equity_jenga' OR method_type='equity') ORDER BY is_default DESC LIMIT 1",[sub.isp_id]);
      if (!pmRow.rows[0] || !pmRow.rows[0].account_number) return res.status(400).json({ error: 'ISP Equity account not set.' });
      const jenga = require('../utils/jenga');
      const jcfg = await jenga.loadConfig();
      if (!jcfg) return res.status(400).json({ error: 'Equity (Jenga) not configured by platform.' });
      const ref = 'RLP' + Date.now().toString(36).toUpperCase() + Math.random().toString(36).slice(2,6).toUpperCase();
      const pay = await query(
        `INSERT INTO payments (isp_id, subscriber_id, amount, payment_method, payment_gateway, gateway_reference, phone_number, description, status, metadata)
         VALUES ($1::uuid,$2::uuid,$3::decimal,'equity','jenga',$4,$5,$6,'pending',$7::jsonb) RETURNING id`,
        [sub.isp_id, sub.id, amount, ref, phone, 'PPPoE - ' + chosenName, JSON.stringify(chosenPkgId ? { switch_package_id: chosenPkgId } : {})]
      );
      const paymentId = pay.rows[0].id;
      const callbackUrl = `${process.env.BASE_URL}/api/payments/jenga/ipn`;
      jenga.stkPush({ cfg: jcfg, ispAccount: pmRow.rows[0].account_number, ispName: pmRow.rows[0].account_name || sub.company_name, phone, amount, ref, callbackUrl })
        .then(()=>logger.info('[PPPoE-portal] Jenga STK acked ref='+ref))
        .catch(je=>{ const m=String(je.message||''); if(!/timeout/i.test(m)){ query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid",[m.slice(0,200),paymentId]).catch(()=>{}); } });
      return res.json({ success:true, payment_id: paymentId, amount, message: `M-Pesa prompt sent to ${phone}.` });
    }


    // RL_PPPOE_INTASEND: the ISP's CHOSEN gateway must be honoured.
    // This branch did not exist, so an ISP whose default method is IntaSend (kimtec is) had its
    // subscribers pushed through DARAJA instead — silently ignoring the gateway they configured.
    // The hotspot (captive.js) already does this correctly; PPPoE did not.
    //
    // As with the hotspot: the STK goes out on the PLATFORM ADMIN IntaSend keys, funds land in the
    // admin account, and the ISP's wallet is credited by /api/payments/intasend/ipn.
    /* RL_PAYMENT_ROUTE: same decision as the hotspot, from the same place — so configuring a
       payment method once applies to every channel. */
    const _route = await require('../utils/paymentRoute').resolve(sub.isp_id);
    if (_route.gateway === 'intasend') {
      const _ispm = await query(
        "SELECT * FROM isp_payment_methods WHERE isp_id=$1::uuid AND is_active=true AND (method_type='intasend' OR provider='intasend') ORDER BY is_default DESC, created_at ASC LIMIT 1",
        [sub.isp_id]
      );
      if (_ispm.rows[0]) {
        const intasend = require('../utils/intasend-client');
        const isfees   = require('../utils/intasend-fees');
        let icfg;
        try { icfg = await intasend.loadConfig(); }
        catch (e) { return res.status(400).json({ error: 'IntaSend is not configured by the platform admin yet.' }); }
        if (!icfg.active) return res.status(400).json({ error: 'IntaSend is not active. Contact the platform admin.' });
    
        const colFee = await isfees.collectionFee(amount, 'mpesa');
        let commRate = 0;
        try {
          const ir = await query('SELECT commission_rate FROM isps WHERE id=$1::uuid', [sub.isp_id]);
          commRate = Number((ir.rows[0] && ir.rows[0].commission_rate) || 0);
        } catch (e) {}
        const commAmount    = amount * commRate;
        const netAmount     = Math.round((amount - colFee.fee - commAmount) * 100) / 100;
        const totalDeducted = Math.round((colFee.fee + commAmount) * 100) / 100;
        const ref = 'RLI' + Date.now().toString(36).toUpperCase() + Math.random().toString(36).slice(2,6).toUpperCase();
    
        // CRITICAL: subscriber_id MUST be set. onPaid() reads pay.subscriber_id to reactivate the
        // account and lift the walled garden. The hotspot's payment rows have no subscriber (there
        // is none), so copying that INSERT verbatim would take the money and leave the customer
        // still blocked — paid, but with no internet.
        const _pay = await query(
          `INSERT INTO payments
             (isp_id, subscriber_id, amount, payment_method, payment_gateway, gateway_reference,
              phone_number, commission_rate, commission_amount, net_amount, description, status,
              used_admin_credentials, metadata)
           VALUES ($1::uuid,$2::uuid,$3::decimal,'mpesa_stk','intasend',$4,$5,$6::decimal,$7::decimal,$8::decimal,$9,'pending',true,$10::jsonb)
           RETURNING id`,
          [sub.isp_id, sub.id, amount, ref, phone, commRate, totalDeducted, netAmount,
           'PPPoE - ' + chosenName,
           JSON.stringify(Object.assign(
             { intasend_fee: colFee.fee, platform_commission: commAmount, gross: amount },
             chosenPkgId ? { switch_package_id: chosenPkgId } : {}))]
        );
        const paymentId = _pay.rows[0].id;
    
        await query(
          `INSERT INTO mpesa_transactions (isp_id, payment_id, checkout_request_id, merchant_request_id, amount, phone, status)
           VALUES ($1::uuid,$2::uuid,$3,$4,$5::decimal,$6,'pending')`,
          [sub.isp_id, paymentId, ref, ref, amount, phone]
        ).catch(() => {});
    
        const callbackUrl = `${process.env.BASE_URL}/api/payments/intasend/ipn`;
        let _stk = null;
        try {
          _stk = await intasend.collectSTK({ phone, amount, apiRef: ref, callbackUrl,
                                      narrative: 'PPPoE - ' + chosenName });
        } catch (se) {
          await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid",
                      [String(se.message).slice(0,240), paymentId]).catch(()=>{});
          logger.error('[PPPoE-portal] IntaSend STK error ref=' + ref + ': ' + se.message);
          return res.status(502).json({ error: 'Payment could not be started: ' + se.message });
        }
        // RL_STORE_INVOICE: persist the IntaSend invoice id so the self-heal poll can query it later.
      // Without this the poll is blind for PPPoE and a missed webhook strands the subscriber.
      try {
        if (_stk && _stk.invoiceId) {
          await query("UPDATE payments SET metadata = COALESCE(metadata,'{}'::jsonb) || $2::jsonb WHERE id=$1::uuid",
            [paymentId, JSON.stringify({ intasend_invoice: _stk.invoiceId, intasend_state: _stk.state || 'PENDING' })]);
          await query("UPDATE mpesa_transactions SET checkout_request_id=COALESCE(checkout_request_id,$2) WHERE payment_id=$1::uuid",
            [paymentId, _stk.invoiceId]).catch(function(){});
        }
      } catch (e) { logger.warn('[PPPoE-portal] store invoice: ' + e.message); }
      logger.info('[PPPoE-portal] IntaSend STK sent ref=' + ref + ' sub=' + sub.username + ' KES ' + amount);
        return res.json({ success: true, payment_id: paymentId, amount,
                          message: `M-Pesa prompt sent to ${phone}.` });
      }
    }

    // Daraja path (ISP mpesa_configs -> admin fallback)
    let cfg = null;
    /* RL_DARAJA_CREDS: same source of truth as the hotspot — the dashboard saves Daraja details
       into isp_payment_methods, which this path never consulted. */
    let _pmCreds = null;
    try { _pmCreds = await require('../utils/paymentRoute').darajaCreds(sub.isp_id); } catch (e) {}
    const ispCfg = _pmCreds
      ? { rows: [{ shortcode: _pmCreds.shortcode, consumer_key: _pmCreds.consumer_key,
                   consumer_secret: _pmCreds.consumer_secret, passkey: _pmCreds.passkey,
                   is_sandbox: _pmCreds.sandbox }] }
      : await query("SELECT * FROM mpesa_configs WHERE isp_id=$1::uuid AND is_active=true AND COALESCE(is_admin_config,false)=false LIMIT 1",[sub.isp_id]);
    if (ispCfg.rows[0] && ispCfg.rows[0].consumer_key) cfg = ispCfg.rows[0];
    if (!cfg) { const adm = await query("SELECT * FROM mpesa_configs WHERE is_admin_config=true AND is_active=true LIMIT 1"); if(adm.rows[0]) cfg = adm.rows[0]; }
    /* RL_PAYMENT_ROUTE: name the actual problem. "M-Pesa not configured" sent us hunting for
       Daraja credentials when the real issue was which gateway had been selected. */
    if (!cfg || !cfg.consumer_key) return res.status(400).json({ error: (_route && _route.error) || 'No M-Pesa gateway is configured. Set up IntaSend or Daraja in the admin dashboard.' });

    const pay = await query(
      `INSERT INTO payments (isp_id, subscriber_id, amount, payment_method, payment_gateway, phone_number, description, status, metadata)
       VALUES ($1::uuid,$2::uuid,$3::decimal,'mpesa','mpesa_stk',$4,$5,'pending',$6::jsonb) RETURNING id`,
      [sub.isp_id, sub.id, amount, phone, 'PPPoE - ' + chosenName, JSON.stringify(chosenPkgId ? { switch_package_id: chosenPkgId } : {})]
    );
    const paymentId = pay.rows[0].id;
    const baseUrl = cfg.is_sandbox ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';
    let token;
    try {
      const tk = await axios.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, { headers:{ Authorization:`Basic ${Buffer.from(`${cfg.consumer_key}:${cfg.consumer_secret}`).toString('base64')}` }, timeout:10000 });
      token = tk.data.access_token;
    } catch(e){ await query("UPDATE payments SET status='failed', failure_reason='auth' WHERE id=$1::uuid",[paymentId]).catch(()=>{}); return res.status(400).json({ error:'M-Pesa auth failed' }); }
    const ts = new Date().toISOString().replace(/[-:TZ.]/g,'').slice(0,14);
    const pwd = Buffer.from(`${cfg.shortcode}${cfg.passkey}${ts}`).toString('base64');
    try {
      await axios.post(`${baseUrl}/mpesa/stkpush/v1/processrequest`, {
        BusinessShortCode: cfg.shortcode, Password: pwd, Timestamp: ts, TransactionType:'CustomerPayBillOnline',
        Amount: amount, PartyA: phone, PartyB: cfg.shortcode, PhoneNumber: phone,
        CallBackURL: `${process.env.BASE_URL}/api/pppoe-portal/callback/${paymentId}`,
        AccountReference: sub.username.substring(0,12), TransactionDesc: 'PPPoE'
      }, { headers:{ Authorization:`Bearer ${token}` }, timeout:15000 });
    } catch(e){ await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid",[String(e.response&&e.response.data&&e.response.data.errorMessage||e.message).slice(0,200),paymentId]).catch(()=>{}); return res.status(400).json({ error:'STK push failed' }); }
    res.json({ success:true, payment_id: paymentId, amount, message: `M-Pesa prompt sent to ${phone}.` });
  } catch (e) { logger.error('[PPPoE-portal] stk: ' + e.message); res.status(500).json({ error: 'Server error' }); }
});

// Shared: on confirmed payment -> extend + restore + forward.


async function onPaid(paymentId, receipt){
  const payRes = await query("SELECT * FROM payments WHERE id=$1::uuid", [paymentId]);
  const pay = payRes.rows[0];
  // RL_ONPAID_IDEMPOTENT: do NOT return just because the payment is already 'paid' — every
  // caller except the Daraja callback marks it paid BEFORE calling onPaid, so that old guard
  // skipped reactivation for IntaSend (IPN/poll/sweep) and the expiry cron re-walled the
  // subscriber a minute later. We guard against DOUBLE reactivation further down instead,
  // using the subscriber's own state (active + future next_billing_date).
  if (!pay) return;
  const subRes = await query(
    `SELECT ps.*, pp.billing_cycle, pp.mikrotik_profile FROM pppoe_subscribers ps JOIN pppoe_packages pp ON pp.id=ps.package_id WHERE ps.id=$1::uuid`,
    [pay.subscriber_id]
  );
  let sub = subRes.rows[0];
  // RL_CONSUMED_ONCE: a payment activates a subscriber exactly ONCE. If it was already consumed
  // (paid_at set) and the subscriber is now expired with updated_at NEWER than paid_at, that means
  // an admin (or the expiry cron) expired them AFTER this payment did its job -> respect the expiry,
  // do NOT reactivate. Only a FRESH, not-yet-consumed payment may reactivate an expired subscriber.
  if (sub && pay.paid_at && sub.status === 'expired') {
    let consumedAt = null;
    try { const md0 = pay.metadata && (typeof pay.metadata==='string' ? JSON.parse(pay.metadata) : pay.metadata); consumedAt = md0 && md0.rl_consumed; } catch(e){}
    // consumed if we have a marker, OR (fallback) if paid_at is set and updated_at is clearly after it
    const paidMs = new Date(pay.paid_at).getTime();
    const updMs = sub.updated_at ? new Date(sub.updated_at).getTime() : 0;
    const wasConsumed = !!consumedAt || (paidMs && updMs && updMs > paidMs + 2000);
    if (wasConsumed) {
      logger.info(`[PPPoE-portal] ${sub.username} expired after payment ${paymentId} already consumed -> NOT reactivating (respecting expiry)`);
      return;
    }
  }
  // RL_ONPAID_IDEMPOTENT: if this subscriber is already active AND already paid past now for
  // this same payment, a prior onPaid run already did the work — avoid extending the billing
  // date twice. We detect a prior run via the payment's paid_at being set on a PREVIOUS call
  // together with the subscriber already being active with a future billing date.
  if (sub && pay.status === 'paid' && pay.paid_at && sub.status === 'active'
      && sub.next_billing_date && new Date(sub.next_billing_date) > new Date()) {
    // Already reactivated by an earlier path (e.g. Daraja callback then IPN). Nothing to do.
    return;
  }
  await query("UPDATE payments SET status='paid', paid_at=NOW(), transaction_id=COALESCE($2,transaction_id) WHERE id=$1::uuid", [paymentId, receipt||null]);
  // Plan change requested at pay time?
  let switchPkgId = null;
  try { const md = pay.metadata && (typeof pay.metadata==='string' ? JSON.parse(pay.metadata) : pay.metadata); switchPkgId = md && md.switch_package_id; } catch(e){}
  if (sub && switchPkgId && switchPkgId !== sub.package_id) {
    const npk = await query("SELECT id, name, bandwidth_down_mbps, bandwidth_up_mbps, mikrotik_profile, address_pool, billing_cycle FROM pppoe_packages WHERE id=$1::uuid AND isp_id=$2::uuid AND is_active=true LIMIT 1", [switchPkgId, pay.isp_id]);
    if (npk.rows[0]) {
      const np = npk.rows[0];
      await query("UPDATE pppoe_subscribers SET package_id=$1::uuid, updated_at=NOW() WHERE id=$2::uuid", [np.id, sub.id]);
      // Rewrite RADIUS reply attributes for the new plan.
      await query("DELETE FROM radreply WHERE username=$1 AND attribute IN ('Mikrotik-Rate-Limit','Mikrotik-Group','Framed-Pool')", [sub.username]).catch(()=>{});
      const down = np.bandwidth_down_mbps, up = np.bandwidth_up_mbps;
      if (down || up) { const rate = (up||down)+'M/'+(down||up)+'M'; await query("INSERT INTO radreply (username, attribute, op, value) VALUES ($1,'Mikrotik-Rate-Limit','=',$2)", [sub.username, rate]).catch(()=>{}); }
      if (np.mikrotik_profile) { await query("INSERT INTO radreply (username, attribute, op, value) VALUES ($1,'Mikrotik-Group','=',$2)", [sub.username, np.mikrotik_profile]).catch(()=>{}); }
      if (np.address_pool) { await query("INSERT INTO radreply (username, attribute, op, value) VALUES ($1,'Framed-Pool','=',$2)", [sub.username, np.address_pool]).catch(()=>{}); }
      logger.info(`[PPPoE-portal] ${sub.username} switched plan -> ${np.name}`);
      // Refresh sub fields used below (cycle + profile for restore).
      sub.billing_cycle = np.billing_cycle || sub.billing_cycle;
      sub.mikrotik_profile = np.mikrotik_profile || null;
    }
  }
  if (sub) {
    // Extend next_billing_date by one cycle from the later of now / current next_billing_date.
    const cycle = (sub.billing_cycle||'monthly');
    const base = sub.next_billing_date && new Date(sub.next_billing_date) > new Date() ? new Date(sub.next_billing_date) : new Date();
    const nb = new Date(base);
    if (cycle === 'weekly') nb.setDate(nb.getDate()+7);
    else if (cycle === 'daily') nb.setDate(nb.getDate()+1);
    else { nb.setMonth(nb.getMonth()+1); }
    await query("UPDATE pppoe_subscribers SET next_billing_date=$1, last_payment_date=CURRENT_DATE, status='active', updated_at=NOW() WHERE id=$2::uuid", [nb.toISOString(), sub.id]);
    /* RL_CONSUMED_ONCE: mark this payment consumed so it can never reactivate again after a future expiry */
    await query("UPDATE payments SET metadata = COALESCE(metadata,'{}'::jsonb) || jsonb_build_object('rl_consumed', NOW()::text) WHERE id=$1::uuid", [paymentId]).catch(function(){});
    try { await walledGarden.restore(sub, sub.mikrotik_profile || null); } catch(e){ logger.warn('[PPPoE-portal] restore: '+e.message); }
    logger.info(`[PPPoE-portal] ${sub.username} paid -> extended to ${nb.toISOString()} + restored`);
    // RL_ONPAID_CREDIT: credit the ISP wallet for this PPPoE payment (idempotent).
    try { await require('../utils/wallet-credit').creditWalletOnce(paymentId); }
    catch(e){ logger.error('[PPPoE-portal] wallet credit: '+e.message); }
    // (B2C forward to ISP happens here in a later sub-step.)
  }
}

// POST /api/pppoe-portal/callback/:paymentId — Daraja STK callback (public)
router.post('/callback/:paymentId', async (req, res) => {
  try {
    const cb = req.body && req.body.Body && req.body.Body.stkCallback;
    const code = cb ? cb.ResultCode : (req.body.ResultCode!=null?req.body.ResultCode:1);
    if (String(code) === '0') {
      let receipt=null; try{ receipt=cb.CallbackMetadata.Item.find(i=>i.Name==='MpesaReceiptNumber').Value; }catch(e){}
      await onPaid(req.params.paymentId, receipt);
    } else {
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid AND status!='paid'", [String((cb&&cb.ResultDesc)||'Cancelled').slice(0,200), req.params.paymentId]).catch(()=>{});
    }
    res.json({ ok:true });
  } catch (e) { logger.error('[PPPoE-portal] callback: '+e.message); res.json({ ok:true }); }
});

// GET /api/pppoe-portal/pay-status/:paymentId — poll a specific payment (reuses public-status self-heal)
router.get('/pay-status/:paymentId', async (req, res) => {
  try {
    let r = await query("SELECT id, status, transaction_id, amount, failure_reason, subscriber_id, payment_gateway, metadata FROM payments WHERE id=$1::uuid", [req.params.paymentId]);
    if (!r.rows[0]) return res.status(404).json({ status:'not_found' });
    // RL_POLL_SELFHEAL: still pending? confirm straight with IntaSend (a missed webhook must not strand the customer).
    if (r.rows[0].status === 'pending') {
      const ns = await rlConfirmWithIntasend(r.rows[0]);
      if (ns !== r.rows[0].status) { r = await query("SELECT id, status, transaction_id, amount, failure_reason, subscriber_id FROM payments WHERE id=$1::uuid", [req.params.paymentId]); }
    }
    // If paid but subscriber still expired (callback missed), heal here.
    if (r.rows[0].status === 'paid') {
      const s = await query("SELECT status FROM pppoe_subscribers WHERE id=$1::uuid",[r.rows[0].subscriber_id]);
      /* RL_ONPAID_RESPECT_EXPIRY: only auto-heal from a poll if this payment is recent (<30 min).
         An old payment must not perpetually un-expire a subscriber an admin just expired. */
      if (s.rows[0] && s.rows[0].status !== 'active') {
        const fresh = await query("SELECT 1 FROM payments WHERE id=$1::uuid AND created_at > NOW() - interval '30 minutes'", [req.params.paymentId]);
        if (fresh.rows[0]) { await onPaid(req.params.paymentId, r.rows[0].transaction_id); }
      }
    }
    res.json({ status: r.rows[0].status, failure_reason: r.rows[0].failure_reason });
  } catch (e) { res.status(500).json({ error:'error' }); }
});

module.exports = router;
// RL_IPN_PPPOE: the IntaSend IPN must reactivate a subscriber exactly as the Daraja callback
// does. Export the ONE implementation rather than copying it — two copies of a reactivation
// path will drift, and the failure mode (paid but still blocked) is silent.
module.exports.onPaid = onPaid;
