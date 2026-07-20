const express = require('express');
const RL_RADIUS_NATIVE = true; // RUMALINK: hotspot auth via RADIUS; skip local-user/mac-cookie creation
const { effectiveHotspotRate } = require('../utils/effectiveRate');
const axios = require('axios');
const { query } = require('../config/database');
const { sendSMS } = require('../utils/sms');
const { generateCode, generateIspUsername } = require('../utils/vouchers');
const { rlConfirmWithIntasend } = require('../utils/intasend-selfheal'); // RL_POLL_SELFHEAL
const { registerMACAuth, triggerMACReconnect } = require('../utils/macAuth');
const logger = require('../utils/logger');
const mt = require('../utils/mikrotik');
const coa = require('../utils/coa');
const { radiusUsername } = require('../utils/radius');


// v57: CoA-Disconnect with REST fallback. Prefers RADIUS CoA over direct REST.
async function kickSession(nasId, sessionRecord, baseURL, auth) {
  // Try CoA-Disconnect first
  try {
    if (sessionRecord && sessionRecord.user) {
      const r = await coa.sendDisconnect(nasId, sessionRecord.user);
      if (r.ok) {
        logger.info(`[COA-KICK] user=${sessionRecord.user} via CoA-Disconnect`);
        return { ok: true, via: 'coa' };
      }
      logger.warn(`[COA-KICK] CoA failed for ${sessionRecord.user}: ${r.error || 'no ACK'} — falling back to REST`);
    }
  } catch(e) { logger.warn(`[COA-KICK] CoA exception: ${e.message}`); }
  // Fallback: REST POST /active/remove
  try {
    const axios = require('axios');
    await axios.post(baseURL + '/ip/hotspot/active/remove', { '.id': sessionRecord['.id'] }, { auth, timeout: 5000 });
    logger.info(`[REST-KICK] user=${sessionRecord.user} via REST`);
    return { ok: true, via: 'rest' };
  } catch(e) { return { ok: false, error: e.message }; }
}

const mpesaService = require('../utils/mpesa');

const router = express.Router();

// ── GET portal data (public) ──────────────────────────────────

// v62.18: helper - sync radcheck + radreply for a voucher (for RADIUS hotspot auth)
async function syncVoucherRadius(voucher, packageData) {
  try {
    const ispShort = String(voucher.isp_id).replace(/-/g, '').slice(0, 8).toLowerCase();
    const realmedUser = voucher.code + '@' + ispShort;
    // RUMALINK_SYNC_SELFETCH: always resolve the real password, independent of caller.
    let _rlPw = voucher.password;
    if (!_rlPw) {
      try {
        const _pwr = await query('SELECT password FROM hotspot_vouchers WHERE code = $1 LIMIT 1', [voucher.code]);
        if (_pwr.rows && _pwr.rows[0] && _pwr.rows[0].password) _rlPw = _pwr.rows[0].password;
      } catch (e) {}
    }
    _rlPw = _rlPw || voucher.code;
    
    // Remove any old entries
    await query("DELETE FROM radcheck WHERE username = $1 OR username = $2", [voucher.code, realmedUser]);
    await query("DELETE FROM radreply WHERE username = $1 OR username = $2", [voucher.code, realmedUser]);
    
    // Insert Cleartext-Password
    await query(
      "INSERT INTO radcheck (username, attribute, op, value) VALUES ($1, 'Cleartext-Password', ':=', $2)",
      [realmedUser, _rlPw] /* RUMALINK_SYNC_SELFETCH */
    );
    
    if (packageData) {
      // Mikrotik-Rate-Limit (e.g. "5M/10M" for 5 Mbps up / 10 Mbps down)
      if (packageData.bandwidth_down_mbps || packageData.bandwidth_up_mbps) {
        const up = packageData.bandwidth_up_mbps || packageData.bandwidth_down_mbps;
        const down = packageData.bandwidth_down_mbps || packageData.bandwidth_up_mbps;
        const rateLimit = up + 'M/' + down + 'M';
        await query(
          "INSERT INTO radreply (username, attribute, op, value) VALUES ($1, 'Mikrotik-Rate-Limit', '=', $2)",
          [realmedUser, rateLimit]
        );
      }
      
      // Session-Timeout — prefer voucher.expires_at if set (more accurate), else duration_hours
      let timeoutSeconds = null;
      if (voucher && voucher.expires_at) {
        timeoutSeconds = Math.max(60, Math.floor((new Date(voucher.expires_at) - Date.now()) / 1000));
      } else if (packageData && packageData.duration_hours) {
        timeoutSeconds = packageData.duration_hours * 3600;
      }
      if (timeoutSeconds && timeoutSeconds > 0) {
        await query(
          "INSERT INTO radreply (username, attribute, op, value) VALUES ($1, 'Session-Timeout', '=', $2)",
          [realmedUser, String(timeoutSeconds)]
        );
      }
      
      // Mikrotik-Total-Limit (data cap in bytes)
      if (packageData.data_limit_mb) {
        const bytes = packageData.data_limit_mb * 1024 * 1024;
        await query(
          "INSERT INTO radreply (username, attribute, op, value) VALUES ($1, 'Mikrotik-Total-Limit', '=', $2)",
          [realmedUser, String(bytes)]
        );
      }
      
      // v62.20: Mikrotik-Group from package's mikrotik_profile (Mikrotik user-profile name)
      if (packageData.mikrotik_profile) {
        await query(
          "INSERT INTO radreply (username, attribute, op, value) VALUES ($1, 'Mikrotik-Group', '=', $2)",
          [realmedUser, packageData.mikrotik_profile]
        );
      }
    }
    
    logger.info('[radius-sync] voucher ' + voucher.code + ' -> ' + realmedUser);
  } catch (e) {
    logger.error('[radius-sync] failed for ' + voucher.code + ': ' + e.message);
  }
}

router.get('/:ispId', async (req, res, next) => {
  // Validate UUID format to prevent SQL errors
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(req.params.ispId)) {
    return res.status(400).json({ error: 'Invalid ISP ID format' });
  }
  try {
    const isp = await query(
      "SELECT id, company_name, logo_url, support_number FROM isps WHERE id=$1::uuid AND status='active'",
      [req.params.ispId]
    );
    if (!isp.rows[0]) return res.status(404).json({ error: 'Portal not found' });

    let portal = { rows: [] };
    let payMethods = { rows: [] };
    try { portal = await query('SELECT * FROM isp_captive_portal WHERE isp_id=$1::uuid', [req.params.ispId]); } catch(e) {}
    const packages = await query(
      'SELECT id, name, description, price, duration_hours, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb FROM hotspot_packages WHERE isp_id=$1::uuid AND is_active=true ORDER BY price ASC',
      [req.params.ispId]
    );
    try {
      payMethods = await query(
        "SELECT id, method_type, label, till_number, paybill_number, account_reference, bank_name, account_name, account_number FROM isp_payment_methods WHERE isp_id=$1::uuid AND is_active=true",
        [req.params.ispId]
      );
    } catch(e) {}

    const portalData = portal.rows[0] || {
      template: 'classic',
      primary_color: '#00d4aa',
      welcome_title: 'Welcome! Connect to WiFi',
      welcome_subtitle: 'Select a package below',
      show_powered_by: true,
      enable_tv_mode: true,
      support_number: null,
      support_label: 'Need Help? Call Us'
    };

    if (!portalData.support_number && isp.rows[0].support_number) {
      portalData.support_number = isp.rows[0].support_number;
    }

    // RL_NOTIF_BANNER: expose the banner only if enabled AND within its schedule window.
    let active_notification = null;
    try {
      const p = portalData || {};
      if (p.notif_enabled && (p.notif_title || p.notif_message)) {
        const now = Date.now();
        const okStart = !p.notif_start || new Date(p.notif_start).getTime() <= now;
        const okEnd   = !p.notif_end   || new Date(p.notif_end).getTime()   >= now;
        if (okStart && okEnd) {
          active_notification = {
            title: p.notif_title || null,
            message: p.notif_message || null,
            severity: p.notif_severity || 'info'
          };
        }
      }
    } catch(e) {}

    res.json({
      isp: isp.rows[0],
      portal: portalData,
      packages: packages.rows,
      payment_methods: payMethods.rows,
      active_notification /* RL_NOTIF_BANNER */
    });
  } catch (err) { next(err); }
});

// ── REDEEM voucher code ───────────────────────────────────────
router.post('/:ispId/redeem', async (req, res, next) => {
  const { code, mac, phone } = req.body;
  if (!code) return res.status(400).json({ error: 'Voucher code required' });

  try {
    const voucher = await query(`
      SELECT hv.*, hp.name as pkg_name, hp.duration_hours, hp.bandwidth_down_mbps,
             hp.bandwidth_up_mbps, hp.data_limit_mb, hp.mikrotik_profile, hp.price, hp.id as pkg_id
      FROM hotspot_vouchers hv
      JOIN hotspot_packages hp ON hp.id = hv.package_id
      WHERE hv.code=$1 AND hv.isp_id=$2::uuid AND hv.status IN ('unused','active')
    `, [code, req.params.ispId]);

    if (!voucher.rows[0]) return res.status(404).json({ error: 'Invalid or expired voucher code.' });

    const v = voucher.rows[0];
    let expiresAt = v.expires_at;

    if (v.status === 'unused') {
      expiresAt = v.duration_hours ? new Date(Date.now() + v.duration_hours * 3600000) : null;
      await query(
        `UPDATE hotspot_vouchers SET status='active', used_by_mac=$1, used_at=NOW(), expires_at=$2,
         buyer_phone=COALESCE($3,buyer_phone), updated_at=NOW() WHERE id=$4::uuid`,
        [mac, expiresAt, phone, v.id]
      );
      await query(
        "INSERT INTO hotspot_sessions (isp_id,voucher_id,nas_id,mac_address,status) VALUES ($1::uuid,$2::uuid,$3,$4,'active')",
        [v.isp_id, v.id, v.nas_id, mac]
      );

      if (mac) {
        await registerMACAuth({ /* RL_MAC_AUTORECONNECT */
          macAddress: mac, ispId: v.isp_id, expiresAt: expiresAt, voucherUsername: radiusUsername(v.code, v.isp_id), /* RL_MAC_USERNAME_REMAP */
          packageData: { id: v.pkg_id, duration_hours: v.duration_hours, bandwidth_down_mbps: v.bandwidth_down_mbps, bandwidth_up_mbps: v.bandwidth_up_mbps, mikrotik_profile: v.mikrotik_profile }
        }).catch(() => {});
      }
    }

    res.json({
      success: true,
      message: 'Connected! You may now browse.',
      voucher: { code: v.code, package: v.pkg_name, expires_at: expiresAt }
    });
  } catch (err) { next(err); }
});

