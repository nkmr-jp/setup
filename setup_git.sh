#!/bin/bash
# Setup script for Git configuration

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Setting up Git configuration ==="

# Create .gitconfig file if it doesn't exist
if [ ! -f ~/.gitconfig ]; then
    cat > ~/.gitconfig << 'EOL'
# ~/.gitconfig
[include]
    path = ~/ghq/github.com/nkmr-jp/setup/gitconfig
EOL
    echo "Created ~/.gitconfig"
else
    # Check if the include directive is already present
    if ! grep -q "path = ~/ghq/github.com/nkmr-jp/setup/gitconfig" ~/.gitconfig; then
        # Add the include directive to the existing .gitconfig
        cat >> ~/.gitconfig << 'EOL'

# Added by setup script
[include]
    path = ~/ghq/github.com/nkmr-jp/setup/gitconfig
EOL
        echo "Updated ~/.gitconfig"
    else
        echo "~/.gitconfig already includes the repository gitconfig"
    fi
fi

# Prompt for git user configuration if not already set
if ! git config --global user.name > /dev/null || ! git config --global user.email > /dev/null; then
    echo "Git user configuration not found. Please set your name and email:"
    
    # Get user name
    if ! git config --global user.name > /dev/null; then
        read -p "Enter your name: " git_name
        git config --global user.name "$git_name"
    fi
    
    # Get user email
    if ! git config --global user.email > /dev/null; then
        read -p "Enter your email: " git_email
        git config --global user.email "$git_email"
    fi
    
    echo "Git user configuration set."
else
    echo "Git user configuration already set."
fi

echo "=== Git configuration setup complete! ==="