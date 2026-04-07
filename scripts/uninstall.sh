#!/bin/bash
# ============================================================================
# RouterPi — Uninstall / Rollback
# Reverses all RouterPi changes and restores original configurations.
# Target: Raspbian OS Lite (Bookworm/Trixie 64-bit)
# ============================================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

header "RouterPi — Uninstall"

warn "This will remove ALL RouterPi configurations and restore defaults."
ask "Are you sure? (type 'yes' to confirm): "
read -r CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    info "Aborted."
    exit 0
fi

# ── Stop and disable services ──────────────────────────────────────────────
info "Stopping and disabling RouterPi services..."

SERVICES=("hostapd" "dnsmasq" "dnscrypt-custom" "routerpi-wlan0")
for svc in "${SERVICES[@]}"; do
    sudo systemctl stop "$svc" 2>/dev/null || true
    sudo systemctl disable "$svc" 2>/dev/null || true
done

# ── Remove custom systemd services ────────────────────────────────────────
info "Removing custom systemd service files..."
sudo rm -f /etc/systemd/system/routerpi-wlan0.service
sudo rm -f /etc/systemd/system/dnscrypt-custom.service
sudo systemctl daemon-reload

# ── Restore dnscrypt-proxy defaults ────────────────────────────────────────
info "Restoring dnscrypt-proxy defaults..."
sudo systemctl unmask dnscrypt-proxy.socket 2>/dev/null || true

# ── Restore resolv.conf ───────────────────────────────────────────────────
info "Restoring /etc/resolv.conf..."
sudo chattr -i /etc/resolv.conf 2>/dev/null || true
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# ── Restore dnsmasq.conf from backup ──────────────────────────────────────
if [[ -f /etc/dnsmasq.conf.bak ]]; then
    info "Restoring dnsmasq.conf from backup..."
    sudo mv /etc/dnsmasq.conf.bak /etc/dnsmasq.conf
else
    sudo rm -f /etc/dnsmasq.conf
fi

# ── Restore hostapd.conf ──────────────────────────────────────────────────
info "Removing hostapd configuration..."
# Find most recent backup
HOSTAPD_BACKUP=$(ls -t /etc/hostapd/hostapd.conf.routerpi-backup.* 2>/dev/null | head -1 || true)
if [[ -n "$HOSTAPD_BACKUP" ]]; then
    info "Restoring hostapd.conf from backup..."
    sudo mv "$HOSTAPD_BACKUP" /etc/hostapd/hostapd.conf
else
    sudo rm -f /etc/hostapd/hostapd.conf
fi

# ── Remove nftables rules ─────────────────────────────────────────────────
info "Removing nftables NAT rules..."
NFT_BACKUP=$(ls -t /etc/nftables.conf.routerpi-backup.* 2>/dev/null | head -1 || true)
if [[ -n "$NFT_BACKUP" ]]; then
    sudo mv "$NFT_BACKUP" /etc/nftables.conf
else
    sudo tee /etc/nftables.conf << 'EOF'
#!/usr/sbin/nft -f
flush ruleset
EOF
fi

# ── Remove IP forwarding drop-in ──────────────────────────────────────────
info "Removing IP forwarding config..."
sudo rm -f /etc/sysctl.d/99-routerpi.conf
sudo sysctl -w net.ipv4.ip_forward=0

# ── Remove NetworkManager unmanage config ──────────────────────────────────
if [[ -f /etc/NetworkManager/conf.d/unmanage-wlan0.conf ]]; then
    info "Removing NetworkManager unmanage config..."
    sudo rm -f /etc/NetworkManager/conf.d/unmanage-wlan0.conf
    if command_exists nmcli; then
        sudo nmcli dev set wlan0 managed yes 2>/dev/null || true
        sudo systemctl reload NetworkManager 2>/dev/null || true
    fi
fi

# ── Remove fan settings ───────────────────────────────────────────────────
CONFIG_FILE="/boot/firmware/config.txt"
if [[ -f "$CONFIG_FILE" ]] && line_in_file "# RouterPi Fan Settings" "$CONFIG_FILE"; then
    info "Removing fan settings from config.txt..."
    sudo sed -i '/^# RouterPi Fan Settings$/,/^dtparam=fan_temp3_speed=255$/d' "$CONFIG_FILE"
    # Remove trailing empty line
    sudo sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$CONFIG_FILE"
fi

# ── Zapret ─────────────────────────────────────────────────────────────────
if [[ -d /opt/zapret ]]; then
    info "Zapret found at /opt/zapret."
    ask "Remove zapret? (y/n): "
    read -r REMOVE_ZAPRET
    if [[ "$REMOVE_ZAPRET" == "y" || "$REMOVE_ZAPRET" == "Y" ]]; then
        if [[ -f /opt/zapret/uninstall_easy.sh ]]; then
            info "Running zapret uninstaller..."
            sudo /opt/zapret/uninstall_easy.sh
        else
            sudo systemctl stop zapret 2>/dev/null || true
            sudo systemctl disable zapret 2>/dev/null || true
            sudo rm -rf /opt/zapret
        fi
        success "Zapret removed."
    else
        info "Keeping zapret."
    fi
fi

# ── Flush wlan0 IP ─────────────────────────────────────────────────────────
info "Flushing wlan0 IP..."
sudo ip addr flush dev wlan0 2>/dev/null || true

# ── Done ───────────────────────────────────────────────────────────────────
echo ""
success "RouterPi uninstalled successfully."
warn "A reboot is recommended: sudo reboot"
