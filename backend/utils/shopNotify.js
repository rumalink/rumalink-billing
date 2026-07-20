// utils/shopNotify.js — Order notifications (Phase 5).
// For now: logs + in-app notification. WhatsApp Business API wired in Phase 5.
const { query } = require('../config/database');
const logger = require('../utils/logger');

async function notifyNewOrder(orderId) {
  try {
    const o = await query('SELECT * FROM shop_orders WHERE id=$1::uuid', [orderId]);
    const order = o.rows[0];
    if (!order) return;
    const items = await query('SELECT product_name, quantity, line_total FROM shop_order_items WHERE order_id=$1::uuid', [orderId]);
    const itemLines = items.rows.map(i => `${i.quantity}x ${i.product_name} (KES ${i.line_total})`).join(', ');
    const summary = `New order ${order.order_number}: ${itemLines}. Subtotal KES ${order.subtotal}, delivery KES ${order.delivery_fee}, total KES ${order.total}. Deliver to: ${order.delivery_address}. Phone: ${order.customer_phone}`;
    logger.info('[SHOP ORDER] ' + summary);

    // Mark notified
    await query('UPDATE shop_orders SET notified_admin=true WHERE id=$1::uuid', [orderId]).catch(()=>{});

    // WhatsApp Business API (Phase 5) — send if configured
    const s = await query('SELECT whatsapp_enabled, whatsapp_phone_id, whatsapp_token, whatsapp_admin_numbers FROM shop_settings WHERE id=1');
    const cfg = s.rows[0] || {};
    if (cfg.whatsapp_enabled && cfg.whatsapp_phone_id && cfg.whatsapp_token && cfg.whatsapp_admin_numbers) {
      const axios = require('axios');
      const numbers = String(cfg.whatsapp_admin_numbers).split(',').map(n => n.trim().replace(/\D/g, '')).filter(Boolean);
      for (const num of numbers) {
        try {
          await axios.post(`https://graph.facebook.com/v21.0/${cfg.whatsapp_phone_id}/messages`, {
            messaging_product: 'whatsapp',
            to: num,
            type: 'text',
            text: { body: `🛒 ${summary}` }
          }, { headers: { Authorization: `Bearer ${cfg.whatsapp_token}`, 'Content-Type': 'application/json' }, timeout: 10000 });
          logger.info('[SHOP] WhatsApp alert sent to ' + num);
        } catch (waErr) {
          logger.warn('[SHOP] WhatsApp send failed for ' + num + ': ' + (waErr.response?.data?.error?.message || waErr.message));
        }
      }
    }
  } catch (e) {
    logger.error('shopNotify.notifyNewOrder: ' + e.message);
  }
}

module.exports = { notifyNewOrder };
