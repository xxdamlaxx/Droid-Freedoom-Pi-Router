#!/bin/bash
# ============================================================================
# RouterPi — Main Setup Script
# Raspberry Pi 5 based 5GHz WiFi Router with DPI Bypass
# Target: Raspbian OS Lite (Bookworm/Trixie 64-bit)
#
# Usage:
#   sudo ./setup.sh          # Interactive mode
#   sudo ./setup.sh --auto   # Use environment variables (non-interactive)
#
# Environment variables (for --auto mode):
#   ROUTERPI_SSID      WiFi SSID (default: RouterPi)
#   ROUTERPI_PASS      WiFi password (required, min 8 chars)
#   ROUTERPI_COUNTRY   Country code (default: TR)
#   ROUTERPI_FAN       Install fan config: yes/no (default: yes)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ── Root check ─────────────────────────────────────────────────────────────
require_root

# ── Banner ─────────────────────────────────────────────────────────────────
clear
echo ""
echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║                                                          ║"
echo "  ║   🛜  RouterPi Setup                                     ║"
echo "  ║                                                          ║"
echo "  ║   Raspberry Pi 5 — 5GHz WiFi Router + DPI Bypass         ║"
echo "  ║   Target: Raspbian OS Lite                               ║"
echo "  ║                                                          ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ── Collect configuration ─────────────────────────────────────────────────
AUTO_MODE=false
if [[ "${1:-}" == "--auto" ]]; then
    AUTO_MODE=true
    info "Running in automatic mode..."
fi

if [[ "$AUTO_MODE" == false ]]; then
    # WiFi SSID
    ask "WiFi network name (SSID) [RouterPi]: "
    read -r INPUT_SSID
    export ROUTERPI_SSID="${INPUT_SSID:-RouterPi}"

    # WiFi Password
    while true; do
        ask "WiFi password (min 8 characters): "
        read -rs INPUT_PASS
        echo ""
        if [[ ${#INPUT_PASS} -ge 8 ]]; then
            export ROUTERPI_PASS="$INPUT_PASS"
            break
        else
            error "Password must be at least 8 characters. Try again."
        fi
    done

    # Country Code
    ask "Country code (ISO 3166-1, e.g. TR, US, DE) [TR]: "
    read -r INPUT_COUNTRY
    export ROUTERPI_COUNTRY="${INPUT_COUNTRY:-TR}"

    # Fan config
    ask "Install fan configuration? (y/n) [y]: "
    read -r INPUT_FAN
    INSTALL_FAN="${INPUT_FAN:-y}"
else
    # Validate required env vars
    if [[ -z "${ROUTERPI_PASS:-}" ]]; then
        error "ROUTERPI_PASS environment variable is required in --auto mode."
        exit 1
    fi
    export ROUTERPI_SSID="${ROUTERPI_SSID:-RouterPi}"
    export ROUTERPI_COUNTRY="${ROUTERPI_COUNTRY:-TR}"
    INSTALL_FAN="${ROUTERPI_FAN:-yes}"
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Configuration:${NC}"
echo -e "  SSID:         ${GREEN}${ROUTERPI_SSID}${NC}"
echo -e "  Password:     ${GREEN}$( printf '*%.0s' $(seq 1 ${#ROUTERPI_PASS}) )${NC}"
echo -e "  Country:      ${GREEN}${ROUTERPI_COUNTRY}${NC}"
echo -e "  Fan config:   ${GREEN}${INSTALL_FAN}${NC}"
echo ""

if [[ "$AUTO_MODE" == false ]]; then
    ask "Proceed with installation? (y/n): "
    read -r PROCEED
    if [[ "$PROCEED" != "y" && "$PROCEED" != "Y" ]]; then
        info "Aborted."
        exit 0
    fi
fi

# ── Run steps ──────────────────────────────────────────────────────────────

run_step() {
    local script="$1"
    local name="$2"

    echo ""
    info "Running: ${name}..."
    echo ""

    if bash "${SCRIPT_DIR}/${script}"; then
        success "${name} — done ✓"
    else
        error "${name} — FAILED ✗"
        error "Fix the issue and re-run: sudo bash ${SCRIPT_DIR}/${script}"
        ask "Continue with remaining steps? (y/n): "
        read -r CONTINUE
        if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
            exit 1
        fi
    fi
}

run_step "01-system-update.sh"    "Step 1: System Update & Packages"
run_step "02-network-manager.sh"  "Step 2: NetworkManager Config"
run_step "03-wlan-static-ip.sh"   "Step 3: wlan0 Static IP"
run_step "04-ip-forwarding.sh"    "Step 4: IP Forwarding"
run_step "05-hostapd.sh"          "Step 5: hostapd (WiFi AP)"
run_step "06-dnsmasq.sh"          "Step 6: dnsmasq (DHCP + DNS)"
run_step "07-dnscrypt.sh"         "Step 7: dnscrypt-proxy (DoH)"
run_step "08-nftables.sh"         "Step 8: nftables (NAT)"

# Step 9: Zapret (semi-interactive, always needs user input)
echo ""
info "Running: Step 9: Zapret (DPI Bypass)..."
echo ""
bash "${SCRIPT_DIR}/09-zapret.sh"

# Step 10: Fan config (optional)
if [[ "$INSTALL_FAN" == "y" || "$INSTALL_FAN" == "yes" || "$INSTALL_FAN" == "Y" ]]; then
    run_step "10-fan-config.sh" "Step 10: Fan Configuration"
else
    info "Skipping Step 10: Fan Configuration"
fi

# ── Final Summary ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║                                                          ║"
echo "  ║   🎉  RouterPi Setup Complete!                           ║"
echo "  ║                                                          ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
info "Next steps:"
echo "  1. Reboot:   sudo reboot"
echo "  2. Verify:   sudo bash ${SCRIPT_DIR}/11-verify.sh"
echo "  3. Connect to '${ROUTERPI_SSID}' WiFi and test internet access"
echo ""
ask "Reboot now? (y/n): "
read -r DO_REBOOT
if [[ "$DO_REBOOT" == "y" || "$DO_REBOOT" == "Y" ]]; then
    info "Rebooting..."
    sudo reboot
fi
