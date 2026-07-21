const { radiusUsername } = require('./radius');
const coa = require('./coa');
const cron = require('node-cron');
const { query } = require('../config/database');
const { sendSMS } = require('./sms');
const logger = require('./logger');

// ── Every minute: expire vouchers, close stale sessions, send expiry SMS ──
cron.schedule('* * * * *', async () => {
  try {
    // Find vouchers that just expired (in last 2 mins) and expiry SMS not sent
    const justExpired = await query(`
      SELECT hv.id, hv.code, hv.buyer_phone, hv.isp_id, hp.name as pkg_name,
             i.company_name, i.sms_gateway, i.sms_api_key, i.sms_sender_id
      FROM hotspot_vouchers hv
      JOIN hotspot_packages hp ON hp.id = hv.package_id
      JOIN isps i ON i.id = hv.isp_id
      WHERE hv.status = 'active'
        AND hv.expires_at IS NOT NULL
        AND hv.expires_at < NOW()
        AND hv.expiry_sms_sent = false
        AND hv.buyer_phone IS NOT NULL
    `);

    for (const v of justExpired.rows) {
      try {
        await sendSMS({
          to: v.buyer_phone,
          message: `${v.company_name} WiFi: Your ${v.pkg_name} package has expired. Purchase a new voucher to continue browsing. Thank you!`,
          isp: v
        });
        await query(`UPDATE hotspot_vouchers SET expiry_sms_sent=true WHERE id=$1`, [v.id]);
        logger.info(`Expiry SMS sent to ${v.buyer_phone} for voucher ${v.code}`);
      } catch (smsErr) {
        logger.error(`Expiry SMS failed for ${v.code}:`, smsErr.message);
      }
    }

    // Mark expired
    await query(`
      UPDATE hotspot_vouchers SET status='expired', updated_at=NOW()
      WHERE status='active' AND expires_at IS NOT NULL AND expires_at < NOW()
    `);

    // Close sessions with expired vouchers
    await query(`
      UPDATE hotspot_sessions SET status='expired', ended_at=NOW()
      WHERE status='active' AND voucher_id IN (
        SELECT id FROM hotspot_vouchers WHERE status='expired'
      )
    `);

    // Device offline detection
    await query(`
      UPDATE nas_devices SET is_online=false, updated_at=NOW()
      WHERE is_online=true AND last_seen < NOW() - INTERVAL '5 minutes'
    `);
  } catch (err) {
    logger.error('Cron (1min) error:', err.message);
  }
});

