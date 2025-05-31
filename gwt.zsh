#!/bin/bash

# zsh環境でのみ補完機能を有効化
if [[ -n "$ZSH_VERSION" ]]; then
    autoload -Uz compinit && compinit
fi

# Git Worktree Manager - 統合コマンド
# 複数のworktreeでの並行作業を効率化するユーティリティ

# 設定可能な環境変数
: ${GIT_WORKTREE_BASE:="$HOME/worktrees"}  # worktreeのベースディレクトリ
: ${GIT_WORKTREE_PREFIX:="wt-"}           # worktreeディレクトリのプレフィックス（廃止予定：リポジトリ名を使用）

# カラー定義 (ANSI escape codes)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ========================================
# メインコマンド
# ========================================
gwt() {
    local cmd="$1"
    shift

    case "$cmd" in
        new|n)
            _gwt_new "$@"
            ;;
        switch|s)
            _gwt_switch "$@"
            ;;
        remove|rm|r)
            _gwt_remove "$@"
            ;;
        list|ls|l)
            _gwt_list "$@"
            ;;
        status|st)
            _gwt_status "$@"
            ;;
        memo|m)
            _gwt_memo "$@"
            ;;
        info|i)
            _gwt_info "$@"
            ;;
        quick|q)
            _gwt_quick "$@"
            ;;
        prune|p)
            _gwt_prune "$@"
            ;;
        help|h|"")
            _gwt_help
            ;;
        *)
            echo -e "${RED}Error: 不明なコマンド '${cmd}'${RESET}"
            _gwt_help
            return 1
            ;;
    esac
}

# ========================================
# 1. 新しいworktreeを作成してそこに移動
# ========================================
_gwt_new() {
    local branch_name="$1"
    local base_branch="${2:-master}"

    if [[ -z "$branch_name" ]]; then
        echo -e "${RED}Error: ブランチ名を指定してください${RESET}"
        echo "Usage: gwt new <branch-name> [base-branch]"
        return 1
    fi

    # Gitリポジトリかチェック
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Gitリポジトリではありません${RESET}"
        return 1
    fi

    # worktreeベースディレクトリを作成
    local repo_name=$(basename $(git rev-parse --show-toplevel))
    local worktree_base="${GIT_WORKTREE_BASE}/${repo_name}"
    mkdir -p "$worktree_base"

    # worktreeパスを生成
    local worktree_path="${worktree_base}/${repo_name}-${branch_name}"

    # ブランチが既に存在するかチェック
    if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
        echo -e "${YELLOW}ブランチ '${branch_name}' は既に存在します。worktreeを作成します...${RESET}"
        git worktree add "$worktree_path" "$branch_name"
    else
        echo -e "${GREEN}新しいブランチ '${branch_name}' を '${base_branch}' から作成します...${RESET}"
        git worktree add -b "$branch_name" "$worktree_path" "$base_branch"
    fi

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Worktreeを作成しました: ${worktree_path}${RESET}"
        cd "$worktree_path"
        echo -e "${BLUE}→ 移動しました: $(pwd)${RESET}"
    else
        echo -e "${RED}Error: Worktreeの作成に失敗しました${RESET}"
        return 1
    fi
}

# ========================================
# 2. fzfを使用してworktreeを切り替え
# ========================================
_gwt_switch() {
    # fzfがインストールされているかチェック
    if ! command -v fzf > /dev/null 2>&1; then
        echo -e "${RED}Error: fzfがインストールされていません${RESET}"
        echo "brew install fzf または apt install fzf でインストールしてください"
        return 1
    fi

    # worktree一覧を取得
    local worktree=$(git worktree list | fzf \
        --height=40% \
        --reverse \
        --header="Select worktree to switch" \
        --preview="echo {} | awk '{print \$1}' | xargs -I{} sh -c 'cd {} && git status -sb && echo && git log --oneline -5'" \
        --preview-window=right:50%:wrap)

    if [[ -n "$worktree" ]]; then
        local wt_path=$(echo "$worktree" | awk '{print $1}')
        cd "$wt_path"
        echo -e "${GREEN}→ 切り替えました: $(pwd)${RESET}"
    fi
}

