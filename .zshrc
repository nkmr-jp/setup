# Source modular Zsh configurations
SETUP_DIR="$HOME/ghq/github.com/nkmr-jp/setup"

# Initialize Zsh (loads all other configurations)
source "$SETUP_DIR/zsh/init.zsh"

alias claude-mem='bun "$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'
