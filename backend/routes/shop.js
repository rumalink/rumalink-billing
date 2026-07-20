// routes/shop.js — RumaLink Shop (e-commerce)
// Admin endpoints (product/order/settings management) + public storefront/checkout.
// Revenue is fully isolated in shop_orders/shop_payments (never touches ISP payments).
const express = require('express');
const axios = require('axios');
const { query } = require('../config/database');
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const { stkPush } = require('../utils/mpesa');
const logger = require('../utils/logger');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
let sharp = null;
try { sharp = require('sharp'); } catch (e) { /* sharp optional; fallback to raw save */ }
const router = express.Router();

// Product image upload — accept large source (up to 12MB), optimize server-side to fast WebP.
const _shopUploadDir = './uploads/products';
try { fs.mkdirSync(_shopUploadDir, { recursive: true }); } catch (e) {}
const _shopUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 12 * 1024 * 1024 },  // accept big phone/camera photos
  fileFilter: (req, file, cb) => {
    if (/^image\//.test(file.mimetype)) cb(null, true);
    else cb(new Error('Only image files allowed'));
  }
});

// Optimize + persist an uploaded image buffer. Returns the public URL.
async function _saveProductImage(buffer, originalName) {
  const base = 'prod_' + Date.now() + '_' + Math.round(Math.random() * 1e6);
  if (sharp) {
    // Resize to max 1200px longest side, convert to WebP ~82% (fast, high quality).
    const outName = base + '.webp';
    await sharp(buffer)
      .rotate()                                   // respect EXIF orientation
      .resize(1200, 1200, { fit: 'inside', withoutEnlargement: true })
      .webp({ quality: 82 })
      .toFile(path.join(_shopUploadDir, outName));
    return '/uploads/products/' + outName;
  }
  // Fallback (no sharp): save raw
  const ext = (String(originalName || '').match(/\.[a-zA-Z0-9]+$/) || ['.jpg'])[0];
  const outName = base + ext;
  fs.writeFileSync(path.join(_shopUploadDir, outName), buffer);
  return '/uploads/products/' + outName;
}

// ---------- helpers ----------
function slugify(s) {
  return String(s || '').toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 200);
}
function genOrderNumber(prefix) {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < 6; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return `${prefix || 'RL'}-${s}`;
}
async function getShopSettings() {
  const r = await query('SELECT * FROM shop_settings WHERE id=1');
  return r.rows[0] || {};
}
async function getAdminMpesaCreds() {
  const r = await query('SELECT shortcode, consumer_key, consumer_secret, passkey, is_sandbox FROM mpesa_configs WHERE is_admin_config=true LIMIT 1');
  return r.rows[0] || null;
}

// ============================================================
// PUBLIC STOREFRONT (no auth)
// ============================================================

// GET /api/shop/products — list active products (optional ?category=slug)
router.get('/products', async (req, res, next) => {
  try {
    const { category, featured, q } = req.query;
    const params = [];
    let where = 'p.is_active = true';
    if (category) { params.push(category); where += ` AND c.slug = $${params.length}`; }
    if (featured === 'true') { where += ' AND p.is_featured = true'; }
    if (q) { params.push(`%${q}%`); where += ` AND p.name ILIKE $${params.length}`; }
    const r = await query(
      `SELECT p.id, p.name, p.slug, p.description, p.price, p.compare_price, p.stock_qty,
              p.track_stock, p.image_url, p.images, p.is_featured, c.name AS category_name, c.slug AS category_slug
       FROM shop_products p LEFT JOIN shop_categories c ON c.id = p.category_id
       WHERE ${where} ORDER BY p.is_featured DESC, p.created_at DESC`, params);
    res.json({ products: r.rows });
  } catch (err) { next(err); }
});

// GET /api/shop/categories — active categories
router.get('/categories', async (req, res, next) => {
  try {
    const r = await query('SELECT id, name, slug FROM shop_categories WHERE is_active=true ORDER BY sort_order, name');
    res.json({ categories: r.rows });
  } catch (err) { next(err); }
});

// GET /api/shop/product/:id — single product
router.get('/product/:id', async (req, res, next) => {
  try {
    const r = await query(
      `SELECT p.id, p.name, p.slug, p.description, p.price, p.compare_price, p.sku, p.stock_qty,
              p.track_stock, p.image_url, p.images, p.is_featured, p.weight_kg,
              c.name AS category_name, c.slug AS category_slug
       FROM shop_products p LEFT JOIN shop_categories c ON c.id = p.category_id
       WHERE p.id = $1::uuid AND p.is_active = true`, [req.params.id]);
    if (!r.rows[0]) return res.status(404).json({ error: 'Product not found' });
    res.json({ product: r.rows[0] });
  } catch (err) { next(err); }
});

