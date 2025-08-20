#!/bin/bash
# Main installation script for dotfiles

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

log_info "Starting dotfiles installation"


# Setup scripts
SETUP_SCRIPTS=(
    "setup_zsh.sh"
    "setup_git.sh"
)

# Run each setup script
for script in "${SETUP_SCRIPTS[@]}"; do
    if [[ -f "$script" ]]; then
        log_info "Running $script"
        if bash "$script"; then
            log_info "$script completed successfully"
        else
            log_error "$script failed with exit code $?"
            exit 1
        fi
    else
        log_warn "$script not found, skipping"
    fi
done

log_info "Installation complete!"
echo "Please restart your shell or run:"
echo "  - For Zsh: source ~/.zshrc"