// utils/mpesa.js — Production-grade M-Pesa Daraja client
// Features:
//   - Token caching per shortcode (avoids 403 from OAuth rate limit)
//   - Background token refresh ~5 min before expiry
//   - Idempotent STK requests (same phone+amount within 60s returns existing)
//   - Retry with exponential backoff on 5xx/transient errors
//   - Clear user-facing error messages
//   - Per-shortcode request queue (max 10 concurrent)

const axios = require('axios');
const logger = require('./logger');

// In-memory token cache: { shortcode: { token, expiresAt, refreshing } }
const tokenCache = new Map();

// In-memory recent-request cache for idempotency
const recentRequests = new Map(); // key: shortcode+phone+amount → { paymentId, ts }

// Per-shortcode concurrency control
const inflight = new Map(); // shortcode → current concurrent count
const MAX_CONCURRENT_PER_SHORTCODE = 10;
const RECENT_REQUEST_WINDOW_MS = 60 * 1000; // 60s

// Clean recentRequests periodically
setInterval(() => {
  const now = Date.now();
  for (const [k, v] of recentRequests.entries()) {
    if (now - v.ts > RECENT_REQUEST_WINDOW_MS) recentRequests.delete(k);
  }
}, 30 * 1000);

/**
 * Get a cached or fresh OAuth token for the shortcode.
 * Token is valid for 3600 seconds (1 hour). We refresh ~5min before expiry.
 */
