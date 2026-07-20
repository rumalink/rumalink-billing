// IntaSend fee engine for RumaLink. All rates admin-configurable via platform_settings (numeric).
// Model: the ISP pays all fees. Collections are netted at credit time; payouts deduct the payout
// fee at withdrawal. Official pricing (IntaSend Pricing Guide) is seeded by
// rumalink_intasend_fees_stage1.sh. Tiered fees are stored as tN_max / tN_fee numeric pairs.
const { query } = require('../config/database');
let _cache = null, _cacheAt = 0;
const TTL = 30000;

async function loadSettings() {
  const now = Date.now();
  if (_cache && (now - _cacheAt) < TTL) return _cache;
  const r = await query("SELECT key, value FROM platform_settings WHERE key LIKE 'intasend_%'", []);
  const m = {};
  for (const row of r.rows) m[row.key] = parseFloat(row.value);
  _cache = m; _cacheAt = now;
  return m;
}
function invalidate() { _cache = null; }

// ── COLLECTION: net credited to the ISP = amount - fee. mpesa is capped. ──
async function collectionFee(amount, channel /* 'mpesa'|'card'|'card_intl'|'cashapp' */) {
  const s = await loadSettings();
  const pct = {
    mpesa: s.intasend_collection_mpesa_pct ?? 0.03,
    card: s.intasend_collection_card_pct ?? 0.035,
    card_intl: s.intasend_collection_cardintl_pct ?? 0.045,
    cashapp: s.intasend_collection_cardintl_pct ?? 0.045,
  }[channel] ?? (s.intasend_collection_mpesa_pct ?? 0.03);
  let fee = amount * pct;
  // mpesa collection is capped (default 400).
  if (channel === 'mpesa' || channel == null) {
    const cap = s.intasend_collection_mpesa_max ?? 400;
    if (cap > 0) fee = Math.min(fee, cap);
  }
  fee = round2(fee);
  return { fee, net: round2(amount - fee), pct };
}

// ── Tier lookup: given ordered [{max,fee}], return the fee for the first max >= amount. ──
function tierFee(amount, tiers, fallback) {
  for (const t of tiers) { if (amount <= t.max) return t.fee; }
  return tiers.length ? tiers[tiers.length - 1].fee : fallback;
}
function bankTiers(s) {
  return [1,2,3,4,5].map(i => ({ max: s['intasend_payout_bank_t'+i+'_max'], fee: s['intasend_payout_bank_t'+i+'_fee'] }))
    .filter(t => t.max != null && t.fee != null);
}
function paybillTiers(s) {
  return [1,2,3,4,5,6,7].map(i => ({ max: s['intasend_payout_paybill_t'+i+'_max'], fee: s['intasend_payout_paybill_t'+i+'_fee'] }))
    .filter(t => t.max != null && t.fee != null);
}

// ── DISBURSEMENT: fee for a method + gross. ──
async function payoutFee(gross, method /* 'mpesa'|'bank'|'paybill'|'till' */) {
  const s = await loadSettings();
  let fee = 0;
  if (method === 'mpesa') {
    const pct = s.intasend_payout_mpesa_pct ?? 0.015;
    const min = s.intasend_payout_mpesa_min ?? 10;
    const max = s.intasend_payout_mpesa_max ?? 50;
    fee = Math.min(Math.max(gross * pct, min), max);
  } else if (method === 'bank') {
    fee = tierFee(gross, bankTiers(s), 500);
  } else if (method === 'paybill') {
    fee = tierFee(gross, paybillTiers(s), 150);
  } else if (method === 'till' || method === 'b2b') {
    const thr = s.intasend_payout_till_threshold ?? 10000;
    fee = gross < thr ? (s.intasend_payout_till_fee_low ?? 20) : (s.intasend_payout_till_fee_high ?? 40);
  } else {
    // unknown method: fall back to mpesa model
    const pct = s.intasend_payout_mpesa_pct ?? 0.015;
    fee = Math.min(Math.max(gross * pct, s.intasend_payout_mpesa_min ?? 10), s.intasend_payout_mpesa_max ?? 50);
  }
  fee = round2(fee);
  return { fee, net: round2(gross - fee) };
}

// Minimum sensible withdrawal so the fee stays under the admin max ratio.
async function minWithdrawal(method) {
  const s = await loadSettings();
  const ratio = s.intasend_max_fee_ratio ?? 0.10;
  if (ratio <= 0) return 0;
  // For the mpesa %+min+max model: the fee ratio is worst (highest) at low amounts where the min
  // dominates. min_amount = mpesa_min / ratio.
  if (method === 'mpesa') {
    const min = s.intasend_payout_mpesa_min ?? 10;
    return round2(min / ratio);
  }
  // For tiered/flat methods: the smallest tier fee / ratio (fee is flat within a tier, worst at the
  // bottom of the tier).
  let smallestFee;
  if (method === 'bank') smallestFee = (bankTiers(s)[0] || {}).fee ?? 100;
  else if (method === 'paybill') smallestFee = (paybillTiers(s)[0] || {}).fee ?? 30;
  else if (method === 'till' || method === 'b2b') smallestFee = s.intasend_payout_till_fee_low ?? 20;
  else smallestFee = 100;
  return round2(smallestFee / ratio);
}

async function enabledMethods() {
  const s = await loadSettings();
  return {
    mpesa: (s.intasend_method_mpesa_enabled ?? 1) == 1,
    bank: (s.intasend_method_bank_enabled ?? 1) == 1,
    paybill: (s.intasend_method_paybill_enabled ?? 1) == 1,
    till: (s.intasend_method_till_enabled ?? 1) == 1,
  };
}

async function quoteWithdrawal(gross, method) {
  const { fee, net } = await payoutFee(gross, method);
  const min = await minWithdrawal(method);
  const s = await loadSettings();
  const ratio = s.intasend_max_fee_ratio ?? 0.10;
  const feeRatio = gross > 0 ? fee / gross : 1;
  return {
    gross: round2(gross), fee, net,
    min_withdrawal: min,
    below_threshold: gross < min,
    fee_ratio: round4(feeRatio),
    max_fee_ratio: ratio,
  };
}

// Return the full official fee table (for admin edit + ISP display).
async function feeTable() {
  const s = await loadSettings();
  return {
    collection: {
      mpesa: { pct: s.intasend_collection_mpesa_pct ?? 0.03, max: s.intasend_collection_mpesa_max ?? 400 },
      card: { pct: s.intasend_collection_card_pct ?? 0.035 },
      card_intl: { pct: s.intasend_collection_cardintl_pct ?? 0.045 },
    },
    payout: {
      mpesa: { pct: s.intasend_payout_mpesa_pct ?? 0.015, min: s.intasend_payout_mpesa_min ?? 10, max: s.intasend_payout_mpesa_max ?? 50 },
      bank: bankTiers(s),
      paybill: paybillTiers(s),
      till: { threshold: s.intasend_payout_till_threshold ?? 10000, low: s.intasend_payout_till_fee_low ?? 20, high: s.intasend_payout_till_fee_high ?? 40 },
    },
    enabled: await enabledMethods(),
  };
}

function round2(n) { return Math.round((Number(n) + Number.EPSILON) * 100) / 100; }
function round4(n) { return Math.round((Number(n) + Number.EPSILON) * 10000) / 10000; }
module.exports = { loadSettings, invalidate, collectionFee, payoutFee, minWithdrawal, enabledMethods, quoteWithdrawal, feeTable };
