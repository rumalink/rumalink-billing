#!/usr/bin/env bash
# Applies WinBox port-forwards from nas_devices (winbox_port -> wireguard_ip:8291). Idempotent.
sysctl -w net.ipv4.ip_forward=1 >/dev/null
sudo -u postgres psql -d rumalink_db -t -A -F' ' -c \
 "SELECT winbox_port, wireguard_ip FROM nas_devices WHERE winbox_port IS NOT NULL AND wireguard_ip IS NOT NULL;" |
while read -r PORT WGIP; do
  [ -z "$PORT" ] && continue
  iptables -t nat -C PREROUTING -p tcp --dport "$PORT" -j DNAT --to-destination "$WGIP:8291" 2>/dev/null || \
    iptables -t nat -A PREROUTING -p tcp --dport "$PORT" -j DNAT --to-destination "$WGIP:8291"
  iptables -t nat -C POSTROUTING -d "$WGIP" -p tcp --dport 8291 -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -d "$WGIP" -p tcp --dport 8291 -j MASQUERADE
  iptables -C FORWARD -p tcp -d "$WGIP" --dport 8291 -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD -p tcp -d "$WGIP" --dport 8291 -j ACCEPT
done
# maintain the display URL for the dashboard
sudo -u postgres psql -d rumalink_db -c "UPDATE nas_devices SET remote_winbox_url='rumalinkenterprise.online:'||winbox_port WHERE winbox_port IS NOT NULL AND (remote_winbox_url IS NULL OR remote_winbox_url NOT LIKE '%'||winbox_port);" >/dev/null 2>&1
