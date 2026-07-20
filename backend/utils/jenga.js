// utils/jenga.js — Jenga (Equity Bank / Finserve) payment client
// M-Pesa STK push with ACCOUNT-BASED settlement: funds settle in real time
// directly into the ISP's Equity account (the platform never holds them).
//
// Token handling: Jenga access tokens are short-lived (the auth response carries
// an `expiresIn` timestamp — often ~15 min). We cache until shortly before that
// real expiry, and stkPush force-refreshes + retries once on a 401.

const axios = require('axios');
const crypto = require('crypto');
const logger = require('./logger');
const { query } = require('../config/database');

const tokenCache = new Map(); // 'jenga' -> { token, expiresAt }

async function loadConfig() {
  const r = await query(
    "SELECT * FROM payment_provider_configs WHERE provider='jenga' AND is_active=true LIMIT 1"
  );
  return r.rows[0] || null;
}

function baseUrl(cfg) {
  return (cfg.base_url || 'https://api.finserve.africa').replace(/\/+$/, '');
}

function normalizePhone(p) {
  return String(p || '').replace(/\D/g, '').replace(/^0/, '254').replace(/^\+/, '');
}

// Parse Jenga's expiry into an epoch-ms "use until" time, minus a 60s safety margin.
function computeExpiry(data) {
  const fallback = Date.now() + 10 * 60 * 1000; // assume 10 min if unparseable
  const raw = data && data.expiresIn;
  if (!raw) return fallback;
  const t = Date.parse(raw);              // ISO timestamp e.g. "2023-07-13T07:03:02Z"
  if (!isNaN(t)) return t - 60 * 1000;    // refresh 60s before it lapses
  const n = parseInt(raw, 10);            // or possibly seconds-from-now
  if (!isNaN(n) && n > 0 && n < 86400) return Date.now() + (n - 60) * 1000;
  return fallback;
}

// ── OAuth (v3 merchant authenticate) ─────────────────────────────────────
async function getToken(cfg, force = false) {
  if (!force) {
    const cached = tokenCache.get('jenga');
    if (cached && cached.expiresAt - Date.now() > 5 * 1000) return cached.token;
  }
  const url = baseUrl(cfg) + '/authentication/api/v3/authenticate/merchant';
  let lastErr = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const res = await axios.post(
        url,
        { merchantCode: cfg.merchant_code, consumerSecret: cfg.consumer_secret },
        { headers: { 'Api-Key': cfg.api_key, 'Content-Type': 'application/json' }, timeout: 15000 }
      );
      const token = res.data.accessToken || res.data.access_token;
      if (!token) throw new Error('No accessToken in Jenga auth response');
      const expiresAt = computeExpiry(res.data);
      tokenCache.set('jenga', { token, expiresAt });
      logger.info('[JENGA] token refreshed; valid until ' + new Date(expiresAt).toISOString());
      return token;
    } catch (e) {
      lastErr = e;
      const status = e.response && e.response.status;
      const delay = status === 403 ? 4000 + Math.random() * 3000 : 1000 + attempt * 2000;
      logger.warn(`[JENGA] auth attempt ${attempt + 1} failed: status=${status} msg=${e.message}`);
      await new Promise(r => setTimeout(r, delay));
    }
  }
  throw new Error('Jenga authentication failed: ' + (lastErr && lastErr.message));
}

// ── RSA-SHA256 request signing ───────────────────────────────────────────
function sign(cfg, dataString) {
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(dataString, 'utf8');
  signer.end();
  return signer.sign(cfg.private_key, 'base64');
}

// ── Account-based M-Pesa STK push ────────────────────────────────────────
// One STK per ref, EXCEPT a single forced-token retry on a 401 (which means the
// request was rejected at auth, before the ref was ever registered — safe to reuse).
async function stkPush({ cfg, ispAccount, ispName, phone, amount, ref, callbackUrl }) {
  if (!cfg) throw new Error('Jenga is not configured on the platform.');
  if (!ispAccount) throw new Error('ISP Equity account number is missing.');

  const msisdn = normalizePhone(phone);
  if (!/^254[17]\d{8}$/.test(msisdn)) throw new Error('Invalid phone number for M-Pesa.');

  const amt = Number(amount).toFixed(2);   // e.g. "10.00"
  const currency = 'KES';
  const telco = 'Safaricom';

  // Signature: accountNumber + ref + mobileNumber + telco + amount + currency
  const sigData = `${ispAccount}${ref}${msisdn}${telco}${amt}${currency}`;
  const signature = sign(cfg, sigData);

  const url = baseUrl(cfg) + '/v3-apis/payment-api/v3.0/stkussdpush/initiate';
  const body = {
    merchant: { accountNumber: String(ispAccount).trim(), countryCode: 'KE', name: String(ispName || 'RumaLink ISP').slice(0, 40) },
    payment: {
      ref,
      amount: amt,
      currency,
      telco,
      mobileNumber: msisdn,
      date: new Date().toISOString().slice(0, 10),
      callBackUrl: callbackUrl,
      pushType: 'STK'
    }
  };

  let forced = false;
  for (let attempt = 0; attempt < 2; attempt++) {
    const token = await getToken(cfg, forced);
    try {
      const res = await axios.post(url, body, {
        headers: { Authorization: `Bearer ${token}`, Signature: signature, 'Content-Type': 'application/json' },
        timeout: 30000
      });
      return { idempotent: false, data: res.data }; // { status, code, message, reference, transactionId }
    } catch (e) {
      const status = e.response && e.response.status;
      const errMsg = (e.response && e.response.data && (e.response.data.message || e.response.data.error)) || e.message;
      logger.error('[JENGA] stk raw error -> status=' + status + ' data=' + JSON.stringify((e.response && e.response.data) || {}));
      // 401 = expired/invalid token; the ref was never registered. Refresh once and retry.
      if (status === 401 && !forced) {
        tokenCache.delete('jenga');
        forced = true;
        logger.warn('[JENGA] 401 — forcing token refresh and retrying once');
        continue;
      }
      throw new Error(prettify(errMsg, status));
    }
  }
  throw new Error('Payment service authentication issue. Please contact support.');
}

// ── Status query fallback (when the IPN callback is slow/missing) ─────────
async function queryStatus({ cfg, reference }) {
  if (!cfg) throw new Error('Jenga is not configured.');
  const token = await getToken(cfg);
  const url = baseUrl(cfg) + '/v3-apis/transaction-api/v3.0/payments/' + encodeURIComponent(reference);
  try {
    const res = await axios.get(url, {
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      timeout: 15000
    });
    return res.data;
  } catch (e) {
    logger.warn(`[JENGA] queryStatus failed for ${reference}: ${e.message}`);
    return null;
  }
}

function prettify(rawMsg, status) {
  const msg = String(rawMsg || '').toLowerCase();
  if (msg.includes('already exists')) return 'This payment was already submitted. Please wait a moment.';
  if (msg.includes('insufficient')) return 'Insufficient M-Pesa balance. Please top up and try again.';
  if (msg.includes('invalid') && msg.includes('account')) return 'The ISP Equity account could not be verified.';
  if (msg.includes('signature')) return 'Payment signing error. Please contact support.';
  if (msg.includes('token')) return 'Payment service authentication issue. Please contact support.';
  if (status === 401 || status === 403) return 'Payment service authentication issue. Please contact support.';
  if (status === 429) return 'Too many requests right now. Please retry in a moment.';
  return 'Payment temporarily unavailable: ' + rawMsg;
}

module.exports = { loadConfig, getToken, sign, stkPush, queryStatus, normalizePhone, prettify };