# ========================================
# 3. 不要なworktreeを削除
# ========================================
_gwt_remove() {
    # 削除対象を選択
    local worktree=$(git worktree list | grep -v "bare" | fzf \
        --height=40% \
        --reverse \
        --header="Select worktree to remove" \
        --preview="echo {} | awk '{print \$1}' | xargs -I{} sh -c 'cd {} && git status -sb && echo && git log --oneline -5'" \
        --preview-window=right:50%:wrap \
        --multi)

    if [[ -n "$worktree" ]]; then
        # パイプラインを避けて配列に格納
        local -a worktree_lines
        while IFS= read -r line; do
            worktree_lines+=("$line")
        done <<< "$worktree"

        for line in "${worktree_lines[@]}"; do
            local wt_path=$(echo "$line" | awk '{print $1}')
            local branch=$(echo "$line" | grep -o '\[.*\]' | tr -d '[]')

            echo -e "${YELLOW}削除しますか？${RESET}"
            echo "  Path: $wt_path"
            echo "  Branch: $branch"
            echo -n "続行しますか？ [y/N]: "
            read -r confirm < /dev/tty

            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                # 現在のディレクトリがworktree内の場合、メインに移動
                if [[ "$(pwd)" == "$wt_path"* ]]; then
                    cd $(git worktree list | head -1 | awk '{print $1}')
                fi

                git worktree remove "$wt_path" --force
                echo -e "${GREEN}✓ Worktreeを削除しました: $wt_path${RESET}"

                # ブランチも削除するか確認
                echo -ne "${YELLOW}ブランチ '${branch}' も削除しますか？ [y/N]: ${RESET}"
                read -r confirm_branch < /dev/tty
                if [[ "$confirm_branch" =~ ^[Yy]$ ]]; then
                    git branch -D "$branch"
                    echo -e "${GREEN}✓ ブランチを削除しました: $branch${RESET}"
                fi
            fi
        done
    fi
}

# ========================================
# 4. worktree一覧を見やすく表示
# ========================================
_gwt_list() {
    echo -e "${CYAN}=== Git Worktrees ===${RESET}"
    git worktree list | while read -r line; do
        local wt_path=$(echo "$line" | awk '{print $1}')
        local commit=$(echo "$line" | awk '{print $2}')
        local branch=$(echo "$line" | grep -o '\[.*\]' | tr -d '[]')

        # 現在のディレクトリかチェック
        if [[ "$(pwd)" == "$wt_path"* ]]; then
            echo -e "${GREEN}→ ${wt_path} ${YELLOW}[${branch}]${RESET} ${commit}"
        else
            echo -e "  ${wt_path} ${BLUE}[${branch}]${RESET} ${commit}"
        fi

        # ステータスを表示
        if [[ -d "$wt_path" ]]; then
            local changed_files=$(cd "$wt_path" && git status --porcelain | wc -l | tr -d ' ')
            if [[ "$changed_files" -gt 0 ]]; then
                echo -e "    ${YELLOW}⚠ ${changed_files} 個の変更があります${RESET}"
            fi
        fi
    done
}

# ========================================
# 5. worktreeのステータスを一括確認
# ========================================
_gwt_status() {
    echo -e "${CYAN}=== Worktree Status ===${RESET}"
    git worktree list | grep -v "bare" | while read -r line; do
        local wt_path=$(echo "$line" | awk '{print $1}')
        local branch=$(echo "$line" | grep -o '\[.*\]' | tr -d '[]')

        if [[ -d "$wt_path" ]]; then
            echo -e "\n${BLUE}[${branch}]${RESET} ${wt_path}"
            (cd "$wt_path" && git status -sb | head -10)
        fi
    done
}

