#!/bin/bash
# ============================================================================
# RouterPi — Step 10: Fan Configuration (Optional)
# Target: Raspbian OS Lite (Bookworm/Trixie 64-bit)
# ============================================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

header "Step 10 — Fan Configuration (Optional)"

CONFIG_FILE="/boot/firmware/config.txt"

# ── Check if already applied ──────────────────────────────────────────────
if line_in_file "# RouterPi Fan Settings" "$CONFIG_FILE"; then
    warn "Fan settings already applied to ${CONFIG_FILE}."
    info "Skipping — no changes needed."
    exit 0
fi

# ── Backup ─────────────────────────────────────────────────────────────────
backup_file "$CONFIG_FILE"

# ── Append fan settings ───────────────────────────────────────────────────
info "Adding fan settings to ${CONFIG_FILE}..."
sudo tee -a "$CONFIG_FILE" << 'EOF'

# RouterPi Fan Settings
dtparam=fan_temp0=45000
dtparam=fan_temp0_hyst=5000
dtparam=fan_temp0_speed=75
dtparam=fan_temp1=50000
dtparam=fan_temp1_hyst=5000
dtparam=fan_temp1_speed=125
dtparam=fan_temp2=55000
dtparam=fan_temp2_hyst=5000
dtparam=fan_temp2_speed=200
dtparam=fan_temp3=60000
dtparam=fan_temp3_hyst=5000
dtparam=fan_temp3_speed=255
EOF

success "Step 10 complete — fan starts at 45°C, full speed at 60°C."
info "Changes take effect after reboot."
