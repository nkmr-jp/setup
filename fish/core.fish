# Core Fish settings

# Set SETUP_DIR if not already set
set -q SETUP_DIR; or set -x SETUP_DIR "$HOME/ghq/github.com/nkmr-jp/setup"

# Import PATH from ZSH_PATH (set by env_vars.sh)
if set -q ZSH_PATH
    set PATH $ZSH_PATH
end

# Source Fish-specific configurations
source "$SETUP_DIR/fish/aliases.fish"
source "$SETUP_DIR/fish/functions.fish"

# Call the greeting function when starting an interactive shell
function fish_greeting
    set -q SETUP_DIR; or set -x SETUP_DIR "$HOME/ghq/github.com/nkmr-jp/setup"
    if test -f "$SETUP_DIR/.messages"
        gshuf -n 1 "$SETUP_DIR/.messages"
    end
end

# Add any other core Fish settings here