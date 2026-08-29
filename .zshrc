# Source modular Zsh configurations
SETUP_DIR="$HOME/ghq/github.com/nkmr-jp/setup"

# Initialize Zsh (loads all other configurations)
source "$SETUP_DIR/zsh/init.zsh"


alias restish="noglob restish"
# >>> restish completion >>>
# Managed by `restish completion install zsh`.
autoload -Uz compinit
if ! whence -w compdef >/dev/null 2>&1; then
  compinit
fi
if [ -r '/Users/nkmr/.config/restish/completions/_restish.zsh' ]; then
  source '/Users/nkmr/.config/restish/completions/_restish.zsh'
fi
# <<< restish completion <<<

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<


# Added by Antigravity CLI installer
export PATH="/Users/nkmr/.local/bin:$PATH"
