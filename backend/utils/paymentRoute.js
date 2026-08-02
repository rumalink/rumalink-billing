const { query } = require('../config/database');

async function darajaCreds(ispId) {
    try {
        const res = await query(
            "SELECT * FROM isp_payment_methods WHERE isp_id = $1 AND (method_type = 'mpesa_stk' OR method_type ILIKE '%daraja%') AND is_active = true ORDER BY is_default DESC LIMIT 1",
            [ispId]
        );
        
        if (!res.rows[0]) {
            console.warn(`[payment-route] No active Daraja method found for ISP ${ispId}`);
            return null;
        }

        const cfg = res.rows[0];
        return {
            source: 'database',
            consumer_key: cfg.consumer_key ? cfg.consumer_key.trim() : '',
            consumer_secret: cfg.consumer_secret ? cfg.consumer_secret.trim() : '',
            passkey: cfg.passkey ? cfg.passkey.trim() : '',
            shortcode: cfg.shortcode ? cfg.shortcode.trim() : (cfg.till_number || cfg.paybill_number || ''),
            environment: cfg.environment || 'production'
        };
    } catch (err) {
        console.error('[payment-route] Error fetching Daraja credentials:', err.message);
        return null;
    }
}

async function paymentRoute(ispId, amount, phone, metadata) {
    const creds = await darajaCreds(ispId);
    if (!creds || !creds.consumer_key) {
        console.warn(`[payment-route] isp=${ispId} selected M-Pesa (Daraja) but no Daraja credentials are configured`);
        throw new Error('Daraja credentials are not configured for this ISP');
    }
    return { gateway: 'daraja', creds };
}

paymentRoute.resolve = paymentRoute;
paymentRoute.darajaCreds = darajaCreds;

module.exports = paymentRoute;
module.exports.paymentRoute = paymentRoute;
module.exports.resolve = paymentRoute;
module.exports.darajaCreds = darajaCreds;
