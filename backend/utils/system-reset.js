// RL_SYSTEM_RESET: wipe test data, preserve platform config. Backup-first, single transaction.
const { query } = require('../config/database');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');
const logger = require('./logger');

// Tables to WIPE (order not critical — we disable triggers within the txn — but we TRUNCATE with
// CASCADE on the isps-rooted set + the RADIUS + logs). Config tables are intentionally absent.
const WIPE = [
  // per-ISP + payment graph
  'commissions','isp_platform_invoices','pppoe_invoices','mpesa_transactions',
  'payments','intasend_withdrawals','isp_transactions',
  'hotspot_sessions','pppoe_sessions','hotspot_vouchers','voucher_batches','mac_auth_cache',
  'hotspot_packages','pppoe_subscribers','pppoe_packages',
  'isp_captive_portal','isp_payment_methods','mpesa_configs',
  'nas_wan_policies','nas_wan_links','nas_events','nas_devices',
  'sms_credit_transactions','sms_logs',
  'support_replies','support_tickets',
  'notifications',
  'usage_daily','usage_daily_pre_fix','usage_session_state','usage_session_state_v2','wan_usage_monthly',
  '_mac_delete_log','_radreply_audit','audit_logs',
  // shop orders (keep catalog: shop_categories, shop_products, shop_settings)
  'shop_payments','shop_order_items','shop_orders',
  // RADIUS runtime
  'radcheck','radreply','radacct','radpostauth','radusergroup','radgroupcheck','radgroupreply','nasreload','nas',
  // finally the ISPs themselves
  'isps',
];

// NEVER touched: admins, platform_settings, payment_provider_configs, platform_secrets,
// sms_provider_config, shop_settings, shop_categories, shop_products.

async function backup() {
  const dir = '/var/www/rumalink/backups';
  fs.mkdirSync(dir, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const file = path.join(dir, `pre-reset-${stamp}.sql`);
  const db = process.env.DB_NAME || 'rumalink_db';
  return new Promise((resolve, reject) => {
    // Use the postgres superuser locally (peer auth) to dump.
    exec(`sudo -u postgres pg_dump ${db} > "${file}"`, { maxBuffer: 1024*1024*512 }, (err) => {
      if (err) return reject(new Error('backup failed: ' + err.message));
      const sz = fs.existsSync(file) ? fs.statSync(file).size : 0;
      if (sz < 1000) return reject(new Error('backup too small — aborting'));
      resolve({ file, size: sz });
    });
  });
}

async function resetToProduction() {
  // 1) backup first — abort if it fails
  const bk = await backup();
  logger.info('[system-reset] backup ok: ' + bk.file + ' (' + bk.size + ' bytes)');

  // 2) RL_WIPE_SUPERUSER: wipe as the postgres superuser. rumalink_user (the app user) does not
  //    own all objects (8 tables + 1 sequence are owned by postgres), so TRUNCATE ... RESTART
  //    IDENTITY fails through the app connection. Run it the same way backup/restore do.
  const { exec } = require('child_process');
  const list = WIPE.map(t => '"' + t + '"').join(', ');
  const db = process.env.DB_NAME || 'rumalink_db';
  const sql = 'BEGIN; TRUNCATE ' + list + ' RESTART IDENTITY CASCADE; COMMIT;';
  await new Promise((resolve, reject) => {
    // pass SQL via stdin to avoid shell-quoting issues; ON_ERROR_STOP makes psql fail the whole run
    const child = exec('sudo -u postgres psql -d ' + db + ' -v ON_ERROR_STOP=1',
      { maxBuffer: 1024*1024*64 }, (err, stdout, stderr) => {
        if (err) return reject(new Error('wipe failed: ' + String(stderr||err.message).slice(0,400)));
        resolve(stdout);
      });
    child.stdin.write(sql);
    child.stdin.end();
  });
  logger.info('[system-reset] wipe complete');
  return { ok: true, backup: bk.file, backup_size: bk.size, wiped: WIPE.length };
}

module.exports = { resetToProduction, WIPE };
