#!/usr/bin/env node
// scripts/migrate.js — Run this once to set up the database
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'rumalink_db',
  user: process.env.DB_USER || 'rumalink_user',
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

async function migrate() {
  console.log('🚀 Running RumaLink database migrations...');
  try {
    const schemaPath = path.join(__dirname, '../../database/schema.sql');
    const sql = fs.readFileSync(schemaPath, 'utf8');
    await pool.query(sql);
    console.log('✅ Database schema created successfully!');
    console.log('');
    console.log('Default admin credentials:');
    console.log('  Email:    admin@rumalink.co.ke');
    console.log('  Password: Admin@2024!');
    console.log('');
    console.log('⚠️  Change the admin password immediately after first login!');
  } catch (err) {
    if (err.message.includes('already exists')) {
      console.log('⚠️  Some objects already exist — schema may already be applied.');
    } else {
      console.error('❌ Migration failed:', err.message);
      process.exit(1);
    }
  } finally {
    await pool.end();
  }
}

migrate();
