#!/bin/bash
# RL_MSGAUTH_OFF: FreeRADIUS 3.2.5 SILENTLY DISCARDS Access-Requests that lack a
# Message-Authenticator when this is 'yes'. provision.js pushes require-message-auth=no
# to the router, so requiring it server-side made every login vanish without a log line.
# RADIUS traffic here is confined to the WireGuard tunnel.
# v62.46: Keep /etc/freeradius/3.0/clients-rumalink.conf in sync with nas_devices DB.
# When nas_devices.secret changes (e.g. after reprovisioning), this regenerates the 
# managed file and reloads FreeRADIUS.
# Runs every minute via cron.
set +e

MANAGED=/etc/freeradius/3.0/clients-rumalink.conf

# RL_SECRET_CONVERGE_CRON: nas_devices has two secret columns and different code paths have
# historically written each one. `secret` is authoritative — it is what provisioning pushes to
# the router and what this script writes into clients-rumalink.conf. radius_nas_clients (loaded
# by FreeRADIUS via read_clients=yes) reads radius_secret, so if they diverge the same NAS is
# registered twice with different secrets and every Access-Request is silently discarded.
# Converge them here, before the file is generated, so any drift self-heals within a minute.
sudo -u postgres psql -d rumalink_db -qtAc "UPDATE nas_devices SET secret = COALESCE(NULLIF(secret,''), radius_secret), radius_secret = COALESCE(NULLIF(secret,''), radius_secret) WHERE secret IS DISTINCT FROM radius_secret;" >/dev/null 2>&1

TMPF=$(mktemp)

# Generate fresh file from DB
sudo -u postgres psql -d rumalink_db -P pager=off -tA <<'SQLEOF' > $TMPF
SELECT '# v62.46: AUTO-GENERATED — DO NOT EDIT. Source: nas_devices table. Updated: ' || NOW() || E'\n\n' ||
  string_agg(
    'client ' || regexp_replace(name, '[^a-zA-Z0-9_]', '_', 'g') || '_' || SUBSTRING(REPLACE(id::text,'-','') FROM 1 FOR 8) || ' {' || E'\n' ||
    '    ipaddr = ' || wireguard_ip || E'\n' ||
    '    secret = ' || secret || E'\n' ||
    '    shortname = ' || regexp_replace(name, '[^a-zA-Z0-9_]', '_', 'g') || E'\n' ||
    '    nas_type = mikrotik' || E'\n' ||
    '    require_message_authenticator = yes' || E'\n' ||
    '}' || E'\n',
    E'\n'
  )
FROM nas_devices
WHERE wireguard_ip IS NOT NULL AND secret IS NOT NULL AND secret <> '';
SQLEOF

# Sanity check: file should have at least "client " somewhere
if ! grep -q "^client " $TMPF; then
  echo "[$(date)] No clients to write or query failed"
  rm -f $TMPF
  exit 0
fi

# Compare to existing managed file — only reload if changed
# RL_IGNORE_COMMENTS: the generated file carries an "Updated: <timestamp>" comment that
# changes every run, so a plain `cmp` ALWAYS differed and FreeRADIUS was SIGHUP'd every
# minute (43,243 times). Each HUP leaks ~1MB, reaching ~1.4GB in ~24h and OOM-freezing
# the instance. Compare ignoring comments so only REAL client changes trigger a reload.
if [ -f "$MANAGED" ] && [ "$(grep -v '^[[:space:]]*#' "$TMPF" | md5sum)" = "$(grep -v '^[[:space:]]*#' "$MANAGED" | md5sum)" ]; then
  rm -f $TMPF
  exit 0  # No change
fi

# Write new file
cp $TMPF $MANAGED
chown freerad:freerad $MANAGED
chmod 640 $MANAGED
rm -f $TMPF

# Reload FreeRADIUS
# RL_RESTART_ON_CLIENT_CHANGE: a reload (SIGHUP) re-reads config files but does NOT
# re-instantiate the SQL client list that read_clients=yes loads at startup. After a
# production reset and re-provision the new router therefore stayed unknown and every
# Access-Request was silently discarded until someone ran `systemctl restart freeradius`
# by hand. Restart instead. This runs ONLY when the client list actually changed, so it
# does not reintroduce the per-minute SIGHUP that leaked ~1MB a time.
systemctl restart freeradius
echo "[$(date)] clients-rumalink.conf updated, FreeRADIUS RESTARTED (client list changed)"

# RL_NAS_TABLE_SYNC: FreeRADIUS is configured with read_clients=yes and sources its client list
# from SQL (radius_nas_clients). A production reset emptied that table, so every RADIUS request
# from the router was silently DISCARDED as coming from an unknown client — the router logged
# "RADIUS server is not responding" and both hotspot auto-login and PPPoE auth failed completely.
# Keep the SQL client list in lockstep with nas_devices so this can never recur.
sudo -u postgres psql -d rumalink_db -P pager=off -tA >/dev/null 2>&1 <<'NASSQL'
INSERT INTO nas (nasname, shortname, type, secret, description)
SELECT d.wireguard_ip, COALESCE(d.name,'router'), 'mikrotik', d.secret, 'RumaLink auto-sync'
FROM nas_devices d
WHERE d.wireguard_ip IS NOT NULL AND d.secret IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM nas n WHERE n.nasname = d.wireguard_ip);

UPDATE nas n SET secret = d.secret, shortname = COALESCE(d.name, n.shortname)
FROM nas_devices d
WHERE n.nasname = d.wireguard_ip AND d.secret IS NOT NULL AND n.secret <> d.secret;

DELETE FROM nas n
WHERE NOT EXISTS (SELECT 1 FROM nas_devices d WHERE d.wireguard_ip = n.nasname);
NASSQL
