#!/bin/bash
# ============================================================================
# RouterPi — Step 5: hostapd (5GHz Access Point)
# Target: Raspbian OS Lite (Bookworm/Trixie 64-bit)
# ============================================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

header "Step 5 — hostapd (5GHz Access Point)"

# ── Read configuration from environment or prompt ──────────────────────────
WIFI_SSID="${ROUTERPI_SSID:-}"
WIFI_PASS="${ROUTERPI_PASS:-}"
WIFI_COUNTRY="${ROUTERPI_COUNTRY:-}"

if [[ -z "$WIFI_SSID" ]]; then
    ask "Enter WiFi network name (SSID) [RouterPi]: "
    read -r WIFI_SSID
    WIFI_SSID="${WIFI_SSID:-RouterPi}"
fi

if [[ -z "$WIFI_PASS" ]]; then
    ask "Enter WiFi password (min 8 characters): "
    read -rs WIFI_PASS
    echo ""
    if [[ ${#WIFI_PASS} -lt 8 ]]; then
        error "Password must be at least 8 characters!"
        exit 1
    fi
fi

if [[ -z "$WIFI_COUNTRY" ]]; then
    ask "Enter country code (ISO, e.g. TR, US, DE) [TR]: "
    read -r WIFI_COUNTRY
    WIFI_COUNTRY="${WIFI_COUNTRY:-TR}"
fi

# ── Backup existing config ────────────────────────────────────────────────
backup_file /etc/hostapd/hostapd.conf

# ── Write hostapd.conf ────────────────────────────────────────────────────
info "Writing /etc/hostapd/hostapd.conf..."
sudo tee /etc/hostapd/hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=${WIFI_SSID}
hw_mode=a
channel=36
wmm_enabled=1
ieee80211n=1
ieee80211ac=1
ht_capab=[HT40+][SHORT-GI-20][SHORT-GI-40][DSSS_CCK-40]
vht_capab=[SHORT-GI-80]
vht_oper_chwidth=1
vht_oper_centr_freq_seg0_idx=42
country_code=${WIFI_COUNTRY}
ieee80211d=1
auth_algs=1
wpa=2
wpa_passphrase=${WIFI_PASS}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

# ── Enable hostapd ─────────────────────────────────────────────────────────
info "Unmasking and enabling hostapd..."
sudo systemctl unmask hostapd
sudo systemctl enable hostapd

success "Step 5 complete — hostapd configured (SSID: ${WIFI_SSID}, Country: ${WIFI_COUNTRY})."
