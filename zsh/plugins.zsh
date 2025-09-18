# Zsh plugin settings

# Source ghu functions
source ~/ghq/github.com/nkmr-jp/fish-functions/ghu.zsh

# Source zsh-syntax-highlighting
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Source fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Initialize zoxide
eval "$(zoxide init zsh)"

# Source any other plugins here