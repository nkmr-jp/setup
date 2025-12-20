#!/bin/zsh

# zsh環境でのみ補完機能を有効化
if [[ -n "$ZSH_VERSION" ]]; then
    autoload -Uz compinit && compinit
fi

# Git Worktree Manager - 統合コマンド
# 複数のworktreeでの並行作業を効率化するユーティリティ

# カラー定義 (ANSI escape codes)
if [[ -t 1 ]]; then
    if command -v tput > /dev/null 2>&1 && tput colors > /dev/null 2>&1; then
        RED=$(tput setaf 1)
        GREEN=$(tput setaf 2)
        YELLOW=$(tput setaf 3)
        BLUE=$(tput setaf 4)
        CYAN=$(tput setaf 6)
        RESET=$(tput sgr0)
    else
        RED=$(printf '\033[0;31m')
        GREEN=$(printf '\033[0;32m')
        YELLOW=$(printf '\033[0;33m')
        BLUE=$(printf '\033[0;34m')
        CYAN=$(printf '\033[0;36m')
        RESET=$(printf '\033[0m')
    fi
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    RESET=""
fi

# ========================================
# Post-create hook 実行
# ========================================
_gwt_run_post_create_hook() {
    local worktree_path="$1"
    local branch_name="$2"
    local base_branch="$3"
    local base_path="$4"

    # 環境変数を設定
    export GWT_WORKTREE_PATH="$worktree_path"
    export GWT_BRANCH_NAME="$branch_name"
    export GWT_BASE_BRANCH="$base_branch"
    export GWT_BASE_PATH="$base_path"

    local hook_executed=false

    # 1. SETUP_DIR のスクリプトを実行（優先）
    if [[ -n "$SETUP_DIR" ]]; then
        local setup_hook="${SETUP_DIR}/zsh/gwt/post-create.sh"
        if [[ -f "$setup_hook" && -x "$setup_hook" ]]; then
            echo -e "${CYAN}→ SETUP_DIR post-create hook を実行中...${RESET}"
            if "$setup_hook"; then
                echo -e "${GREEN}✓ SETUP_DIR hook 完了${RESET}"
            else
                echo -e "${YELLOW}⚠ SETUP_DIR hook がエラーで終了しました (exit code: $?)${RESET}"
            fi
            hook_executed=true
        fi
    fi

    # 2. リポジトリルートのスクリプトを実行
    local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    local repo_hook="${repo_root}/.gwt-post-create.sh"
    if [[ -f "$repo_hook" && -x "$repo_hook" ]]; then
        echo -e "${CYAN}→ リポジトリ post-create hook を実行中...${RESET}"
        if "$repo_hook"; then
            echo -e "${GREEN}✓ リポジトリ hook 完了${RESET}"
        else
            echo -e "${YELLOW}⚠ リポジトリ hook がエラーで終了しました (exit code: $?)${RESET}"
        fi
        hook_executed=true
    fi

    # 環境変数をクリア
    unset GWT_WORKTREE_PATH GWT_BRANCH_NAME GWT_BASE_BRANCH GWT_BASE_PATH

    if [[ "$hook_executed" == false ]]; then
        # hookが見つからなかった場合は何も表示しない（通常動作）
        :
    fi
}

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
    local base_branch="${2:-$(git branch --show-current)}"

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

    # 元リポジトリと同じディレクトリにworktreeを作成
    local current_repo_name=$(basename $(git rev-parse --show-toplevel))
    local repo_parent_dir=$(dirname $(git rev-parse --show-toplevel))
    
    # 既存の-wt-サフィックスを除去してベースリポジトリ名を取得
    local repo_name=$(echo "$current_repo_name" | sed 's/-wt-.*$//')

    # worktreeパスを生成（元リポジトリと同じディレクトリに作成）
    local worktree_path="${repo_parent_dir}/${repo_name}-wt-${branch_name}"

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

        # ベースパス（メインworktree）を取得
        local base_path=$(git worktree list | head -1 | awk '{print $1}')

        cd "$worktree_path"
        echo -e "${BLUE}→ 移動しました: $(pwd)${RESET}"

        # Post-create hook を実行
        _gwt_run_post_create_hook "$worktree_path" "$branch_name" "$base_branch" "$base_path"
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
        --header="Select worktree to switch")

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
    local base_branch="${2:-$(git branch --show-current)}"

    if [[ -z "$prefix" ]]; then
        echo -e "${RED}Error: プレフィックスを指定してください${RESET}"
        echo "Usage: gwt quick <prefix> [base-branch]"
        echo "Example: gwt quick feature/login"
        return 1
    fi

    # 日付とランダムな文字列を追加
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local branch_name="${prefix}-${timestamp}"

    _gwt_new "$branch_name" "$base_branch"
}

