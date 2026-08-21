#!/bin/bash
# v62.22b: Re-sync radcheck/radreply for ALL active vouchers (paid OR redeemed)
# Includes vouchers that are status='active' even if is_paid=false
# This catches admin-generated vouchers that were handed out for free
sudo -u postgres psql -d rumalink_db -P pager=off -tA << 'SQLEOF'
-- Remove entries for vouchers that are no longer active
DELETE FROM radcheck 
WHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K
  AND NOT EXISTS (
    SELECT 1 FROM hotspot_vouchers v
    WHERE v.status IN ('unused', 'active')
      AND (v.expires_at IS NULL OR v.expires_at > NOW())
      AND v.code = SPLIT_PART(radcheck.username, '@', 1)
  );

DELETE FROM radreply
WHERE username LIKE '%@%'  -- RL_VOUCHER_EXEMPT: any ISP prefix, not just K
  AND NOT EXISTS (
    SELECT 1 FROM hotspot_vouchers v
    WHERE v.status IN ('unused', 'active')
      AND (v.expires_at IS NULL OR v.expires_at > NOW())
      AND v.code = SPLIT_PART(radreply.username, '@', 1)
  );

-- Add radcheck for active vouchers (status in unused/active, not expired)
-- The key check: status='active' means user has redeemed it (NOT is_paid)
INSERT INTO radcheck (username, attribute, op, value)
SELECT 
  v.code || '@' || LOWER(SUBSTRING(REPLACE(v.isp_id::text, '-', '') FROM 1 FOR 8)),
  -- RL_RESYNC_REAL_PW: this wrote v.code. The customer is given v.password by SMS and by the
  -- portal, so every voucher this touched became unusable — and running each minute, it undid any
  -- correction within sixty seconds. It also raced the backend: Node deletes then inserts, this
  -- slipped into the gap, and the voucher ended up with two different passwords that FreeRADIUS
  -- required BOTH of. The NOT EXISTS tested the username alone, so a voucher holding only
  -- Simultaneous-Use never received a password either. Upsert the real one.
  'Cleartext-Password', ':=', COALESCE(NULLIF(v.password, ''), v.code)
FROM hotspot_vouchers v
WHERE v.status IN ('unused', 'active')
  AND (v.expires_at IS NULL OR v.expires_at > NOW())
ON CONFLICT (username, attribute) DO UPDATE SET value = EXCLUDED.value, op = EXCLUDED.op;

-- Mikrotik-Rate-Limit
INSERT INTO radreply (username, attribute, op, value)
SELECT 
  v.code || '@' || LOWER(SUBSTRING(REPLACE(v.isp_id::text, '-', '') FROM 1 FOR 8)),
  'Mikrotik-Rate-Limit', '=',
  COALESCE(p.bandwidth_up_mbps, p.bandwidth_down_mbps, 1) || 'M/' || COALESCE(p.bandwidth_down_mbps, p.bandwidth_up_mbps, 1) || 'M'
FROM hotspot_vouchers v
JOIN hotspot_packages p ON p.id = v.package_id
WHERE v.status IN ('unused', 'active')
  AND (v.expires_at IS NULL OR v.expires_at > NOW())
  AND (p.bandwidth_down_mbps IS NOT NULL OR p.bandwidth_up_mbps IS NOT NULL)
  AND NOT EXISTS (
    SELECT 1 FROM radreply rr
    WHERE rr.username = v.code || '@' || LOWER(SUBSTRING(REPLACE(v.isp_id::text, '-', '') FROM 1 FOR 8))
      AND rr.attribute = 'Mikrotik-Rate-Limit'
  )
ON CONFLICT (username, attribute) DO UPDATE SET value = EXCLUDED.value, op = EXCLUDED.op;
-- Session-Timeout
INSERT INTO radreply (username, attribute, op, value)
SELECT 
  v.code || '@' || LOWER(SUBSTRING(REPLACE(v.isp_id::text, '-', '') FROM 1 FOR 8)),
  'Session-Timeout', '=',
  GREATEST(60, EXTRACT(EPOCH FROM (v.expires_at - NOW()))::integer)::text
FROM hotspot_vouchers v
WHERE v.status IN ('unused', 'active')
  AND v.expires_at IS NOT NULL
  AND v.expires_at > NOW()
  AND NOT EXISTS (
    SELECT 1 FROM radreply rr
    WHERE rr.username = v.code || '@' || LOWER(SUBSTRING(REPLACE(v.isp_id::text, '-', '') FROM 1 FOR 8))
      AND rr.attribute = 'Session-Timeout'
  )
ON CONFLICT (username, attribute) DO UPDATE SET value = EXCLUDED.value, op = EXCLUDED.op;
-- Mikrotik-Total-Limit (data cap)
INSERT INTO radreply (username, attribute, op, value)
SELECT 
  v.code || '@' || LOWER(SUBSTRING(REPLACE(v.isp_id::text, '-', '') FROM 1 FOR 8)),
  'Mikrotik-Total-Limit', '=',
  (p.data_limit_mb * 1024 * 1024)::text
FROM hotspot_vouchers v
JOIN hotspot_packages p ON p.id = v.package_id
WHERE v.status IN ('unused', 'active')
  AND (v.expires_at IS NULL OR v.expires_at > NOW())
  AND p.data_limit_mb IS NOT NULL
  AND p.data_limit_mb > 0
  AND NOT EXISTS (
    SELECT 1 FROM radreply rr
    WHERE rr.username = v.code || '@' || LOWER(SUBSTRING(REPLACE(v.isp_id::text, '-', '') FROM 1 FOR 8))
      AND rr.attribute = 'Mikrotik-Total-Limit'
  )
ON CONFLICT (username, attribute) DO UPDATE SET value = EXCLUDED.value, op = EXCLUDED.op;
-- Mikrotik-Group
INSERT INTO radreply (username, attribute, op, value)
SELECT 
  v.code || '@' || LOWER(SUBSTRING(REPLACE(v.isp_id::text, '-', '') FROM 1 FOR 8)),
  'Mikrotik-Group', '=',
  p.mikrotik_profile
FROM hotspot_vouchers v
JOIN hotspot_packages p ON p.id = v.package_id
WHERE v.status IN ('unused', 'active')
  AND (v.expires_at IS NULL OR v.expires_at > NOW())
  AND p.mikrotik_profile IS NOT NULL
  AND p.mikrotik_profile <> ''
  AND NOT EXISTS (
    SELECT 1 FROM radreply rr
    WHERE rr.username = v.code || '@' || LOWER(SUBSTRING(REPLACE(v.isp_id::text, '-', '') FROM 1 FOR 8))
      AND rr.attribute = 'Mikrotik-Group'
  )
ON CONFLICT (username, attribute) DO UPDATE SET value = EXCLUDED.value, op = EXCLUDED.op;SQLEOF
