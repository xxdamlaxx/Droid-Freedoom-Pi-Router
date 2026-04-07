#!/bin/bash
# ============================================================================
# RouterPi — Step 8: nftables (NAT Masquerade)
# Target: Raspbian OS Lite (Bookworm/Trixie 64-bit)
# ============================================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

header "Step 8 — nftables (NAT Masquerade)"

NFT_CONF="/etc/nftables.conf"

# ── Backup existing config ─────────────────────────────────────────────────
backup_file "$NFT_CONF"

# ── Write nftables.conf ───────────────────────────────────────────────────
# WARNING: Only put NAT rules here. Zapret adds its own rules at runtime.
# Do NOT save zapret's xt match rules here — they crash nftables on boot.
info "Writing ${NFT_CONF}..."
sudo tee "$NFT_CONF" << 'EOF'
#!/usr/sbin/nft -f
flush ruleset

table ip routerpi {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        oifname "eth0" masquerade
    }
    chain forward {
        type filter hook forward priority 0; policy accept;
    }
}
EOF

# ── Enable nftables ───────────────────────────────────────────────────────
info "Enabling nftables..."
sudo systemctl enable nftables

success "Step 8 complete — NAT masquerade configured (eth0)."
