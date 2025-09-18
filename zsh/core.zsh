# Core Zsh settings

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY        # Share history between sessions
setopt HIST_IGNORE_SPACE    # Don't record commands starting with space
setopt HIST_IGNORE_DUPS     # Don't record duplicated commands

# Completion system
autoload -Uz compinit
compinit

# Enable colors
autoload -Uz colors
colors

# Source common configurations
# Order matters: env_vars.sh must be first to set SETUP_DIR
source ~/ghq/github.com/nkmr-jp/setup/common/env_vars.sh
source "$SETUP_DIR/common/gwt.sh"
source "$SETUP_DIR/common/aliases.sh"
source "$SETUP_DIR/common/functions.sh"

# Call the greeting function when starting an interactive shell
if [[ $- == *i* ]]; then
    display_greeting
fi

# Load minimal iTerm2 directory restore
[[ -f "$SETUP_DIR/iterm2_directory_restore.zsh" ]] && source "$SETUP_DIR/iterm2_directory_restore.zsh"

# Source local configurations if they exist
if [[ -f ~/.zshrc.local ]]; then
    source ~/.zshrc.local
fi

eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"
