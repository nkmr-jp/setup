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
# ブロッキングコマンドの遅延実行（zle-line-init経由）
# ========================================
# iTerm2の "Reuse previous session's directory" はプロンプトが実際に表示され、
# シェルが入力待ち状態になって初めてCWDを更新する。
# precmd内やエスケープシーケンスだけではCWDが更新されない。
#
# 解決策: 関数からリターン → precmd発火 → プロンプト表示 → zle-line-init発火
# → この時点でiTerm2のCWDが更新済み → コマンドを自動実行
_GWT_DEFERRED_CMD=""
_GWT_DEFERRED_RETURN=""

_gwt_zle_auto_execute() {
    if [[ -n "$_GWT_DEFERRED_CMD" ]]; then
        local cmd="$_GWT_DEFERRED_CMD"
        local return_dir="$_GWT_DEFERRED_RETURN"
        _GWT_DEFERRED_CMD=""
        _GWT_DEFERRED_RETURN=""

        # BUFFERにコマンドを設定してaccept-lineで自動実行
        # プロンプト表示後なのでiTerm2のCWDは更新済み
        if [[ -n "$return_dir" ]]; then
            BUFFER="${cmd} && cd '${return_dir}'"
        else
            BUFFER="$cmd"
        fi
        zle accept-line
    fi
}
zle -N _gwt_zle_auto_execute
zle -N zle-line-init _gwt_zle_auto_execute

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
# JetBrains Recent Projectsから削除
# ========================================
_gwt_remove_from_jetbrains_recent() {
    local wt_path="$1"
    local jetbrains_dir="$HOME/Library/Application Support/JetBrains"

    # JetBrainsディレクトリが存在しない場合はスキップ
    [[ ! -d "$jetbrains_dir" ]] && return 0

    # $HOME を $USER_HOME$ に変換（JetBrainsのXML形式）
    local escaped_path="${wt_path/#$HOME/\$USER_HOME\$}"
    # XMLで使う正規表現用にエスケープ
    local escaped_for_sed=$(echo "$escaped_path" | sed 's/[\/&]/\\&/g')

    local removed=false

    # 全てのJetBrains IDEのrecentProjects.xmlを処理
    find "$jetbrains_dir" -name "recentProjects.xml" -type f 2>/dev/null | while read -r xml_file; do
        # backupディレクトリはスキップ
        [[ "$xml_file" == *"-backup"* ]] && continue

        # 該当エントリが存在するかチェック
        if grep -q "\"${escaped_path}\"" "$xml_file" 2>/dev/null; then
            # sedでエントリブロック全体を削除
            # <entry key="$USER_HOME$/path">...</entry> の形式
            sed -i '' "/<entry key=\"${escaped_for_sed}\">/,/<\/entry>/d" "$xml_file" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                local ide_name=$(echo "$xml_file" | sed 's|.*/JetBrains/\([^/]*\)/.*|\1|')
                echo -e "${GREEN}✓ JetBrains Recent Projectsから削除: ${ide_name}${RESET}"
                removed=true
            fi
        fi
    done

    return 0
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
        claude|cc)
            _gwt_claude "$@"
            ;;
        yolo|y)
            _gwt_claude_yolo "$@"
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

        # 作成されたworktreeパスを共有変数に保存
        _GWT_LAST_WORKTREE_PATH="$worktree_path"

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
    # 保護対象のブランチ
    local -a protected_branches=("main" "master" "develop" "development")

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

            # 保護対象ブランチのチェック
            local is_protected=false
            for protected in "${protected_branches[@]}"; do
                [[ "$branch" == "$protected" ]] && is_protected=true && break
            done
            if [[ "$is_protected" == true ]]; then
                echo -e "${RED}Error: '${branch}' は保護対象ブランチのため削除できません${RESET}"
                continue
            fi

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

                # JetBrains Recent Projectsから削除
                _gwt_remove_from_jetbrains_recent "$wt_path"

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

    # 日付時刻サフィックス (MMDDHHmm形式)
    local timestamp=$(date +"%m%d%H%M")
    local branch_name="${prefix}-${timestamp}"

    _gwt_new "$branch_name" "$base_branch"
}