// ── Daily at 8:00 AM: PPPoE billing, reminders, suspensions ──
cron.schedule('0 8 * * *', async () => {
  logger.info('Running daily billing cron...');
  try {
    // 1-day expiry reminder for PPPoE
    const expiringSoon = await query(`
      SELECT ps.*, pp.name as pkg_name, pp.price,
             i.company_name, i.sms_gateway, i.sms_api_key, i.sms_sender_id,
             pm.method_type, pm.till_number, pm.paybill_number, pm.account_number,
             pm.bank_name, pm.account_name, pm.account_reference
      FROM pppoe_subscribers ps
      JOIN pppoe_packages pp ON pp.id = ps.package_id
      JOIN isps i ON i.id = ps.isp_id
      LEFT JOIN isp_payment_methods pm ON pm.isp_id = i.id AND pm.is_default=true AND pm.is_active=true
      WHERE ps.status='active'
        AND ps.next_billing_date = CURRENT_DATE + 1
        AND (ps.expiry_reminder_sent=false OR ps.expiry_reminder_sent IS NULL)
    `);

    for (const sub of expiringSoon.rows) {
      if (sub.phone) {
        const payDetails = buildPaymentDetails(sub);
        try {
          await sendSMS({
            to: sub.phone,
            message: `Dear ${sub.full_name}, your ${sub.company_name} internet (${sub.pkg_name}) expires TOMORROW. Pay KES ${sub.price} to continue.\n${payDetails}`,
            isp: sub
          });
          await query(`UPDATE pppoe_subscribers SET expiry_reminder_sent=true WHERE id=$1`, [sub.id]);
          logger.info(`1-day reminder SMS sent to ${sub.phone}`);
        } catch (e) { logger.error(`Reminder SMS failed ${sub.phone}:`, e.message); }
      }
    }

    // PPPoE billing reminders (3 days before)
    const due = await query(`
      SELECT ps.*, pp.name as pkg_name, pp.price,
             i.company_name, i.sms_gateway, i.sms_api_key, i.sms_sender_id,
             pm.method_type, pm.till_number, pm.paybill_number, pm.account_number,
             pm.bank_name, pm.account_name, pm.account_reference
      FROM pppoe_subscribers ps
      JOIN pppoe_packages pp ON pp.id = ps.package_id
      JOIN isps i ON i.id = ps.isp_id
      LEFT JOIN isp_payment_methods pm ON pm.isp_id = i.id AND pm.is_default=true AND pm.is_active=true
      WHERE ps.status='active' AND ps.next_billing_date = CURRENT_DATE + 3
    `);

    for (const sub of due.rows) {
      // Create invoice
      const existing = await query(
        `SELECT id FROM pppoe_invoices WHERE subscriber_id=$1 AND status='pending'
         AND billing_period_start=DATE_TRUNC('month', NOW())`,
        [sub.id]
      );
      if (!existing.rows[0]) {
        const periodStart = new Date(); periodStart.setDate(1);
        const periodEnd = new Date(periodStart); periodEnd.setMonth(periodEnd.getMonth()+1); periodEnd.setDate(0);
        await query(`
          INSERT INTO pppoe_invoices (isp_id, subscriber_id, package_id, amount, total_amount, billing_period_start, billing_period_end, due_date)
          VALUES ($1,$2,$3,$4,$4,$5,$6,$7)
        `, [sub.isp_id, sub.id, sub.package_id, sub.price, periodStart, periodEnd, sub.next_billing_date]);
      }

      if (sub.phone) {
        const payDetails = buildPaymentDetails(sub);
        try {
          await sendSMS({
            to: sub.phone,
            message: `Dear ${sub.full_name}, your ${sub.company_name} internet (${sub.pkg_name}) of KES ${sub.price} is due on ${new Date(sub.next_billing_date).toLocaleDateString('en-KE')}. Pay to avoid disconnection.\n${payDetails}`,
            isp: sub
          });
        } catch (e) { logger.error(`Due SMS failed ${sub.phone}:`, e.message); }
      }
    }

    // Suspend overdue PPPoE (past due > 3 days, no payment)
    const overdue = await query(`
      SELECT ps.*, pp.name as pkg_name, pp.price,
             i.company_name, i.sms_gateway, i.sms_api_key, i.sms_sender_id,
             pm.method_type, pm.till_number, pm.paybill_number, pm.account_number,
             pm.bank_name, pm.account_name, pm.account_reference
      FROM pppoe_subscribers ps
      JOIN pppoe_packages pp ON pp.id = ps.package_id
      JOIN isps i ON i.id = ps.isp_id
      LEFT JOIN isp_payment_methods pm ON pm.isp_id = i.id AND pm.is_default=true AND pm.is_active=true
      WHERE FALSE -- superseded by per-minute expiry-enforcer (immediate restriction, no 3-day grace)
    `);

    for (const sub of overdue.rows) {
      // Walled garden: keep them online but restricted to the pay page (instead of a hard reject).
      try { await require('./walledGarden').restrict(sub); }
      catch (wgErr) {
        logger.error('[WG] restrict in cron failed for ' + sub.username + ': ' + wgErr.message);
        // Fallback to the old hard-suspend if the walled garden errors.
        await query(`UPDATE pppoe_subscribers SET status='suspended', updated_at=NOW() WHERE id=$1`, [sub.id]).catch(()=>{});
        await query(`INSERT INTO radcheck (username, attribute, op, value) VALUES ($1,'Auth-Type',':=','Reject') ON CONFLICT DO NOTHING`, [sub.username]).catch(()=>{});
      }

      if (sub.phone) {
        const payDetails = buildPaymentDetails(sub);
        try {
          await sendSMS({
            to: sub.phone,
            message: `Dear ${sub.full_name}, your ${sub.company_name} internet plan has EXPIRED and your account has been suspended. Pay KES ${sub.price} to reconnect.\n${payDetails}`,
            isp: sub
          });
        } catch (e) { logger.error(`Expiry SMS failed ${sub.phone}:`, e.message); }
      }
    }

    // Generate platform invoices (1st of month)
    const today = new Date();
    if (today.getDate() === 1) {
      const isps = await query(`SELECT id, pppoe_rate_per_user FROM isps WHERE plan_type IN ('pppoe','both') AND status='active'`);
      for (const isp of isps.rows) {
        const cnt = await query(`SELECT COUNT(*) as c FROM pppoe_subscribers WHERE isp_id=$1 AND status='active'`, [isp.id]);
        const count = parseInt(cnt.rows[0].c);
        if (count > 0) {
          const total = count * parseFloat(isp.pppoe_rate_per_user || 32.25);
          await query(`
            INSERT INTO isp_platform_invoices (isp_id, period_month, period_year, pppoe_user_count, amount_per_user, total_amount, due_date)
            VALUES ($1,$2,$3,$4,$5,$6, CURRENT_DATE+7) ON CONFLICT DO NOTHING
          `, [isp.id, today.getMonth()+1, today.getFullYear(), count, isp.pppoe_rate_per_user || 32.25, total]);
          await query(`INSERT INTO notifications (isp_id, type, title, message, link) VALUES ($1,'warning','Invoice Generated',$2,'/isp/dashboard.html#billing')`,
            [isp.id, `Your monthly invoice of KES ${total.toLocaleString()} for ${count} PPPoE users is ready.`]);
        }
      }
    }
  } catch (err) {
    logger.error('Daily billing cron error:', err.message);
  }
});

function buildPaymentDetails(sub) {
  if (!sub.method_type) return 'Contact us for payment details.';
  if (sub.method_type === 'till') return `Pay via MPesa:\nBuy Goods Till: ${sub.till_number}`;
  if (sub.method_type === 'paybill') return `Pay via MPesa:\nPaybill: ${sub.paybill_number}\nAccount: ${sub.account_reference || sub.username}`;
  if (sub.method_type === 'bank') return `Bank: ${sub.bank_name}\nAcc: ${sub.account_number}\nName: ${sub.account_name}`;
  if (sub.method_type === 'mpesa_stk') return `Pay via MPesa to ${sub.paybill_number || sub.shortcode}`;
  return 'Contact us for payment details.';
}

