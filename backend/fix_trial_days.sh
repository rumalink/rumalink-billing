#!/usr/bin/env bash
#
# fix_trial_days.sh — every ISP gets a 30-day trial regardless of policy.
#
# trial_ends_at has a COLUMN DEFAULT of now() + '30 days', and auth.js never sets it. So the trial
# length is decided by the schema, is invisible from the admin dashboard, and cannot be changed
# without a migration. Whatever was configured for three days had nowhere to be stored —
# platform_settings has no trial row and admin/dashboard.html has no trial field.
#
# The signup route already reads sms_signup_bonus from platform_settings with a fallback; trial
# days follow the same pattern, so there is one way this works rather than two.
#
# Rumalink's own record is NOT touched here — moving a live account's trial end changes when it
# starts being billed, and that is your decision, not a side effect of a bug fix. The options are
# printed at the end.
#
set -uo pipefail
BE=/var/www/rumalink/backend
TS=$(date +%s)
G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Where the 30 days comes from"
q -c "SELECT column_name, column_default FROM information_schema.columns WHERE table_name='isps' AND column_name='trial_ends_at';"
q -c "SELECT key, value FROM platform_settings ORDER BY key;"

say "2) Store the trial length where it can be configured"
q -c "INSERT INTO platform_settings (key, value) VALUES ('trial_days', 3)
      ON CONFLICT (key) DO NOTHING;"
q -c "SELECT key, value FROM platform_settings WHERE key='trial_days';"

say "3) Have signup read it"
sudo cp "$BE/routes/auth.js" "$BE/routes/.auth.js.bak_$TS" && echo "   auth.js"
sudo python3 - "$BE/routes/auth.js" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if 'RL_TRIAL_DAYS' in s:
    print("   already patched"); sys.exit(0)

old_cols = """        company_name, owner_name, email, phone, password_hash, plan_type,
        county, town, email_verify_token, status
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'active')"""
new_cols = """        company_name, owner_name, email, phone, password_hash, plan_type,
        county, town, email_verify_token, status, trial_ends_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'active', NOW() + ($10 || ' days')::interval)"""
if old_cols not in s:
    print("   ERROR: insert columns not found"); sys.exit(1)
s = s.replace(old_cols, new_cols, 1)

old_params = "`, [company_name, owner_name, email, phone, password_hash, plan_type, county, town, verify_token]);"
new_params = "`, [company_name, owner_name, email, phone, password_hash, plan_type, county, town, verify_token, String(_trialDays)]);"
if old_params not in s:
    print("   ERROR: insert params not found"); sys.exit(1)
s = s.replace(old_params, new_params, 1)

anchor = "    const result = await query(`"
lead = """    /* RL_TRIAL_DAYS: trial_ends_at was left to the column default of now() + '30 days', so every
       ISP got thirty days whatever the policy said — and the length could not be changed without
       a migration. Read it from platform_settings, the same way the signup bonus just below does,
       so there is one place it lives and the admin dashboard can set it. */
    let _trialDays = 3;
    try {
      const _td = await query("SELECT value FROM platform_settings WHERE key='trial_days' LIMIT 1");
      if (_td.rows[0] && _td.rows[0].value != null) {
        const _n = parseInt(_td.rows[0].value, 10);
        if (Number.isFinite(_n) && _n >= 0) _trialDays = _n;
      }
    } catch (e) { require('../utils/logger').warn('[signup] trial_days lookup: ' + e.message); }

"""
s = s.replace(anchor, lead + anchor, 1)
open(p,'w').write(s); print("   signup now sets trial_ends_at from platform_settings")
PY
cd "$BE" && sudo -u www-data node --check routes/auth.js && echo "   auth.js OK"

say "4) Drop the column default so nothing overrides it silently again"
q -c "ALTER TABLE isps ALTER COLUMN trial_ends_at DROP DEFAULT;"
q -c "SELECT column_name, column_default FROM information_schema.columns WHERE table_name='isps' AND column_name='trial_ends_at';"
echo "   ${Y}signup now decides this explicitly; a NULL here would be visible rather than silently 30 days${N}"

say "5) Restart + verify with a dry run"
sudo pm2 restart rumalink-backend --update-env >/dev/null 2>&1; sleep 8
q -c "SELECT NOW() AS now, NOW() + ((SELECT value FROM platform_settings WHERE key='trial_days')::text || ' days')::interval AS a_new_isp_would_end;"
pm2 logs rumalink-backend --lines 15 --nostream 2>/dev/null | grep -iE "error" | tail -3 | sed 's/^/   /' || echo "   clean"

say "6) Rumalink's own trial — your call, not mine"
q -c "SELECT company_name, created_at, trial_ends_at, license_status FROM isps;"
cat <<'EOS'
   Its record still says 2026-09-02 (the old 30-day default). Three options:

   a) Apply the 3-day policy retroactively — the trial ended 6 Aug, billing starts from then:
      sudo -u postgres psql -d rumalink_db -c "UPDATE isps SET trial_ends_at = created_at + INTERVAL '3 days', billing_window_start = created_at + INTERVAL '3 days';"

   b) End the trial now, bill from today:
      sudo -u postgres psql -d rumalink_db -c "UPDATE isps SET trial_ends_at = NOW(), billing_window_start = NOW();"

   c) Leave it — grandfather the account on the terms it signed up under.

   I have not run any of these. Changing when a live account starts being charged is a business
   decision, and (a) backdates a bill for days already used.
EOS

say "7) Still open"
cat <<'EOS'
   - The admin dashboard has no trial-days field; the value is settable in platform_settings but
     not yet in the UI.
   - license_expires_at is NULL, so once a trial ends the billing page will show "Expires: —".
     Whatever activates a licence after trial needs to set it.
EOS

say "8) Commit"
sudo git -C /var/www/rumalink add -A 2>/dev/null
sudo git -C /var/www/rumalink commit -qm "Trial length read from platform_settings at signup instead of a hidden 30-day column default" 2>&1 | head -2 | sed 's/^/   /'
