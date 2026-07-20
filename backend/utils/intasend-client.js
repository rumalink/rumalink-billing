// IntaSend client — written against the official OpenAPI spec:
//   https://developers.intasend.com/reference/api_v1_payment_mpesa_stk_push_create
//   https://developers.intasend.com/reference/api_v1_payment_status_create
//   https://developers.intasend.com/reference/api_v1_send_money_initiate_create
//
// Auth: Bearer <SECRET key> (IntaSendBearerAuth) on every request.
// Note: the STK schema (MPesaSTKPushInit) has NO callback/webhook field — collection
// confirmation arrives via the webhook registered in the IntaSend DASHBOARD, and/or by
// polling /api/v1/payment/status/. Send-money DOES accept callback_url.
const axios = require('axios');
const { query } = require('../config/database');

// Invoice states per InvoicesSerStateEnum.
const STATE = {
  PENDING: 'PENDING', PROCESSING: 'PROCESSING', FAILED: 'FAILED',
  CANCELED: 'CANCELED', PARTIAL: 'PARTIAL', COMPLETE: 'COMPLETE', RETRY: 'RETRY',
};
const TERMINAL_OK = ['COMPLETE'];
const TERMINAL_BAD = ['FAILED', 'CANCELED'];

// Bank codes for PESALINK payouts (BankCode2fbEnum). Keyed by a normalized bank name.
const BANK_CODES = {
  kcb: '1', 'standard chartered': '2', absa: '3', 'bank of baroda': '6', ncba: '7',
  'prime bank': '10', cooperative: '11', 'co-operative': '11', coop: '11',
  'national bank': '12', 'm-oriental': '14', citibank: '16', 'habib bank': '17',
  'middle east bank': '18', 'bank of africa': '19', consolidated: '23', 'credit bank': '25',
  stanbic: '31', unaitas: '32', abc: '35', 'choice microfinance': '36', 'eco bank': '43',
  ecobank: '43', caritas: '48', spire: '49', paramount: '50', kingdom: '51', guaranty: '53',
  'victoria commercial': '54', guardian: '55', 'i&m': '57', im: '57', sbm: '60',
  'housing finance': '61', hfck: '61', dtb: '63', 'diamond trust': '63', cib: '65',
  sidian: '66', equity: '68', family: '70', 'gulf african': '72', premier: '74', dib: '75',
  uba: '76', kwft: '78', faulu: '79', 'stima sacco': '89', stima: '89', telkom: '97',
};

function resolveBankCode(input) {
  if (!input) return null;
  const s = String(input).trim();
  if (/^\d+$/.test(s)) return s;                 // already a code
  const k = s.toLowerCase().replace(/\s*bank\s*/g, ' ').replace(/\s+/g, ' ').trim();
  if (BANK_CODES[k]) return BANK_CODES[k];
  for (const [name, code] of Object.entries(BANK_CODES)) {
    if (k.includes(name) || name.includes(k)) return code;
  }
  return null;
}

async function loadConfig() {
  const r = await query(
    "SELECT api_key, private_key, base_url, is_sandbox, is_active FROM payment_provider_configs WHERE provider='intasend' LIMIT 1", []);
  if (!r.rows[0]) throw new Error('IntaSend is not configured');
  const c = r.rows[0];
  const base = c.is_sandbox ? 'https://sandbox.intasend.com' : 'https://payment.intasend.com';
  const secret = c.private_key || c.api_key;     // the SECRET key authenticates the API
  if (!secret) throw new Error('IntaSend secret key missing');
  return { publishable: c.api_key, secret, base, active: !!c.is_active, sandbox: c.is_sandbox !== false };
}