logger.info('✅ Cron jobs initialized');


// ── RL_CREDIT_SAFETYNET: any PAID intasend payment without a commission row gets credited here.
//    Some confirm paths (the clearing sweep) resolve a payment without calling creditWalletOnce.
//    creditWalletOnce is idempotent (unique commissions(payment_id)), so this can run every minute. ──
let _creditSnRunning = false;
cron.schedule('* * * * *', async () => {
  if (_creditSnRunning) return; _creditSnRunning = true;
  try {
    const rows = (await query(
      `SELECT p.id
         FROM payments p
         LEFT JOIN commissions c ON c.payment_id = p.id
        WHERE p.status='paid' AND p.payment_gateway='intasend' AND c.id IS NULL
        LIMIT 50`)).rows;
    if (rows.length) {
      const { creditWalletOnce } = require('./wallet-credit');
      let n=0;
      for (const r of rows) {
        try { const res = await creditWalletOnce(r.id); if (res && res.credited) n++; }
        catch (e) { logger.error('[credit-safetynet] ' + r.id + ': ' + e.message); }
      }
      if (n) logger.info('[credit-safetynet] credited ' + n + ' missed payment(s)');
    }
  } catch (e) { logger.error('[credit-safetynet] ' + e.message); }
  finally { _creditSnRunning = false; }
});

// ── RL_ACTIVATE_SAFETYNET: any PAID hotspot payment whose voucher was never activated (e.g. it was
//    confirmed only by the clearing sweep, which doesn't activate) gets activated here. activateVoucher
//    is idempotent (guard + paid_at+duration anchor), so this is safe to run every minute. ──
let _snRunning = false;
cron.schedule('* * * * *', async () => {
  if (_snRunning) return; _snRunning = true;
  try {
    const rows = (await query(
      `SELECT p.id
         FROM payments p
         JOIN hotspot_vouchers v ON v.payment_id = p.id
        WHERE p.status='paid' AND p.voucher_activated_at IS NULL
          AND p.description ILIKE 'Hotspot%'
        LIMIT 25`)).rows;
    if (rows.length) {
      const act = require('./intasend-activate');
      for (const r of rows) {
        try { await act.activateVoucher(r.id); }
        catch (e) { logger.error('[activate-safetynet] ' + r.id + ': ' + e.message); }
      }
      logger.info('[activate-safetynet] activated ' + rows.length + ' missed voucher payment(s)');
    }
  } catch (e) { logger.error('[activate-safetynet] ' + e.message); }
  finally { _snRunning = false; }
});

// ── RL_KICK_ACTIVE_SESSIONS: disconnect LIVE router sessions for expired vouchers. The main
//    enforcer removes the hotspot USER, but an already-established /ip/hotspot/active session keeps
//    running until removed by its .id. This pass matches live sessions to expired vouchers (by MAC
//    or username) and removes them — so "expired" means offline within ~60s, even if the voucher was
//    already flagged expired by a reconcile. ──
let _kickRunning = false;
cron.schedule('* * * * *', async () => {
  if (_kickRunning) return; _kickRunning = true;
  try {
    // expired vouchers that could still be online (expired within the last 2 days)
    const exp = (await query(`
      SELECT v.code, v.isp_id, v.used_by_mac
      FROM hotspot_vouchers v
      WHERE v.expires_at IS NOT NULL AND v.expires_at < NOW()
        AND v.expires_at > NOW() - INTERVAL '2 days'
    `)).rows;
    if (!exp.length) { _kickRunning = false; return; }
    const mt = require('./mikrotik');
    // group by isp -> device, fetch live sessions once per device
    const byIsp = {};
    for (const v of exp) { (byIsp[v.isp_id] = byIsp[v.isp_id] || []).push(v); }
    for (const ispId of Object.keys(byIsp)) {
      const dev = (await query(
        `SELECT id, name FROM nas_devices WHERE isp_id=$1::uuid AND wireguard_ip IS NOT NULL
          ORDER BY last_seen DESC NULLS LAST LIMIT 1`, [ispId])).rows[0];
      if (!dev) continue;
      let live = [];
      try { live = await mt.liveHotspotSessions(dev.id); } catch (e) { continue; }
      if (!live.length) continue;
      const codes = new Set(byIsp[ispId].map(v => v.code));
      const macs = new Set(byIsp[ispId].map(v => (v.used_by_mac||'').toUpperCase()).filter(Boolean));
      for (const sess of live) {
        const uMatch = sess.user && codes.has(sess.user.split('@')[0]);
        const mMatch = sess.mac_address && macs.has(sess.mac_address.toUpperCase());
        if (uMatch || mMatch) {
          try {
            await mt.disconnectHotspotSession(dev.id, sess.id);
            await query("UPDATE radacct SET acctstoptime=NOW(), acctterminatecause='Session-Timeout' WHERE acctstoptime IS NULL AND callingstationid ILIKE $1", ['%'+(sess.mac_address||'')+'%']);
            logger.info('[KICK-ACTIVE] disconnected ' + (sess.user||sess.mac_address) + ' from ' + dev.name);
          } catch (e) { logger.warn('[KICK-ACTIVE] failed for ' + sess.id + ': ' + e.message); }
        }
      }
    }
  } catch (e) { logger.error('[KICK-ACTIVE] ' + e.message); }
  finally { _kickRunning = false; }
});