// ── LOGIN with username + password (vouchers re-used) ────────
// Allows a customer who was disconnected to reconnect using their voucher code
router.post('/:ispId/login', async (req, res, next) => {
  const { username, password, mac } = req.body;
  if (!username) return res.status(400).json({ error: 'Username (voucher code) required' });

  try {
    // For RumaLink, the "username" is the voucher code
    // The "password" can be the same code, or the phone number used to purchase it
    const code = username.trim().toUpperCase();
    const voucher = await query(`
      SELECT hv.*, hp.name as pkg_name, hp.duration_hours, hp.bandwidth_down_mbps,
             hp.bandwidth_up_mbps, hp.data_limit_mb, hp.mikrotik_profile, hp.id as pkg_id
      FROM hotspot_vouchers hv
      JOIN hotspot_packages hp ON hp.id = hv.package_id
      WHERE hv.code=$1 AND hv.isp_id=$2::uuid AND hv.status IN ('unused','active')
    `, [code, req.params.ispId]);

    if (!voucher.rows[0]) {
      return res.status(404).json({ error: 'Invalid voucher code. Check spelling or buy a new package.' });
    }

    const v = voucher.rows[0];

    // Check expiry
    if (v.expires_at && new Date(v.expires_at) < new Date()) {
      return res.status(410).json({ error: 'This voucher has expired. Please purchase a new one.' });
    }

    // If password provided, validate it matches either the code or buyer_phone
    if (password) {
      const passClean = password.replace(/\D/g, '');
      const buyerClean = (v.buyer_phone || '').replace(/\D/g, '');
      const matchesCode = password.trim().toUpperCase() === v.code;
      const matchesPhone = buyerClean && (
        passClean === buyerClean ||
        passClean === buyerClean.replace(/^254/, '0') ||
        ('254' + passClean.replace(/^0/, '')) === buyerClean
      );
      if (!matchesCode && !matchesPhone && password.trim() !== '') {
        // RL_SYNC2_FIX: reject wrong password (no code-only bypass)
        logger.info(`Login: password mismatch for voucher ${code}, rejecting`);
        return res.status(401).json({ error: 'Incorrect password. Use the password from your SMS.' });
      }
    }

    let expiresAt = v.expires_at;
    if (v.status === 'unused') {
      expiresAt = v.duration_hours ? new Date(Date.now() + v.duration_hours * 3600000) : null;
      await query(
        `UPDATE hotspot_vouchers SET status='active', used_by_mac=COALESCE($1, used_by_mac),
         used_at=NOW(), expires_at=$2, updated_at=NOW() WHERE id=$3::uuid`,
        [mac, expiresAt, v.id]
      );
    } else if (mac && v.used_by_mac && v.used_by_mac !== mac) {
      // Already in use by another MAC — update to allow reconnection from new device
      await query(
        "UPDATE hotspot_vouchers SET used_by_mac=$1, updated_at=NOW() WHERE id=$2::uuid",
        [mac, v.id]
      );
    }

    // Register MAC for hotspot auto-login
    if (mac) {
      await registerMACAuth({ /* RL_MAC_AUTORECONNECT */
        macAddress: mac, ispId: v.isp_id, expiresAt: expiresAt, voucherUsername: radiusUsername(v.code, v.isp_id), /* RL_MAC_USERNAME_REMAP */
        packageData: { id: v.pkg_id, duration_hours: v.duration_hours, bandwidth_down_mbps: v.bandwidth_down_mbps, bandwidth_up_mbps: v.bandwidth_up_mbps, mikrotik_profile: v.mikrotik_profile }
      }).catch(e => logger.warn('MAC register:', e.message));
    }

    // Trigger reconnect on MikroTik via CoA
    if (mac) {
      triggerMACReconnect({ macAddress: mac, ispId: v.isp_id }).catch(()=>{});
    }

    res.json({
      success: true,
      message: 'Reconnected successfully! You can now browse.',
      voucher: {
        code: v.code,
        package: v.pkg_name,
        expires_at: expiresAt,
        bandwidth_down: v.bandwidth_down_mbps,
        bandwidth_up: v.bandwidth_up_mbps
      }
    });
  } catch (err) {
    logger.error('Captive login error:', err.message);
    next(err);
  }
});

