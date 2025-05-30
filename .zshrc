# ~/.zshrc
# Ported from Fish shell configuration (config.fish)

# ===== Aliases =====
alias l='ls'
alias ll='ls -l'
alias lla='ls -la'
alias op='open'
alias rm='trash-put'
alias pecob='peco --layout bottom-up'
alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
alias load='exec $SHELL -l'
alias c='clear'
alias m='code ~/ghq/github.com/nkmr-jp/setup/.messages'
alias setup='code ~/ghq/github.com/nkmr-jp/setup'
alias sleepon='sudo pmset -a disablesleep 0'
alias sleepoff='sudo pmset -a disablesleep 1'
alias opg='gh repo view --web'
alias oura='open https://cloud.ouraring.com/dashboard'
alias e='open /Applications/Effortless.app'
alias get='ghu get'
alias init='ghu init'
alias profile='code ~/.zprofile'
alias run='go run main.go'
alias xbar='code ~/ghq/github.com/nkmr-jp/xbar/plugins'
alias ops='open https://console.cloud.google.com/storage/browser'
alias opf='open https://console.cloud.google.com/functions/list'
alias opb='open https://console.cloud.google.com/bigquery'
alias opr='open https://console.cloud.google.com/run'
alias ope='open https://console.cloud.google.com/eventarc/triggers'
alias wind='windsurf'
alias cl='claude'

# ===== Functions =====
# Display bash colors
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

# ===== Zsh Settings =====
# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY        # Share history between sessions
setopt HIST_IGNORE_SPACE    # Don't record commands starting with space
setopt HIST_IGNORE_DUPS     # Don't record duplicated commands

# Completion system
autoload -Uz compinit
compinit

# Enable colors
autoload -Uz colors
# colorsコマンドはcolor表示関数と名前が競合するため、関数名を変更
# colors_fn

# ===== Greeting Message =====
# Display random message on startup (equivalent to fish_greeting)
function display_greeting() {
    if [[ -f "$HOME/ghq/github.com/nkmr-jp/setup/.messages" ]]; then
        gshuf -n 1 "$HOME/ghq/github.com/nkmr-jp/setup/.messages"
    fi
}

# Call the greeting function when starting an interactive shell
if [[ $- == *i* ]]; then
    display_greeting
fi

# ===== Key Bindings =====
# Add any key bindings here
# Note: Fish's bind \c] enhancd would be implemented differently in Zsh

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
bindkey '^G' ghq_finder

# 履歴検索 (Ctrl+R)
function history_search() {
    local selected_command=$(history -n 1 | awk '!seen[$0]++' | fzf --reverse --height 40%)
    if [[ -n "$selected_command" ]]; then
        BUFFER="$selected_command"
        zle end-of-line
    fi
    zle reset-prompt
}
zle -N history_search
bindkey '^R' history_search

# 最近アクセスしたディレクトリに移動 (Ctrl+])
function recent_dirs() {
    # ディレクトリスタックの操作を有効化
    setopt AUTO_PUSHD
    
    # dirs -pは重複も含むため、ユニークな結果を返すようにする
    local selected_dir=$(dirs -p | sort -u | fzf --reverse --height 40% --preview 'ls -la {}')
    if [[ -n "$selected_dir" ]]; then
        BUFFER="cd ${selected_dir}"
        zle accept-line
        cd "$selected_dir"
    else
        zle reset-prompt
    fi
}
zle -N recent_dirs
bindkey '^]' recent_dirs


# Git worktree operations
function wt() {
    case "$1" in
        "add")
            if [[ -z "$2" ]]; then
                echo "Usage: wt add <branch_name>"
                return 1
            fi
            git worktree add "../${PWD##*/}-$2" -b "$2"
            ;;
        "ls")
            git worktree list
            ;;
        "rm")
            if [[ -z "$2" ]]; then
                echo "Usage: wt rm [-f] <worktree_path>"
                return 1
            fi
            if [[ "$2" == "-f" ]]; then
                if [[ -z "$3" ]]; then
                    echo "Usage: wt rm -f <worktree_path>"
                    return 1
                fi
                git worktree remove --force "$3"
            else
                git worktree remove "$2"
            fi
            ;;
        "rmall")
            # Get main directory (directory without suffix)
            local main_dir=$(basename "$PWD")
            local base_name=$(echo "$main_dir" | sed 's/-[^-]*$//')
            
            # Remove all worktrees except the main one
            git worktree list --porcelain | grep "^worktree" | while read -r line; do
                local worktree_path=$(echo "$line" | cut -d' ' -f2-)
                local worktree_name=$(basename "$worktree_path")
                
                # Skip if this is the main directory (no suffix)
                if [[ "$worktree_name" != "$base_name" && "$worktree_path" != "$PWD" ]]; then
                    echo "Removing worktree: $worktree_path"
                    git worktree remove --force "$worktree_path"
                fi
            done
            ;;
        *)
            echo "Usage: wt {add|ls|rm|rmall}"
            echo "  add <branch>    - Create new branch and worktree"
            echo "  ls              - List worktrees"
            echo "  rm [-f] <path>  - Remove worktree (use -f to force)"
            echo "  rmall           - Remove all worktrees except main"
            return 1
            ;;
    esac
}

# ghu
source ~/ghq/github.com/nkmr-jp/fish-functions/ghu.zsh

# ===== Tool Integrations =====
# Add any tool-specific configurations here

# ===== Path Settings =====
# The path is already set in ~/.zprofile, which is sourced before ~/.zshrc
# No need to modify PATH here unless there are specific additions

# ===== Plugin Settings =====
# Equivalent to Fish's __done_min_cmd_duration setting
# This would need a Zsh plugin equivalent to be implemented

# Source additional configuration files if they exist
if [[ -f ~/.zshrc.local ]]; then
    source ~/.zshrc.local
fi

eval "$(starship init zsh)"