# ========================================
# 9. pruneとclean up
# ========================================
_gwt_prune() {
    echo -e "${CYAN}=== Pruning Worktrees ===${RESET}"

    # リモートから最新の情報を取得
    echo -e "${BLUE}リモートから最新の情報を取得中...${RESET}"
    git pull

    # 削除されたworktreeをクリーンアップ
    git worktree prune -v

    # 削除されたリモートブランチの追跡を削除
    git remote prune origin

    # メインブランチを特定
    local main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [[ -z "$main_branch" ]]; then
        # mainブランチが存在するかチェック
        if git show-ref --verify --quiet "refs/heads/main" || git show-ref --verify --quiet "refs/remotes/origin/main"; then
            main_branch="main"
        else
            main_branch="master"
        fi
    fi

    echo -e "\n${YELLOW}=== マージ済みのworktreeとブランチを削除 ===${RESET}"
    echo -e "${CYAN}メインブランチ: ${main_branch}${RESET}"

    # 保護対象のブランチ
    local -a protected_branches=("main" "master" "develop" "development" "$main_branch")
    
    # マージ済みのworktreeとブランチを収集
    local -a merged_worktrees
    local -a merged_branches
    local deleted_count=0

    # worktree一覧を取得してマージ済みかチェック
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        local wt_path=$(echo "$line" | awk '{print $1}')
        local branch=$(echo "$line" | grep -o '\[.*\]' | tr -d '[]')
        
        # メインリポジトリはスキップ
        [[ "$wt_path" == *"[bare]"* ]] && continue
        [[ "$branch" == "$main_branch" ]] && continue
        
        # 保護対象ブランチをスキップ
        local is_protected=false
        for protected in "${protected_branches[@]}"; do
            [[ "$branch" == "$protected" ]] && is_protected=true && break
        done
        [[ "$is_protected" == true ]] && continue
        
        # マージ済みかチェック（master、main、developにマージ済みの場合）
        local is_merged=false
        for check_branch in "master" "main" "develop"; do
            if git show-ref --verify --quiet "refs/heads/$check_branch" || git show-ref --verify --quiet "refs/remotes/origin/$check_branch"; then
                # 通常のマージ: git branch --merged を使ってマージ済みブランチをチェック
                if git branch --merged "$check_branch" 2>/dev/null | grep -q "^[[:space:]]*[+*][[:space:]]*${branch}$"; then
                    is_merged=true
                    break
                fi
                
                # スカッシュマージの検知: ブランチの変更がすべてメインブランチに含まれているかチェック
                if ! git merge-base --is-ancestor "$check_branch" "$branch" 2>/dev/null; then
                    # ブランチの全ファイル変更を取得
                    local branch_changes=$(git diff --name-only "$check_branch"..."$branch" 2>/dev/null)
                    if [[ -n "$branch_changes" ]]; then
                        # 各ファイルの内容がメインブランチと同じかチェック
                        local all_changes_included=true
                        while IFS= read -r file; do
                            if [[ -n "$file" ]]; then
                                # ブランチでの最終的な内容とメインブランチでの内容を比較
                                local branch_content=$(git show "$branch":"$file" 2>/dev/null || echo "")
                                local main_content=$(git show "$check_branch":"$file" 2>/dev/null || echo "")
                                if [[ "$branch_content" != "$main_content" ]]; then
                                    all_changes_included=false
                                    break
                                fi
                            fi
                        done <<< "$branch_changes"
                        
                        if [[ "$all_changes_included" == true ]]; then
                            is_merged=true
                            break
                        fi
                    fi
                fi
            fi
        done
        
        if [[ "$is_merged" == true ]]; then
            # 作成から30分以上経過しているかチェック
            local is_old_enough=false
            if [[ -d "$wt_path" ]]; then
                local current_time=$(date +%s)
                # macOSではstat -f %B、Linuxではstat -c %W（未対応の場合は%Y）
                local creation_time
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    creation_time=$(stat -f %B "$wt_path" 2>/dev/null)
                else
                    creation_time=$(stat -c %W "$wt_path" 2>/dev/null)
                    # 作成時間が取得できない場合は変更時間を使用
                    if [[ "$creation_time" == "0" || -z "$creation_time" ]]; then
                        creation_time=$(stat -c %Y "$wt_path" 2>/dev/null)
                    fi
                fi

                if [[ -n "$creation_time" && "$creation_time" != "0" ]]; then
                    local age_seconds=$((current_time - creation_time))
                    local age_minutes=$((age_seconds / 60))
                    if [[ $age_minutes -ge 30 ]]; then
                        is_old_enough=true
                    else
                        echo -e "${BLUE}⏳ スキップ: ${branch} (${wt_path})${RESET}"
                        echo -e "  ${CYAN}作成から ${age_minutes} 分経過（30分未満のためスキップ）${RESET}"
                    fi
                else
                    # 作成時間が取得できない場合はスキップしない
                    is_old_enough=true
                fi
            fi

            if [[ "$is_old_enough" == false ]]; then
                continue
            fi

            # 未コミットの変更があるかチェック
            local has_uncommitted=false
            if [[ -d "$wt_path" ]]; then
                local uncommitted_count=$(cd "$wt_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
                if [[ "$uncommitted_count" -gt 0 ]]; then
                    has_uncommitted=true
                    echo -e "${RED}⚠ スキップ: ${branch} (${wt_path})${RESET}"
                    echo -e "  ${YELLOW}未コミットの変更が ${uncommitted_count} 個あります${RESET}"
                    # 変更内容を表示
                    (cd "$wt_path" && git status --porcelain | head -10 | while read -r status_line; do
                        echo -e "    ${CYAN}${status_line}${RESET}"
                    done)
                    local remaining=$((uncommitted_count - 10))
                    if [[ $remaining -gt 0 ]]; then
                        echo -e "    ${YELLOW}... 他 ${remaining} 個${RESET}"
                    fi
                fi
            fi

            if [[ "$has_uncommitted" == false ]]; then
                echo -e "${YELLOW}マージ済み検出: ${branch} (${wt_path})${RESET}"
                merged_worktrees+=("$wt_path")
                merged_branches+=("$branch")
            fi
        fi
    done < <(git worktree list | grep -v "bare")

    # マージ済みworktreeとブランチがある場合削除処理
    if [[ ${#merged_worktrees[@]} -gt 0 ]]; then
        echo -e "${CYAN}削除対象: ${#merged_worktrees[@]}個のworktreeとブランチ${RESET}"
        
        # worktreeを削除
        for ((i=1; i<=$#merged_worktrees; i++)); do
            local wt_path="${merged_worktrees[$i]}"
            local branch="${merged_branches[$i]}"
            
            echo -e "${YELLOW}削除中: ${branch} -> ${wt_path}${RESET}"
            
            # 現在のディレクトリがworktree内の場合、メインに移動
            if [[ "$(pwd)" == "$wt_path"* ]]; then
                local main_path=$(git worktree list | head -1 | awk '{print $1}')
                cd "$main_path"
                echo -e "${BLUE}メインリポジトリに移動: ${main_path}${RESET}"
            fi
            
            # worktreeを削除
            if git worktree remove "$wt_path" --force 2>/dev/null; then
                echo -e "${GREEN}✓ Worktreeを削除: ${wt_path}${RESET}"
                ((deleted_count++))
            else
                echo -e "${RED}✗ Worktreeの削除に失敗: ${wt_path}${RESET}"
                continue
            fi
            
            # ブランチを削除
            if git branch -d "$branch" 2>/dev/null; then
                echo -e "${GREEN}✓ ブランチを削除: ${branch}${RESET}"
            elif git branch -D "$branch" 2>/dev/null; then
                echo -e "${GREEN}✓ ブランチを強制削除: ${branch}${RESET}"
            else
                echo -e "${RED}✗ ブランチの削除に失敗: ${branch}${RESET}"
            fi
            
            echo ""
        done
        
        echo -e "${GREEN}✓ ${deleted_count}個のworktreeとブランチを削除しました${RESET}"
    else
        echo -e "${GREEN}マージ済みのworktreeとブランチはありません${RESET}"
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

${YELLOW}Post-create Hook:${RESET}
  worktree作成後に自動的にスクリプトを実行できます。

  ${CYAN}スクリプトの配置場所 (実行順序):${RESET}
    1. \$SETUP_DIR/zsh/gwt/post-create.sh  (setup リポジトリで管理)
    2. <repo-root>/.gwt-post-create.sh     (リポジトリ固有)

  ${CYAN}利用可能な環境変数:${RESET}
    GWT_WORKTREE_PATH   作成されたworktreeのパス
    GWT_BRANCH_NAME     ブランチ名
    GWT_BASE_BRANCH     ベースブランチ名
    GWT_BASE_PATH       ベースリポジトリ（メインworktree）のパス

  ${CYAN}例 (.gwt-post-create.sh):${RESET}
    #!/bin/bash
    npm install  # 依存関係をインストール
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

# ========================================
# エイリアス
# ========================================
alias g='gwt'
alias gq='gwt q'
alias gp='gwt p'
alias gr='gwt r'
alias gl='gwt l'
alias gs='gwt s'