// ── PAY (initiate STK push) ───────────────────────────────────
router.post('/:ispId/pay', require('../middleware/auth').requireActiveLicense, async (req, res) => {
  const { phone, package_id, mac, tv_mac, is_tv } = req.body; /* RL_TV_PAY */
  const effectiveMac = (is_tv && tv_mac) ? String(tv_mac).toUpperCase() : mac;
  if (!phone || !package_id) return res.status(400).json({ error: 'Phone and package required' });

  // Normalize phone
  const normalizedPhone = String(phone).replace(/\D/g, '').replace(/^0/, '254').replace(/^\+/, '');
  if (!/^254[17]\d{8}$/.test(normalizedPhone)) {
    return res.status(400).json({ error: `Invalid phone format. Use 0712345678 or 254712345678. Got: ${phone}` });
  }

  try {
    const pkg = await query(
      'SELECT * FROM hotspot_packages WHERE id=$1::uuid AND isp_id=$2::uuid',
      [package_id, req.params.ispId]
    );
    if (!pkg.rows[0]) return res.status(404).json({ error: 'Package not found' });

    const isp = await query('SELECT * FROM isps WHERE id=$1::uuid', [req.params.ispId]);
    if (!isp.rows[0]) return res.status(404).json({ error: 'ISP not found' });
    const ispData = isp.rows[0];
    const amount = parseFloat(pkg.rows[0].price);

    // ── IntaSend collection path (RL_INTASEND_CAPTIVE) ───────────────────
    // ISP on IntaSend: send the STK via IntaSend with the PLATFORM ADMIN keys. Funds land in
    // the admin IntaSend account, so the ISP wallet is credited by /api/payments/intasend/ipn.
    try {
      const _ispm = await query(
        "SELECT * FROM isp_payment_methods WHERE isp_id=$1::uuid AND is_active=true AND (method_type='intasend' OR provider='intasend') ORDER BY is_default DESC, created_at ASC LIMIT 1",
        [req.params.ispId]
      );
      if (_ispm.rows[0]) {
        const intasend = require('../utils/intasend-client');
        const isfees = require('../utils/intasend-fees');
        let icfg;
        try { icfg = await intasend.loadConfig(); } catch (e) { return res.status(400).json({ error: 'IntaSend is not configured by the platform admin yet.' }); }
        if (!icfg.active) return res.status(400).json({ error: 'IntaSend is not active. Contact the platform admin.' });
        const colFee = await isfees.collectionFee(amount, 'mpesa');
        const commRate = await effectiveHotspotRate(ispData.commission_rate);
        /* RL_NET_FEE_ONLY: the ISP earns gross minus the IntaSend collection fee ONLY. RumaLink's
           platform commission is billed monthly via the license invoice (isp_platform_invoices),
           NOT deducted per payment — deducting it here would double-charge. commission_amount is
           still recorded for reporting, but it is NOT subtracted from net_amount. */
        const commAmount = Math.round((amount * commRate) * 100) / 100;   // recorded only
        const netAmount = Math.round((amount - colFee.fee) * 100) / 100;  // gross - IntaSend fee
        const totalDeducted = colFee.fee;                                  // only IntaSend leaves per-payment
        const ref = 'RLI' + Date.now().toString(36).toUpperCase() + Math.random().toString(36).slice(2, 6).toUpperCase();
        const _pay = await query(
          `INSERT INTO payments
             (isp_id, amount, payment_method, payment_gateway, gateway_reference, phone_number,
              commission_rate, commission_amount, net_amount, description, status, used_admin_credentials, metadata)
           VALUES ($1::uuid,$2::decimal,'mpesa_stk','intasend',$3,$4,$5::decimal,$6::decimal,$7::decimal,$8,'pending',true,$9::jsonb)
           RETURNING id`,
          [req.params.ispId, amount, ref, normalizedPhone, commRate, totalDeducted, netAmount,
           `Hotspot - ${pkg.rows[0].name}`,
           JSON.stringify({ intasend_fee: colFee.fee, platform_commission: commAmount, gross: amount })]
        );
        const paymentId = _pay.rows[0].id;
        const callbackUrl = `${process.env.BASE_URL}/api/payments/intasend/ipn`;
        await query(
          `INSERT INTO mpesa_transactions (isp_id, payment_id, checkout_request_id, merchant_request_id, amount, phone, status)
           VALUES ($1::uuid,$2::uuid,$3,$4,$5::decimal,$6,'pending')`,
          [req.params.ispId, paymentId, ref, ref, amount, normalizedPhone]
        ).catch(() => {});
        let stk;
        try {
          stk = await intasend.collectSTK({ phone: normalizedPhone, amount, apiRef: ref, callbackUrl, narrative: `Hotspot - ${pkg.rows[0].name}` });
        } catch (se) {
          await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid", [String(se.message).slice(0,240), paymentId]).catch(()=>{});
          logger.error('[INTASEND] STK error ref=' + ref + ': ' + se.message);
          return res.status(502).json({ error: 'Payment could not be started: ' + se.message });
        }
        await query("UPDATE payments SET transaction_id=$1, metadata = COALESCE(metadata,'{}'::jsonb) || $2::jsonb WHERE id=$3::uuid",
          [String(stk.invoiceId||''), JSON.stringify({ intasend_invoice: stk.invoiceId, intasend_state: stk.state }), paymentId]).catch(()=>{});
        if (is_tv && effectiveMac) { await query("UPDATE payments SET metadata = COALESCE(metadata,'{}'::jsonb) || jsonb_build_object('is_tv',true,'tv_mac',$1::text) WHERE id=$2::uuid", [effectiveMac, paymentId]).catch(()=>{}); }
        /* RL_STORE_INVOICE_COL: also persist invoice in the COLUMN refreshClearing reads, and
           start as CLEARING so held funds are tracked. */
        await query("UPDATE payments SET intasend_invoice=COALESCE(intasend_invoice,$1), clearing_status=COALESCE(NULLIF(clearing_status,''),'CLEARING') WHERE id=$2::uuid", [String(stk.invoiceId||''), paymentId]).catch(()=>{});
        try {
          let code, voucherId;
          const existing = await query(
            `SELECT code, id FROM hotspot_vouchers WHERE isp_id=$1::uuid AND buyer_phone=$2 AND payment_id IS NOT NULL ORDER BY created_at ASC LIMIT 1`,
            [req.params.ispId, normalizedPhone]
          );
          if (existing.rows[0]) {
            voucherId = existing.rows[0].id; code = existing.rows[0].code;
            await query(`UPDATE hotspot_vouchers SET payment_id=$1::uuid, package_id=$2::uuid, used_by_mac=COALESCE($4, used_by_mac), updated_at=NOW() WHERE id=$3::uuid`,
              [paymentId, package_id, voucherId, mac || null]);
          } else {
            code = await generateIspUsername(req.params.ispId);
            await query(`INSERT INTO hotspot_vouchers (isp_id, package_id, code, status, buyer_phone, payment_id, used_by_mac, is_tv, tv_mac) VALUES ($1::uuid,$2::uuid,$3,'unused',$4,$5::uuid,$6,$7,$8)`,
              [req.params.ispId, package_id, code, normalizedPhone, paymentId, (is_tv && effectiveMac ? effectiveMac : (mac || null)), !!(is_tv && tv_mac), (is_tv && tv_mac ? effectiveMac : null)]); /* RL_TV_VOUCHER_SCOPE */
          }
          logger.info(`Captive(IntaSend): voucher ${code} reserved for ${normalizedPhone}`);
        } catch (ve) { logger.warn('IntaSend voucher reserve: ' + ve.message); }
        return res.json({ success: true, payment_id: paymentId, amount, checkout_request_id: ref, message: `M-Pesa prompt sent to ${normalizedPhone}.` });
      }
    } catch (ipathErr) {
      logger.error('Captive IntaSend path error: ' + ipathErr.message);
      return res.status(500).json({ error: 'IntaSend payment error: ' + ipathErr.message });
    }
    // ── (not IntaSend) continue below ────────────────────────────────────

    // ── Equity Bank (Jenga) collection path ──────────────────────────────
    // If the ISP's active payment method is Equity, route the STK through Jenga so
    // funds settle directly into the ISP's own Equity account (platform holds nothing).
    // If not Equity, this block does nothing and we fall through to the Daraja path.
    try {
      const _pm = await query(
        "SELECT * FROM isp_payment_methods WHERE isp_id=$1::uuid AND is_active=true AND (provider='equity_jenga' OR method_type='equity') ORDER BY is_default DESC, created_at ASC LIMIT 1",
        [req.params.ispId]
      );
      if (_pm.rows[0] && _pm.rows[0].account_number) {
        const jenga = require('../utils/jenga');
        const jcfg = await jenga.loadConfig();
        if (!jcfg) return res.status(400).json({ error: 'Equity (Jenga) is not configured by the platform admin yet.' });
        const equityAccount = _pm.rows[0].account_number;
        const equityName = _pm.rows[0].account_name || ispData.company_name || 'RumaLink ISP';
        const commRate = await effectiveHotspotRate(ispData.commission_rate);
        const commAmount = amount * commRate;
        const netAmount = amount; /* RL_NET_FEE_ONLY_ALL: ISP's own gateway (Jenga/Daraja) — no IntaSend fee to deduct; commAmount recorded for the MONTHLY platform invoice, never deducted per-payment (was double-charging). */
        const ref = 'RLJ' + Date.now().toString(36).toUpperCase() + Math.random().toString(36).slice(2, 6).toUpperCase();
        const _pay = await query(
          `INSERT INTO payments
             (isp_id, amount, payment_method, payment_gateway, gateway_reference, phone_number,
              commission_rate, commission_amount, net_amount, description, status)
           VALUES ($1::uuid,$2::decimal,'equity','jenga',$3,$4,$5::decimal,$6::decimal,$7::decimal,$8,'pending')
           RETURNING id`,
          [req.params.ispId, amount, ref, normalizedPhone, commRate, commAmount, netAmount, `Hotspot - ${pkg.rows[0].name}`]
        );
        const paymentId = _pay.rows[0].id;
        const callbackUrl = `${process.env.BASE_URL}/api/payments/jenga/ipn`;
        // Record the transaction up-front, then fire the STK ASYNCHRONOUSLY. Jenga's
        // ack can be slow in sandbox; confirmation arrives via the IPN, so we do not block
        // the captive portal on the synchronous ack. On timeout we leave the payment
        // pending (Jenga has registered it; the IPN will confirm) — only a real error fails it.
        await query(
          `INSERT INTO mpesa_transactions (isp_id, payment_id, checkout_request_id, merchant_request_id, amount, phone, status)
           VALUES ($1::uuid,$2::uuid,$3,$4,$5::decimal,$6,'pending')`,
          [req.params.ispId, paymentId, ref, ref, amount, normalizedPhone]
        ).catch(() => {});
        jenga.stkPush({ cfg: jcfg, ispAccount: equityAccount, ispName: equityName, phone: normalizedPhone, amount, ref, callbackUrl })
          .then(jres => { logger.info('[JENGA] STK acked ref=' + ref + ' msg=' + ((jres && jres.data && jres.data.message) || '')); })
          .catch(je => {
            const m = String(je.message || '');
            if (/timeout/i.test(m)) { logger.warn('[JENGA] STK ack slow/timeout, left pending (IPN will confirm) ref=' + ref); }
            else { query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid", [m.slice(0, 240), paymentId]).catch(() => {}); logger.error('[JENGA] STK async error ref=' + ref + ': ' + m); }
          });
        try {
          let code, voucherId;
          const existing = await query(
            `SELECT code, id FROM hotspot_vouchers WHERE isp_id=$1::uuid AND buyer_phone=$2 AND payment_id IS NOT NULL ORDER BY created_at ASC LIMIT 1`,
            [req.params.ispId, normalizedPhone]
          );
          if (existing.rows[0]) {
            voucherId = existing.rows[0].id; code = existing.rows[0].code;
            await query(`UPDATE hotspot_vouchers SET payment_id=$1::uuid, package_id=$2::uuid, used_by_mac=COALESCE($4, used_by_mac), updated_at=NOW() WHERE id=$3::uuid`,
              [paymentId, package_id, voucherId, mac || null]);
          } else {
            code = await generateIspUsername(req.params.ispId);
            await query(`INSERT INTO hotspot_vouchers (isp_id, package_id, code, status, buyer_phone, payment_id, used_by_mac, is_tv, tv_mac) VALUES ($1::uuid,$2::uuid,$3,'unused',$4,$5::uuid,$6,$7,$8)`,
              [req.params.ispId, package_id, code, normalizedPhone, paymentId, (is_tv && effectiveMac ? effectiveMac : (mac || null)), !!(is_tv && tv_mac), (is_tv && tv_mac ? effectiveMac : null)]); /* RL_TV_VOUCHER_SCOPE */
          }
          logger.info(`Captive(Jenga): voucher ${code} reserved for ${normalizedPhone}`);
        } catch (ve) { logger.warn('Jenga voucher reserve:', ve.message); }
        return res.json({ success: true, payment_id: paymentId, amount, checkout_request_id: ref, message: `M-Pesa prompt sent to ${normalizedPhone}.` });
      }
    } catch (jpathErr) {
      logger.error('Captive Equity path error:', jpathErr.message);
      return res.status(500).json({ error: 'Equity payment error: ' + jpathErr.message });
    }
    // ── (not Equity) continue to Daraja path below ───────────────────────


    // ── Load MPesa credentials (priority chain) ───────────────
    let mpesaCreds = null;
    let usedAdminCreds = false;

    // 1. ISP-specific mpesa_configs
    try {
      const ispMpesa = await query(
        "SELECT * FROM mpesa_configs WHERE isp_id=$1::uuid AND is_active=true AND COALESCE(is_admin_config,false)=false LIMIT 1",
        [req.params.ispId]
      );
      if (ispMpesa.rows[0] && ispMpesa.rows[0].consumer_key) {
        const m = ispMpesa.rows[0];
        mpesaCreds = {
          shortcode: m.shortcode, consumer_key: m.consumer_key,
          consumer_secret: m.consumer_secret, passkey: m.passkey, sandbox: m.is_sandbox
        };
      }
    } catch(e) {}

    // 2. Fall back to admin global Daraja
    if (!mpesaCreds) {
      try {
        const admin = await query(
          'SELECT * FROM mpesa_configs WHERE is_admin_config=true AND is_active=true LIMIT 1'
        );
        if (admin.rows[0] && admin.rows[0].consumer_key) {
          const m = admin.rows[0];
          mpesaCreds = {
            shortcode: m.shortcode, consumer_key: m.consumer_key,
            consumer_secret: m.consumer_secret, passkey: m.passkey, sandbox: m.is_sandbox
          };
          usedAdminCreds = true;
        }
      } catch(e) {}
    }

    // 3. Last resort: process.env
    if (!mpesaCreds) {
      mpesaCreds = {
        shortcode: process.env.MPESA_SHORTCODE,
        consumer_key: process.env.MPESA_CONSUMER_KEY,
        consumer_secret: process.env.MPESA_CONSUMER_SECRET,
        passkey: process.env.MPESA_PASSKEY,
        sandbox: process.env.MPESA_ENVIRONMENT !== 'production'
      };
      usedAdminCreds = true;
    }

    if (!mpesaCreds.consumer_key || !mpesaCreds.consumer_secret || !mpesaCreds.shortcode || !mpesaCreds.passkey) {
      return res.status(400).json({ error: 'M-Pesa not configured. Contact the ISP or platform admin.' });
    }

    const commRate = await effectiveHotspotRate(ispData.commission_rate);
    const commAmount = amount * commRate;
    const netAmount = amount; /* RL_NET_FEE_ONLY_ALL: ISP's own gateway (Jenga/Daraja) — no IntaSend fee to deduct; commAmount recorded for the MONTHLY platform invoice, never deducted per-payment (was double-charging). */

    // Create payment record
    const payment = await query(
      `INSERT INTO payments
         (isp_id, amount, payment_method, payment_gateway, phone_number,
          commission_rate, commission_amount, net_amount, description, status, used_admin_credentials)
       VALUES ($1::uuid, $2::decimal, 'mpesa', 'mpesa_stk', $3,
               $4::decimal, $5::decimal, $6::decimal, $7, 'pending', $8::boolean)
       RETURNING id`,
      [req.params.ispId, amount, normalizedPhone, commRate, commAmount, netAmount,
       `Hotspot - ${pkg.rows[0].name}`, usedAdminCreds]
    );
    const paymentId = payment.rows[0].id;

    // ── Send STK Push ─────────────────────────────────────────
    const baseUrl = mpesaCreds.sandbox ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';

    let accessToken;
    try {
      const tokRes = await axios.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, {
        headers: { Authorization: `Basic ${Buffer.from(`${mpesaCreds.consumer_key}:${mpesaCreds.consumer_secret}`).toString('base64')}` },
        timeout: 10000
      });
      accessToken = tokRes.data.access_token;
    } catch (tokenErr) {
      const errMsg = (tokenErr.response?.data?.errorMessage || tokenErr.message).substring(0, 240);
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid", [errMsg, paymentId]).catch(()=>{});
      return res.status(502).json({ error: 'M-Pesa auth failed: ' + errMsg });
    }

    const timestamp = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
    const password = Buffer.from(`${mpesaCreds.shortcode}${mpesaCreds.passkey}${timestamp}`).toString('base64');

    let stkRes;
    try {
      stkRes = await axios.post(`${baseUrl}/mpesa/stkpush/v1/processrequest`, {
        BusinessShortCode: mpesaCreds.shortcode,
        Password: password,
        Timestamp: timestamp,
        TransactionType: 'CustomerPayBillOnline',
        Amount: Math.ceil(amount),
        PartyA: normalizedPhone,
        PartyB: mpesaCreds.shortcode,
        PhoneNumber: normalizedPhone,
        CallBackURL: `${process.env.BASE_URL}/api/captive/${req.params.ispId}/callback/${paymentId}`,
        AccountReference: paymentId.substring(0, 12),
        TransactionDesc: `WiFi - ${pkg.rows[0].name}`.substring(0, 13)
      }, { headers: { Authorization: `Bearer ${accessToken}` }, timeout: 15000 });
    } catch (stkErr) {
      const errMsg = (stkErr.response?.data?.errorMessage || stkErr.response?.data?.ResponseDescription || stkErr.message).substring(0, 240);
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid", [errMsg, paymentId]).catch(()=>{});
      logger.error('Captive STK push error:', errMsg);
      return res.status(502).json({ error: 'M-Pesa STK push failed: ' + errMsg });
    }

    // Track in mpesa_transactions
    await query(
      `INSERT INTO mpesa_transactions
         (isp_id, payment_id, checkout_request_id, merchant_request_id, amount, phone, status)
       VALUES ($1::uuid, $2::uuid, $3, $4, $5::decimal, $6, 'pending')`,
      [req.params.ispId, paymentId, stkRes.data.CheckoutRequestID, stkRes.data.MerchantRequestID, amount, normalizedPhone]
    ).catch(()=>{});

    // Reserve voucher for after-payment confirmation
    try {
      // ALWAYS reuse existing voucher for same (isp, phone) regardless of status.
      // This ensures one phone = one username forever. Multiple purchases extend expiry.
      let code, voucherId;
      try {
        // ONLY match captive-origin vouchers (those that were ever linked to a payment).
        // This prevents reusing manually-generated batch vouchers.
        const existing = await query(
          `SELECT code, id FROM hotspot_vouchers
           WHERE isp_id=$1::uuid AND buyer_phone=$2 AND payment_id IS NOT NULL
           ORDER BY created_at ASC LIMIT 1`,
          [req.params.ispId, normalizedPhone]
        );
        if (existing.rows[0]) {
          voucherId = existing.rows[0].id;
          const oldCode = existing.rows[0].code;

          // If existing code doesn't look like a K-code (single letter + digits),
          // upgrade it to a proper K-username. This handles legacy hex codes that
          // were generated before the K-naming was in place.
          const ispRes = await query('SELECT company_name FROM isps WHERE id=$1::uuid', [req.params.ispId]);
          const firstLetter = ((ispRes.rows[0] && ispRes.rows[0].company_name) || 'K').trim().charAt(0).toUpperCase() || 'K';
          const kPattern = new RegExp('^' + firstLetter + '\\d+$');

          if (!kPattern.test(oldCode)) {
            code = await generateIspUsername(req.params.ispId);
            logger.info(`[CAPTIVE] UPGRADING voucher code ${oldCode} -> ${code} for phone ${normalizedPhone}`);
            await query(
              `UPDATE hotspot_vouchers
                 SET code=$5, payment_id=$1::uuid, package_id=$2::uuid,
                     used_by_mac=COALESCE($4, used_by_mac), updated_at=NOW()
               WHERE id=$3::uuid`,
              [paymentId, package_id, voucherId, mac || null, code]
            );
            // Schedule removal of old code from router (idempotent fire-and-forget)
            try {
              const nasRes = await query(
                `SELECT id FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL ORDER BY last_seen DESC NULLS LAST LIMIT 1`,
                [req.params.ispId]
              );
              if (nasRes.rows[0]) {
                const mt = require('../utils/mikrotik');
                mt.removeHotspotUser(nasRes.rows[0].id, oldCode).catch(() => {});
              }
            } catch (e) { /* swallow */ }
          } else {
            code = oldCode;
            await query(
              `UPDATE hotspot_vouchers
                 SET payment_id=$1::uuid, package_id=$2::uuid,
                     used_by_mac=COALESCE($4, used_by_mac), updated_at=NOW()
               WHERE id=$3::uuid`,
              [paymentId, package_id, voucherId, mac || null]
            );
          }
          logger.info(`Captive: REUSING voucher ${code} for phone ${normalizedPhone}`);
        } else {
          // First-ever purchase from this phone -> generate fresh K-username
          code = await generateIspUsername(req.params.ispId);
          const v = await query(
            `INSERT INTO hotspot_vouchers
               (isp_id, package_id, code, status, buyer_phone, payment_id, used_by_mac)
             VALUES ($1::uuid, $2::uuid, $3, 'unused', $4, $5::uuid, $6)
             RETURNING id`,
            [req.params.ispId, package_id, code, normalizedPhone, paymentId, mac || null]
          );
          voucherId = v.rows[0].id;
          logger.info(`Captive: NEW voucher ${code} for phone ${normalizedPhone} mac=${mac||'-'}`);
        }
      } catch (dupErr) {
        logger.error('Voucher creation:', dupErr.message);
        code = await generateIspUsername(req.params.ispId);
        const v = await query(
          `INSERT INTO hotspot_vouchers
             (isp_id, package_id, code, status, buyer_phone, payment_id, used_by_mac)
           VALUES ($1::uuid, $2::uuid, $3, 'unused', $4, $5::uuid, $6) RETURNING id`,
          [req.params.ispId, package_id, code, normalizedPhone, paymentId, mac || null]
        );
        voucherId = v.rows[0].id;
      }
    } catch (e) {
      // Try without payment_id column
      try {
        await query(
          `INSERT INTO hotspot_vouchers (isp_id, package_id, code, status, buyer_phone)
           VALUES ($1::uuid, $2::uuid, $3, 'unused', $4)`,
          [req.params.ispId, package_id, await generateIspUsername(req.params.ispId), normalizedPhone]
        );
      } catch (e2) { logger.warn('Voucher pre-create:', e2.message); }
    }

    res.json({
      success: true,
      payment_id: paymentId,
      amount: amount,
      checkout_request_id: stkRes.data.CheckoutRequestID,
      message: `M-Pesa prompt sent to ${normalizedPhone}.`
    });

  } catch (err) {
    logger.error('Captive pay error:', err.message);
    logger.error(err.stack);
    res.status(500).json({ error: 'Internal error: ' + err.message });
  }
});

