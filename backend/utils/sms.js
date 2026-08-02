const axios = require('axios');
const { query } = require('../config/database');
const logger = require('./logger');

// All Kenya SMS Gateways
const KENYA_GATEWAYS = {
  africastalking: {
    name: "Africa's Talking",
    send: async ({ to, message, apiKey, username, senderId }) => {
      const res = await axios.post(
        'https://api.africastalking.com/version1/messaging',
        new URLSearchParams({ username: username || 'sandbox', to, message, from: senderId }),
        { headers: { apiKey, 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' } }
      );
      return res.data;
    }
  },
  bongasms: {
    name: 'BongaSMS',
    send: async ({ to, message, apiKey, partnerId, senderId }) => {
      const res = await axios.post('https://www.bongasms.co.ke/api/send-sms', {
        apikey: apiKey, partnerID: partnerId, message, shortcode: senderId, mobile: to
      });
      return res.data;
    }
  },
  websms: {
    name: 'WebSMS (Elitehost)',
    send: async ({ to, message, apiKey, senderId }) => {
      const res = await axios.get('https://websms.co.ke/api/send', {
        params: { apiKey, phone: to, message, sender: senderId }
      });
      return res.data;
    }
  },
  advanta: {
    name: 'Advanta SMS',
    send: async ({ to, message, apiKey, senderId }) => {
      const res = await axios.post('https://quicksms.advantasms.com/api/services/sendsms/', {
        apikey: apiKey, partnerID: '', message, shortcode: senderId, mobile: to
      });
      return res.data;
    }
  },
  sendsms: {
    name: 'SendSMS Kenya',
    send: async ({ to, message, apiKey, senderId }) => {
      const res = await axios.post('https://sendsms.co.ke/api/v1/send', {
        api_key: apiKey, sender_id: senderId, message, phone: to
      });
      return res.data;
    }
  },
  wigal: {
    name: 'Wigal SMS',
    send: async ({ to, message, apiKey, senderId }) => {
      const res = await axios.post('https://frog.wigal.com.gh/sendmsg', {
        api_key: apiKey, senderid: senderId, message, destinations: [{ destination: to }]
      });
      return res.data;
    }
  },
  textmagic: {
    name: 'TextMagic',
    send: async ({ to, message, apiKey, username }) => {
      const res = await axios.post('https://rest.textmagic.com/api/v2/messages', {
        phones: to, text: message
      }, { auth: { username, password: apiKey } });
      return res.data;
    }
  },
  bulksms: {
    name: 'BulkSMS Kenya',
    send: async ({ to, message, apiKey, senderId }) => {
      const res = await axios.post('https://bulksms.co.ke/api/send', null, {
        params: { apikey: apiKey, mobile: to, message, sender_id: senderId }
      });
      return res.data;
    }
  },
  mobitech: {
    name: 'Mobitech Kenya',
    send: async ({ to, message, apiKey, senderId }) => {
      const res = await axios.post('https://api.mobitech.co.ke/messaging', {
        apiKey, clientId: '', phoneNumber: to, message, serviceCode: senderId
      });
      return res.data;
    }
  },
  cellfonie: {
    name: 'Cellfonie',
    send: async ({ to, message, apiKey, senderId }) => {
      const res = await axios.post('https://www.cellfonie.com/api/sms', {
        api_key: apiKey, from: senderId, to, text: message
      });
      return res.data;
    }
  },
  hubtel: {
    name: 'Hubtel',
    send: async ({ to, message, apiKey, apiSecret, senderId }) => {
      const res = await axios.post('https://smsc.hubtel.com/v1/messages/send', {
        From: senderId, To: to, Content: message
      }, { auth: { username: apiKey, password: apiSecret } });
      return res.data;
    }
  },
  sparrowsms: {
    name: 'Sparrow SMS',
    send: async ({ to, message, apiKey, senderId }) => {
      const res = await axios.post('https://api.sparrowsms.com/v2/sms/', {
        token: apiKey, from: senderId, to, text: message
      });
      return res.data;
    }
  },

  talksasa: {
    name: 'TalkSasa',
    send: async ({ to, message, apiKey, senderId }) => {
      // TalkSasa Bulk SMS API - Bearer token auth
      // Base: https://bulksms.talksasa.com/api/v3/
      const res = await axios.post('https://bulksms.talksasa.com/api/v3/sms/send', {
        recipient: to,
        sender_id: senderId || 'TalkSasa',
        type: 'plain',
        message: message
      }, {
        headers: {
          'Authorization': 'Bearer ' + apiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        timeout: 15000
      });
      return res.data;
    }
  },

  rumalink: {
    name: 'RumaLink SMS',
    // Routes through the PLATFORM's TalkSasa account (admin creds), not the ISP's.
    send: async ({ to, message, senderId }) => {
      const cfgRes = await query("SELECT api_key, sender_id, base_url FROM sms_provider_config WHERE id=1");
      const cfg = cfgRes.rows[0];
      if (!cfg || !cfg.api_key) throw new Error('RumaLink SMS gateway not configured by admin');
      const base = (cfg.base_url || 'https://bulksms.talksasa.com/api/v3').replace(/\/$/,'');
      const res = await axios.post(base + '/sms/send', {
        recipient: to,
        sender_id: cfg.sender_id || senderId || 'RumaLink',
        type: 'plain',
        message: message
      }, {
        headers: { 'Authorization':'Bearer '+cfg.api_key, 'Content-Type':'application/json', 'Accept':'application/json' },
        timeout: 15000
      });
      return res.data;
    }
  },

};

const sendSMS = async ({ to, message, isp }) => {
  /* RL_DEFAULT_GATEWAY: defaulted to 'africastalking', which is not configured here, while the
     logging wrapper below defaulted to 'rumalink'. Any caller that did not set sms_gateway
     explicitly (cron expiry notices, ISP alerts) failed to send AND was logged against the
     wrong provider. 'rumalink' is the platform reseller gateway backed by sms_provider_config. */
  const gateway = isp?.sms_gateway?.toLowerCase() || process.env.SMS_DEFAULT_GATEWAY || 'rumalink';
  const phone = to.toString().replace(/^0/, '+254').replace(/^\+?254/, '+254').replace(/\s/g, '');

  const gw = KENYA_GATEWAYS[gateway];
  if (!gw) throw new Error(`Unknown SMS gateway: ${gateway}`);

  // RumaLink SMS: enforce the ISP's credit balance BEFORE sending.
  if (gateway === 'rumalink') {
    if (!isp || !isp.id) throw new Error('RumaLink SMS requires ISP context');
    const balRes = await query("SELECT sms_balance FROM isps WHERE id=$1::uuid", [isp.id]);
    const bal = balRes.rows[0] ? parseFloat(balRes.rows[0].sms_balance) : 0;
    if (!(bal >= 1)) {
      const e = new Error('Insufficient SMS balance. Top up your SMS from the dashboard to continue sending.');
      e.code = 'SMS_BALANCE_EMPTY';
      throw e;
    }
  }

  try {
    const result = await gw.send({
      to: phone,
      message,
      apiKey: isp?.sms_api_key || process.env.AT_API_KEY,
      username: isp?.sms_username || process.env.AT_USERNAME || 'sandbox',
      senderId: isp?.sms_sender_id || process.env.AT_SENDER_ID || 'RumaLink',
      partnerId: isp?.sms_partner_id,
      apiSecret: isp?.sms_api_secret
    });
    logger.info(`SMS sent via ${gw.name} to ${phone}`);

    // RumaLink SMS: decrement the ISP balance + record consumption.
    if (gateway === 'rumalink' && isp && isp.id) {
      try {
        const upd = await query("UPDATE isps SET sms_balance = GREATEST(sms_balance - 1, 0) WHERE id=$1::uuid RETURNING sms_balance", [isp.id]);
        const after = upd.rows[0] ? parseFloat(upd.rows[0].sms_balance) : null;
        await query(`INSERT INTO sms_credit_transactions (isp_id, txn_type, sms_count, isp_balance_after, status, note)
                     VALUES ($1::uuid, 'consumption', -1, $2, 'completed', 'SMS sent')`, [isp.id, after]).catch(()=>{});
      } catch (de) { logger.error('rumalink balance decrement failed: ' + de.message); }
    }
    return result;
  } catch (err) {
    logger.error(`SMS failed via ${gw.name}:`, err.response?.data || err.message);
    throw err;
  }
};

// Export list of gateways for frontend
const GATEWAY_LIST = Object.entries(KENYA_GATEWAYS).map(([id, g]) => ({ id, name: g.name }));

/* RL_SMS_LOGGING: record every message that leaves the platform.
   sms_logs existed with the right columns but nothing ever wrote to it, so per-customer history
   was permanently empty and there was no way to answer "did this person actually get their code?".
   Wrapping the exported function rather than editing the sender means every caller is covered —
   purchase confirmations, expiry notices, OTPs, ISP alerts and manual messages — without each one
   having to remember to log. Failures are recorded too: a message that never arrived is exactly
   the one worth being able to see. */
const _rlSendCore = sendSMS;
const _rlSendLogged = async function (opts) {
  const o = opts || {};
  const to = o.to || o.phone || '';
  const body = o.message || o.text || '';
  const isp = o.isp || {};
  const gateway = (isp.sms_gateway || process.env.SMS_DEFAULT_GATEWAY || 'rumalink').toLowerCase();
  let result = null, failure = null;
  try {
    result = await _rlSendCore(o);
  } catch (e) {
    failure = e;
  }
  try {
    const gwId = result && (result.messageId || result.message_id || result.id ||
                            (result.data && (result.data.messageId || result.data.id))) || null;
    const cost = result && (result.cost || (result.data && result.data.cost)) || null;
    /* RL_STATUS_NORMALISE: gateways disagree on vocabulary — TalkSASA answers 'success', others
       return nothing at all and fall through to 'sent'. Two words for one outcome made identical
       messages look like different events in the history. Collapse them at write time. */
    let status = failure ? 'failed' : ((result && (result.status || result.state)) || 'sent');
    status = String(status).toLowerCase();
    if (['success', 'ok', 'queued', 'submitted', 'accepted', 'delivered'].indexOf(status) >= 0) status = 'sent';
    if (['error', 'rejected', 'undelivered'].indexOf(status) >= 0) status = 'failed';
    const note = failure ? String(failure.message || 'send failed').slice(0, 200) : null;
    await query(
      "INSERT INTO sms_logs (isp_id, recipient, message, gateway, gateway_message_id, status, cost, sent_at) " +
      "VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, NOW())",
      [isp.id || null, String(to), note ? (String(body) + '\n[' + note + ']') : String(body),
       gateway, gwId ? String(gwId) : null, String(status).slice(0, 40),
       cost != null ? Number(cost) : null]);
  } catch (le) {
    try { require('./logger').warn('[sms-log] ' + le.message); } catch (e) {}
  }
  if (failure) throw failure;
  return result;
};

module.exports = { sendSMS: _rlSendLogged, GATEWAY_LIST };
