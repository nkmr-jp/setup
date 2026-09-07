# Source modular Zsh configurations
SETUP_DIR="$HOME/ghq/github.com/nkmr-jp/setup"

# Initialize Zsh (loads all other configurations)
source "$SETUP_DIR/zsh/init.zsh"

# Do not add settings here. Put them in the modules under zsh/.
# (PATH belongs in zsh/env.zsh, aliases in zsh/aliases.zsh, and completions before
# compinit in zsh/init.zsh.) Move any installer additions into those modules too.
# Background: while the symlink was disconnected, installer additions accumulated,
# causing duplicate compinit calls and slow startup (setup#20).
