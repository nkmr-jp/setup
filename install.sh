#!/bin/bash
# Main installation script for dotfiles

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Starting dotfiles installation ==="

# Create necessary directories
mkdir -p ~/.config/fish

# Setup scripts
SETUP_SCRIPTS=(
    "setup_zsh.sh"
    "setup_fish.sh"
    "setup_git.sh"
)

# Run each setup script
for script in "${SETUP_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "Running $script..."
        bash "$script"
    else
        echo "Warning: $script not found, skipping..."
    fi
done

echo "=== Installation complete! ==="
echo "Please restart your shell or run 'source ~/.zshrc' (for Zsh) or 'source ~/.config/fish/config.fish' (for Fish) to apply changes."