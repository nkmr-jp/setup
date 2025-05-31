#!/bin/bash
# Setup script for Fish configuration

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Setting up Fish configuration ==="

# Create config.fish file
mkdir -p ~/.config/fish
cat > ~/.config/fish/config.fish << 'EOL'
# Source modular Fish configurations
set SETUP_DIR "$HOME/ghq/github.com/nkmr-jp/setup"

# Core settings
source "$SETUP_DIR/fish/core.fish"

# Key bindings
source "$SETUP_DIR/fish/keybindings.fish"

# Plugins
source "$SETUP_DIR/fish/plugins.fish"

# Theme
source "$SETUP_DIR/fish/theme.fish"

# Create Fish functions from Bash aliases
# This is a workaround since Fish doesn't support Bash-style aliases
# We'll create a function for each alias in the common/aliases.sh file

# Helper function to convert Bash aliases to Fish functions
function create_alias_functions
    set -l aliases_file "$SETUP_DIR/common/aliases.sh"
    if test -f $aliases_file
        # Extract aliases and create Fish functions
        grep "^alias" $aliases_file | while read -l line
            set -l parts (string split "=" $line)
            set -l alias_name (string replace "alias " "" $parts[1])
            set -l command (string trim -c "'" (string trim -c '"' $parts[2]))
            
            # Create the function
            echo "function $alias_name; $command \$argv; end" | source
        end
    end
end

# Call the function to create alias functions
create_alias_functions
EOL

echo "Created ~/.config/fish/config.fish"

# Make sure the files are executable
chmod +x common/*.sh
chmod +x fish/*.fish

echo "=== Fish configuration setup complete! ==="