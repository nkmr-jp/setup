# Zsh key bindings

# ghqリポジトリ検索と移動 (Ctrl+G)
function ghq_finder() {
    local selected_dir=$(find ~/ghq -mindepth 3 -maxdepth 3 -type d | sed "s|$HOME/ghq/||" | fzf --reverse --height 40%)
    if [[ -n "$selected_dir" ]]; then
        local full_path="$HOME/ghq/$selected_dir"
        BUFFER="cd ${full_path}"
        zle accept-line
        cd "$full_path"
    else
        zle reset-prompt
    fi
}
zle -N ghq_finder
bindkey '^G' ghq_finder

# fzfと組み合わせたウィジェット (Ctrl+])
fzf-cd-enhanced() {
  local dir
  dir=$(
    (
      zoxide query -l 2>/dev/null | sed 's/^[0-9.]* *//'
      echo ".."
      echo "../.."
      echo "../../.."
      echo "../../../.."
      echo "../../../../.."
      find . -type d -not -path '*/\.*' 2>/dev/null | head -100
    ) | awk '!seen[$0]++' | fzf --height 50% --reverse --preview 'tree -C {} 2>/dev/null | head -200'
  ) && cd "$dir"
  zle reset-prompt
}
zle -N fzf-cd-enhanced
bindkey '^]' fzf-cd-enhanced

# Ctrl+F for fzf-cd-widget
#bindkey '^F' fzf-cd-widget

# Git Worktree switch (Alt+W)
function gwt_switch_widget() {
    _gwt_switch
    zle reset-prompt
}
zle -N gwt_switch_widget
bindkey '^F' gwt_switch_widget