// ── RL_TV_EXPIRE: remove ip-binding + queue for bound TVs whose package expired (the guarantee). ──
let _tvExpRunning = false;
cron.schedule('* * * * *', async () => {
  if (_tvExpRunning) return; _tvExpRunning = true;
  try {
    const rows = (await query("SELECT id, isp_id, mac_address, bound_ip FROM hotspot_bound_devices WHERE is_bound=true AND expires_at IS NOT NULL AND expires_at < NOW() LIMIT 50")).rows;
    if (rows.length) {
      const mt = require('./mikrotik');
      for (const tv of rows) {
        try {
          const dev = (await query("SELECT id FROM nas_devices WHERE isp_id=$1::uuid AND wireguard_ip IS NOT NULL ORDER BY last_seen DESC NULLS LAST LIMIT 1", [tv.isp_id])).rows[0];
          if (dev) {
            await mt.removeIpBinding(dev.id, tv.mac_address).catch(()=>{});
            await mt.removeQueueRateLimit(dev.id, 'tv-'+String(tv.mac_address).replace(/:/g,'')).catch(()=>{});
          }
          await query("UPDATE hotspot_bound_devices SET is_bound=false, bound_ip=NULL, updated_at=NOW() WHERE id=$1::uuid", [tv.id]);
          logger.info('[TV-EXPIRE] unbound ' + tv.mac_address);
        } catch (e) { logger.warn('[TV-EXPIRE] ' + tv.mac_address + ': ' + e.message); }
      }
    }
  } catch (e) { logger.error('[TV-EXPIRE] ' + e.message); }
  finally { _tvExpRunning = false; }
});