// GET /api/shop/settings-public — delivery fee info for checkout
router.get('/settings-public', async (req, res, next) => {
  try {
    const s = await getShopSettings();
    res.json({
      default_delivery_fee: Number(s.default_delivery_fee || 0),
      free_delivery_over: s.free_delivery_over != null ? Number(s.free_delivery_over) : null,
      currency: s.currency || 'KES',
      shop_enabled: s.shop_enabled !== false,
      free_delivery_locations: (s.free_delivery_locations || '').split(',').map(x=>x.trim()).filter(Boolean)
    });
  } catch (err) { next(err); }
});

// POST /api/shop/checkout — create order + initiate STK push
router.post('/checkout', async (req, res, next) => {
  try {
    const { customer_name, customer_phone, customer_email, delivery_address, delivery_notes, items,
            needs_delivery, delivery_location, map_location } = req.body;
    if (!customer_name || !customer_phone) {
      return res.status(400).json({ error: 'Name and phone are required.' });
    }
    if (needs_delivery && !delivery_location) {
      return res.status(400).json({ error: 'Please choose a delivery location.' });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Cart is empty.' });
    }
    const settings = await getShopSettings();
    if (settings.shop_enabled === false) return res.status(403).json({ error: 'Shop is currently closed.' });

    // Resolve products server-side (never trust client prices)
    let subtotal = 0;
    const resolved = [];
    for (const it of items) {
      const pr = await query('SELECT id, name, price, image_url, stock_qty, track_stock, is_active FROM shop_products WHERE id=$1::uuid', [it.product_id]);
      const p = pr.rows[0];
      if (!p || !p.is_active) return res.status(400).json({ error: `Product unavailable: ${it.product_id}` });
      const qty = Math.max(1, parseInt(it.quantity) || 1);
      if (p.track_stock && p.stock_qty < qty) return res.status(400).json({ error: `Insufficient stock for ${p.name}` });
      const lineTotal = Number(p.price) * qty;
      subtotal += lineTotal;
      resolved.push({ product_id: p.id, product_name: p.name, product_image: p.image_url || null, unit_price: Number(p.price), quantity: qty, line_total: lineTotal });
    }

    // Delivery logic (location-based).
    // needs_delivery=false -> pickup (no fee). In free list -> free. Otherwise -> fee arranged later.
    let deliveryFee = 0;
    let deliveryType = 'none';
    let deliveryLoc = null;
    if (needs_delivery) {
      deliveryLoc = String(delivery_location || '').trim();
      const freeList = (settings.free_delivery_locations || '').split(',').map(x => x.trim().toLowerCase()).filter(Boolean);
      if (deliveryLoc && deliveryLoc.toLowerCase() !== 'other' && freeList.includes(deliveryLoc.toLowerCase())) {
        deliveryType = 'free'; deliveryFee = 0;
      } else {
        // "Other" / not in list -> fee arranged after; customer pays subtotal now
        deliveryType = 'paid_pending'; deliveryFee = 0;
      }
    }
    const total = subtotal + deliveryFee;

    // Create order
    const orderNumber = genOrderNumber(settings.order_prefix);
    const ordRes = await query(
      `INSERT INTO shop_orders (order_number, customer_name, customer_phone, customer_email, delivery_address, delivery_notes, delivery_type, delivery_location, map_location, subtotal, delivery_fee, total, status, payment_status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'pending_payment','pending') RETURNING id, order_number`,
      [orderNumber, customer_name, customer_phone, customer_email || null, (delivery_address || deliveryLoc || 'Pickup'), delivery_notes || null, deliveryType, deliveryLoc, (needs_delivery && map_location ? String(map_location).slice(0,500) : null), subtotal, deliveryFee, total]);
    const order = ordRes.rows[0];

    // Insert items
    for (const r of resolved) {
      await query(
        `INSERT INTO shop_order_items (order_id, product_id, product_name, product_image, unit_price, quantity, line_total)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [order.id, r.product_id, r.product_name, r.product_image, r.unit_price, r.quantity, r.line_total]);
    }

    // STK push via admin credentials
    const creds = await getAdminMpesaCreds();
    if (!creds || !creds.consumer_key) {
      return res.status(503).json({ error: 'Payment not configured. Contact admin.', order_number: orderNumber });
    }
    const baseUrl = creds.is_sandbox ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke';
    const callbackUrl = `${process.env.BASE_URL || 'https://rumalinkenterprise.online'}/api/shop/mpesa-callback/${order.id}`;

    // Create pending shop_payment
    await query(`INSERT INTO shop_payments (order_id, amount, phone_number, status) VALUES ($1,$2,$3,'pending')`,
      [order.id, total, customer_phone]);

    try {
      const stk = await stkPush({
        creds, baseUrl, phone: customer_phone, amount: Math.ceil(total),
        accountRef: orderNumber, transactionDesc: `Order ${orderNumber}`, callbackUrl
      });
      const checkoutId = stk.stkData?.CheckoutRequestID || null;
      if (checkoutId) {
        await query('UPDATE shop_orders SET mpesa_checkout_id=$1 WHERE id=$2::uuid', [checkoutId, order.id]);
        await query('UPDATE shop_payments SET mpesa_checkout_id=$1 WHERE order_id=$2::uuid', [checkoutId, order.id]);
      }
      res.json({ success: true, order_number: orderNumber, order_id: order.id, total, checkout_id: checkoutId, message: 'Check your phone to complete payment.' });
    } catch (stkErr) {
      logger.error('shop STK error: ' + stkErr.message);
      res.status(502).json({ error: 'Could not initiate payment: ' + stkErr.message, order_number: orderNumber, order_id: order.id });
    }
  } catch (err) { next(err); }
});

// POST /api/shop/mpesa-callback/:orderId — M-Pesa confirms payment
router.post('/mpesa-callback/:orderId', async (req, res) => {
  const orderId = req.params.orderId;
  try {
    const cb = req.body && req.body.Body && req.body.Body.stkCallback;
    if (cb && cb.ResultCode === 0) {
      const items = (cb.CallbackMetadata && cb.CallbackMetadata.Item) || [];
      const g = n => { const f = items.find(x => x.Name === n); return f ? f.Value : null; };
      const receipt = g('MpesaReceiptNumber');
      const payerPhone = g('PhoneNumber');
      const payerAmount = g('Amount');
      const cbCheckoutId = cb.CheckoutRequestID || null;
      const ord = await query("SELECT id, status, payment_status, total, mpesa_checkout_id FROM shop_orders WHERE id=$1::uuid", [orderId]);
      const o = ord.rows[0];
      // SECURITY: verify this callback genuinely matches our STK request, not a forgery.
      // 1) CheckoutRequestID must match the one we stored when initiating payment.
      // 2) Paid amount must match the order total (STK amount was Math.ceil(total)).
      const idOk = o && o.mpesa_checkout_id && cbCheckoutId && String(o.mpesa_checkout_id) === String(cbCheckoutId);
      const amtOk = o && payerAmount != null && Math.abs(Number(payerAmount) - Math.ceil(Number(o.total))) < 0.5;
      if (o && o.payment_status !== 'paid' && !(idOk && amtOk)) {
        logger.warn(`shop callback REJECTED (order ${orderId}): idOk=${idOk} amtOk=${amtOk} cbId=${cbCheckoutId} amt=${payerAmount}`);
        return res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
      }
      if (o && o.payment_status !== 'paid') {
        await query("UPDATE shop_orders SET payment_status='paid', status='paid', mpesa_receipt=$1, paid_at=NOW(), updated_at=NOW() WHERE id=$2::uuid", [receipt, orderId]);
        await query("UPDATE shop_payments SET status='paid', mpesa_receipt=$1, phone_number=COALESCE(phone_number,$2), raw_callback=$3::jsonb, updated_at=NOW() WHERE order_id=$4::uuid",
          [receipt, payerPhone ? String(payerPhone) : null, JSON.stringify(req.body), orderId]);
        // Decrement stock
        const its = await query("SELECT product_id, quantity FROM shop_order_items WHERE order_id=$1::uuid", [orderId]);
        for (const it of its.rows) {
          if (it.product_id) await query("UPDATE shop_products SET stock_qty = GREATEST(0, stock_qty - $1) WHERE id=$2::uuid AND track_stock=true", [it.quantity, it.product_id]);
        }
        // Trigger admin notification (Phase 5) — mark for processing
        try { await require('../utils/shopNotify').notifyNewOrder(orderId); } catch (e) { logger.warn('shop notify skipped: ' + e.message); }
      }
    } else if (cb) {
      await query("UPDATE shop_orders SET payment_status='failed', updated_at=NOW() WHERE id=$1::uuid AND payment_status='pending'", [orderId]);
      await query("UPDATE shop_payments SET status='failed', raw_callback=$1::jsonb WHERE order_id=$2::uuid AND status='pending'", [JSON.stringify(req.body), orderId]);
    }
  } catch (e) { logger.error('shop mpesa cb: ' + e.message); }
  res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
});

// GET /api/shop/track/:orderNumber — customer order tracking
router.get('/track/:orderNumber', async (req, res, next) => {
  try {
    const r = await query(
      `SELECT order_number, customer_name, status, payment_status, subtotal, delivery_fee, total, created_at, paid_at
       FROM shop_orders WHERE order_number = $1`, [req.params.orderNumber.toUpperCase()]);
    if (!r.rows[0]) return res.status(404).json({ error: 'Order not found' });
    const items = await query('SELECT product_name, unit_price, quantity, line_total FROM shop_order_items WHERE order_id=(SELECT id FROM shop_orders WHERE order_number=$1)', [req.params.orderNumber.toUpperCase()]);
    res.json({ order: r.rows[0], items: items.rows });
  } catch (err) { next(err); }
});

// GET /api/shop/order-status/:orderId — poll payment status (for checkout page)
router.get('/order-status/:orderId', async (req, res, next) => {
  try {
    const r = await query('SELECT order_number, status, payment_status FROM shop_orders WHERE id=$1::uuid', [req.params.orderId]);
    if (!r.rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(r.rows[0]);
  } catch (err) { next(err); }
});

// ============================================================
// ADMIN (requires superadmin)
// ============================================================
const admin = express.Router();
admin.use(authenticateToken, requireAdmin);

// POST /api/shop/admin/upload — upload a product image, returns { url }
admin.post('/upload', _shopUpload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  try {
    const url = await _saveProductImage(req.file.buffer, req.file.originalname);
    res.json({ url });
  } catch (e) {
    logger.error('shop image optimize: ' + e.message);
    res.status(500).json({ error: 'Image processing failed' });
  }
});

// --- Products ---
admin.get('/products', async (req, res, next) => {
  try {
    const r = await query(
      `SELECT p.*, c.name AS category_name FROM shop_products p
       LEFT JOIN shop_categories c ON c.id=p.category_id ORDER BY p.created_at DESC`);
    res.json({ products: r.rows });
  } catch (err) { next(err); }
});
admin.post('/products', async (req, res, next) => {
  try {
    const { name, description, price, compare_price, category_id, sku, stock_qty, track_stock, image_url, images, is_active, is_featured, weight_kg, supplier_name, supplier_phone, supplier_price } = req.body;
    if (!name || price == null) return res.status(400).json({ error: 'Name and price are required.' });
    const r = await query(
      `INSERT INTO shop_products (name, slug, description, price, compare_price, category_id, sku, stock_qty, track_stock, image_url, images, is_active, is_featured, weight_kg, supplier_name, supplier_phone, supplier_price)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17) RETURNING *`,
      [name, slugify(name), description || null, price, compare_price || null, category_id || null, sku || null,
       parseInt(stock_qty) || 0, track_stock !== false, image_url || null, JSON.stringify(images || []),
       is_active !== false, !!is_featured, weight_kg || null,
       supplier_name || null, supplier_phone || null, supplier_price != null && supplier_price !== '' ? supplier_price : null]);
    res.json({ product: r.rows[0] });
  } catch (err) { next(err); }
});
admin.put('/products/:id', async (req, res, next) => {
  try {
    const { name, description, price, compare_price, category_id, sku, stock_qty, track_stock, image_url, images, is_active, is_featured, weight_kg, supplier_name, supplier_phone, supplier_price } = req.body;
    const r = await query(
      `UPDATE shop_products SET
        name=COALESCE($1,name), description=COALESCE($2,description), price=COALESCE($3,price),
        compare_price=$4, category_id=$5, sku=$6, stock_qty=COALESCE($7,stock_qty),
        track_stock=COALESCE($8,track_stock), image_url=$9, images=COALESCE($10,images),
        is_active=COALESCE($11,is_active), is_featured=COALESCE($12,is_featured), weight_kg=$13,
        supplier_name=$15, supplier_phone=$16, supplier_price=$17, updated_at=NOW()
       WHERE id=$14::uuid RETURNING *`,
      [name || null, description || null, price != null ? price : null, compare_price || null, category_id || null,
       sku || null, stock_qty != null ? parseInt(stock_qty) : null, track_stock, image_url || null,
       images ? JSON.stringify(images) : null, is_active, is_featured, weight_kg || null, req.params.id,
       supplier_name || null, supplier_phone || null, supplier_price != null && supplier_price !== '' ? supplier_price : null]);
    if (!r.rows[0]) return res.status(404).json({ error: 'Product not found' });
    res.json({ product: r.rows[0] });
  } catch (err) { next(err); }
});
admin.delete('/products/:id', async (req, res, next) => {
  try {
    await query('DELETE FROM shop_products WHERE id=$1::uuid', [req.params.id]);
    res.json({ message: 'Product deleted' });
  } catch (err) { next(err); }
});

// --- Categories ---
admin.get('/categories', async (req, res, next) => {
  try {
    const r = await query('SELECT * FROM shop_categories ORDER BY sort_order, name');
    res.json({ categories: r.rows });
  } catch (err) { next(err); }
});
admin.post('/categories', async (req, res, next) => {
  try {
    const { name, sort_order } = req.body;
    if (!name) return res.status(400).json({ error: 'Name required' });
    const r = await query('INSERT INTO shop_categories (name, slug, sort_order) VALUES ($1,$2,$3) RETURNING *',
      [name, slugify(name), parseInt(sort_order) || 0]);
    res.json({ category: r.rows[0] });
  } catch (err) { next(err); }
});
admin.delete('/categories/:id', async (req, res, next) => {
  try {
    await query('DELETE FROM shop_categories WHERE id=$1::uuid', [req.params.id]);
    res.json({ message: 'Category deleted' });
  } catch (err) { next(err); }
});

// --- Orders ---
admin.get('/orders', async (req, res, next) => {
  try {
    const { status, q } = req.query;
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 25));
    const offset = (page - 1) * limit;
    const params = [];
    let where = '1=1';
    if (status) { params.push(status); where += ` AND status=$${params.length}`; }
    if (q && q.trim()) {
      params.push('%' + q.trim() + '%');
      const i = params.length;
      where += ` AND (order_number ILIKE $${i} OR customer_phone ILIKE $${i} OR customer_name ILIKE $${i} OR delivery_address ILIKE $${i} OR delivery_location ILIKE $${i} OR mpesa_receipt ILIKE $${i})`;
    }
    const countRes = await query(`SELECT COUNT(*)::int AS total FROM shop_orders WHERE ${where}`, params);
    const total = countRes.rows[0].total;
    params.push(limit); params.push(offset);
    const r = await query(
      `SELECT id, order_number, customer_name, customer_phone, delivery_address, delivery_type, delivery_location, map_location,
              subtotal, delivery_fee, total, status, payment_status, mpesa_receipt, created_at, paid_at
       FROM shop_orders WHERE ${where} ORDER BY created_at DESC LIMIT $${params.length-1} OFFSET $${params.length}`, params);
    res.json({ orders: r.rows, total, page, limit, pages: Math.ceil(total / limit) });
  } catch (err) { next(err); }
});
admin.get('/orders/:id', async (req, res, next) => {
  try {
    const o = await query('SELECT * FROM shop_orders WHERE id=$1::uuid', [req.params.id]);
    if (!o.rows[0]) return res.status(404).json({ error: 'Order not found' });
    const items = await query(
      `SELECT oi.*, COALESCE(oi.product_image, p.image_url) AS image_url
       FROM shop_order_items oi LEFT JOIN shop_products p ON p.id = oi.product_id
       WHERE oi.order_id=$1::uuid`, [req.params.id]);
    res.json({ order: o.rows[0], items: items.rows });
  } catch (err) { next(err); }
});
admin.put('/orders/:id/status', async (req, res, next) => {
  try {
    const { status } = req.body;
    const allowed = ['pending_payment', 'paid', 'processing', 'delivered', 'cancelled'];
    if (!allowed.includes(status)) return res.status(400).json({ error: 'Invalid status' });
    const r = await query('UPDATE shop_orders SET status=$1, updated_at=NOW() WHERE id=$2::uuid RETURNING id, status', [status, req.params.id]);
    if (!r.rows[0]) return res.status(404).json({ error: 'Order not found' });
    res.json({ order: r.rows[0] });
  } catch (err) { next(err); }
});

// --- Revenue (shop-only, separated) ---
admin.get('/revenue', async (req, res, next) => {
  try {
    const r = await query(
      `SELECT
        COALESCE(SUM(total) FILTER (WHERE payment_status='paid'),0) AS total_revenue,
        COALESCE(SUM(total) FILTER (WHERE payment_status='paid' AND paid_at >= date_trunc('month', NOW() AT TIME ZONE 'Africa/Nairobi') AT TIME ZONE 'Africa/Nairobi'),0) AS month_revenue,
        COALESCE(SUM(total) FILTER (WHERE payment_status='paid' AND paid_at >= date_trunc('day', NOW() AT TIME ZONE 'Africa/Nairobi') AT TIME ZONE 'Africa/Nairobi'),0) AS today_revenue,
        COALESCE(SUM(delivery_fee) FILTER (WHERE payment_status='paid'),0) AS total_delivery_fees,
        COUNT(*) FILTER (WHERE payment_status='paid') AS paid_orders,
        COUNT(*) FILTER (WHERE status='pending_payment') AS pending_orders
       FROM shop_orders`);
    res.json(r.rows[0]);
  } catch (err) { next(err); }
});

// --- Order notifications (badge) ---
admin.get('/unseen-count', async (req, res, next) => {
  try {
    const r = await query("SELECT COUNT(*)::int AS n FROM shop_orders WHERE payment_status='paid' AND admin_seen=false");
    res.json({ count: r.rows[0].n });
  } catch (err) { next(err); }
});
admin.post('/mark-seen', async (req, res, next) => {
  try {
    await query("UPDATE shop_orders SET admin_seen=true WHERE payment_status='paid' AND admin_seen=false");
    res.json({ success: true });
  } catch (err) { next(err); }
});

// --- Settings ---
admin.get('/settings', async (req, res, next) => {
  try {
    const s = await getShopSettings();
    res.json({
      default_delivery_fee: Number(s.default_delivery_fee || 0),
      free_delivery_over: s.free_delivery_over,
      currency: s.currency || 'KES',
      shop_enabled: s.shop_enabled !== false,
      whatsapp_enabled: !!s.whatsapp_enabled,
      whatsapp_phone_id: s.whatsapp_phone_id ? '***SET***' : '',
      whatsapp_token: s.whatsapp_token ? '***SET***' : '',
      whatsapp_admin_numbers: s.whatsapp_admin_numbers || '',
      order_prefix: s.order_prefix || 'RL',
      free_delivery_locations: s.free_delivery_locations || ''
    });
  } catch (err) { next(err); }
});
admin.put('/settings', async (req, res, next) => {
  try {
    const { default_delivery_fee, free_delivery_over, shop_enabled, whatsapp_enabled, whatsapp_phone_id, whatsapp_token, whatsapp_admin_numbers, order_prefix } = req.body;
    // Only overwrite whatsapp creds if a real value (not the masked ***SET***) is provided
    const s = await getShopSettings();
    const newPhoneId = (whatsapp_phone_id && whatsapp_phone_id !== '***SET***') ? whatsapp_phone_id : s.whatsapp_phone_id;
    const newToken = (whatsapp_token && whatsapp_token !== '***SET***') ? whatsapp_token : s.whatsapp_token;
    await query(
      `UPDATE shop_settings SET
        default_delivery_fee=COALESCE($1,default_delivery_fee),
        free_delivery_over=$2,
        shop_enabled=COALESCE($3,shop_enabled),
        whatsapp_enabled=COALESCE($4,whatsapp_enabled),
        whatsapp_phone_id=$5, whatsapp_token=$6,
        whatsapp_admin_numbers=COALESCE($7,whatsapp_admin_numbers),
        order_prefix=COALESCE($8,order_prefix),
        free_delivery_locations=COALESCE($9,free_delivery_locations),
        updated_at=NOW() WHERE id=1`,
      [default_delivery_fee != null ? default_delivery_fee : null,
       free_delivery_over != null && free_delivery_over !== '' ? free_delivery_over : null,
       shop_enabled, whatsapp_enabled, newPhoneId || null, newToken || null,
       whatsapp_admin_numbers != null ? whatsapp_admin_numbers : null, order_prefix || null,
       req.body.free_delivery_locations != null ? req.body.free_delivery_locations : null]);
    res.json({ success: true, message: 'Shop settings saved.' });
  } catch (err) { next(err); }
});

router.use('/admin', admin);
module.exports = router;
