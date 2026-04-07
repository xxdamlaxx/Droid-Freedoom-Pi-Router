#!/bin/bash
# ============================================================================
# RouterPi — Step 6: dnsmasq (DHCP + DNS)
# Target: Raspbian OS Lite (Bookworm/Trixie 64-bit)
# ============================================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

header "Step 6 — dnsmasq (DHCP + DNS)"

DNSMASQ_CONF="/etc/dnsmasq.conf"

# ── Backup existing config ─────────────────────────────────────────────────
if [[ -f "$DNSMASQ_CONF" ]] && ! [[ -f "${DNSMASQ_CONF}.bak" ]]; then
    info "Backing up default dnsmasq.conf..."
    sudo mv "$DNSMASQ_CONF" "${DNSMASQ_CONF}.bak"
else
    backup_file "$DNSMASQ_CONF"
fi

# ── Write dnsmasq.conf ────────────────────────────────────────────────────
info "Writing ${DNSMASQ_CONF}..."
sudo tee "$DNSMASQ_CONF" << 'EOF'
# RouterPi dnsmasq configuration
# bind-interfaces: listen on wlan0 only, prevents port 53 conflicts
# no-resolv: use dnscrypt-proxy (port 5053) instead of /etc/resolv.conf

interface=wlan0
bind-interfaces
dhcp-range=192.168.4.2,192.168.4.100,255.255.255.0,24h
server=127.0.0.1#5053
no-resolv
EOF

# ── Enable dnsmasq ─────────────────────────────────────────────────────────
info "Enabling dnsmasq..."
sudo systemctl enable dnsmasq

success "Step 6 complete — dnsmasq configured (DHCP: 192.168.4.2-100, DNS: 127.0.0.1:5053)."
