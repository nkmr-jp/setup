# Core Fish settings

# Source common configurations
# Note: Fish uses a different syntax for sourcing files
# We'll need to create Fish-compatible versions of these files or use bass
# For now, we'll use the PATH from zsh
set PATH $ZSH_PATH

# Source common aliases (need to convert to Fish syntax)
# This will be handled by a script that converts Bash aliases to Fish functions

# Call the greeting function when starting an interactive shell
function fish_greeting
    gshuf -n 1 $HOME/ghq/github.com/nkmr-jp/setup/.messages
end

# Add any other core Fish settings here