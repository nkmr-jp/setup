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
source ~/ghq/github.com/nkmr-jp/setup/common/aliases.sh
source ~/ghq/github.com/nkmr-jp/setup/common/functions.sh
source ~/ghq/github.com/nkmr-jp/setup/common/env_vars.sh
source ~/ghq/github.com/nkmr-jp/setup/common/paths.sh

# Call the greeting function when starting an interactive shell
if [[ $- == *i* ]]; then
    display_greeting
fi

# Source local configurations if they exist
if [[ -f ~/.zshrc.local ]]; then
    source ~/.zshrc.local
fi