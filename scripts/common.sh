#!/bin/bash
# ============================================================================
# RouterPi — Common helper functions
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Logging Functions ──────────────────────────────────────────────────────

header() {
    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  🛜 RouterPi — $1${NC}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

info() {
    echo -e "${BLUE}[ℹ]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

ask() {
    echo -e "${BOLD}${YELLOW}[?]${NC} $1"
}

# ── Utility Functions ──────────────────────────────────────────────────────

# Check if running as root
require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)."
        exit 1
    fi
}

# Check if a systemd service exists
service_exists() {
    systemctl list-unit-files "$1" &>/dev/null
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Backup a file before modifying
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.routerpi-backup.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$backup"
        info "Backup created: $backup"
    fi
}

# Check if a line exists in a file
line_in_file() {
    grep -qF "$1" "$2" 2>/dev/null
}