# ========================================
# 6. worktreeごとのメモ機能
# ========================================
_gwt_memo() {
    local action="$1"
    local memo_file=".git/worktree-memo"

    case "$action" in
        "edit"|"e")
            ${EDITOR:-vim} "$memo_file"
            ;;
        "show"|"s"|"")
            if [[ -f "$memo_file" ]]; then
                echo -e "${CYAN}=== Worktree Memo ===${RESET}"
                cat "$memo_file"
            else
                echo -e "${YELLOW}メモはまだありません${RESET}"
            fi
            ;;
        "clear"|"c")
            rm -f "$memo_file"
            echo -e "${GREEN}メモをクリアしました${RESET}"
            ;;
        *)
            echo "Usage: gwt memo [edit|show|clear]"
            ;;
    esac
}

# ========================================
# 7. 現在のworktree情報を表示
# ========================================
_gwt_info() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Gitリポジトリではありません${RESET}"
        return 1
    fi

    local current_path=$(pwd)
    local worktree_info=$(git worktree list | grep "^${current_path}")

    if [[ -n "$worktree_info" ]]; then
        local branch=$(echo "$worktree_info" | grep -o '\[.*\]' | tr -d '[]')
        echo -e "${CYAN}=== Current Worktree Info ===${RESET}"
        echo "Path: ${current_path}"
        echo "Branch: ${branch}"
        echo "Status:"
        git status -sb
    else
        echo -e "${YELLOW}現在のディレクトリはworktreeではありません${RESET}"
    fi
}

# ========================================
# 8. worktreeを素早く作成（日付付き）
# ========================================
_gwt_quick() {
    local prefix="$1"
    local base_branch="${2:-master}"

    if [[ -z "$prefix" ]]; then
        echo -e "${RED}Error: プレフィックスを指定してください${RESET}"
        echo "Usage: gwt quick <prefix> [base-branch]"
        echo "Example: gwt quick feature/login"
        return 1
    fi

    # 日付とランダムな文字列を追加
    local date_str=$(date +%Y%m%d)
    local random_str=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 4)
    local branch_name="${prefix}-${date_str}-${random_str}"

    _gwt_new "$branch_name" "$base_branch"
}