// ── PAYMENT STATUS POLL (for spinner) ─────────────────────────
router.get('/:ispId/payment-status/:paymentId', async (req, res) => {
  try {
    let r = await query(
      `SELECT id, status, transaction_id, amount, failure_reason, payment_gateway, metadata
       FROM payments WHERE id=$1::uuid AND isp_id=$2::uuid`,
      [req.params.paymentId, req.params.ispId]
    );
    if (!r.rows[0]) return res.status(404).json({ status: 'not_found' });
    // RL_POLL_SELFHEAL: confirm with IntaSend if still pending, then activate the voucher.
    if (r.rows[0].status === 'pending') {
      const ns = await rlConfirmWithIntasend(r.rows[0]);
      if (ns === 'paid') {
        try {
          const vv = await query("SELECT id FROM hotspot_vouchers WHERE isp_id=$1::uuid AND payment_id=$2::uuid ORDER BY created_at DESC LIMIT 1", [req.params.ispId, req.params.paymentId]);
          if (vv.rows[0]) await syncRadiusForVoucher(vv.rows[0].id).catch(()=>{});
        } catch(e) {}
      }
      if (ns !== r.rows[0].status) { r = await query(`SELECT id, status, transaction_id, amount, failure_reason FROM payments WHERE id=$1::uuid AND isp_id=$2::uuid`, [req.params.paymentId, req.params.ispId]); }
    }

    // If paid, fetch the voucher code
    let voucher_code = null;
    if (r.rows[0].status === 'paid') {
      try {
        const v = await query(
          `SELECT code FROM hotspot_vouchers
           WHERE isp_id=$1::uuid AND (payment_id=$2::uuid OR buyer_phone IS NOT NULL)
           ORDER BY created_at DESC LIMIT 1`,
          [req.params.ispId, req.params.paymentId]
        );
        if (v.rows[0]) voucher_code = v.rows[0].code;
      } catch(e) {
        const v = await query(
          `SELECT code FROM hotspot_vouchers
           WHERE isp_id=$1::uuid ORDER BY created_at DESC LIMIT 1`,
          [req.params.ispId]
        );
        if (v.rows[0]) voucher_code = v.rows[0].code;
      }
    }

    res.json({
      payment_id: r.rows[0].id,
      status: r.rows[0].status,
      transaction_id: r.rows[0].transaction_id,
      amount: r.rows[0].amount,
      failure_reason: r.rows[0].failure_reason,
      voucher_code
    });
  } catch (err) {
    res.json({ status: 'pending' });
  }
});

