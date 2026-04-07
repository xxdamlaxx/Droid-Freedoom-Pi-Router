#!/bin/bash
# ============================================================================
# RouterPi — Step 9: Zapret (DPI Bypass)
# Target: Raspbian OS Lite (Bookworm/Trixie 64-bit)
# Note: This step is SEMI-INTERACTIVE — zapret's install_easy.sh requires
#       manual input. The script will clone the repo and guide you.
# ============================================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

header "Step 9 — Zapret (DPI Bypass)"

ZAPRET_DIR="$HOME/zapret"

# ── Clone zapret ───────────────────────────────────────────────────────────
if [[ -d "$ZAPRET_DIR" ]]; then
    warn "Zapret directory already exists: $ZAPRET_DIR"
    info "Pulling latest changes..."
    cd "$ZAPRET_DIR"
    git pull || warn "Could not pull — continuing with existing code."
else
    info "Cloning zapret..."
    git clone --depth 1 https://github.com/bol-van/zapret.git "$ZAPRET_DIR"
    cd "$ZAPRET_DIR"
fi

# ── Display recommended answers ───────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}${CYAN}│             ZAPRET INSTALLATION — RECOMMENDED ANSWERS         │${NC}"
echo -e "${BOLD}${CYAN}├──────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BOLD}${CYAN}│                                                              │${NC}"
echo -e "${BOLD}${CYAN}│  Copy to /opt/zapret?        →  ${GREEN}Y${CYAN}                             │${NC}"
echo -e "${BOLD}${CYAN}│  Firewall                    →  ${GREEN}iptables${CYAN}                      │${NC}"
echo -e "${BOLD}${CYAN}│  IPv6 support                →  ${YELLOW}Your choice${CYAN}                   │${NC}"
echo -e "${BOLD}${CYAN}│  Filtering                   →  ${GREEN}4 (autohostlist)${CYAN}              │${NC}"
echo -e "${BOLD}${CYAN}│  tpws SOCKS mode             →  ${GREEN}N${CYAN}                             │${NC}"
echo -e "${BOLD}${CYAN}│  tpws transparent mode        →  ${GREEN}N${CYAN}                             │${NC}"
echo -e "${BOLD}${CYAN}│  nfqws options               →  ${GREEN}Accept defaults${CYAN}               │${NC}"
echo -e "${BOLD}${CYAN}│  LAN interface               →  ${GREEN}wlan0${CYAN}                         │${NC}"
echo -e "${BOLD}${CYAN}│  WAN interface               →  ${GREEN}eth0${CYAN}                          │${NC}"
echo -e "${BOLD}${CYAN}│  Auto download list          →  ${GREEN}Y → default${CYAN}                   │${NC}"
echo -e "${BOLD}${CYAN}│                                                              │${NC}"
echo -e "${BOLD}${CYAN}└──────────────────────────────────────────────────────────────┘${NC}"
echo ""

ask "Ready to start zapret installer? (y/n): "
read -r CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    warn "Skipping zapret installation. Run manually later:"
    info "  cd $ZAPRET_DIR && sudo ./install_easy.sh"
    exit 0
fi

# ── Run installer ──────────────────────────────────────────────────────────
info "Launching zapret installer..."
sudo ./install_easy.sh

success "Step 9 complete — zapret installed."
info "Verify with: sudo systemctl status zapret"
