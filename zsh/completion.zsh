# Zsh plugins, theme, and completion settings

# fzf-tab plugin
# https://github.com/Aloxaf/fzf-tab?tab=readme-ov-file
# `ghq root` は毎回プロセスを起こす (36ms) が値は固定なのでキャッシュする
_zsh_cache_var ghq-root.zsh GHQ_ROOT "${commands[ghq]}" -- ghq root
source "${GHQ_ROOT:-$HOME/ghq}/github.com/Aloxaf/fzf-tab/fzf-tab.plugin.zsh"

# Syntax highlighting
# $HOMEBREW_PREFIX は .zprofile の `brew shellenv` が export 済みなので
# `brew --prefix` (12ms) を起こす必要は無い
source "${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Starship prompt theme
eval "$(starship init zsh)"

# Google Cloud SDK completion
if [ -f '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc' ]; then
  source '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc'
fi