// ── M-Pesa CALLBACK ───────────────────────────────────────────
router.post('/:ispId/callback/:paymentId', async (req, res) => {
  try {
    const cb = req.body?.Body?.stkCallback;
    logger.info(`[CB-START] paymentId=${req.params.paymentId} result=${cb?.ResultCode}`);
    if (cb && cb.ResultCode === 0) {
      const items = cb.CallbackMetadata?.Item || [];
      const g = n => items.find(x => x.Name === n)?.Value;
      const receipt = g('MpesaReceiptNumber');
      const amt = g('Amount');

      const payerPhone = g('PhoneNumber');
      const payerAmount = g('Amount');
      await query("UPDATE payments SET status='paid', transaction_id=$1, paid_at=NOW(), mpesa_phone=$2::varchar, mpesa_amount=$3::decimal WHERE id=$4::uuid",
        [receipt, payerPhone ? String(payerPhone) : null, payerAmount || null, req.params.paymentId]);
      await query("UPDATE mpesa_transactions SET status='completed', mpesa_receipt=$1, transaction_date=NOW() WHERE payment_id=$2::uuid",
        [receipt, req.params.paymentId]).catch(()=>{});

      // Activate the voucher: extend expiry by package duration + push to router
      try {
        // Calculate new expiry: existing expires_at + package duration_hours (or NOW() + duration if expired/null)
        const expRes = await query(`
          UPDATE hotspot_vouchers v
          SET status = 'active', /* RL_PURCHASE_EXPIRY: paid => active immediately */
              /* RL_ACTIVATE_IDEMPOTENT: expiry = payment paid_at + duration (deterministic; re-scan safe) */
              expires_at = COALESCE((SELECT paid_at FROM payments WHERE id = v.payment_id), NOW()) + COALESCE((SELECT (duration_hours || ' hours')::interval FROM hotspot_packages WHERE id = v.package_id), interval '24 hours'),
              updated_at = NOW()
          WHERE payment_id=$1::uuid
          RETURNING id, code, isp_id, expires_at, package_id, buyer_phone, used_by_mac`,
          [req.params.paymentId]);

        const voucher = expRes.rows[0];
        if (voucher) {
          logger.info(`Voucher ${voucher.code} activated. New expiry: ${voucher.expires_at}`);
          await syncRadiusForVoucher(voucher.id).catch(()=>{});
          logger.info(`[CB-VOUCHER] code=${voucher.code} mac=${voucher.used_by_mac || '(none)'} package=${voucher.package_id} isp=${voucher.isp_id}`);

          // ─── CB-QUEUE-APPLY v54: apply queue to router NOW for this voucher's MAC ───
          // The user may auto-reconnect via MAC cookie, bypassing /manual-login.
          // To guarantee the queue gets created with the new package's rate, we apply
          // it here directly from the callback. If MAC is on active session, queue
          // attaches to that session's IP. If not, we wait for /manual-login to apply.
          try {
            const targetMac = voucher.used_by_mac;
            if (targetMac) {
              const nasRes = await query(
                `SELECT id, wireguard_ip, mikrotik_api_user, mikrotik_api_password
                 FROM nas_devices WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL
                 ORDER BY last_seen DESC NULLS LAST LIMIT 1`,
                [voucher.isp_id]
              );
              if (nasRes.rows[0]) {
                const { id: nasId, wireguard_ip, mikrotik_api_user, mikrotik_api_password } = nasRes.rows[0];
                const baseURL = `http://${wireguard_ip}/rest`;
                const auth = { username: mikrotik_api_user, password: mikrotik_api_password };
                const axios = require('axios');

                // Get current active sessions and find one matching MAC
                const active = await axios.get(baseURL + '/ip/hotspot/active', { auth, timeout: 5000 });
                let sessionIp = null;
                for (const s of (active.data || [])) {
                  if ((s['mac-address'] || '').toLowerCase() === targetMac.toLowerCase()) {
                    sessionIp = s.address;
                    break;
                  }
                }

                if (sessionIp) {
                  // Read radreply Mikrotik-Rate-Limit for this voucher
                  const rrRow = await query(
                    `SELECT value FROM radreply WHERE username = $1 AND attribute = 'Mikrotik-Rate-Limit' LIMIT 1`, [radiusUsername(voucher.code, voucher.isp_id || req.params.ispId)]
                  );
                  const rate = rrRow.rows[0]?.value;
                  if (rate && rate !== '0M/0M') {
                    // Apply queue (mt.applyQueueRateLimit handles cleanup of stale queues on same IP)
                    const result = await mt.applyQueueRateLimit(nasId, {
                      username: voucher.code, ip: sessionIp, max_limit: rate
                    });
                    logger.info(`[CB-QUEUE-APPLY] applied rate=${rate} for ${voucher.code} on ${sessionIp} result=${JSON.stringify(result)}`);
                  } else {
                    logger.info(`[CB-QUEUE-APPLY] no rate for ${voucher.code} in radreply`);
                  }
                } else {
                  logger.info(`[CB-QUEUE-APPLY] MAC ${targetMac} not on active sessions yet — queue will apply on next login`);
                  // CB-QUEUE-RETRY-POLL: try again every 5s for up to 60s
                  // to catch the user reconnecting shortly after payment
                  const pollDeviceId = nasId;
                  const pollVoucherCode = voucher.code;
                  const pollTargetMac = targetMac;
                  const pollBaseURL = baseURL;
                  const pollAuth = auth;
                  let pollAttempts = 0;
                  const maxPollAttempts = 12; // 12 * 5s = 60s
                  const pollFn = async () => {
                    pollAttempts++;
                    try {
                      const ar = await axios.get(pollBaseURL + '/ip/hotspot/active', { auth: pollAuth, timeout: 5000 });
                      let foundIp = null;
                      for (const s of (ar.data || [])) {
                        if ((s['mac-address'] || '').toLowerCase() === pollTargetMac.toLowerCase()) {
                          foundIp = s.address; break;
                        }
                      }
                      if (foundIp) {
                        const rrR = await query(`SELECT value FROM radreply WHERE username = $1 AND attribute = 'Mikrotik-Rate-Limit' LIMIT 1`, [radiusUsername(pollVoucherCode, voucher.isp_id || req.params.ispId)]);
                        const rate2 = rrR.rows[0]?.value;
                        if (rate2 && rate2 !== '0M/0M') {
                          const r = await mt.applyQueueRateLimit(pollDeviceId, { username: pollVoucherCode, ip: foundIp, max_limit: rate2 });
                          logger.info(`[CB-QUEUE-RETRY-POLL] applied ${rate2} for ${pollVoucherCode} on ${foundIp} attempt=${pollAttempts}: ${JSON.stringify(r)}`);
                        }
                        return; // done
                      }
                      if (pollAttempts < maxPollAttempts) setTimeout(pollFn, 5000);
                      else logger.info(`[CB-QUEUE-RETRY-POLL] gave up after ${pollAttempts} attempts for ${pollVoucherCode}`);
                    } catch(e) {
                      if (pollAttempts < maxPollAttempts) setTimeout(pollFn, 5000);
                    }
                  };
                  setTimeout(pollFn, 5000);
                }
              }
            }
          } catch (qErr) { logger.warn(`[CB-QUEUE-APPLY] failed: ${qErr.message}`); }
        

          // PUSH USER TO ROUTER via REST API (Phase C-1)
          try {
            const mt = require('../utils/mikrotik');
            // Find the NAS device for this ISP that has a WG tunnel up
            const nasRes = await query(
              `SELECT id, name, wireguard_ip FROM nas_devices
               WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL
               ORDER BY last_seen DESC NULLS LAST LIMIT 1`,
              [voucher.isp_id]
            );
            if (nasRes.rows[0]) {
              const nasId = nasRes.rows[0].id;
              // Get package profile name (or default)
              const pkgRes = await query(
                `SELECT name FROM hotspot_packages WHERE id = $1::uuid`,
                [voucher.package_id]
              );
              const profileName = 'default'; // TODO: map package->router profile name once we set those up
              // Remove any prior version of this user on the router (idempotent)
              await mt.removeHotspotUser(nasId, voucher.code).catch(()=>{});
              // Calculate limit-uptime from voucher expiry
              let limitUptime = null;
              if (voucher.expires_at) {
                const seconds = Math.max(0, Math.floor((new Date(voucher.expires_at).getTime() - Date.now()) / 1000));
                if (seconds > 0) {
                  const d = Math.floor(seconds / 86400), h = Math.floor((seconds % 86400) / 3600), m = Math.floor((seconds % 3600) / 60);
                  limitUptime = (d ? d + 'd' : '') + (h ? h + 'h' : '') + (m ? m + 'm' : '');
                }
              }

              // Fetch package details for rate limits + data caps
              const pkgFull = await query(
                `SELECT name, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb,
                        mikrotik_profile, simultaneous_sessions
                 FROM hotspot_packages WHERE id = $1::uuid`,
                [voucher.package_id]
              );
              const pkg = pkgFull.rows[0] || {};

              // Build rate limit string: e.g. "5M/10M" (up/down)
              let rateLimit = null;
              if (pkg.bandwidth_up_mbps || pkg.bandwidth_down_mbps) {
                const up = pkg.bandwidth_up_mbps ? pkg.bandwidth_up_mbps + 'M' : '0';
                const down = pkg.bandwidth_down_mbps ? pkg.bandwidth_down_mbps + 'M' : '0';
                rateLimit = up + '/' + down;
              }

              // Build limit-bytes-total in bytes (MB * 1024 * 1024)
              let limitBytesTotal = null;
              if (pkg.data_limit_mb && pkg.data_limit_mb > 0) {
                limitBytesTotal = String(pkg.data_limit_mb * 1024 * 1024);
              }

              const addResult = RL_RADIUS_NATIVE ? { ok: true, skipped: true } : await mt.addHotspotUser(nasId, {
                name: voucher.code,
                password: voucher.code,
                mac_address: null,  // do NOT bind to MAC - allow voucher reuse from any device
                limit_uptime: limitUptime,
                rate_limit: rateLimit,
                limit_bytes_total: limitBytesTotal,
                comment: 'RumaLink:' + (pkg.name || 'package')
                // server auto-detected, profile uses RouterOS default
              });
              if (addResult.ok) {
                logger.info(`[CAPTIVE] Pushed ${voucher.code} to ${nasRes.rows[0].name} via REST (server=${addResult.server})`);
              } else {
                logger.error(`[CAPTIVE] FAILED to push ${voucher.code} to router: ${addResult.error || addResult.status}. Details: ${JSON.stringify(addResult.details || {})}`);
              }
            } else {
              logger.warn(`No router with WG tunnel for ISP ${voucher.isp_id} - voucher exists in DB but not on router`);
            }
          } catch (mtErr) {
            logger.error('Router push failed:', mtErr.message);
            // Don't fail the callback — voucher is still good in DB
          }
        }
      } catch(e) { logger.warn('Voucher activate:', e.message); }
      try {
      } catch(e) {}

      // Send SMS with the voucher
      try {
        const v = await query(
          `SELECT hv.code, hv.buyer_phone, hv.password, hv.expires_at, hp.name FROM hotspot_vouchers hv /* RL_SYNC2_FIX */
           JOIN hotspot_packages hp ON hp.id=hv.package_id
           WHERE hv.isp_id=$1::uuid ORDER BY hv.created_at DESC LIMIT 1`,
          [req.params.ispId]);
        if (v.rows[0] && v.rows[0].buyer_phone) {
          const ispInfo = await query("SELECT * FROM isps WHERE id=$1::uuid", [req.params.ispId]);
          sendSMS({
            to: v.rows[0].buyer_phone,
            message: `Your ${v.rows[0].name} voucher: ${v.rows[0].code}. Receipt: ${receipt}\nValid until: ${v.rows[0].expires_at ? new Date(v.rows[0].expires_at).toLocaleString('en-KE', { timeZone: 'Africa/Nairobi', day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'N/A'}\nReconnect if dropped: user ${v.rows[0].code} pass ${v.rows[0].password || v.rows[0].code}`, /* RL_SYNC2_FIX */
            isp: ispInfo.rows[0]
          }).catch(()=>{});
        }
      } catch(e){}
    } else if (cb) {
      await query("UPDATE payments SET status='failed', failure_reason=$1 WHERE id=$2::uuid",
        [(cb.ResultDesc || 'Cancelled').substring(0, 240), req.params.paymentId]);
    }
  } catch (e) {
    logger.error('Captive callback:', e.message);
  }
  res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
});