# ========================================
# 9. pruneとclean up
# ========================================
_gwt_prune() {
    echo -e "${CYAN}=== Pruning Worktrees ===${RESET}"

    # 削除されたworktreeをクリーンアップ
    git worktree prune -v

    # 削除されたリモートブランチの追跡を削除
    git remote prune origin

    # マージ済みのブランチを確認して削除
    echo -e "\n${YELLOW}=== マージ済みのブランチとworktreeを削除 ===${RESET}"
    
    # マージ済みブランチを取得（+記号とprotected branchesを除外）
    local -a merged_branches
    while IFS= read -r branch; do
        [[ -n "$branch" ]] && merged_branches+=("$branch")
    done < <(git branch --merged | grep -v '\*\|main\|master\|develop\|+' | tr -d ' ')
    
    if [[ ${#merged_branches[@]} -gt 0 ]]; then
        echo -e "${CYAN}マージ済みブランチ: ${merged_branches[*]}${RESET}"
        
        # まず、マージ済みブランチに対応するworktreeをすべて削除
        for branch in "${merged_branches[@]}"; do
            [[ -z "$branch" ]] && continue
            
            # 該当するworktreeを検索
            local worktree_info=$(git worktree list | grep "\[$branch\]")
            
            if [[ -n "$worktree_info" ]]; then
                local wt_path=$(echo "$worktree_info" | awk '{print $1}')
                echo -e "${YELLOW}マージ済みブランチ '${branch}' のworktreeを削除: ${wt_path}${RESET}"
                
                # 現在のディレクトリがworktree内の場合、メインに移動
                if [[ "$(pwd)" == "$wt_path"* ]]; then
                    cd $(git worktree list | head -1 | awk '{print $1}')
                fi
                
                # worktreeを削除
                if git worktree remove "$wt_path" --force 2>/dev/null; then
                    echo -e "${GREEN}✓ Worktreeを削除: ${wt_path}${RESET}"
                else
                    echo -e "${RED}! Worktreeの削除に失敗: ${wt_path}${RESET}"
                fi
            fi
        done
        
        # 次に、ブランチを削除
        for branch in "${merged_branches[@]}"; do
            [[ -z "$branch" ]] && continue
            
            # ブランチを削除
            if git branch -d "$branch" 2>/dev/null; then
                echo -e "${GREEN}✓ ブランチを削除: ${branch}${RESET}"
            elif git branch -D "$branch" 2>/dev/null; then
                echo -e "${GREEN}✓ ブランチを強制削除: ${branch}${RESET}"
            else
                echo -e "${RED}! ブランチの削除に失敗: ${branch}${RESET}"
            fi
        done
    else
        echo -e "${GREEN}マージ済みのブランチはありません${RESET}"
    fi

    echo -e "\n${GREEN}✓ クリーンアップが完了しました${RESET}"
}

# ========================================
# ヘルプ表示
# ========================================
_gwt_help() {
    cat << EOF
${CYAN}Git Worktree Manager (gwt)${RESET}

${YELLOW}使い方:${RESET}
  gwt <command> [options]

${YELLOW}コマンド:${RESET}
  new, n <branch> [base]     新しいworktreeを作成して移動
  switch, s                  fzfでworktreeを選択して切り替え
  remove, rm, r              不要なworktreeを削除
  list, ls, l                worktree一覧を表示
  status, st                 全worktreeのステータスを確認
  memo, m [edit|show|clear]  worktreeごとのメモ管理
  info, i                    現在のworktree情報を表示
  quick, q <prefix> [base]   日付付きでworktreeを素早く作成
  prune, p                   worktreeのクリーンアップ
  help, h                    このヘルプを表示

${YELLOW}環境変数:${RESET}
  GIT_WORKTREE_BASE    worktreeのベースディレクトリ (default: ~/worktrees)
  GIT_WORKTREE_PREFIX  worktreeディレクトリのプレフィックス (廃止予定：リポジトリ名を使用)

${YELLOW}使用例:${RESET}
  gwt new feature/login develop    # developブランチから新しいworktreeを作成
  gwt quick fix/bug                 # 日付付きブランチを素早く作成
  gwt switch                        # worktreeを切り替え
  gwt status                        # 全worktreeの状態を確認
  gwt remove                        # 不要なworktreeを削除

${YELLOW}短縮形:${RESET}
  gwt n    = gwt new
  gwt s    = gwt switch
  gwt r    = gwt remove
  gwt l    = gwt list
  gwt st   = gwt status
  gwt m    = gwt memo
  gwt i    = gwt info
  gwt q    = gwt quick
  gwt p    = gwt prune
EOF
}

# ========================================
# 補完設定
# ========================================
_gwt_completion() {
    local -a commands
    commands=(
        'new:新しいworktreeを作成して移動'
        'switch:fzfでworktreeを選択して切り替え'
        'remove:不要なworktreeを削除'
        'list:worktree一覧を表示'
        'status:全worktreeのステータスを確認'
        'memo:worktreeごとのメモ管理'
        'info:現在のworktree情報を表示'
        'quick:日付付きでworktreeを素早く作成'
        'prune:worktreeのクリーンアップ'
        'help:ヘルプを表示'
    )

    local -a short_commands
    short_commands=(
        'n:new'
        's:switch'
        'r:remove'
        'l:list'
        'st:status'
        'm:memo'
        'i:info'
        'q:quick'
        'p:prune'
        'h:help'
    )

    _describe 'command' commands
    _describe 'short command' short_commands
}

# zsh補完を設定
if [[ -n "$ZSH_VERSION" ]]; then
    compdef _gwt_completion gwt
fi