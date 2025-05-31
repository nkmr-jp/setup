#!/bin/bash
# Setup script for Fish configuration

set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'       # Secure IFS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Source common utilities
source "$SCRIPT_DIR/common/backup.sh"

log_info "Setting up Fish configuration"

# Create config.fish file with backup
mkdir -p ~/.config/fish
safe_write ~/.config/fish/config.fish '# Source modular Fish configurations
set SETUP_DIR "$HOME/ghq/github.com/nkmr-jp/setup"

# Core settings
source "$SETUP_DIR/fish/core.fish"

# Key bindings
source "$SETUP_DIR/fish/keybindings.fish"

# Plugins
source "$SETUP_DIR/fish/plugins.fish"

# Theme
source "$SETUP_DIR/fish/theme.fish"'

# Make sure the files are executable
if chmod +x common/*.sh fish/*.fish 2>/dev/null; then
    log_info "Set executable permissions"
else
    log_warn "Some files may not have been found for chmod"
fi

log_info "Fish configuration setup complete!"