function client(cfg) {
  return axios.create({
    baseURL: cfg.base,
    timeout: 30000,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${cfg.secret}`,
    },
    validateStatus: () => true,
  });
}

function normPhone(p) {
  let s = String(p || '').replace(/\D/g, '');
  if (s.startsWith('0')) s = '254' + s.slice(1);
  if (s.startsWith('7') || s.startsWith('1')) s = '254' + s;
  return s;
}
function errText(d) {
  try { return typeof d === 'object' ? JSON.stringify(d).slice(0, 400) : String(d).slice(0, 400); }
  catch (_) { return 'unknown error'; }
}

// ── COLLECTION: M-Pesa STK push ────────────────────────────────────────────
// MPesaSTKPushInit: { amount*, phone_number*, api_ref, wallet_id, mobile_tarrif }
async function collectSTK({ phone, amount, apiRef }) {
  const cfg = await loadConfig();
  if (!cfg.active) throw new Error('IntaSend is not active (admin must add keys and activate)');
  const api = client(cfg);
  const body = {
    amount: Number(amount).toFixed(2),   // spec: decimal string
    phone_number: normPhone(phone),
  };
  // api_ref pattern: ^[a-zA-Z0-9-_: ]+$ — strip anything else.
  if (apiRef) body.api_ref = String(apiRef).replace(/[^a-zA-Z0-9\-_: ]/g, '');

  const r = await api.post('/api/v1/payment/mpesa-stk-push/', body);
  if (r.status >= 400) throw new Error('IntaSend STK failed: ' + errText(r.data));
  const d = r.data || {};
  const inv = d.invoice || {};
  return {
    ok: true,
    invoiceId: inv.invoice_id || null,
    state: String(inv.state || STATE.PENDING).toUpperCase(),
    raw: d,
  };
}

// ── COLLECTION STATUS ──────────────────────────────────────────────────────
// PaymentStatus: { invoice_id* }  →  { invoice: {...}, meta: {...} }
async function collectionStatus(invoiceId) {
  const cfg = await loadConfig();
  const api = client(cfg);
  const r = await api.post('/api/v1/payment/status/', { invoice_id: invoiceId });
  if (r.status >= 400) return { ok: false, state: null, invoice: null, raw: r.data };
  const d = r.data || {};
  const inv = d.invoice || {};
  const state = String(inv.state || '').toUpperCase();
  return {
    ok: true,
    state,
    isPaid: TERMINAL_OK.includes(state),
    isDead: TERMINAL_BAD.includes(state),
    receipt: inv.mpesa_reference || null,
    value: inv.value,
    charges: inv.charges,
    netAmount: inv.net_amount,
    failedReason: inv.failed_reason || null,
    invoice: inv,
    raw: d,
  };
}

// ── PAYOUTS: send money ────────────────────────────────────────────────────
// SendMoneyInit: { currency*, provider*, transactions*, requires_approval, callback_url, ... }
// provider enum: MPESA-B2C | MPESA-B2B | PESALINK | INTASEND | INTASEND-XB | AIRTIME
function buildPayout(method, destination, amount) {
  const amt = Number(amount).toFixed(2);
  const clean = (s) => String(s || '').replace(/[^a-zA-Z0-9\-_: ]/g, '').slice(0, 240);

  if (method === 'mpesa') {
    return {
      provider: 'MPESA-B2C',
      transactions: [{
        name: clean(destination.name || 'ISP'),
        account: normPhone(destination.phone),
        amount: amt,
        narrative: clean(destination.narrative || 'RumaLink withdrawal'),
      }],
    };
  }
  if (method === 'b2b') {
    const acct = String(destination.account || destination.paybill || destination.till || '').replace(/\D/g, '');
    if (!acct) throw new Error('Paybill/Till number required');
    return {
      provider: 'MPESA-B2B',
      transactions: [{
        name: clean(destination.name || 'ISP'),
        account: acct,
        amount: amt,
        account_type: destination.account_type === 'TillNumber' ? 'TillNumber' : 'PayBill',
        account_reference: clean(destination.account_reference || '').slice(0, 20),
        narrative: clean(destination.narrative || 'RumaLink withdrawal'),
      }],
    };
  }
  if (method === 'bank') {
    const code = resolveBankCode(destination.bank_code || destination.bank_name);
    if (!code) throw new Error('Unknown bank — a valid IntaSend bank code is required');
    const acct = String(destination.account_number || '').replace(/\s/g, '');
    if (!acct) throw new Error('Bank account number required');
    return {
      provider: 'PESALINK',                    // spec enum (NOT "PESALINK-BANK")
      transactions: [{
        name: clean(destination.account_name || 'ISP'),
        account: acct,
        bank_code: code,                       // numeric code, e.g. Equity = "68"
        amount: amt,
        narrative: clean(destination.narrative || 'RumaLink withdrawal'),
      }],
    };
  }
  throw new Error('Unsupported method: ' + method);
}

async function sendPayout(method, destination, amount, callbackUrl) {
  const cfg = await loadConfig();
  if (!cfg.active) throw new Error('IntaSend is not active (add keys and activate in admin settings)');
  const api = client(cfg);
  const p = buildPayout(method, destination, amount);
  const body = {
    currency: 'KES',
    provider: p.provider,
    requires_approval: 'NO',      // straight-through processing
    transactions: p.transactions,
  };
  if (callbackUrl) body.callback_url = callbackUrl;   // valid on send-money

  const r = await api.post('/api/v1/send-money/initiate/', body);
  if (r.status >= 400) {
    return { ok: false, state: 'failed', error: errText(r.data), raw: r.data };
  }
  const d = r.data || {};
  return {
    ok: true,
    trackingId: d.tracking_id || d.file_id || null,
    state: String(d.status || 'processing'),
    chargeEstimate: d.charge_estimate,
    raw: d,
  };
}

// Check Send Money Status: POST /api/v1/send-money/status/ { tracking_id }
async function payoutStatus(trackingId) {
  const cfg = await loadConfig();
  const api = client(cfg);
  const r = await api.post('/api/v1/send-money/status/', { tracking_id: trackingId });
  if (r.status >= 400) return { ok: false, state: null, raw: r.data };
  const d = r.data || {};
  return {
    ok: true,
    state: String(d.status || '').toUpperCase(),
    transactions: d.transactions || [],
    raw: d,
  };
}

// RL_CLEARING: the platform's real IntaSend KES wallet. available_balance is the ONLY
// figure that can actually be disbursed — current_balance includes money still CLEARING.
async function walletBalance(currency) {
  const cfg = await loadConfig();
  const api = client(cfg);
  const r = await api.get('/api/v1/wallets/');
  if (r.status >= 400) throw new Error('wallet fetch failed: ' + errText(r.data));
  const cur = (currency || 'KES').toUpperCase();
  const list = (r.data && r.data.results) || [];
  const w = list.find(x => String(x.currency).toUpperCase() === cur);
  if (!w) return { found: false, available: 0, current: 0, canDisburse: false };
  return {
    found: true,
    walletId: w.wallet_id,
    currency: cur,
    current: Number(w.current_balance || 0),
    available: Number(w.available_balance || 0),   // ← withdrawable NOW
    uncleared: Number(w.current_balance || 0) - Number(w.available_balance || 0),
    canDisburse: !!w.can_disburse,
    raw: w,
  };
}

// Treat these clearing states as settled/withdrawable.
// RL_CLEARED_AVAILABLE: IntaSend marks settled funds as clearing_status = 'AVAILABLE'.
// That is THE value that means "withdrawable now". It was missing from this list, so
// money IntaSend had already released was still shown to ISPs as 'clearing'.
// CLEARING / ON_HOLD = not yet settled. Anything else settled is treated as available.
const CLEARED_STATES = ['AVAILABLE', 'CLEARED', 'SETTLED', 'ON_HOLD_CLEARED', 'COMPLETE'];
const PENDING_STATES = ['CLEARING', 'ON_HOLD', 'PENDING', 'PROCESSING'];
function isCleared(clearingStatus) {
  const c = String(clearingStatus || '').trim().toUpperCase();
  if (!c) return true;                       // no clearing info → not held
  if (PENDING_STATES.includes(c)) return false;
  return CLEARED_STATES.includes(c) || !c.startsWith('CLEAR');
}

module.exports = {
  loadConfig, collectSTK, collectionStatus, sendPayout, payoutStatus, walletBalance, isCleared,
  resolveBankCode, BANK_CODES, STATE,
};
