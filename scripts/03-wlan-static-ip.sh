#!/bin/bash
# ============================================================================
# RouterPi — Step 3: wlan0 Static IP Service
# Target: Raspbian OS Lite (Bookworm/Trixie 64-bit)
# ============================================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

header "Step 3 — wlan0 Static IP Service"

SERVICE_FILE="/etc/systemd/system/routerpi-wlan0.service"

# ── Create systemd service ─────────────────────────────────────────────────
if [[ -f "$SERVICE_FILE" ]]; then
    warn "Service file already exists: $SERVICE_FILE"
    info "Overwriting with current configuration..."
fi

info "Creating routerpi-wlan0.service..."
sudo tee "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Set static IP on wlan0
After=network.target
Before=hostapd.service dnsmasq.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/ip addr flush dev wlan0
ExecStart=/usr/sbin/ip addr add 192.168.4.1/24 dev wlan0
ExecStart=/usr/sbin/sysctl -w net.ipv4.ip_forward=1

[Install]
WantedBy=multi-user.target
EOF

# ── Enable ─────────────────────────────────────────────────────────────────
info "Reloading systemd and enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable routerpi-wlan0.service

success "Step 3 complete — wlan0 static IP service created and enabled."
