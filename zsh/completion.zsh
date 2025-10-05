# Zsh plugins, theme, and completion settings

# fzf-tab plugin
# https://github.com/Aloxaf/fzf-tab?tab=readme-ov-file
source "$(ghq root)/github.com/Aloxaf/fzf-tab/fzf-tab.plugin.zsh"

# Syntax highlighting
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Starship prompt theme
eval "$(starship init zsh)"

# Google Cloud SDK completion
if [ -f '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc' ]; then
  source '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc'
fi
