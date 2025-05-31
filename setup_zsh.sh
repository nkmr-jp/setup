#!/bin/bash
# Setup script for Zsh configuration

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Setting up Zsh configuration ==="

# Create .zshrc file
cat > ~/.zshrc << 'EOL'
# Amazon Q pre block. Keep at the top of this file.
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
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"
EOL

echo "Created ~/.zshrc"

# Make sure the files are executable
chmod +x common/*.sh
chmod +x zsh/*.zsh

echo "=== Zsh configuration setup complete! ==="