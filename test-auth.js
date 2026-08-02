const { query } = require('./backend/config/database');
const axios = require('axios');

async function test() {
    const res = await query("SELECT consumer_key, consumer_secret, environment FROM isp_payment_methods WHERE method_type='mpesa_stk' LIMIT 1");
    if (!res.rows[0]) return console.log("No Daraja config found.");
    
    const cfg = res.rows[0];
    const baseUrl = cfg.environment === 'production' ? 'https://api.safaricom.co.ke' : 'https://sandbox.safaricom.co.ke';
    const auth = Buffer.from(cfg.consumer_key + ':' + cfg.consumer_secret).toString('base64');
    
    try {
        console.log(`Testing ${cfg.environment} Daraja Auth with Consumer Key length: ${cfg.consumer_key.length}...`);
        const token = await axios.get(`${baseUrl}/oauth/v1/generate?grant_type=client_credentials`, {
            headers: { Authorization: `Basic ${auth}` }
        });
        console.log("✅ SUCCESS! Safaricom accepted the keys. Token:", token.data.access_token.substring(0, 10) + '...');
    } catch (e) {
        console.error("❌ SAFARICOM REJECTION REASON:", JSON.stringify(e.response ? e.response.data : e.message, null, 2));
    }
    process.exit(0);
}
test();
