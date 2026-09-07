# Zsh plugins, theme, and completion settings

# fzf-tab plugin
# https://github.com/Aloxaf/fzf-tab?tab=readme-ov-file
# Cache `ghq root`: its value is fixed, but each process takes 36ms.
_zsh_cache_var ghq-root.zsh GHQ_ROOT "${commands[ghq]}" -- ghq root
source "${GHQ_ROOT:-$HOME/ghq}/github.com/Aloxaf/fzf-tab/fzf-tab.plugin.zsh"

# Syntax highlighting
# .zprofile already exports $HOMEBREW_PREFIX via `brew shellenv`, so
# there is no need to run `brew --prefix` (12ms).
source "${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Starship prompt theme
eval "$(starship init zsh)"

# Google Cloud SDK completion
if [ -f '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc' ]; then
  source '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc'
fi