// Internal endpoint: activate voucher + push to router for a given payment.
// Called from payments.js when STK Query self-heal finds a paid payment that
// the callback never processed.
router.post('/:ispId/activate-payment/:paymentId', async (req, res) => {
  try {
    logger.info(`[MANUAL-ACTIVATE] Activating voucher for payment ${req.params.paymentId}`);
      await syncRadiusForVoucher(voucher.id).catch(()=>{});

    const expRes = await query(`
      UPDATE hotspot_vouchers v
      SET status = 'active', /* RL_PURCHASE_EXPIRY: paid => active immediately */
          /* RL_ACTIVATE_IDEMPOTENT: expiry = payment paid_at + duration (deterministic; re-scan safe) */
          expires_at = COALESCE((SELECT paid_at FROM payments WHERE id = v.payment_id), NOW()) + COALESCE((SELECT (duration_hours || ' hours')::interval FROM hotspot_packages WHERE id = v.package_id), interval '24 hours'),
          updated_at = NOW()
      WHERE payment_id=$1::uuid
      RETURNING id, code, isp_id, expires_at, package_id, buyer_phone, used_by_mac`,
      [req.params.paymentId]);

    const voucher = expRes.rows[0];
    if (!voucher) {
      logger.warn(`[MANUAL-ACTIVATE] No voucher linked to payment ${req.params.paymentId}`);
      return res.json({ ok: false, error: 'No voucher for payment' });
    }
    logger.info(`[MANUAL-ACTIVATE] Voucher ${voucher.code} activated. Expiry: ${voucher.expires_at}`);
      await syncRadiusForVoucher(voucher.id).catch(()=>{});

    // Push to router via REST
    try {
      const mt = require('../utils/mikrotik');
      const nasRes = await query(
        `SELECT id, name FROM nas_devices
         WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL
         ORDER BY last_seen DESC NULLS LAST LIMIT 1`, [voucher.isp_id]);
      if (!nasRes.rows[0]) {
        logger.warn(`[MANUAL-ACTIVATE] No router with WG for ISP ${voucher.isp_id}`);
        return res.json({ ok: true, voucher_code: voucher.code, pushed: false, reason: 'No router with WG' });
      }
      const nasId = nasRes.rows[0].id;

      let limitUptime = null;
      if (voucher.expires_at) {
        const seconds = Math.max(0, Math.floor((new Date(voucher.expires_at).getTime() - Date.now()) / 1000));
        if (seconds > 0) {
          const d = Math.floor(seconds/86400), h = Math.floor((seconds%86400)/3600), m = Math.floor((seconds%3600)/60);
          limitUptime = (d?d+'d':'') + (h?h+'h':'') + (m?m+'m':'');
        }
      }
      const pkgFull = await query(
        `SELECT name, bandwidth_down_mbps, bandwidth_up_mbps, data_limit_mb FROM hotspot_packages WHERE id = $1::uuid`,
        [voucher.package_id]);
      const pkg = pkgFull.rows[0] || {};
      let rateLimit = null;
      if (pkg.bandwidth_up_mbps || pkg.bandwidth_down_mbps) {
        rateLimit = (pkg.bandwidth_up_mbps ? pkg.bandwidth_up_mbps + 'M' : '0') + '/' + (pkg.bandwidth_down_mbps ? pkg.bandwidth_down_mbps + 'M' : '0');
      }
      let limitBytesTotal = null;
      if (pkg.data_limit_mb && pkg.data_limit_mb > 0) limitBytesTotal = String(pkg.data_limit_mb * 1024 * 1024);

      await mt.removeHotspotUser(nasId, voucher.code).catch(()=>{});
      const addResult = RL_RADIUS_NATIVE ? { ok: true, skipped: true } : await mt.addHotspotUser(nasId, {
        name: voucher.code, password: voucher.code,
        mac_address: null,  // do NOT bind to MAC - allow voucher reuse from any device
        limit_uptime: limitUptime, rate_limit: rateLimit,
        limit_bytes_total: limitBytesTotal,
        comment: 'RumaLink:' + (pkg.name || 'package')
      });
      if (addResult.ok) {
        logger.info(`[MANUAL-ACTIVATE] Pushed ${voucher.code} to ${nasRes.rows[0].name} via REST (server=${addResult.server})`);
      await syncRadiusForVoucher(voucher.id).catch(()=>{});

        // ─── MA-QUEUE-APPLY v54: apply queue from /activate-payment if MAC has active session ───
        try {
          const targetMac = voucher.used_by_mac;
          if (targetMac) {
            const axios = require('axios');
            const nasRow = await query(
              `SELECT id, wireguard_ip, mikrotik_api_user, mikrotik_api_password
               FROM nas_devices WHERE id = $1::uuid LIMIT 1`,
              [nasRes.rows[0].id]
            );
            if (nasRow.rows[0]) {
              const baseURL = `http://${nasRow.rows[0].wireguard_ip}/rest`;
              const auth = { username: nasRow.rows[0].mikrotik_api_user, password: nasRow.rows[0].mikrotik_api_password };
              const active = await axios.get(baseURL + '/ip/hotspot/active', { auth, timeout: 5000 });
              let sessionIp = null;
              for (const s of (active.data || [])) {
                if ((s['mac-address'] || '').toLowerCase() === targetMac.toLowerCase()) {
                  sessionIp = s.address;
                  break;
                }
              }
              if (sessionIp) {
                const rrRow = await query(`SELECT value FROM radreply WHERE username = $1 AND attribute = 'Mikrotik-Rate-Limit' LIMIT 1`, [radiusUsername(voucher.code, voucher.isp_id || req.params.ispId)]);
                const rate = rrRow.rows[0]?.value;
                if (rate && rate !== '0M/0M') {
                  const result = await mt.applyQueueRateLimit(nasRes.rows[0].id, { username: voucher.code, ip: sessionIp, max_limit: rate });
                  logger.info(`[MA-QUEUE-APPLY] applied rate=${rate} for ${voucher.code} on ${sessionIp}: ${JSON.stringify(result)}`);
                }
              } else {
                logger.info(`[MA-QUEUE-APPLY] MAC ${targetMac} not yet on active sessions`);
              }
            }
          }
        } catch(qErr) { logger.warn(`[MA-QUEUE-APPLY] failed: ${qErr.message}`); }

        return res.json({ ok: true, voucher_code: voucher.code, pushed: true, server: addResult.server });
      } else {
        logger.error(`[MANUAL-ACTIVATE] Push FAILED for ${voucher.code}: ${addResult.error}`);
        return res.json({ ok: true, voucher_code: voucher.code, pushed: false, error: addResult.error });
      }
    } catch (mtErr) {
      logger.error('[MANUAL-ACTIVATE] Router push exception:', mtErr.message);
      return res.json({ ok: true, voucher_code: voucher.code, pushed: false, error: mtErr.message });
    }
  } catch (err) {
    logger.error('[MANUAL-ACTIVATE] error:', err.message);
    res.status(500).json({ error: err.message });
  }
});