// ── EXPIRY-ENFORCE: kick expired hotspot users off their routers (every 60s) ──
// Uses REST API via WG tunnel. This is the "RADIUS-lite" approach: when a voucher
// expires, we remove it from the router (which kicks any active session).
let _expiryRunning = false;
cron.schedule('* * * * *', async () => {
  if (_expiryRunning) return;
  _expiryRunning = true;
  try {
    const r = await query(`
      SELECT v.id, v.code, v.isp_id, v.expires_at
      FROM hotspot_vouchers v
      WHERE v.expires_at IS NOT NULL
        AND v.expires_at < NOW()
        AND v.status != 'expired'
        AND v.payment_id IS NOT NULL
      ORDER BY v.expires_at ASC
      LIMIT 50`);

    if (!r.rows.length) { _expiryRunning = false; return; }

    logger.info(`[EXPIRY-ENFORCE] Processing ${r.rows.length} expired voucher(s)`);
    const mt = require('./mikrotik');

    for (const v of r.rows) {
      try {
        const nasRes = await query(
          `SELECT id, name FROM nas_devices
           WHERE isp_id = $1::uuid AND wireguard_ip IS NOT NULL
           ORDER BY last_seen DESC NULLS LAST LIMIT 1`,
          [v.isp_id]
        );
        if (nasRes.rows[0]) {
          const result = await mt.removeHotspotUser(nasRes.rows[0].id, v.code);
          if (result.ok) {
            logger.info(`[EXPIRY-ENFORCE] Kicked ${v.code} from ${nasRes.rows[0].name}`);
          } else if (!result.not_found) {
            logger.warn(`[EXPIRY-ENFORCE] Remove failed for ${v.code}: ${result.error}`);
          }
        }
        await query(
          `UPDATE hotspot_vouchers SET status='expired', updated_at=NOW() WHERE id=$1::uuid`,
          [v.id]
        );

    // RADIUS-EXPIRY-CLEAR: remove expired codes from radcheck/radreply
    try {
      const cleared = await query(`
        WITH expired AS (
          SELECT code FROM hotspot_vouchers
           WHERE status='expired' AND expires_at IS NOT NULL AND expires_at < NOW()
        )
        DELETE FROM radcheck WHERE username IN (SELECT code FROM expired) RETURNING username
      `);
      if (cleared.rows.length > 0) {
        await query(`DELETE FROM radreply WHERE username = ANY($1::text[])`,
          [cleared.rows.map(r => r.username)]);
        require('./logger').info(`[RADIUS-EXPIRY-CLEAR] removed ${cleared.rows.length} expired code(s) from RADIUS`);
      }
    } catch(e) { require('./logger').warn(`[RADIUS-EXPIRY-CLEAR] failed: ${e.message}`); }

    // RL_MAC_AUTORECONNECT: also revoke MAC auto-reconnect entries for expired vouchers
    try {
      const macsCleared = await query(`
        WITH expired AS (
          SELECT used_by_mac AS m FROM hotspot_vouchers
           WHERE status='expired' AND used_by_mac IS NOT NULL AND used_by_mac <> ''
             AND expires_at IS NOT NULL AND expires_at < NOW()
        ),
        forms AS (
          SELECT lower(m) AS mform FROM expired
          UNION SELECT upper(m) FROM expired
        )
        DELETE FROM radcheck WHERE username IN (SELECT mform FROM forms) RETURNING username
      `);
      if (macsCleared.rows.length > 0) {
        await query(`DELETE FROM radreply WHERE username = ANY($1::text[])`, [macsCleared.rows.map(r=>r.username)]);
        await query(`DELETE FROM radusergroup WHERE username = ANY($1::text[])`, [macsCleared.rows.map(r=>r.username)]);
        await query(`UPDATE mac_auth_cache SET is_active=false WHERE lower(mac_address) = ANY($1::text[])`, [macsCleared.rows.map(r=>String(r.username).toLowerCase())]);
        require('./logger').info(`[MAC-EXPIRY-CLEAR] revoked ${macsCleared.rows.length} expired MAC entr(ies)`);
      }
    } catch(e) { require('./logger').warn(`[MAC-EXPIRY-CLEAR] failed: ${e.message}`); }

    // QUEUE-EXPIRY-CLEANUP: remove rl-CODE queues from each ISP's router for expired vouchers
    try {
      const axios = require('axios');
      const expiredVouchers = await query(`
        SELECT v.code, v.isp_id, n.id as nas_id, n.wireguard_ip, n.mikrotik_api_user, n.mikrotik_api_password
        FROM hotspot_vouchers v
        JOIN nas_devices n ON n.isp_id = v.isp_id AND n.wireguard_ip IS NOT NULL
        WHERE v.status = 'expired' AND v.expires_at IS NOT NULL AND v.expires_at < NOW()
          AND v.updated_at > NOW() - INTERVAL '10 minutes'
      `);
      for (const v of expiredVouchers.rows) {
        try {
          const baseURL = `http://${v.wireguard_ip}/rest`;
          const auth = { username: v.mikrotik_api_user, password: v.mikrotik_api_password };
          const queues = await axios.get(baseURL + '/queue/simple', { auth, timeout: 5000 });
          for (const q of (queues.data || [])) {
            if (q.name === 'rl-' + v.code) {
              await axios.delete(`${baseURL}/queue/simple/${q['.id']}`, { auth, timeout: 5000 });
              require('./logger').info(`[QUEUE-EXPIRY-CLEANUP] removed rl-${v.code} from ${v.wireguard_ip}`);
            }
          }
          // ALSO kick active session for this voucher if still on router
          const active = await axios.get(baseURL + '/ip/hotspot/active', { auth, timeout: 5000 });
          for (const s of (active.data || [])) {
            if (s.user === v.code) {
              (async ()=>{
                try {
                  const r = await coa.sendDisconnect(nas.id || v.nas_id, s.user || v.code);
                  if (r.ok) { require('./logger').info(`[QUEUE-EXPIRY-COA] ${s.user||v.code} kicked via CoA`); return; }
                } catch(e) {}
                try { await axios.post(baseURL + '/ip/hotspot/active/remove', { '.id': s['.id'] }, { auth, timeout: 5000 }); } catch(e) {}
              })();
              require('./logger').info(`[QUEUE-EXPIRY-CLEANUP] kicked expired session ${v.code} on ${v.wireguard_ip}`);
            }
          }
        } catch(qErr) { require('./logger').warn(`[QUEUE-EXPIRY-CLEANUP] ${v.code}: ${qErr.message}`); }
      }
    } catch(e) { require('./logger').warn(`[QUEUE-EXPIRY-CLEANUP] failed: ${e.message}`); }
      } catch (e) {
        logger.warn(`[EXPIRY-ENFORCE] Error on ${v.code}: ${e.message}`);
      }
    }
  } catch (e) {
    logger.error(`[EXPIRY-ENFORCE] Sweep failed: ${e.message}`);
  } finally {
    _expiryRunning = false;
  }
});

logger.info('[EXPIRY-ENFORCE] Registered (every 60s)');




