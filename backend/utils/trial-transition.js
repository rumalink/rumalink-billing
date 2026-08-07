// RL_TRIAL_TRANSITION — end a trial and start the billing clock.
//
// Nothing performed this step. The invoice cron only looks at ISPs with license_expires_at set,
// so an account whose trial lapsed kept license_status='trial' and a NULL expiry and was never
// billed at all — the trial effectively ran forever. Rumalink's ended on 6 August unnoticed.
//
// Billing accrues from the MOMENT THE TRIAL ENDED, not from when this sweep happens to run: an
// ISP who took payments the day their trial lapsed owes commission on them, and a sweep that
// started the window at its own runtime would quietly forgive whatever fell in between.
const { query } = require('../config/database');
const logger = require('./logger');
const billing = require('./billing');

async function pass() {
  let rows;
  try {
    rows = (await query(
      `SELECT id, company_name, trial_ends_at
         FROM isps
        WHERE license_status = 'trial'
          AND trial_ends_at IS NOT NULL
          AND trial_ends_at < NOW()
          AND COALESCE(billing_exempt, false) = false`)).rows;
  } catch (e) { logger.warn('[trial-transition] lookup: ' + e.message); return; }

  for (const isp of rows) {
    try {
      /* addMonth handles month lengths properly — a trial ending 31 January expires 28 February,
         not 3 March. */
      const expiry = billing.addMonth(new Date(isp.trial_ends_at));
      await query(
        `UPDATE isps
            SET license_status = 'active',
                billing_window_start = COALESCE(billing_window_start, trial_ends_at),
                license_expires_at = COALESCE(license_expires_at, $2)
          WHERE id = $1::uuid AND license_status = 'trial'`,
        [isp.id, expiry.toISOString()]);

      logger.info('[trial-transition] ' + isp.company_name + ': trial ended ' +
        new Date(isp.trial_ends_at).toISOString() + ' — billing from then, licence expires ' +
        expiry.toISOString());

      try {
        await query(
          `INSERT INTO notifications (isp_id, type, title, message)
           VALUES ($1::uuid, 'warning', 'Free trial ended',
                   'Your free trial ended on ' || to_char($2::timestamptz AT TIME ZONE 'Africa/Nairobi', 'DD Mon YYYY HH24:MI') ||
                   '. Billing now runs from that date and your licence is due on ' ||
                   to_char($3::timestamptz AT TIME ZONE 'Africa/Nairobi', 'DD Mon YYYY') || '.')`,
          [isp.id, isp.trial_ends_at, expiry.toISOString()]).catch(function(){});
      } catch (e) {}
    } catch (e) {
      logger.error('[trial-transition] ' + isp.company_name + ': ' + e.message);
    }
  }
}

function start() {
  setTimeout(function () { pass().catch(function () {}); }, 25000);
  setInterval(function () { pass().catch(function () {}); }, 60 * 60 * 1000);
  logger.info('[trial-transition] Registered (hourly) — ends lapsed trials and starts billing from the trial end date');
}

module.exports = { start, pass };
