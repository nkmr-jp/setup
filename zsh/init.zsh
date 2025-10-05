# Zsh initialization and core settings

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

# Load zsh configurations
# Order matters: env.zsh must be first to set up environment
source "$SETUP_DIR/zsh/env.zsh"
source "$SETUP_DIR/zsh/completion.zsh"
source "$SETUP_DIR/zsh/gwt.zsh"
source "$SETUP_DIR/zsh/ghu.zsh"
source "$SETUP_DIR/zsh/aliases.zsh"
source "$SETUP_DIR/zsh/functions.zsh"
source "$SETUP_DIR/zsh/keybindings.zsh"

# Initialize tools
eval "$(anyenv init -)"
eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"
eval "$(zoxide init zsh)"

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