// ─── RADIUS sync helpers — keep radcheck/radreply in lockstep with vouchers ───
async function syncRadiusForVoucher(voucherId) {
  try {
    const v = await query(
      `SELECT v.code, v.expires_at, v.payment_id, v.password, v.isp_id, hp.bandwidth_up_mbps, hp.bandwidth_down_mbps /* RL_SYNC2_FIX */
       FROM hotspot_vouchers v
       LEFT JOIN hotspot_packages hp ON hp.id = v.package_id
       WHERE v.id = $1::uuid LIMIT 1`,
      [voucherId]
    );
    if (!v.rows[0]) return;
    const r = v.rows[0];
    if (!r.payment_id) return; // only sync captive-paid vouchers

    // Clear any stale entries for this code
    await query(`DELETE FROM radcheck WHERE username = $1`, [radiusUsername(r.code, r.isp_id)]);
    await query(`DELETE FROM radreply WHERE username = $1`, [radiusUsername(r.code, r.isp_id)]);

    // Skip if expired
    if (r.expires_at && new Date(r.expires_at) <= new Date()) return;

    // RL_SYNC2_FIX: Cleartext-Password = REAL voucher password, at realmed username
    await query(
      `INSERT INTO radcheck (username, attribute, op, value)
       VALUES ($1, 'Cleartext-Password', ':=', $2)`,
      [radiusUsername(r.code, r.isp_id), r.password || r.code]
    );

    // Session-Timeout from expires_at
    if (r.expires_at) {
      const seconds = Math.max(60, Math.floor((new Date(r.expires_at).getTime() - Date.now()) / 1000));
      await query(
        `INSERT INTO radreply (username, attribute, op, value)
         VALUES ($1, 'Session-Timeout', ':=', $2)`,
        [radiusUsername(r.code, r.isp_id), String(seconds)]
      );
    }

    // Mikrotik-Rate-Limit from package
    if (r.bandwidth_up_mbps != null || r.bandwidth_down_mbps != null) {
      const rate = (r.bandwidth_up_mbps || 0) + 'M/' + (r.bandwidth_down_mbps || 0) + 'M';
      await query(
        `INSERT INTO radreply (username, attribute, op, value)
         VALUES ($1, 'Mikrotik-Rate-Limit', ':=', $2)`,
        [radiusUsername(r.code, r.isp_id), rate]
      );
    }
    logger.info(`[RADIUS-SYNC] voucher ${r.code} synced (expires=${r.expires_at})`);
  } catch (e) {
    logger.error(`[RADIUS-SYNC] failed for voucher ${voucherId}: ${e.message}`);
  }
}

async function clearRadiusForCode(code) {
  try {
    await query(`DELETE FROM radcheck WHERE username = $1`, [code]);
    await query(`DELETE FROM radreply WHERE username = $1`, [code]);
    logger.info(`[RADIUS-SYNC] cleared ${code}`);
  } catch (e) {
    logger.error(`[RADIUS-SYNC] clear failed for ${code}: ${e.message}`);
  }
}