# ========================================
# 9. pruneとclean up
# ========================================
_gwt_prune() {
    # --force / -f オプションで確認プロンプトをスキップ
    local force_mode=false
    for arg in "$@"; do
        [[ "$arg" == "--force" || "$arg" == "-f" ]] && force_mode=true
    done

    echo -e "${CYAN}=== Pruning Worktrees ===${RESET}"

    # リモートから最新の情報を取得（--pruneで削除済みリモートブランチも反映）
    echo -e "${BLUE}リモートから最新の情報を取得中...${RESET}"
    git fetch --prune

    # main/developブランチのローカルコピーを最新に更新
    local _current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    local -a _fetch_refspecs
    local -a _updated_branches
    for _branch in main master develop; do
        if git show-ref --verify --quiet "refs/remotes/origin/$_branch" 2>/dev/null && \
           git show-ref --verify --quiet "refs/heads/$_branch" 2>/dev/null; then
            if [[ "$_branch" == "$_current_branch" ]]; then
                # チェックアウト中のブランチはfetchで更新できないためmergeで更新
                if git merge --ff-only "origin/$_branch" 2>/dev/null; then
                    _updated_branches+=("$_branch")
                else
                    echo -e "${YELLOW}⚠ ${_branch} の更新をスキップ（未コミットの変更またはfast-forward不可）${RESET}"
                fi
            else
                _fetch_refspecs+=("$_branch:$_branch")
            fi
        fi
    done
    if [[ ${#_fetch_refspecs[@]} -gt 0 ]]; then
        if git fetch origin "${_fetch_refspecs[@]}" 2>/dev/null; then
            _updated_branches+=("${_fetch_refspecs[@]%%:*}")
        fi
    fi
    if [[ ${#_updated_branches[@]} -gt 0 ]]; then
        echo -e "${GREEN}✓ ブランチ更新完了: ${_updated_branches[*]}${RESET}"
    fi

    # 削除されたworktreeをクリーンアップ
    git worktree prune -v

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
    local -a auto_delete_worktrees
    local -a auto_delete_branches
    local deleted_count=0
    local current_time=$(date +%s)

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

        # 通常マージ・スカッシュマージの検知
        for check_branch in "master" "main" "develop"; do
            # origin/$check_branch が存在するかチェック
            if ! git show-ref --verify --quiet "refs/remotes/origin/$check_branch" 2>/dev/null; then
                continue
            fi

            # 通常のマージ: ブランチのHEADがorigin/$check_branchの祖先かチェック
            if git merge-base --is-ancestor "$branch" "origin/$check_branch" 2>/dev/null; then
                is_merged=true
                break
            fi

            # スカッシュマージの検知: ブランチの変更がすべてリモートのメインブランチに含まれているかチェック
            local merge_base=$(git merge-base "origin/$check_branch" "$branch" 2>/dev/null)
            if [[ -n "$merge_base" ]]; then
                # merge-base..branchの差分がorigin/check_branchに全て含まれているか一括チェック
                if git diff --quiet "$branch" "origin/$check_branch" -- $(git diff --name-only "$merge_base" "$branch" 2>/dev/null) 2>/dev/null; then
                    # 差分なし = スカッシュマージ済み（ただし変更がある場合のみ）
                    if [[ -n "$(git diff --name-only "$merge_base" "$branch" 2>/dev/null)" ]]; then
                        is_merged=true
                        break
                    fi
                fi
            fi
        done

        # GitHub PRマージ済みチェック（スカッシュマージ後にターゲットが進んだ場合のフォールバック）
        if [[ "$is_merged" == false ]] && command -v gh > /dev/null 2>&1; then
            local _pr_count=$(gh pr list --head "$branch" --state merged --json number --jq 'length' 2>/dev/null)
            if [[ "$_pr_count" -gt 0 ]]; then
                is_merged=true
            fi
        fi
        
        if [[ "$is_merged" == true ]]; then
            # 作成から30分以上経過しているかチェック
            local is_old_enough=false
            if [[ -d "$wt_path" ]]; then
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
                    # 作成時間が取得できない場合は安全のためスキップ
                    echo -e "${BLUE}⏳ スキップ: ${branch} (${wt_path})${RESET}"
                    echo -e "  ${CYAN}作成時間を取得できないためスキップ${RESET}"
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
                # ローカルの現在ブランチに取り込み済みか判定（通常マージ+スカッシュマージ）
                local _merged_to_local=false

                # 通常マージの検出
                if git merge-base --is-ancestor "$branch" "$_current_branch" 2>/dev/null; then
                    _merged_to_local=true
                fi

                # スカッシュマージの検出
                if [[ "$_merged_to_local" == false ]]; then
                    local _local_merge_base=$(git merge-base "$_current_branch" "$branch" 2>/dev/null)
                    if [[ -n "$_local_merge_base" ]]; then
                        local _changed_files=$(git diff --name-only "$_local_merge_base" "$branch" 2>/dev/null)
                        if [[ -n "$_changed_files" ]]; then
                            if git diff --quiet "$branch" "$_current_branch" -- $_changed_files 2>/dev/null; then
                                _merged_to_local=true
                            fi
                        fi
                    fi
                fi

                if [[ "$_merged_to_local" == true ]]; then
                    echo -e "${GREEN}✓ ローカルに取り込み済み: ${branch} (${wt_path})${RESET}"
                    auto_delete_worktrees+=("$wt_path")
                    auto_delete_branches+=("$branch")
                else
                    echo -e "${YELLOW}マージ済み検出（リモートのみ）: ${branch} (${wt_path})${RESET}"
                    merged_worktrees+=("$wt_path")
                    merged_branches+=("$branch")
                fi
            fi
        fi
    done < <(git worktree list | grep -v "bare")

    # メインリポジトリのパスをキャッシュ
    local _main_repo_path=$(git worktree list | head -1 | awk '{print $1}')

    # worktreeとブランチを削除する共通関数
    _gwt_delete_worktree_and_branch() {
        local wt_path="$1"
        local branch="$2"

        echo -e "${YELLOW}削除中: ${branch} -> ${wt_path}${RESET}"

        # 現在のディレクトリがworktree内の場合、メインに移動
        if [[ "$(pwd)" == "$wt_path"* ]]; then
            cd "$_main_repo_path"
            echo -e "${BLUE}メインリポジトリに移動: ${_main_repo_path}${RESET}"
        fi

        # worktreeを削除（--forceなしで安全に削除）
        if git worktree remove "$wt_path" 2>/dev/null; then
            echo -e "${GREEN}✓ Worktreeを削除: ${wt_path}${RESET}"
            ((deleted_count++))
            _gwt_remove_from_jetbrains_recent "$wt_path"
        else
            echo -e "${RED}✗ Worktreeの削除に失敗: ${wt_path}${RESET}"
            return 1
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
    }

    # ローカルに取り込み済みのworktreeを確認なしで自動削除
    if [[ ${#auto_delete_worktrees[@]} -gt 0 ]]; then
        echo -e "\n${GREEN}=== ローカルに取り込み済み: ${#auto_delete_worktrees[@]}個を自動削除 ===${RESET}"
        for ((i=1; i<=$#auto_delete_worktrees; i++)); do
            _gwt_delete_worktree_and_branch "${auto_delete_worktrees[$i]}" "${auto_delete_branches[$i]}"
        done
    fi

    # リモートのみにマージ済みのworktreeは確認して削除
    if [[ ${#merged_worktrees[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}=== リモートのみにマージ済み: ${#merged_worktrees[@]}個（確認が必要） ===${RESET}"
        for ((i=1; i<=$#merged_worktrees; i++)); do
            echo -e "  ${YELLOW}${merged_branches[$i]}${RESET} -> ${merged_worktrees[$i]}"
        done

        # 確認プロンプト（--force でスキップ）
        if [[ "$force_mode" == false ]]; then
            echo ""
            local answer
            read -r "answer?${YELLOW}削除しますか？ [y/N]: ${RESET}"
            if [[ ! "$answer" =~ ^[Yy]$ ]]; then
                echo -e "${BLUE}キャンセルしました${RESET}"
                if [[ $deleted_count -gt 0 ]]; then
                    echo -e "${GREEN}✓ ${deleted_count}個のworktreeとブランチを削除しました${RESET}"
                fi
                return 0
            fi
        fi

        for ((i=1; i<=$#merged_worktrees; i++)); do
            _gwt_delete_worktree_and_branch "${merged_worktrees[$i]}" "${merged_branches[$i]}"
        done
    fi

    if [[ $deleted_count -gt 0 ]]; then
        echo -e "${GREEN}✓ 合計 ${deleted_count}個のworktreeとブランチを削除しました${RESET}"
    elif [[ ${#auto_delete_worktrees[@]} -eq 0 && ${#merged_worktrees[@]} -eq 0 ]]; then
        echo -e "${GREEN}マージ済みのworktreeとブランチはありません${RESET}"
    fi

    echo -e "\n${GREEN}✓ クリーンアップが完了しました${RESET}"
}

# ========================================
# 10. worktreeを作成してClaude Codeを起動
# ========================================
_gwt_claude() {
    local prefix="$1"
    shift

    if [[ -z "$prefix" ]]; then
        echo -e "${RED}Error: プレフィックスを指定してください${RESET}"
        echo "Usage: gwt claude <prefix> [base-branch]"
        echo "Example: gwt claude feature/login"
        return 1
    fi

    local base_branch="$1"
    local original_dir="$(pwd)"

    # quickでworktreeを作成
    _GWT_LAST_WORKTREE_PATH=""
    _gwt_quick "$prefix" ${base_branch:+"$base_branch"}
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # 作成されたworktreeのパスを保持
    local worktree_dir="$_GWT_LAST_WORKTREE_PATH"
    if [[ -n "$worktree_dir" && -d "$worktree_dir" ]]; then
        cd "$worktree_dir"
    fi

    # Claude Codeを遅延実行（関数リターン → precmd発火 → CWD更新 → claude起動）
    echo -e "${CYAN}→ Claude Code を起動します ($(pwd))...${RESET}"
    _GWT_DEFERRED_CMD="claude"
    _GWT_DEFERRED_RETURN="$original_dir"
}

# ========================================
# 11. worktreeを作成してClaude Code (yolo) を起動
# ========================================
_gwt_claude_yolo() {
    local prefix="$1"
    shift

    if [[ -z "$prefix" ]]; then
        echo -e "${RED}Error: プレフィックスを指定してください${RESET}"
        echo "Usage: gwt yolo <prefix> [base-branch]"
        echo "Example: gwt yolo feature/login"
        return 1
    fi

    local base_branch="$1"
    local original_dir="$(pwd)"

    # quickでworktreeを作成
    _GWT_LAST_WORKTREE_PATH=""
    _gwt_quick "$prefix" ${base_branch:+"$base_branch"}
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # 作成されたworktreeのパスを保持
    local worktree_dir="$_GWT_LAST_WORKTREE_PATH"
    if [[ -n "$worktree_dir" && -d "$worktree_dir" ]]; then
        cd "$worktree_dir"
    fi

    # Claude Code (yolo mode) を遅延実行（関数リターン → precmd発火 → CWD更新 → claude起動）
    echo -e "${YELLOW}→ Claude Code (yolo mode) を起動します ($(pwd))...${RESET}"
    _GWT_DEFERRED_CMD="claude --dangerously-skip-permissions"
    _GWT_DEFERRED_RETURN="$original_dir"
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
  prune, p [-f|--force]      worktreeのクリーンアップ（-f: 確認スキップ）
  claude, cc <prefix> [base] 日付付きworktreeを作成してClaude Codeを起動
  yolo, y <prefix> [base]    日付付きworktreeを作成してClaude Code (yolo) を起動
  help, h                    このヘルプを表示

${YELLOW}使用例:${RESET}
  gwt new feature/login develop    # developブランチから新しいworktreeを作成
  gwt quick fix/bug                 # 日付付きブランチを素早く作成
  gwt switch                        # worktreeを切り替え
  gwt status                        # 全worktreeの状態を確認
  gwt remove                        # 不要なworktreeを削除
  gwt claude feature/login develop  # 日付付きworktreeを作成してClaude Codeを起動
  gwt yolo feature/login develop   # 日付付きworktreeを作成してClaude Code (yolo) を起動

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
  gwt cc   = gwt claude
  gwt y    = gwt yolo

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
        'claude:worktreeを作成してClaude Codeを起動'
        'yolo:worktreeを作成してClaude Code (yolo) を起動'
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
        'cc:claude'
        'y:yolo'
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
alias gn='gwt n'
alias gcc='gwt cc'
alias gy='gwt y'
alias claudew='gwt cc'
alias yolow='gwt y'
