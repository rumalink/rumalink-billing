#!/bin/bash
# v62.48: Walled-garden-aware RADIUS sync for PPPoE subscribers. Runs every minute via cron.
# - active subscribers   -> package Mikrotik-Group (or none) + rate-limit + pool
# - expired/suspended    -> Mikrotik-Group = rl-expired (walled garden), keep password so they can auth
# - truly-removed users  -> radreply/radcheck cleaned up

compute_nt_hash() {
  printf "%s" "$1" | iconv -t UTF-16LE 2>/dev/null | openssl dgst -provider legacy -provider default -md4 2>/dev/null | awk '{print toupper($NF)}'
}

PSQL_T() { sudo -u postgres psql -d rumalink_db -P pager=off -tA -c "$1"; }
PSQL() { sudo -u postgres psql -d rumalink_db -P pager=off -c "$1" > /dev/null 2>&1; }

# Part A: NT-Password sync for ALL serviceable states (active keeps internet; expired/suspended need auth to reach pay page).
USERNAMES=$(PSQL_T "SELECT username FROM pppoe_subscribers WHERE status IN ('active','expired','suspended') ORDER BY username")

for U in $USERNAMES; do
  PW=$(PSQL_T "SELECT value FROM radcheck WHERE username='$U' AND attribute='Cleartext-Password' LIMIT 1" | tr -d ' ')
  [ -z "$PW" ] && continue
  NT_HASH=$(compute_nt_hash "$PW")
  [ -z "$NT_HASH" ] && continue
  [ ${#NT_HASH} -lt 32 ] && continue
  EXISTING=$(PSQL_T "SELECT value FROM radcheck WHERE username='$U' AND attribute='NT-Password' LIMIT 1" | tr -d ' ')
  if [ "$EXISTING" != "$NT_HASH" ]; then
    PSQL "DELETE FROM radcheck WHERE username='$U' AND attribute='NT-Password'"
    PSQL "INSERT INTO radcheck (username, attribute, op, value) VALUES ('$U', 'NT-Password', ':=', '$NT_HASH')"
  fi
done

# Part B: radreply sync (walled-garden aware)
sudo -u postgres psql -d rumalink_db -P pager=off -tA <<'SQLEOF' > /dev/null 2>&1
-- Remove radreply rows ONLY for subscribers that are truly gone (not active/expired/suspended).
DELETE FROM radreply rr
USING (
  SELECT DISTINCT username FROM radreply
  WHERE username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries
    -- RL_VOUCHER_EXEMPT: prefix-agnostic voucher protection (see radcheck block below)
    AND NOT EXISTS (
      SELECT 1 FROM hotspot_vouchers v
      WHERE v.code = SPLIT_PART(radreply.username, '@', 1)
    )
) sub
LEFT JOIN pppoe_subscribers ps
  ON ps.username = sub.username AND ps.status IN ('active','expired','suspended')
WHERE rr.username = sub.username
  AND ps.id IS NULL;

-- Refresh Mikrotik-Rate-Limit for active subs (delete + insert).
DELETE FROM radreply
WHERE attribute = 'Mikrotik-Rate-Limit'
  AND username IN (SELECT username FROM pppoe_subscribers);

INSERT INTO radreply (username, attribute, op, value)
SELECT ps.username, 'Mikrotik-Rate-Limit', '=',
  COALESCE(pp.bandwidth_up_mbps, pp.bandwidth_down_mbps, 1) || 'M/' || COALESCE(pp.bandwidth_down_mbps, pp.bandwidth_up_mbps, 1) || 'M'
FROM pppoe_subscribers ps
JOIN pppoe_packages pp ON pp.id = ps.package_id
WHERE ps.status = 'active'
  AND (pp.bandwidth_down_mbps IS NOT NULL OR pp.bandwidth_up_mbps IS NOT NULL);

-- Refresh Mikrotik-Group: rebuild for active/expired/suspended.
DELETE FROM radreply
WHERE attribute = 'Mikrotik-Group'
  AND username IN (SELECT username FROM pppoe_subscribers);

-- Active subscribers -> their package profile (only if package defines one).
INSERT INTO radreply (username, attribute, op, value)
SELECT ps.username, 'Mikrotik-Group', '=', pp.mikrotik_profile
FROM pppoe_subscribers ps
JOIN pppoe_packages pp ON pp.id = ps.package_id
WHERE ps.status = 'active'
  AND pp.mikrotik_profile IS NOT NULL
  AND pp.mikrotik_profile <> '';

-- Expired/suspended subscribers -> rl-expired (walled garden). THIS is the key line.
INSERT INTO radreply (username, attribute, op, value)
SELECT ps.username, 'Mikrotik-Group', '=', 'rl-expired'
FROM pppoe_subscribers ps
WHERE ps.status IN ('expired','suspended');

-- Refresh Framed-Pool for active subs.
DELETE FROM radreply
WHERE attribute = 'Framed-Pool'
  AND username IN (SELECT username FROM pppoe_subscribers);

INSERT INTO radreply (username, attribute, op, value)
SELECT ps.username, 'Framed-Pool', '=', pp.address_pool
FROM pppoe_subscribers ps
JOIN pppoe_packages pp ON pp.id = ps.package_id
WHERE ps.status = 'active'
  AND pp.address_pool IS NOT NULL
  AND pp.address_pool <> '';

-- Clean up radcheck ONLY for truly-unknown usernames (keep active/expired/suspended).
DELETE FROM radcheck
WHERE username !~* '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'  -- RL_MAC_EXEMPT: keep MAC auto-reconnect entries
  -- RL_VOUCHER_EXEMPT: never touch hotspot voucher creds. The old test hardcoded a 'K' prefix,
  -- but voucher codes derive from the ISP's company initial (RumaLink -> R1), so any letter is
  -- valid. Match the REAL voucher table instead of guessing at the code's shape.
  AND NOT EXISTS (
    SELECT 1 FROM hotspot_vouchers v
    WHERE v.code = SPLIT_PART(radcheck.username, '@', 1)
  )
  AND NOT EXISTS (
    SELECT 1 FROM pppoe_subscribers ps
    WHERE ps.username = radcheck.username AND ps.status IN ('active','expired','suspended')
  );
SQLEOF
