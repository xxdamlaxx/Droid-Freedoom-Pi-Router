#!/bin/bash
# ============================================================================
# RouterPi — Step 2: Remove wlan0 from NetworkManager
# Target: Raspbian OS Lite (Bookworm/Trixie 64-bit)
# Note: Raspbian Lite typically does NOT have NetworkManager installed.
#       This script detects NM and skips gracefully if absent.
# ============================================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

header "Step 2 — Remove wlan0 from NetworkManager"

# ── Check if NetworkManager is installed ───────────────────────────────────
if ! command_exists nmcli; then
    success "NetworkManager is NOT installed (typical for Raspbian Lite)."
    info "Skipping this step — no action needed."
    exit 0
fi

info "NetworkManager detected. Releasing wlan0..."

# ── Delete existing WiFi connections on wlan0 ──────────────────────────────
WIFI_CONNECTIONS=$(nmcli -t -f NAME,TYPE con show | grep ":802-11-wireless" | cut -d: -f1 || true)

if [[ -n "$WIFI_CONNECTIONS" ]]; then
    while IFS= read -r conn; do
        info "Deleting WiFi connection: $conn"
        sudo nmcli con delete "$conn" || warn "Could not delete: $conn"
    done <<< "$WIFI_CONNECTIONS"
else
    info "No WiFi connections found to delete."
fi

# ── Set wlan0 as unmanaged ─────────────────────────────────────────────────
info "Setting wlan0 as unmanaged..."
sudo nmcli dev set wlan0 managed no

# ── Make it persistent ─────────────────────────────────────────────────────
info "Creating persistent unmanage config..."
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/unmanage-wlan0.conf << 'EOF'
[keyfile]
unmanaged-devices=interface-name:wlan0
EOF

# ── Reload NetworkManager ──────────────────────────────────────────────────
info "Reloading NetworkManager..."
sudo systemctl reload NetworkManager || sudo systemctl restart NetworkManager

success "Step 2 complete — wlan0 released from NetworkManager."