// ─── MANUAL LOGIN (Already Paid?) ────────────────────────────────────────
// User clicks "Already Paid? Login" on captive. They paste their voucher code.
// We validate the voucher server-side (paid, not expired) then ask MikroTik to
// CREATE the hotspot active session via REST. This bypasses the stale-loginurl
// problem of submitting an HTML form to MikroTik.
// ─── VALIDATE VOUCHER (pre-form-POST sanity check) ──────────────────────────
// Captive v9 calls this BEFORE submitting the form to MikroTik, so we can
// give a clean error UX for invalid/expired vouchers. Actual auth still
// happens via MikroTik → RADIUS when the form posts.
router.post('/:ispId/validate-voucher', async (req, res) => {
  try {
    const { code } = req.body;
    if (!code) return res.status(400).json({ ok: false, error: 'Voucher code required' });
    const norm = String(code).trim().toUpperCase();
    const v = await query(
      `SELECT v.code, v.expires_at, v.payment_id, v.password FROM hotspot_vouchers v
       WHERE v.isp_id = $1::uuid AND UPPER(v.code) = $2 LIMIT 1`,
      [req.params.ispId, norm]
    );
    if (!v.rows[0]) return res.status(404).json({ ok: false, error: 'Voucher not found' });
    const voucher = v.rows[0];
    if (!voucher.payment_id) return res.status(403).json({ ok: false, error: 'Voucher has no payment' });
    if (voucher.expires_at && new Date(voucher.expires_at) < new Date()) {
      return res.status(410).json({ ok: false, error: 'Voucher expired' });
    }
    {
      const ispShort = String(req.params.ispId).replace(/-/g, '').slice(0, 8).toLowerCase();
      const radiusUsername = voucher.code + '@' + ispShort;
      const radiusPassword = voucher.password || voucher.code;
      return res.json({ ok: true, voucher_code: voucher.code, radius_username: radiusUsername }); /* RL_PAY_AUTHZ: password no longer exposed here */
    }
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});


// ═══ RADIUS-HYBRID MANUAL LOGIN — v47 ═══
// Backend acts as RADIUS client. Sends Access-Request to local FreeRADIUS,
// reads Mikrotik-Rate-Limit attribute from Access-Accept, then creates the
// hotspot session via REST AND applies the rate limit via /queue/simple.
router.post('/:ispId/manual-login', async (req, res) => {
  try {
    const { code, mac, ip } = req.body;
    if (!code) return res.status(400).json({ ok: false, error: 'Voucher code required' });
    if (!ip) return res.status(400).json({ ok: false, error: 'IP required' });

    const norm = String(code).trim().toUpperCase();

    // 1. Validate voucher in DB
    const v = await query(
      `SELECT v.id, v.code, v.expires_at, v.payment_id, v.package_id,
              hp.bandwidth_up_mbps, hp.bandwidth_down_mbps
       FROM hotspot_vouchers v
       LEFT JOIN hotspot_packages hp ON hp.id = v.package_id
       WHERE v.isp_id = $1::uuid AND UPPER(v.code) = $2 LIMIT 1`,
      [req.params.ispId, norm]
    );
    if (!v.rows[0]) return res.status(404).json({ ok: false, error: 'Voucher not found' });
    const voucher = v.rows[0];
    if (!voucher.payment_id) return res.status(403).json({ ok: false, error: 'Voucher has no payment' });
    if (voucher.expires_at && new Date(voucher.expires_at) < new Date()) {
      return res.status(410).json({ ok: false, error: 'Voucher expired' });
    }

    // 2. Get NAS device for this ISP
    const nasRes = await query(
      `SELECT id, wireguard_ip FROM nas_devices
       WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL
       ORDER BY last_seen DESC NULLS LAST LIMIT 1`,
      [req.params.ispId]
    );
    if (!nasRes.rows[0]) return res.status(503).json({ ok: false, error: 'No router available' });
    const nasId = nasRes.rows[0].id;

    // ═══ 2.5 Re-sync radreply for this voucher BEFORE asking RADIUS
    // ensures Mikrotik-Rate-Limit reflects the CURRENT package bandwidth
    try { await syncRadiusForVoucher(voucher.id); } catch(e) { logger.warn(`[RADIUS-HYBRID] pre-sync failed: ${e.message}`); }

    // ═══ 3. RADIUS-HYBRID: ask local FreeRADIUS, get attributes ═══
    let radiusAttrs = {};
    let radiusOk = false;
    try {
      const radiusResult = await mt.radiusAuthVoucher(radiusUsername(voucher.code, req.params.ispId), voucher.code);
      radiusOk = radiusResult.accepted;
      radiusAttrs = radiusResult.attrs || {};
      logger.info(`[RADIUS-HYBRID] voucher=${voucher.code} accepted=${radiusOk} attrs=${JSON.stringify(radiusAttrs)}`);
    } catch (rErr) {
      logger.warn(`[RADIUS-HYBRID] radclient failed: ${rErr.message}`);
    }

    if (!radiusOk) {
      // RADIUS rejected. Optionally fall through to legacy behavior:
      // - For robustness, allow login but log warning
      logger.warn(`[RADIUS-HYBRID] proceeding without RADIUS attrs for ${voucher.code}`);
    }

    // 4. Create hotspot session via REST /ip/hotspot/active/login
    // Before creating session, kick any existing session on this IP/MAC
    // (so the new login isn't rejected with "already logged in")
    try {
      const axios = require('axios');
      const nasRow = await query(
        `SELECT wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE id = $1::uuid LIMIT 1`,
        [nasId]
      );
      if (nasRow.rows[0]) {
        const { wireguard_ip, mikrotik_api_user, mikrotik_api_password } = nasRow.rows[0];
        const baseURL = `http://${wireguard_ip}/rest`;
        const auth = { username: mikrotik_api_user, password: mikrotik_api_password };
        const activeResp = await axios.get(baseURL + '/ip/hotspot/active', { auth, timeout: 5000 });
        for (const s of (activeResp.data || [])) {
          if (s.address === ip || (mac && s['mac-address'] === mac)) {
            try {
              await kickSession(nasId, s, baseURL, auth);
              logger.info(`[MANUAL-LOGIN] kicked existing session ${s.user || '?'} on ${s.address} mac=${s['mac-address']}`);
            } catch(e) { logger.warn(`[MANUAL-LOGIN] kick failed: ${e.message}`); }
          }
        }
      }
    } catch(e) { logger.warn(`[MANUAL-LOGIN] pre-kick check failed: ${e.message}`); }

    const loginResult = await mt.hotspotActiveLogin(nasId, {
      user: voucher.code,
      password: voucher.code,
      ip: ip,
      mac_address: mac || null
    });
    if (!loginResult.ok) {
      return res.status(500).json({ ok: false, error: 'Router login failed', detail: loginResult });
    }
    logger.info(`[MANUAL-LOGIN] session created for ${voucher.code} @ ${ip} mac=${mac || '-'}`);

    // 5. Apply rate limit via /queue/simple using RADIUS attribute (preferred)
    // or package DB fallback
    let appliedRate = null;
    try {
      const radiusRate = radiusAttrs['Mikrotik-Rate-Limit'];
      const dbRate = (voucher.bandwidth_up_mbps || voucher.bandwidth_down_mbps)
        ? (voucher.bandwidth_up_mbps || 0) + 'M/' + (voucher.bandwidth_down_mbps || 0) + 'M'
        : null;
      appliedRate = radiusRate || dbRate;

      if (appliedRate && appliedRate !== '0M/0M') {
        const queueResult = await mt.applyQueueRateLimit(nasId, {
          username: voucher.code,
          ip: ip,
          max_limit: appliedRate
        });
        logger.info(`[QUEUE-RL] rate=${appliedRate} (from ${radiusRate ? 'RADIUS' : 'package'}) result=${JSON.stringify(queueResult)}`);
      } else {
        logger.info(`[QUEUE-RL] no rate limit configured for ${voucher.code}`);
      }
    } catch (qErr) {
      logger.warn(`[QUEUE-RL] failed: ${qErr.message}`);
    }

    // 6. Sync RADIUS tables for future logins (in case state changed)
    try { await syncRadiusForVoucher(voucher.id); } catch(e) {}

    res.json({
      ok: true,
      voucher_code: voucher.code,
      rate_limit: appliedRate,
      radius_authenticated: radiusOk,
      message: 'Connected. Rate limit applied.'
    });
  } catch (err) {
    logger.error(`[MANUAL-LOGIN] error: ${err.message}`);
    res.status(500).json({ ok: false, error: err.message });
  }
});



// ─── TEST ENDPOINT v48: explicitly call the hybrid flow end-to-end ───
// Usage: curl -X POST http://localhost:5000/api/captive/$ISP_ID/test-flow \
//   -H 'Content-Type: application/json' -d '{"code":"K6","ip":"192.168.100.249","mac":"66:87:6A:49:95:DA"}'
// Returns detailed JSON showing each step.
router.post('/:ispId/test-flow', async (req, res) => {
  const result = { steps: [] };
  function step(name, data) {
    logger.info(`[TEST-FLOW] ${name}: ${JSON.stringify(data)}`);
    result.steps.push({ name, ...data });
  }
  try {
    const { code, mac, ip } = req.body;
    if (!code || !ip) {
      return res.status(400).json({ ok: false, error: 'code and ip required', usage: req.body });
    }

    // 1. Validate voucher
    const norm = String(code).trim().toUpperCase();
    const v = await query(
      `SELECT v.id, v.code, v.payment_id, v.expires_at, hp.bandwidth_up_mbps, hp.bandwidth_down_mbps
       FROM hotspot_vouchers v
       LEFT JOIN hotspot_packages hp ON hp.id = v.package_id
       WHERE v.isp_id = $1::uuid AND UPPER(v.code) = $2 LIMIT 1`,
      [req.params.ispId, norm]
    );
    if (!v.rows[0]) {
      step('voucher-lookup', { ok: false, error: 'not found' });
      return res.json({ ok: false, ...result });
    }
    const voucher = v.rows[0];
    step('voucher-lookup', { ok: true, code: voucher.code, has_payment: !!voucher.payment_id, expires_at: voucher.expires_at });

    // 2. Get NAS
    const nasRes = await query(
      `SELECT id, name, wireguard_ip FROM nas_devices
       WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL
       ORDER BY last_seen DESC NULLS LAST LIMIT 1`,
      [req.params.ispId]
    );
    if (!nasRes.rows[0]) {
      step('nas-lookup', { ok: false });
      return res.json({ ok: false, ...result });
    }
    const nas = nasRes.rows[0];
    step('nas-lookup', { ok: true, nas_id: nas.id, name: nas.name, wg_ip: nas.wireguard_ip });

    // 2.5 Re-sync radreply for this voucher (so radclient gets fresh attrs)
    try { await syncRadiusForVoucher(voucher.id); step('radreply-sync', { ok: true }); } catch (e) { step('radreply-sync', { ok: false, error: e.message }); }

    // 3. RADIUS auth via radclient
    let radiusOk = false, radiusAttrs = {};
    try {
      const radResult = await mt.radiusAuthVoucher(radiusUsername(voucher.code, req.params.ispId), voucher.code);
      radiusOk = radResult.accepted;
      radiusAttrs = radResult.attrs || {};
      step('radius-auth', { ok: radiusOk, accepted: radiusOk, attrs: radiusAttrs });
    } catch (e) {
      step('radius-auth', { ok: false, error: e.message });
    }

    // 4. Create hotspot session
    let sessionOk = false;
    try {
      // Pre-kick existing session if any on same IP/MAC
      try {
        const axios = require('axios');
        const nasRow = await query(
          `SELECT wireguard_ip, mikrotik_api_user, mikrotik_api_password FROM nas_devices WHERE id = $1::uuid`,
          [nas.id]
        );
        if (nasRow.rows[0]) {
          const baseURL = `http://${nasRow.rows[0].wireguard_ip}/rest`;
          const auth = { username: nasRow.rows[0].mikrotik_api_user, password: nasRow.rows[0].mikrotik_api_password };
          const activeResp = await axios.get(baseURL + '/ip/hotspot/active', { auth, timeout: 5000 });
          let kicked = 0;
          for (const s of (activeResp.data || [])) {
            if (s.address === ip || (mac && s['mac-address'] === mac)) {
              try { await kickSession(nasId, s, baseURL, auth); kicked++; } catch(e) {}
            }
          }
          if (kicked) step('pre-kick', { ok: true, kicked });
        }
      } catch(e) { step('pre-kick', { ok: false, error: e.message }); }

      const loginResult = await mt.hotspotActiveLogin(nas.id, {
        user: voucher.code, password: voucher.code, ip: ip, mac_address: mac || null
      });
      sessionOk = !!loginResult.ok;
      step('session-create', { ok: sessionOk, response: loginResult });
    } catch (e) {
      step('session-create', { ok: false, error: e.message });
    }

    // 5. Apply queue rate limit
    const radiusRate = radiusAttrs['Mikrotik-Rate-Limit'];
    const dbRate = (voucher.bandwidth_up_mbps || voucher.bandwidth_down_mbps)
      ? (voucher.bandwidth_up_mbps || 0) + 'M/' + (voucher.bandwidth_down_mbps || 0) + 'M'
      : null;
    const rate = radiusRate || dbRate;
    if (rate && rate !== '0M/0M') {
      try {
        if (typeof mt.applyQueueRateLimit !== 'function') {
          step('queue-rl', { ok: false, error: 'mt.applyQueueRateLimit is not a function' });
        } else {
          const queueResult = await mt.applyQueueRateLimit(nas.id, {
            username: voucher.code, ip: ip, max_limit: rate
          });
          step('queue-rl', { ok: !!queueResult.ok, rate: rate, source: radiusRate ? 'RADIUS' : 'package-db', result: queueResult });
        }
      } catch (e) {
        step('queue-rl', { ok: false, error: e.message, stack: e.stack });
      }
    } else {
      step('queue-rl', { ok: false, error: 'no rate limit configured' });
    }

    res.json({ ok: true, ...result });
  } catch (err) {
    step('error', { error: err.message, stack: err.stack });
    res.status(500).json({ ok: false, ...result });
  }
});



// ─── v56: M-Pesa health diagnostic endpoint ───
router.get('/:ispId/mpesa-health', async (req, res) => {
  try {
    const r = await query(`
      SELECT consumer_key, consumer_secret, shortcode, passkey, environment, is_active
      FROM isp_payment_methods
      WHERE isp_id = $1::uuid AND provider = 'mpesa'
      ORDER BY is_default DESC, created_at ASC LIMIT 1
    `, [req.params.ispId]);
    if (!r.rows[0]) return res.json({ ok: false, configured: false });

    const m = r.rows[0];
    const baseUrl = m.environment === 'production'
      ? 'https://api.safaricom.co.ke'
      : 'https://sandbox.safaricom.co.ke';

    const tokenResult = { ok: false };
    try {
      const t = await mpesaService.getAccessToken({
        consumer_key: m.consumer_key,
        consumer_secret: m.consumer_secret,
        shortcode: m.shortcode,
        passkey: m.passkey
      }, baseUrl);
      tokenResult.ok = true;
      tokenResult.token_prefix = t.substring(0, 16) + '...';
    } catch (e) {
      tokenResult.error = e.message;
    }

    res.json({
      ok: true,
      configured: true,
      environment: m.environment,
      shortcode: m.shortcode,
      base_url: baseUrl,
      is_active: m.is_active,
      token: tokenResult
    });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// ── RL_TV_CRUD: saved TVs per ISP (name + MAC). Public portal endpoints, scoped by ispId + phone. ──
function _normMac(m){ return String(m||'').trim().toUpperCase().replace(/[^0-9A-F:]/g,''); }
router.post('/:ispId/tv/save', async (req, res) => {
  try {
    const { name, mac, phone } = req.body;
    const mac2 = _normMac(mac);
    if (!name || !/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/.test(mac2)) return res.status(400).json({ error: 'Valid name and MAC (AA:BB:CC:DD:EE:FF) required' });
    const r = await query(
      "INSERT INTO hotspot_bound_devices (isp_id, name, mac_address, buyer_phone) VALUES ($1::uuid,$2,$3,$4) ON CONFLICT (isp_id, lower(mac_address)) DO UPDATE SET name=EXCLUDED.name, buyer_phone=COALESCE(EXCLUDED.buyer_phone, hotspot_bound_devices.buyer_phone), updated_at=NOW() RETURNING id, name, mac_address",
      [req.params.ispId, String(name).slice(0,60), mac2, phone||null]);
    res.json({ ok:true, tv: r.rows[0] });
  } catch (e) { res.status(500).json({ error: e.message }); }
});
router.get('/:ispId/tv/list', async (req, res) => {
  try {
    const phone = req.query.phone ? String(req.query.phone) : null;
    const base = "SELECT id, name, mac_address, is_bound, expires_at, (expires_at IS NOT NULL AND expires_at > NOW()) AS active FROM hotspot_bound_devices WHERE isp_id=$1::uuid";
    const sql = base + (phone ? " AND buyer_phone=$2" : "") + " ORDER BY name ASC";
    const r = await query(sql, phone ? [req.params.ispId, phone] : [req.params.ispId]);
    res.json({ ok:true, tvs: r.rows });
  } catch (e) { res.status(500).json({ error: e.message }); }
});
router.delete('/:ispId/tv/:id', async (req, res) => {
  try {
    await query("DELETE FROM hotspot_bound_devices WHERE id=$1::uuid AND isp_id=$2::uuid", [req.params.id, req.params.ispId]);
    res.json({ ok:true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
// RL_PAYMENT_SWEEP: the cron sweep reuses this to activate a recovered hotspot voucher.
module.exports.syncRadiusForVoucher = syncRadiusForVoucher;
