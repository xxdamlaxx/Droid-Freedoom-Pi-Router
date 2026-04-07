#!/bin/bash
# ============================================================================
# RouterPi — Step 7: dnscrypt-proxy (DNS-over-HTTPS)
# Target: Raspbian OS Lite (Bookworm/Trixie 64-bit)
# ============================================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

header "Step 7 — dnscrypt-proxy (DNS-over-HTTPS)"

TOML_FILE="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
SERVICE_FILE="/etc/systemd/system/dnscrypt-custom.service"

# ── Disable Debian's default dnscrypt-proxy service/socket ─────────────────
info "Disabling default dnscrypt-proxy service and socket..."
sudo systemctl stop dnscrypt-proxy.service 2>/dev/null || true
sudo systemctl stop dnscrypt-proxy.socket 2>/dev/null || true
sudo systemctl disable dnscrypt-proxy.service 2>/dev/null || true
sudo systemctl disable dnscrypt-proxy.socket 2>/dev/null || true
sudo systemctl mask dnscrypt-proxy.socket

# ── Configure dnscrypt-proxy.toml ──────────────────────────────────────────
info "Configuring ${TOML_FILE}..."
backup_file "$TOML_FILE"

# Update listen_addresses
sudo sed -i "s|^listen_addresses.*|listen_addresses = ['127.0.0.1:5053']|" "$TOML_FILE"

# Update server_names
if grep -q "^server_names" "$TOML_FILE"; then
    sudo sed -i "s|^server_names.*|server_names = ['cloudflare', 'google']|" "$TOML_FILE"
elif grep -q "^# server_names" "$TOML_FILE"; then
    sudo sed -i "s|^# server_names.*|server_names = ['cloudflare', 'google']|" "$TOML_FILE"
else
    # Add server_names after listen_addresses
    sudo sed -i "/^listen_addresses/a server_names = ['cloudflare', 'google']" "$TOML_FILE"
fi

# ── Create required directories ────────────────────────────────────────────
info "Creating cache and log directories..."
sudo mkdir -p /var/cache/dnscrypt-proxy /var/log/dnscrypt-proxy

# ── Create custom systemd service ─────────────────────────────────────────
info "Creating dnscrypt-custom.service..."
sudo tee "$SERVICE_FILE" << 'EOF'
[Unit]
Description=DNSCrypt DoH Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/sbin/dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable dnscrypt-custom

# ── Point Pi's DNS to DoH proxy ───────────────────────────────────────────
info "Setting /etc/resolv.conf to use local DoH proxy..."

# Remove immutable flag if present
sudo chattr -i /etc/resolv.conf 2>/dev/null || true

echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf

# Make immutable so NM/dhcpcd can't overwrite
sudo chattr +i /etc/resolv.conf

success "Step 7 complete — dnscrypt-proxy configured (DoH via Cloudflare + Google)."