// ACTIVE-SESSION-QUEUE-SYNC (v55) — ensure every active hotspot session has a queue
// rule matching its radreply Mikrotik-Rate-Limit. Catches:
//   - users who reconnected via MAC cookie after voucher renewal
//   - users who paid while offline, then reconnected later
//   - any state drift between radreply and /queue/simple
async function syncActiveSessionQueues() {
  try {
    const axios = require('axios');
    const { query } = require('../config/database');
    const logger = require('./logger');
    const nasList = await query(
      `SELECT id, isp_id, wireguard_ip, mikrotik_api_user, mikrotik_api_password
       FROM nas_devices WHERE wireguard_ip IS NOT NULL`
    );
    for (const nas of nasList.rows) {
      try {
        const baseURL = `http://${nas.wireguard_ip}/rest`;
        const auth = { username: nas.mikrotik_api_user, password: nas.mikrotik_api_password };
        const [activeR, queuesR] = await Promise.all([
          axios.get(baseURL + '/ip/hotspot/active', { auth, timeout: 5000 }),
          axios.get(baseURL + '/queue/simple', { auth, timeout: 5000 }),
        ]);
        const active = activeR.data || [];
        const queues = queuesR.data || [];
        const queueByName = {};
        const queueByIp = {};
        for (const q of queues) {
          if ((q.name || '').startsWith('rl-')) {
            queueByName[q.name] = q;
            const t = q.target || '';
            const ipPart = t.split('/')[0];
            if (ipPart) queueByIp[ipPart] = q;
          }
        }
        for (const s of active) {
          const code = s.user;
          const ip = s.address;
          if (!code || !ip) continue;
          if (!/^[A-Z]+\d+/.test(code)) continue; // only K-codes
          const rr = await query(
            `SELECT rr.value FROM radreply rr
             WHERE rr.username = (
               SELECT $1 || '@' || LOWER(REPLACE(LEFT(v.isp_id::text, 8), '-', ''))
               FROM hotspot_vouchers v WHERE v.code = $1 AND v.isp_id = $2::uuid LIMIT 1
             ) AND rr.attribute = 'Mikrotik-Rate-Limit' LIMIT 1`,
            [code, nas.isp_id]
          );
          const rate = rr.rows[0] && rr.rows[0].value;
          if (!rate || rate === '0M/0M') continue;
          const expectedName = 'rl-' + code;
          const existingByName = queueByName[expectedName];
          // Normalize rate for comparison: "5M/5M" vs "5000000/5000000"
          const expectedBytes = rate.replace(/M/g, '000000').replace(/K/g, '000');
          if (existingByName) {
            // Check max-limit matches
            const curLimit = (existingByName['max-limit'] || '').replace(/M/g, '000000');
            if (curLimit !== expectedBytes && existingByName['max-limit'] !== rate) {
              try {
                await axios.patch(`${baseURL}/queue/simple/${existingByName['.id']}`, {
                  target: ip + '/32', 'max-limit': rate, disabled: 'false'
                }, { auth, timeout: 5000 });
                logger.info(`[ACTIVE-SESSION-QUEUE-SYNC] PATCH rl-${code}: ${existingByName['max-limit']} -> ${rate}`);
              } catch(e) {}
            }
          } else {
            // No queue with this name - remove any stale queue on same IP, then create
            for (const q of queues) {
              if ((q.name || '').startsWith('rl-') && q.name !== expectedName) {
                const t = q.target || '';
                if (t === ip + '/32' || t === ip) {
                  try { await axios.delete(`${baseURL}/queue/simple/${q['.id']}`, { auth, timeout: 5000 }); } catch(e) {}
                }
              }
            }
            try {
              await axios.put(baseURL + '/queue/simple', {
                name: expectedName, target: ip + '/32', 'max-limit': rate,
                comment: 'RumaLink:' + code
              }, { auth, timeout: 5000 });
              logger.info(`[ACTIVE-SESSION-QUEUE-SYNC] CREATED ${expectedName} ${rate} on ${ip}`);
            } catch(e) { logger.warn(`[ACTIVE-SESSION-QUEUE-SYNC] create ${expectedName}: ${e.message}`); }
          }
        }
      } catch(nasErr) { /* per-NAS errors - skip silently */ }
    }
  } catch(e) { require('./logger').warn(`[ACTIVE-SESSION-QUEUE-SYNC] outer: ${e.message}`); }
}

// Run every 30 seconds
setInterval(syncActiveSessionQueues, 30 * 1000);
// Also run 10s after startup
setTimeout(syncActiveSessionQueues, 10 * 1000);


// v62.89: ISP link monitor — check internet reachability from all MikroTiks every 60s
const { pollAllDevices: pollIspLinks } = require('./isp-monitor');
cron.schedule('* * * * *', async () => {
  try {
    await pollIspLinks();
  } catch (e) {
    require('./logger').error('[cron isp-monitor] ' + e.message);
  }
});
require('./logger').info('[cron] ISP link monitor scheduled (every 60s)');


// ── v62.104: Multi-WAN internet-aware failover monitor (every 15 seconds) ──
// Runs entirely on the VPS. Pings each WAN's probe target, decides which links
// have internet, adjusts MikroTik route distances by priority, updates DB status.
// The MikroTik just applies the distance changes — no monitoring load on the router.
const mwanApplier = require('./mwan-applier');
let _mwanMonitorBusy = false;
cron.schedule('*/15 * * * * *', async () => {
  if (_mwanMonitorBusy) return;  // prevent overlap if a pass runs long
  _mwanMonitorBusy = true;
  try {
    await mwanApplier.monitorAll();
  } catch (e) {
    logger.error('[mwan-monitor] cron error: ' + e.message);
  } finally {
    _mwanMonitorBusy = false;
  }
});


// ── v62.107: Hotspot rate-limit queue reconciler (every 15s) ──
// Keeps /queue/simple targets glued to each active hotspot session's LIVE IP and
// the user's RADIUS Mikrotik-Rate-Limit. Fixes caps leaking after a user reconnects
// or after WAN failover (stale static queues pinned to old IPs). VPS-side; minimal.
const hotspotQueueSync = require('./hotspot-queue-sync');
let _queueSyncBusy = false;
cron.schedule('*/15 * * * * *', async () => {
  if (_queueSyncBusy) return;
  _queueSyncBusy = true;
  try { await hotspotQueueSync.syncAll(); }
  catch (e) { logger.error('[queue-sync] cron: ' + e.message); }
  finally { _queueSyncBusy = false; }
});


