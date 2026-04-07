#!/bin/bash
# ============================================================================
# RouterPi — Step 4: IP Forwarding (Persistent)
# Target: Raspbian OS Lite (Bookworm/Trixie 64-bit)
# ============================================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

header "Step 4 — IP Forwarding (Persistent)"

# ── Enable in sysctl.conf ─────────────────────────────────────────────────
info "Enabling ip_forward in /etc/sysctl.conf..."
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# ── Create drop-in file ───────────────────────────────────────────────────
info "Creating /etc/sysctl.d/99-routerpi.conf..."
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-routerpi.conf

# ── Apply immediately ─────────────────────────────────────────────────────
info "Applying ip_forward now..."
sudo sysctl -w net.ipv4.ip_forward=1

# ── Verify ─────────────────────────────────────────────────────────────────
CURRENT=$(cat /proc/sys/net/ipv4/ip_forward)
if [[ "$CURRENT" == "1" ]]; then
    success "Step 4 complete — IP forwarding is enabled."
else
    error "IP forwarding could not be enabled! Current value: $CURRENT"
    exit 1
fi
