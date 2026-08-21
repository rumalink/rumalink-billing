#!/usr/bin/env bash
#
# audit_radius_writers.sh — find every place that writes RADIUS credentials.
#
# radcheck and radreply now carry a unique index on (username, attribute). Any writer still doing
# a plain INSERT will throw instead of silently duplicating — better than the old behaviour, but
# it means a path we have not found will now FAIL rather than misbehave quietly. So find them all.
#
# READ ONLY. It reports; it changes nothing.
#
set -uo pipefail
BE=/var/www/rumalink/backend
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
say(){ echo; echo "${G}===== $* =====${N}"; }
q(){ sudo -u postgres psql -d rumalink_db -P pager=off "$@" 2>&1; }

say "1) Every INSERT into radcheck or radreply in live code"
echo "   (.bak, .rec2_, .v3_ and backup_ copies are excluded — they are not loaded)"
MATCHES=$(grep -rn "INSERT INTO radcheck\|INSERT INTO radreply" "$BE" \
  --include=*.js 2>/dev/null \
  | grep -vE "/\.(bak|rec2_|v3_|backup_)|/node_modules/|\.bak_" || true)
if [ -z "$MATCHES" ]; then echo "   none found"; else
  echo "$MATCHES" | while IFS= read -r line; do
    FILE=$(echo "$line" | cut -d: -f1); LNO=$(echo "$line" | cut -d: -f2)
    SNIPPET=$(sudo sed -n "${LNO},$((LNO+3))p" "$FILE" 2>/dev/null | tr '\n' ' ')
    if echo "$SNIPPET" | grep -q "ON CONFLICT"; then
      printf "   ${G}SAFE${N}   %s:%s\n" "${FILE#$BE/}" "$LNO"
    else
      printf "   ${R}PLAIN${N}  %s:%s\n" "${FILE#$BE/}" "$LNO"
      echo "$SNIPPET" | cut -c1-150 | sed 's/^/            /'
    fi
  done
fi

say "2) Anything writing credentials outside the backend"
echo "   shell scripts:"
sudo grep -rln "radcheck\|radreply" /usr/local/bin/ /etc/cron.d/ /etc/cron.daily/ 2>/dev/null | sed 's/^/     /' || echo "     none"
echo "   crontab entries mentioning radius:"
sudo crontab -l 2>/dev/null | grep -iE "radius|radcheck|rad" | sed 's/^/     /' || echo "     none"
echo "   FreeRADIUS SQL that writes (autz/accounting can INSERT):"
sudo grep -rn "INSERT INTO radcheck\|INSERT INTO radreply" /etc/freeradius/ 2>/dev/null | head -5 | sed 's/^/     /' || echo "     none"

say "3) Has anything hit the new constraint since it was created?"
sudo pm2 logs rumalink-backend --lines 800 --nostream 2>/dev/null \
  | grep -iE "ux_radcheck_user_attr|ux_radreply_user_attr|duplicate key" | tail -10 | cut -c1-170 | sed 's/^/   /' \
  || echo "   nothing yet"
echo "   ${Y}if a line appears here, that is a writer this audit should have listed${N}"

say "4) Are credentials consistent with the vouchers right now?"
q -c "SELECT count(*) AS vouchers_with_wrong_password
      FROM hotspot_vouchers v
      JOIN radcheck rc ON rc.username = v.code || '@' || lower(left(replace(v.isp_id::text,'-',''),8))
     WHERE rc.attribute='Cleartext-Password'
       AND v.password IS NOT NULL AND v.password <> ''
       AND rc.value IS DISTINCT FROM v.password;"
q -c "SELECT count(*) AS active_vouchers_with_no_credentials
      FROM hotspot_vouchers v
     WHERE v.status='active' AND (v.is_tv IS NOT TRUE)
       AND NOT EXISTS (SELECT 1 FROM radcheck rc
                       WHERE rc.username = v.code || '@' || lower(left(replace(v.isp_id::text,'-',''),8))
                         AND rc.attribute='Cleartext-Password');"
q -c "SELECT count(*) AS tv_vouchers_that_still_have_credentials
      FROM hotspot_vouchers v
     WHERE v.is_tv = true
       AND EXISTS (SELECT 1 FROM radcheck rc
                   WHERE rc.username = v.code || '@' || lower(left(replace(v.isp_id::text,'-',''),8)));"
q -c "SELECT count(*) AS pppoe_subs_with_no_credentials
      FROM pppoe_subscribers s
     WHERE s.deleted_at IS NULL
       AND NOT EXISTS (SELECT 1 FROM radcheck rc WHERE rc.username = s.username);"

say "5) Orphans — credentials with no owner"
q -c "SELECT count(*) AS radcheck_orphans FROM radcheck rc
      WHERE rc.username NOT LIKE '%:%'
        AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v
                        WHERE rc.username = v.code || '@' || lower(left(replace(v.isp_id::text,'-',''),8)))
        AND NOT EXISTS (SELECT 1 FROM pppoe_subscribers s WHERE s.username = rc.username);"
q -c "SELECT rc.username, rc.attribute FROM radcheck rc
      WHERE rc.username NOT LIKE '%:%'
        AND NOT EXISTS (SELECT 1 FROM hotspot_vouchers v
                        WHERE rc.username = v.code || '@' || lower(left(replace(v.isp_id::text,'-',''),8)))
        AND NOT EXISTS (SELECT 1 FROM pppoe_subscribers s WHERE s.username = rc.username)
      ORDER BY rc.username LIMIT 12;"

say "6) Reading this"
cat <<'EOS'
   Section 1: every PLAIN line is a writer that will now throw on a race instead of duplicating.
     Each one wants ON CONFLICT (username, attribute) DO UPDATE.
   Section 4: all four counts should be zero. A non-zero "wrong password" or "no credentials"
     means customers who cannot log in; "tv vouchers with credentials" means a television has a
     login somebody could use on a phone.
   Section 5: orphans are harmless but they accumulate, and a stale row can collide with a reissued
     code later.
EOS