// ── v62.109: Multi-WAN policy reconciler (every 15s) ──
// Populates rl_wanN_users with each matched session's LIVE IP so policies actually
// steer traffic (mangle + custom-table routes from v62.108 do the rest).
const mwanPolicySync = require('./mwan-policy-sync');
let _policySyncBusy = false;
cron.schedule('*/15 * * * * *', async () => {
  if (_policySyncBusy) return;
  _policySyncBusy = true;
  try { await mwanPolicySync.syncAll(); }
  catch (e) { logger.error('[policy-sync] cron: ' + e.message); }
  finally { _policySyncBusy = false; }
});

// ── Daily 08:05 — generate platform invoices 5 days before license expiry ──
cron.schedule('5 8 * * *', async () => {
  try {
    const billing = require('./billing');
    const isps = await query(`
      SELECT id, company_name, plan_type, license_expires_at, billing_window_start, subscription_started_at, trial_ends_at
      FROM isps
      WHERE billing_exempt IS NOT TRUE
        AND license_expires_at IS NOT NULL
        AND license_expires_at > NOW()
        AND license_expires_at <= NOW() + INTERVAL '5 days'
        AND NOT EXISTS (SELECT 1 FROM isp_platform_invoices pi WHERE pi.isp_id = isps.id AND pi.status='pending')
    `);
    for (const isp of isps.rows) {
      try {
        const ws = isp.billing_window_start || isp.subscription_started_at || isp.trial_ends_at;
        const owed = await billing.computeOwed(isp.id, ws, new Date());
        const now = new Date();
        const invNum = 'RLINV-' + now.getFullYear() + (now.getMonth()+1).toString().padStart(2,'0') + '-' + String(isp.id).slice(0,6).toUpperCase();
        await query(`
          INSERT INTO isp_platform_invoices
            (isp_id, period_month, period_year, pppoe_user_count, amount_per_user,
             hotspot_revenue, hotspot_fee, hotspot_rate, pppoe_fee,
             total_amount, status, due_date, window_start, window_end, period_expires_at,
             invoice_number, invoice_type)
          VALUES ($1::uuid,$2,$3,$4,$5,$6,$7,$8,$9,$10,'pending',$11,$12,$13,$14,$15,'combined')
        `, [isp.id, now.getMonth()+1, now.getFullYear(), owed.pppoe_users, owed.amount_per_user,
            owed.hotspot_revenue, owed.hotspot_fee, owed.hotspot_rate, owed.pppoe_fee,
            owed.total, isp.license_expires_at, owed.window_start, owed.window_end, isp.license_expires_at, invNum]);
        await query(`INSERT INTO notifications (isp_id, type, title, message) VALUES ($1::uuid,'warning','Invoice Due',$2)`,
          [isp.id, 'Your platform license invoice of KES ' + owed.total.toFixed(2) + ' is due by ' + new Date(isp.license_expires_at).toLocaleString() + '.']).catch(()=>{});
        logger.info('[BILLING] invoice ' + invNum + ' for ' + isp.company_name + ': KES ' + owed.total);
      } catch (e) { logger.error('[BILLING] invoice gen failed for ' + isp.id + ': ' + e.message); }
    }
  } catch (e) { logger.error('[BILLING] invoice cron: ' + e.message); }
});


// ── Per-minute: immediate PPPoE expiry enforcer ──────────────────────────────
// Walls any active PPPoE subscriber the moment their next_billing_date passes.
// No 3-day grace, no balance condition — restriction is immediate and time-accurate.
// walledGarden.restrict() sets status=expired + Mikrotik-Group=rl-expired + bounces the
// session; the every-minute RADIUS sync keeps them walled. Payment -> onPaid restores them.
let _pppoeExpiryBusy = false;
cron.schedule('* * * * *', async () => {
  if (_pppoeExpiryBusy) return;
  _pppoeExpiryBusy = true;
  try {
    const due = await query(`
      SELECT ps.id, ps.username, ps.nas_id, ps.isp_id, ps.phone, ps.full_name, ps.payment_sms_sent_at,
             pp.name AS pkg_name, pp.price, pp.mikrotik_profile,
             i.company_name, i.sms_gateway, i.sms_api_key, i.sms_sender_id,
             pm.method_type, pm.till_number, pm.paybill_number, pm.account_number, pm.account_reference,
             pm.bank_name, pm.account_name
        FROM pppoe_subscribers ps
        JOIN pppoe_packages pp ON pp.id = ps.package_id
        JOIN isps i ON i.id = ps.isp_id
        LEFT JOIN isp_payment_methods pm ON pm.isp_id = i.id AND pm.is_default=true AND pm.is_active=true
       WHERE ps.status = 'active'
         AND ps.next_billing_date < NOW()
         AND (ps.is_test IS NULL OR ps.is_test = false)
       LIMIT 200
    `);
    for (const sub of due.rows) {
      try {
        await require('./walledGarden').restrict(sub);
        logger.info('[expiry-enforcer] ' + sub.username + ' expired -> walled');
        // One-time expiry SMS with the pay link (only if not already sent recently).
        if (sub.phone && sub.sms_gateway) {
          try {
            const payDetails = buildPaymentDetails(sub);
            await sendSMS({
              to: sub.phone,
              message: 'Dear ' + (sub.full_name||'Customer') + ', your ' + sub.company_name + ' internet (' + sub.pkg_name + ') has expired. Pay KES ' + sub.price + ' to reconnect.\n' + payDetails,
              isp: sub
            });
          } catch (smsErr) { logger.warn('[expiry-enforcer] sms ' + sub.username + ': ' + smsErr.message); }
        }
      } catch (e) {
        logger.error('[expiry-enforcer] restrict ' + sub.username + ': ' + e.message);
      }
    }
  } catch (e) {
    logger.error('[expiry-enforcer] cron: ' + e.message);
  } finally {
    _pppoeExpiryBusy = false;
  }
});


