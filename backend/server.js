require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const { createServer } = require('http');
const { Server } = require('socket.io');
const path = require('path');
const logger = require('./utils/logger');
const { connectDB } = require('./config/database');

const app = express();
app.set('trust proxy', 1); /* RL_TRUST_PROXY: behind nginx — rate-limit per real client IP, not per nginx */
const httpServer = createServer(app);

const io = new Server(httpServer, {
  cors: { origin: process.env.ALLOWED_ORIGINS?.split(',') || '*', methods: ['GET', 'POST'] }
});
app.set('io', io);
io.on('connection', (socket) => {
  socket.on('join_isp', (ispId) => socket.join(`isp_${ispId}`));
  socket.on('join_admin', () => socket.join('admin'));
});

app.use(helmet({ contentSecurityPolicy: false }));
app.use(compression());
app.use(morgan('combined', { stream: { write: (msg) => logger.info(msg.trim()) } }));
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key']
}));

const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 900000,
  max: parseInt(process.env.RATE_LIMIT_MAX) || 1000,
  skip: (req) => req.path.startsWith('/provision/') || req.path.includes('/callback/') || req.path.includes('/payment-status/') || req.path.startsWith('/webhooks/'),
  standardHeaders: true, legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' }
});
app.use('/api/', limiter);
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use((req, res, next) => {
  // Let multer handle multipart/form-data (file uploads) — skip the text catch-all below,
  // which would otherwise try to URI-decode binary and throw 'URI malformed'.
  const ct = req.headers['content-type'] || '';
  if (ct.indexOf('multipart/form-data') !== -1) return next();
  return express.text({ type: ['text/*','application/octet-stream','*/*'], limit: '10mb' })(req, res, next);
});
app.use((req, res, next) => {
  if (typeof req.body === 'string' && req.body.length > 0) {
    const parsed = {};
    req.body.split('&').forEach(pair => { const i = pair.indexOf('='); if (i>-1){ parsed[decodeURIComponent(pair.slice(0,i).trim())] = decodeURIComponent(pair.slice(i+1).trim()); } });
    req.body = parsed;
  }
  if (!req.body || typeof req.body !== 'object') req.body = {};
  next();
});
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ── ROUTES ──
app.use('/api/auth', require('./routes/auth'));
app.use('/api/admin', require('./routes/admin'));
app.use('/api/isp', require('./routes/isp'));
app.use('/api/nas', require('./routes/nas'));
app.use('/api/hotspot', require('./routes/hotspot'));
app.use('/api/pppoe', require('./routes/pppoe'));
app.use('/api/payments', require('./routes/payments'));
app.use('/api/withdrawals', require('./routes/withdrawals'));  // IntaSend withdrawals
app.use('/api/payment-methods', require('./routes/paymentMethods'));  // NEW
app.use('/api/portal-settings', require('./routes/portalSettings'));  // NEW
app.use('/api/public', require('./routes/public'));  // NEW: public pricing/rates
app.use('/api/captive', require('./routes/captive'));                  // NEW
app.use('/api/pppoe-portal', require('./routes/pppoePortal'));
app.use('/api/vouchers', require('./routes/vouchers'));
app.use('/api/reports', require('./routes/reports'));
app.use('/api/sms', require('./routes/sms'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/radius', require('./routes/radius'));
app.use('/api/support', require('./routes/support'));
app.use('/api/provision', require('./routes/provision'));
app.use('/api/shop', require('./routes/shop'));  // e-commerce

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'RumaLink Enterprise API', timestamp: new Date() });
});

app.use((err, req, res, next) => {
  logger.error(err.stack);
  res.status(err.status || 500).json({
    error: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message
  });
});
app.use((req, res) => res.status(404).json({ error: 'Route not found' }));

require('./utils/cron');

const PORT = process.env.PORT || 5000;
async function start() {
  try {
    await connectDB();
    logger.info('✅ Database connected');
    httpServer.listen(PORT, () => {
      logger.info(`🚀 RumaLink Enterprise API running on port ${PORT}`);
    });
  } catch (err) {
    logger.error('Failed to start server:', err);
    process.exit(1);
  }
}
start();

// ─── v56: M-Pesa token warmer (avoids first-request OAuth latency) ───
// mpesa-token-warmer
setTimeout(async () => {
  try {
    const { query } = require('./config/database');
    const mpesaService = require('./utils/mpesa');
    const r = await query(`
      SELECT DISTINCT consumer_key, consumer_secret, shortcode, passkey, environment
      FROM isp_payment_methods
      WHERE provider = 'mpesa' AND is_active = true
        AND consumer_key IS NOT NULL AND consumer_secret IS NOT NULL
    `);
    for (const m of r.rows) {
      const baseUrl = m.environment === 'production'
        ? 'https://api.safaricom.co.ke'
        : 'https://sandbox.safaricom.co.ke';
      await mpesaService.warmToken({
        consumer_key: m.consumer_key,
        consumer_secret: m.consumer_secret,
        shortcode: m.shortcode,
        passkey: m.passkey
      }, baseUrl);
    }
    require('./utils/logger').info(`[STARTUP] M-Pesa token warmer: warmed ${r.rows.length} shortcodes`);
  } catch (e) {
    require('./utils/logger').warn(`[STARTUP] token warmer failed: ${e.message}`);
  }
}, 5000);

module.exports = { app, io };
