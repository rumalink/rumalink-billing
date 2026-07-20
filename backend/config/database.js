const { Pool } = require('pg');
const logger = require('../utils/logger');

// CRITICAL: Force all credentials to be strings.
// Some Node/dotenv versions coerce numeric-looking values to numbers,
// which breaks PostgreSQL SASL authentication.
const dbConfig = {
  host:     String(process.env.DB_HOST || 'localhost'),
  port:     parseInt(process.env.DB_PORT, 10) || 5432,
  database: String(process.env.DB_NAME || 'rumalink_db'),
  user:     String(process.env.DB_USER || 'rumalink_user'),
  password: String(process.env.DB_PASSWORD || ''),
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
};

// Sanity check: warn loudly if password is missing
if (!dbConfig.password) {
  logger.error('CRITICAL: DB_PASSWORD is empty! Set it in .env');
}

const pool = new Pool(dbConfig);

pool.on('error', (err) => {
  logger.error('Unexpected PostgreSQL pool error:', err.message);
});

const connectDB = async () => {
  const client = await pool.connect();
  try {
    const result = await client.query('SELECT NOW() as time, current_database() as db, current_user as user');
    logger.info(`PostgreSQL connected: db=${result.rows[0].db} user=${result.rows[0].user}`);
  } finally {
    client.release();
  }
};

const query = (text, params) => pool.query(text, params);
const getClient = () => pool.connect();

module.exports = { pool, query, connectDB, getClient };
