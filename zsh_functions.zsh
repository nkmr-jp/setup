#!/bin/bash
# ===== Import =====
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ===== Functions =====
# Display random message on startup (equivalent to fish_greeting)
function display_greeting() {
    if [[ -f "$HOME/ghq/github.com/nkmr-jp/setup/.messages" ]]; then
        gshuf -n 1 "$HOME/ghq/github.com/nkmr-jp/setup/.messages"
    fi
}

function bash_colors() {
    # See: https://gist.github.com/rsperl/d2dfe88a520968fbc1f49db0a29345b9
    bash -c 'for c in {0..255}; do tput setaf $c; tput setaf $c | cat -v; echo =$c; done'
}

# Display available colors
function colors() {
    # Zsh equivalent of Fish's set_color --print-colors
    # This is a simplified version that shows basic colors
    local colors=("black" "red" "green" "yellow" "blue" "magenta" "cyan" "white")

    for color in "${colors[@]}"; do
        echo -e "\e[$(color_code $color)m$color\e[0m"
    done
}

# Helper function to get color code
function color_code() {
    case "$1" in
        "black") echo "30" ;;
        "red") echo "31" ;;
        "green") echo "32" ;;
        "yellow") echo "33" ;;
        "blue") echo "34" ;;
        "magenta") echo "35" ;;
        "cyan") echo "36" ;;
        "white") echo "37" ;;
        *) echo "0" ;;
    esac
}

# Display system stats
function stats() {
    echo ""
    echo "[ Programing Languages ]"
    go version
    node -v
    python -V
    ruby -v

    echo ""
    echo ""
    echo "[ macOS ]"
    system_profiler SPSoftwareDataType
    # system_profiler SPHardwareDataType

    echo ""
    echo ""
    echo "[ iStats ]"
    istats
}


# ghqリポジトリ検索と移動 (Ctrl+G)
function ghq_finder() {
    local selected_dir=$(find ~/ghq -mindepth 3 -maxdepth 3 -type d | fzf --reverse --height 40% --preview 'ls -la {}')
    if [[ -n "$selected_dir" ]]; then
        BUFFER="cd ${selected_dir}"
        zle accept-line
        cd "$selected_dir"
    else
        zle reset-prompt
    fi
}
zle -N ghq_finder

# worktreeを作成して即座に移動
function wtc() {
    git worktree add "$1" && cd "$1"
}

# worktreeをインタラクティブに選択して移動
function wts() {
    local worktree=$(git worktree list | fzf | awk '{print $1}')
    if [ -n "$worktree" ]; then
        cd "$worktree"
    fi
}

# 不要なworktreeを一括削除
function wtclean() {
    git worktree list | grep -E '\[.*gone\]' | awk '{print $1}' | xargs -I {} git worktree remove {}
}

# fzfと組み合わせたウィジェット
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

# ===== KeyBinds =====
bindkey '^G' ghq_finder
bindkey '^]' fzf-cd-enhanced
bindkey '^F' fzf-cd-widget
