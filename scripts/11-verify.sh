#!/bin/bash
# ============================================================================
# RouterPi — Step 11: Post-Reboot Verification
# Target: Raspbian OS Lite (Bookworm/Trixie 64-bit)
# Run this AFTER rebooting the Pi.
# ============================================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

header "Step 11 — Post-Reboot Verification"

PASS=0
FAIL=0

check_pass() {
    success "$1"
    ((PASS++))
}

check_fail() {
    error "$1"
    ((FAIL++))
}

# ── Service Checks ────────────────────────────────────────────────────────
info "Checking services..."

SERVICES=("hostapd" "dnsmasq" "dnscrypt-custom" "zapret" "nftables" "routerpi-wlan0")

for svc in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$svc"; then
        check_pass "$svc is running"
    else
        check_fail "$svc is NOT running"
    fi
done

# ── IP Forwarding ─────────────────────────────────────────────────────────
info "Checking IP forwarding..."
IP_FWD=$(cat /proc/sys/net/ipv4/ip_forward)
if [[ "$IP_FWD" == "1" ]]; then
    check_pass "IP forwarding is enabled"
else
    check_fail "IP forwarding is DISABLED"
fi

# ── wlan0 Static IP ───────────────────────────────────────────────────────
info "Checking wlan0 IP address..."
WLAN_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP 'inet \K[\d.]+' || true)
if [[ "$WLAN_IP" == "192.168.4.1" ]]; then
    check_pass "wlan0 has correct IP: 192.168.4.1"
else
    check_fail "wlan0 IP is '${WLAN_IP:-not set}' (expected: 192.168.4.1)"
fi

# ── NAT Rules ─────────────────────────────────────────────────────────────
info "Checking nftables NAT rules..."
if sudo nft list table ip routerpi 2>/dev/null | grep -q "masquerade"; then
    check_pass "NAT masquerade rule is active"
else
    check_fail "NAT masquerade rule NOT found"
fi

# ── DNS-over-HTTPS ─────────────────────────────────────────────────────────
info "Checking DNS-over-HTTPS..."
if command -v dig &>/dev/null; then
    DNS_RESULT=$(dig @127.0.0.1 -p 5053 +short cloudflare.com A 2>/dev/null | head -1 || true)
    if [[ -n "$DNS_RESULT" ]] && [[ "$DNS_RESULT" != ";" ]]; then
        check_pass "DoH is working (cloudflare.com → ${DNS_RESULT})"
    else
        check_fail "DoH query failed — dnscrypt-proxy may not be working"
    fi
else
    warn "dig not installed — skipping DNS test (install dnsutils for this check)"
fi

# ── Internet Connectivity ─────────────────────────────────────────────────
info "Checking internet connectivity..."
if ping -c 2 -W 3 1.1.1.1 &>/dev/null; then
    check_pass "Internet connectivity OK (1.1.1.1 reachable)"
else
    check_fail "Cannot reach 1.1.1.1 — check Ethernet connection and routes"
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  VERIFICATION RESULTS${NC}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Passed: ${PASS}${NC}"
echo -e "  ${RED}Failed: ${FAIL}${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
    success "All checks passed! RouterPi is fully operational. 🎉"
    echo ""
    info "Connect to the WiFi network and verify internet + blocked site access."
else
    warn "${FAIL} check(s) failed. Review the errors above."
    info "Troubleshooting guide: https://github.com/xxdamlaxx/Droid-Freedoom-Pi-Router#-troubleshooting"
fi
