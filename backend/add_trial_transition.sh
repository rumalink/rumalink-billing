#!/usr/bin/env bash
#
# add_trial_transition.sh — nothing moves an ISP from trial to active.
#
# The invoice cron (cron.js:641) only considers ISPs with license_expires_at IS NOT NULL. An ISP
# whose trial has lapsed still has license_status='trial' and a NULL expiry, so it is invisible to
# billing — the trial simply never ends and no invoice is ever raised. Rumalink's lapsed on 6 Aug
# and nothing noticed.
#
# The sweep sets, for any ISP whose trial_ends_at has passed:
#     license_status       -> 'active'
#     billing_window_start -> trial_ends_at   (billing accrues from the moment the trial ended)
#     license_expires_at   -> trial_ends_at + 1 month
#
# It touches only rows still marked 'trial' with an elapsed date, so it cannot re-trigger, and it
# skips billing_exempt accounts.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Who is stranded in a lapsed trial"
q -c "SELECT company_name, license_status, trial_ends_at,
             trial_ends_at < NOW() AS trial_over,
             license_expires_at, billing_window_start, billing_exempt
      FROM isps ORDER BY created_at;"

say "2) What the sweep would set (dry run — nothing written)"
q -c "SELECT company_name,
             trial_ends_at AS billing_starts,
             (trial_ends_at + INTERVAL '1 month') AS license_would_expire,
             (trial_ends_at + INTERVAL '1 month') < NOW() AS already_overdue
      FROM isps
      WHERE license_status = 'trial' AND trial_ends_at IS NOT NULL
        AND trial_ends_at < NOW() AND COALESCE(billing_exempt,false) = false;"

say "3) Create utils/trial-transition.js"
sudo tee "$BE/utils/trial-transition.js" > /dev/null <<'JS'
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
JS
sudo chown www-data:www-data "$BE/utils/trial-transition.js"
sudo -u www-data node --check "$BE/utils/trial-transition.js" && echo "   trial-transition.js OK"

say "4) Register it"
sudo cp "$BE/utils/cron.js" "$BE/utils/.cron.js.bak_$TS"
if sudo grep -q "trial-transition" "$BE/utils/cron.js"; then echo "   already registered"
else echo "try { require('./trial-transition').start(); } catch (e) { require('./logger').warn('[trial-transition] start: ' + e.message); }" | sudo tee -a "$BE/utils/cron.js" >/dev/null; echo "   registered"; fi
sudo -u www-data node --check "$BE/utils/cron.js" && echo "   cron.js OK"

say "5) Restart and run it once"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
(async()=>{ await require('$BE/utils/trial-transition').pass(); console.log('   pass complete'); process.exit(0); })();" 2>&1 | grep -vE "^info: \[" | sed 's/^/  /'

say "6) The result"
q -c "SELECT company_name, license_status, trial_ends_at, billing_window_start, license_expires_at FROM isps;"
echo "   what is now owed for the window since the trial ended:"
sudo -u www-data node -e "
require('dotenv').config({path:'$BE/.env'});
const {query}=require('$BE/config/database');
(async()=>{
  const b=require('$BE/utils/billing');
  const rows=(await query('SELECT id, company_name, billing_window_start FROM isps WHERE billing_window_start IS NOT NULL')).rows;
  for (const i of rows) {
    const o = await b.computeOwed(i.id, i.billing_window_start, new Date());
    console.log('   '+i.company_name+': hotspot KES '+Number(o.hotspot_revenue||0).toFixed(2)+
      ' -> fee '+Number(o.hotspot_fee||0).toFixed(2)+
      ' | pppoe users '+(o.pppoe_users||0)+' -> '+Number(o.pppoe_fee||0).toFixed(2)+
      ' | total KES '+Number(o.total||0).toFixed(2));
  }
  process.exit(0);
})();" 2>&1 | grep -v "^info:" | sed 's/^/  /'

say "7) Check the billing page"
cat <<'EOS'
   Billing & License should now show Active, a real expiry date, days remaining, and the hotspot
   and PPPoE figures for the window since the trial ended — instead of Trial with zeros.

   The invoice cron (cron.js:641) raises an invoice five days before expiry. That now applies,
   because license_expires_at is finally set.
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "End lapsed trials and bill from the trial end date (nothing performed this transition, so trials never ended)" 2>&1 | head -2 | sed 's/^/   /'
