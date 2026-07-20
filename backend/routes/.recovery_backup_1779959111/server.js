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
  max: parseInt(process.env.RATE_LIMIT_MAX) || 200,
  standardHeaders: true, legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' }
});
app.use('/api/', limiter);
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ── ROUTES ──
app.use('/api/auth', require('./routes/auth'));
app.use('/api/admin', require('./routes/admin'));
app.use('/api/isp', require('./routes/isp'));
app.use('/api/nas', require('./routes/nas'));
app.use('/api/hotspot', require('./routes/hotspot'));
app.use('/api/pppoe', require('./routes/pppoe'));
app.use('/api/payments', require('./routes/payments'));
app.use('/api/payment-methods', require('./routes/paymentMethods'));  // NEW
app.use('/api/portal-settings', require('./routes/portalSettings'));  // NEW
app.use('/api/captive', require('./routes/captive'));                  // NEW
app.use('/api/vouchers', require('./routes/vouchers'));
app.use('/api/reports', require('./routes/reports'));
app.use('/api/sms', require('./routes/sms'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/radius', require('./routes/radius'));
app.use('/api/support', require('./routes/support'));
app.use('/api/provision', require('./routes/provision'));

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
module.exports = { app, io };
