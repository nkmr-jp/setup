# Zsh plugin settings


# Source zsh-syntax-highlighting
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Source fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Initialize zoxide
eval "$(zoxide init zsh)"

# Source any other plugins here