// ── RL_INTASEND_POLL: confirm pending IntaSend collections (webhook-independent) ──
try {
  const intasendPoll = require('./intasend-poll');
  setInterval(() => { intasendPoll.pollPending().catch(() => {}); }, 20000);
  require('./logger').info('[CRON] IntaSend payment poller started (20s)');
} catch (e) {
  require('./logger').warn('[CRON] IntaSend poller not started: ' + e.message);
}


// ── RL_PAYMENT_SWEEP: closed-page safety net ─────────────────────────────────
// A customer can pay, close the pay page, and have the webhook dropped — then nothing is watching
// and they stay walled (this is exactly what happened to benard). This sweep confirms stale
// 'pending' payments directly with the gateway and, when one is genuinely paid, runs the SAME
// activation the webhook/poll runs. Age-bounded so it never hammers the gateway on ancient dead
// rows.
let _sweepRunning = false;
cron.schedule('*/2 * * * *', async () => {
  if (_sweepRunning) return;
  _sweepRunning = true;
  try {
    const { rlConfirmWithGateway } = require('./intasend-selfheal');
    const due = await query(
      `SELECT id, status, payment_gateway, metadata, isp_id, subscriber_id, transaction_id
         FROM payments
        WHERE status = 'pending'
          AND payment_gateway IN ('intasend','mpesa_stk')
          AND created_at < NOW() - INTERVAL '2 minutes'
          AND created_at > NOW() - INTERVAL '6 hours'
        ORDER BY created_at DESC
        LIMIT 25`);
    if (!due.rows.length) { _sweepRunning = false; return; }

    let healed = 0;
    for (const pay of due.rows) {
      try {
        const ns = await rlConfirmWithGateway(pay);
        if (ns !== 'paid') continue;           // still pending or failed -> nothing to activate

        // Marked paid by the gateway check. Now RUN THE ACTIVATION the caller is responsible for.
        if (pay.subscriber_id) {
          // PPPoE: re-read the receipt the confirm just wrote, then reactivate.
          const pr = await query("SELECT transaction_id FROM payments WHERE id=$1::uuid", [pay.id]);
          const receipt = pr.rows[0] && pr.rows[0].transaction_id;
          const portal = require('../routes/pppoePortal');
          if (typeof portal.onPaid === 'function') {
            await portal.onPaid(pay.id, receipt);
            logger.info('[PAYMENT-SWEEP] PPPoE ' + pay.id + ' recovered + reactivated');
            healed++;
          } else {
            logger.error('[PAYMENT-SWEEP] onPaid not exported — ' + pay.id + ' PAID BUT STILL WALLED');
          }
        } else {
          // Hotspot: activate the voucher tied to this payment.
          try {
            const vv = await query(
              "SELECT id FROM hotspot_vouchers WHERE payment_id=$1::uuid ORDER BY created_at DESC LIMIT 1",
              [pay.id]);
            if (vv.rows[0]) {
              const captive = require('../routes/captive');
              if (typeof captive.syncRadiusForVoucher === 'function') {
                await captive.syncRadiusForVoucher(vv.rows[0].id);
              }
              logger.info('[PAYMENT-SWEEP] hotspot ' + pay.id + ' recovered + voucher synced');
              healed++;
            }
          } catch (ve) { logger.warn('[PAYMENT-SWEEP] voucher sync: ' + ve.message); }
        }
      } catch (pe) {
        logger.warn('[PAYMENT-SWEEP] payment ' + pay.id + ': ' + pe.message);
      }
    }
    if (healed) logger.info('[PAYMENT-SWEEP] recovered ' + healed + ' payment(s) this pass');
  } catch (e) {
    logger.error('[PAYMENT-SWEEP] ' + e.message);
  } finally {
    _sweepRunning = false;
  }
});


// RL_TV_RECONCILE boot
try { require('./tv-reconcile').start(); } catch (e) { require('./logger').warn('[tv-reconcile] start: ' + e.message); }

// RL_STRAND_HEAL: paid-but-voucherless payments are healed every minute; TV voucher<->device kept in sync.
try { require('./strand-heal').start(); } catch (e) { require('./logger').warn('[strand-heal] start: ' + e.message); }

// RL_ROUTER_HARDEN: every online router keeps fasttrack + MSS clamp + pcq + mac-auth (no mac-cookie).
// Makes a delete/re-add (or a pre-fix router) self-heal to the current performance+auth baseline.
try { require('./router-harden').start(); } catch (e) { require('./logger').warn('[router-harden] start: ' + e.message); }
