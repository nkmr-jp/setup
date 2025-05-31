#!/bin/bash
# Setup script for Zsh configuration

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

log_info "Setting up Zsh configuration"

# Create .zshrc file with backup
safe_write ~/.zshrc '# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"

# Source modular Zsh configurations
SETUP_DIR="$HOME/ghq/github.com/nkmr-jp/setup"

# Core settings
source "$SETUP_DIR/zsh/core.zsh"

# Key bindings
source "$SETUP_DIR/zsh/keybindings.zsh"

# Plugins
source "$SETUP_DIR/zsh/plugins.zsh"

# Theme
source "$SETUP_DIR/zsh/theme.zsh"

# Amazon Q post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"'

# Make sure the files are executable
if chmod +x common/*.sh zsh/*.zsh 2>/dev/null; then
    log_info "Set executable permissions"
else
    log_warn "Some files may not have been found for chmod"
fi

log_info "Zsh configuration setup complete!"