async function getAccessToken(creds, baseUrl) {
  const cacheKey = creds.shortcode + ':' + creds.consumer_key;
  const cached = tokenCache.get(cacheKey);
  const now = Date.now();

  if (cached && cached.expiresAt - now > 5 * 60 * 1000) {
    return cached.token;
  }

  // Prevent concurrent token fetches for same shortcode
  if (cached && cached.refreshing) {
    // Wait briefly for ongoing fetch to complete
    for (let i = 0; i < 30; i++) {
      await new Promise(r => setTimeout(r, 100));
      const updated = tokenCache.get(cacheKey);
      if (updated && !updated.refreshing && updated.expiresAt - Date.now() > 60 * 1000) {
        return updated.token;
      }
    }
  }

  // Mark refreshing
  tokenCache.set(cacheKey, { ...cached, refreshing: true });

  let lastError = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const tokenRes = await axios.get(
        `${baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
        {
          headers: { Authorization: `Basic ${Buffer.from(creds.consumer_key + ':' + creds.consumer_secret).toString('base64')}` },
          timeout: 10000
        }
      );
      const token = tokenRes.data.access_token;
      // Daraja tokens last 3599s; we use 50min lifetime to be safe
      tokenCache.set(cacheKey, {
        token,
        expiresAt: Date.now() + 50 * 60 * 1000,
        refreshing: false
      });
      logger.info(`[MPESA] token refreshed for shortcode ${creds.shortcode}`);
      return token;
    } catch (e) {
      lastError = e;
      const status = e.response && e.response.status;
      // 403 → wait longer (likely rate limit or temp block)
      // 5xx → retry quickly
      const delay = status === 403 ? 5000 + Math.random() * 5000 : 1000 + attempt * 2000;
      logger.warn(`[MPESA] token attempt ${attempt+1} failed: status=${status} msg=${e.message} — retry in ${Math.round(delay)}ms`);
      await new Promise(r => setTimeout(r, delay));
    }
  }

  tokenCache.delete(cacheKey);
  throw new Error('M-Pesa OAuth failed after 3 attempts: ' + (lastError && lastError.message));
}

/**
 * Send STK push with idempotency, retry, and concurrency control.
 * Returns { stkData, idempotent } where idempotent=true if duplicate within window.
 */
async function stkPush({ creds, baseUrl, phone, amount, accountRef, transactionDesc, callbackUrl }) {
  const normalizedPhone = phone.replace(/^0/, '254').replace(/^\+/, '').replace(/\D/g, '');
  const idempotencyKey = `${creds.shortcode}:${normalizedPhone}:${Math.ceil(amount)}`;
  const now = Date.now();
  const existing = recentRequests.get(idempotencyKey);
  if (existing && now - existing.ts < RECENT_REQUEST_WINDOW_MS) {
    logger.info(`[MPESA] idempotent: returning existing payment for ${idempotencyKey}`);
    return { idempotent: true, paymentId: existing.paymentId, stkData: existing.stkData };
  }

  // Concurrency check
  const currentInflight = inflight.get(creds.shortcode) || 0;
  if (currentInflight >= MAX_CONCURRENT_PER_SHORTCODE) {
    // Queue (wait briefly for slot)
    for (let i = 0; i < 50; i++) {
      await new Promise(r => setTimeout(r, 100));
      const cur = inflight.get(creds.shortcode) || 0;
      if (cur < MAX_CONCURRENT_PER_SHORTCODE) break;
    }
    if ((inflight.get(creds.shortcode) || 0) >= MAX_CONCURRENT_PER_SHORTCODE) {
      throw new Error('M-Pesa is processing many requests right now. Please retry in a moment.');
    }
  }

  inflight.set(creds.shortcode, (inflight.get(creds.shortcode) || 0) + 1);

  try {
    const token = await getAccessToken(creds, baseUrl);
    const timestamp = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
    const password = Buffer.from(creds.shortcode + creds.passkey + timestamp).toString('base64');

    let lastError = null;
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        const stkRes = await axios.post(`${baseUrl}/mpesa/stkpush/v1/processrequest`, {
          BusinessShortCode: creds.shortcode,
          Password: password,
          Timestamp: timestamp,
          TransactionType: 'CustomerPayBillOnline',
          Amount: Math.ceil(amount),
          PartyA: normalizedPhone,
          PartyB: creds.shortcode,
          PhoneNumber: normalizedPhone,
          CallBackURL: callbackUrl,
          AccountReference: accountRef,
          TransactionDesc: transactionDesc
        }, {
          headers: { Authorization: `Bearer ${token}` },
          timeout: 15000
        });

        // Cache for idempotency
        recentRequests.set(idempotencyKey, { ts: now, stkData: stkRes.data });
        return { idempotent: false, stkData: stkRes.data };
      } catch (e) {
        lastError = e;
        const status = e.response && e.response.status;
        const errMsg = (e.response && e.response.data && (e.response.data.errorMessage || e.response.data.ResultDesc)) || e.message;
        // Don't retry on 4xx client errors (except 429 rate limit)
        if (status && status >= 400 && status < 500 && status !== 429) {
          throw new Error(prettifyMpesaError(errMsg, status));
        }
        const delay = 1000 + attempt * 2000 + Math.random() * 1000;
        logger.warn(`[MPESA] stkpush attempt ${attempt+1} failed: ${errMsg} — retry in ${Math.round(delay)}ms`);
        await new Promise(r => setTimeout(r, delay));
      }
    }
    const errMsg = (lastError.response && lastError.response.data && (lastError.response.data.errorMessage || lastError.response.data.ResultDesc)) || lastError.message;
    throw new Error(prettifyMpesaError(errMsg, lastError.response && lastError.response.status));
  } finally {
    inflight.set(creds.shortcode, Math.max(0, (inflight.get(creds.shortcode) || 1) - 1));
  }
}

function prettifyMpesaError(rawMsg, status) {
  const msg = String(rawMsg || '').toLowerCase();
  if (msg.includes('busy') || msg.includes('try again')) {
    return 'M-Pesa is temporarily busy. Please try again in a moment.';
  }
  if (msg.includes('insufficient')) {
    return 'Insufficient M-Pesa balance. Please top up and try again.';
  }
  if (msg.includes('invalid') && msg.includes('phone')) {
    return 'Invalid phone number for M-Pesa.';
  }
  if (status === 403) {
    return 'Payment service authentication issue. Please contact support.';
  }
  if (status === 429) {
    return 'Too many requests right now. Please retry in 30 seconds.';
  }
  return 'Payment temporarily unavailable: ' + rawMsg;
}

/**
 * Record an idempotency mapping (paymentId → idempotency key) so the route
 * can register the paymentId after creating the DB row.
 */
function recordIdempotencyPaymentId(shortcode, phone, amount, paymentId) {
  const normalizedPhone = phone.replace(/^0/, '254').replace(/^\+/, '').replace(/\D/g, '');
  const key = `${shortcode}:${normalizedPhone}:${Math.ceil(amount)}`;
  const e = recentRequests.get(key);
  if (e) e.paymentId = paymentId;
}


// RL_DARAJA_QUERY: ask Safaricom whether an STK request completed, so a dropped callback cannot
// strand a paying customer. Same auth scheme as stkPush: base64(shortcode+passkey+timestamp).
// Returns the SAME shape as intasend.collectionStatus so one self-heal path handles both.
//   ResultCode 0            -> paid
//   1032 (cancelled) / 1 (insufficient) / 2001 etc -> dead
//   1037 (timeout) / 500.x / still processing      -> unknown (leave pending)
async function stkQuery({ creds, baseUrl, checkoutRequestId }) {
  try {
    const token = await getAccessToken(creds, baseUrl);
    const timestamp = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
    const password = Buffer.from(creds.shortcode + creds.passkey + timestamp).toString('base64');
    const r = await axios.post(`${baseUrl}/mpesa/stkpushquery/v1/processrequest`, {
      BusinessShortCode: creds.shortcode,
      Password: password,
      Timestamp: timestamp,
      CheckoutRequestID: checkoutRequestId,
    }, { headers: { Authorization: 'Bearer ' + token }, timeout: 15000 });

    const code = String((r.data && r.data.ResultCode) != null ? r.data.ResultCode : '');
    // Safaricom returns ResultCode as string or number depending on path.
    const DEAD = ['1032','1','2001','1019','1001'];
    return {
      ok: true,
      resultCode: code,
      isPaid: code === '0',
      isDead: DEAD.includes(code),
      raw: r.data,
    };
  } catch (e) {
    // RL_STKQUERY_404: classify Safaricom's non-success responses. The one rule that matters:
    // NEVER mark a payment dead on anything ambiguous — only genuine failure ResultCodes (handled
    // in the success branch above) do that. Everything here is UNKNOWN -> leave the payment
    // pending, to be retried on the next poll or cron sweep.
    const data = (e.response && e.response.data) || {};
    const httpStatus = e.response && e.response.status;
    const ec = String(data.errorCode || data.ResultCode || '');

    // 'still being processed' — the STK is mid-flight. Try again later.
    if (ec === '500.001.1001') {
      return { ok: true, resultCode: 'processing', isPaid: false, isDead: false, unknown: true };
    }
    // 404 'Resource not found' — the CheckoutRequestID is expired or unknown to Safaricom. Common
    // on sandbox and for old ids. Cannot determine outcome; do NOT treat as failure.
    if (httpStatus === 404 || ec.startsWith('404')) {
      logger.warn('[MPESA] stkQuery 404 (expired/unknown CheckoutRequestID) — leaving pending: ' + (data.errorMessage || ''));
      return { ok: false, resultCode: 'not_found', isPaid: false, isDead: false, unknown: true };
    }
    // Anything else (network, 5xx, token) — transient. Unknown, never dead.
    logger.warn('[MPESA] stkQuery error (' + (httpStatus || 'no-status') + '): ' + e.message);
    return { ok: false, resultCode: null, isPaid: false, isDead: false, error: e.message, unknown: true };
  }
}

module.exports = {
  getAccessToken,
  stkPush,
  stkQuery,
  recordIdempotencyPaymentId,
  prettifyMpesaError,
  // Allow forcing fresh token on startup
  warmToken: async (creds, baseUrl) => {
    try { await getAccessToken(creds, baseUrl); } catch(e) { logger.warn(`[MPESA] warmToken failed: ${e.message}`); }
  }
};
