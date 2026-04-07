#!/bin/bash
# ============================================================================
# RouterPi — Step 1: System Update & Package Installation
# Target: Raspbian OS Lite (Bookworm/Trixie 64-bit)
# ============================================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

header "Step 1 — System Update & Package Installation"

# ── System Update ──────────────────────────────────────────────────────────
info "Updating package lists..."
sudo apt update

info "Upgrading installed packages..."
sudo apt upgrade -y

# ── Core Packages ──────────────────────────────────────────────────────────
info "Installing core packages (hostapd, dnsmasq, iptables, nftables, git)..."
sudo apt install -y hostapd dnsmasq iptables iptables-persistent nftables git

# ── Zapret Build Dependencies ─────────────────────────────────────────────
info "Installing zapret build dependencies..."
sudo apt install -y build-essential \
  libnetfilter-queue-dev \
  libmnl-dev \
  zlib1g-dev \
  libcap-dev \
  libnfnetlink-dev \
  libsystemd-dev

# ── DNS-over-HTTPS ─────────────────────────────────────────────────────────
info "Installing dnscrypt-proxy..."
sudo apt install -y dnscrypt-proxy

success "Step 1 complete — all packages installed."
