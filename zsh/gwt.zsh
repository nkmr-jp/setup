#!/bin/zsh

# Enable completion only in zsh.
if [[ -n "$ZSH_VERSION" ]]; then
    autoload -Uz compinit && compinit
fi

# Git Worktree Manager - unified command.
# Utilities for efficient parallel work across multiple worktrees.

# Color definitions (ANSI escape codes).
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
# Defer blocking commands through zle-line-init.
# ========================================
# iTerm2's "Reuse previous session's directory" updates CWD only after the prompt
# is displayed and the shell starts waiting for input.
# precmd or escape sequences alone do not update CWD.
#
# Sequence: return from function -> precmd -> display prompt -> zle-line-init
# -> iTerm2 has now updated CWD -> execute the command automatically.
_GWT_DEFERRED_CMD=""
_GWT_DEFERRED_RETURN=""
_GWT_RETURN_AFTER=""

_gwt_zle_auto_execute() {
    if [[ -n "$_GWT_DEFERRED_CMD" ]]; then
        local cmd="$_GWT_DEFERRED_CMD"
        local return_dir="$_GWT_DEFERRED_RETURN"
        _GWT_DEFERRED_CMD=""
        _GWT_DEFERRED_RETURN=""

        # Save the return directory for precmd without putting the old path into BUFFER.
        if [[ -n "$return_dir" ]]; then
            _GWT_RETURN_AFTER="$return_dir"
        fi

        # Emit OSC 1337 immediately before accept-line to ensure iTerm2 updates CWD.
        _iterm2_send_current_dir 2>/dev/null

        BUFFER="$cmd"
        zle accept-line
    fi
}
zle -N _gwt_zle_auto_execute
zle -N zle-line-init _gwt_zle_auto_execute

# Return to the original directory in precmd after the command completes.
_gwt_return_after_precmd() {
    if [[ -n "$_GWT_RETURN_AFTER" ]]; then
        local dir="$_GWT_RETURN_AFTER"
        _GWT_RETURN_AFTER=""
        cd "$dir"
    fi
}
precmd_functions=($precmd_functions _gwt_return_after_precmd)

# ========================================
# Run the post-create hook.
# ========================================
_gwt_run_post_create_hook() {
    local hook_executed=false

    # 2. Run the script at the repository root.
    local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    local repo_hook="${repo_root}/.gwt-post-create.sh"
    if [[ -f "$repo_hook" && -x "$repo_hook" ]]; then
        # Set environment variables.
        export GWT_WORKTREE_PATH="$1"
        export GWT_BRANCH_NAME="$2"
        export GWT_BASE_BRANCH="$3"
        export GWT_BASE_PATH="$4"
        echo -e "${CYAN}→ リポジトリ post-create hook を実行中...${RESET}"
        if "$repo_hook"; then
            echo -e "${GREEN}✓ リポジトリ hook 完了${RESET}"
        else
            echo -e "${YELLOW}⚠ リポジトリ hook がエラーで終了しました (exit code: $?)${RESET}"
        fi
        hook_executed=true

        # Clear environment variables.
        unset GWT_WORKTREE_PATH GWT_BRANCH_NAME GWT_BASE_BRANCH GWT_BASE_PATH
    fi

    if [[ "$hook_executed" == false ]]; then
        # Remain silent if no hook is found (normal behavior).
        :
    fi
}

# ========================================
# Create the .agentsws/issues symlink.
# ========================================
# Create .agentsws/issues in the worktree and link it to
# the matching project directory in the issues repository ($GWT_ISSUES_REPO_DIR).
# The project name is the base repository name with the -wt- suffix removed.
# - Do nothing if GWT_ISSUES_REPO_DIR is unset.
# - Skip without an error if the issues repository does not exist.
# - If the issues repository has projects/, use it as the parent of project directories.
# - Create the target project directory first if it does not exist.
_gwt_setup_agentsws_issues_link() {
    local worktree_path="$1"
    local project_name="$2"
    local issues_repo_dir="$GWT_ISSUES_REPO_DIR"

    # Skip if GWT_ISSUES_REPO_DIR is unset or empty.
    [[ -n "$issues_repo_dir" ]] || return 0

    # Also skip without an error if the issues repository does not exist.
    [[ -d "$issues_repo_dir" ]] || return 0

    # For the projects/ layout, use that directory as the parent of project directories.
    # Actual content lives in <repo>/projects/<project>/; linking to the repository root
    # would create an empty directory and hide all existing issues from the link.
    # If GWT_ISSUES_REPO_DIR already points to projects/, projects/projects does not exist,
    # so the path is used unchanged (idempotent).
    local projects_parent="$issues_repo_dir"
    [[ -d "${issues_repo_dir}/projects" ]] && projects_parent="${issues_repo_dir}/projects"

    local issues_project_dir="${projects_parent}/${project_name}"
    local agentsws_dir="${worktree_path}/.agentsws"
    local link_path="${agentsws_dir}/issues"

    # Skip if a link or file already exists.
    [[ -e "$link_path" || -L "$link_path" ]] && return 0

    # Create the project directory in the issues repository.
    if [[ ! -d "$issues_project_dir" ]]; then
        mkdir -p "$issues_project_dir"
        echo -e "${CYAN}→ issues プロジェクトフォルダを作成: ${issues_project_dir}${RESET}"
    fi

    # Create the .agentsws directory and symlink.
    mkdir -p "$agentsws_dir"
    ln -s "$issues_project_dir" "$link_path"
    echo -e "${GREEN}✓ .agentsws/issues -> ${issues_project_dir}${RESET}"
}

# ========================================
# Remove from JetBrains Recent Projects.
# ========================================
_gwt_jetbrains_dir="$HOME/Library/Application Support/JetBrains"
_gwt_jetbrains_pending_file="$HOME/.cache/gwt/jetbrains_pending_cleanup.txt"

_gwt_is_jetbrains_running() {
    pgrep -f '/Applications/.+\.app/Contents/MacOS/(goland|idea|pycharm|webstorm|clion|rubymine|rider|phpstorm|datagrip)' > /dev/null 2>&1
}

_gwt_remove_from_jetbrains_recent() {
    local wt_path="$1"
    [[ ! -d "$_gwt_jetbrains_dir" ]] && return 0

    # Record pending removal if a JetBrains IDE is running.
    if _gwt_is_jetbrains_running; then
        mkdir -p "$HOME/.cache/gwt"
        echo "$wt_path" >> "$_gwt_jetbrains_pending_file"
        echo -e "${YELLOW}⚠ JetBrains IDEが起動中のため、Recent Projects削除を保留しました${RESET}"
        echo -e "  ${CYAN}IDE終了後に gwt prune を再実行すると削除されます${RESET}"
        return 0
    fi

    _gwt_do_remove_from_jetbrains_recent "$wt_path"
}

_gwt_do_remove_from_jetbrains_recent() {
    local wt_path="$1"
    [[ ! -d "$_gwt_jetbrains_dir" ]] && return 0

    local escaped_path="${wt_path/#$HOME/\$USER_HOME\$}"
    local escaped_for_sed="${escaped_path//\//\\/}"
    escaped_for_sed="${escaped_for_sed//&/\\&}"

    # Process recentProjects.xml for every JetBrains IDE.
    find "$_gwt_jetbrains_dir" -name "recentProjects.xml" -type f 2>/dev/null | while read -r xml_file; do
        [[ "$xml_file" == *"-backup"* ]] && continue

        if grep -q "\"${escaped_path}\"" "$xml_file" 2>/dev/null; then
            # Remove the entire <entry key="$USER_HOME$/path">...</entry> block.
            if sed -i '' "/<entry key=\"${escaped_for_sed}\">/,/<\/entry>/d" "$xml_file" 2>/dev/null; then
                local ide_name="${xml_file#*JetBrains/}"
                ide_name="${ide_name%%/*}"
                echo -e "${GREEN}✓ JetBrains Recent Projectsから削除: ${ide_name}${RESET}"
            fi
        fi
    done
}

_gwt_process_jetbrains_pending() {
    [[ ! -f "$_gwt_jetbrains_pending_file" ]] && return 0

    if _gwt_is_jetbrains_running; then
        local pending_count=$(( $(wc -l < "$_gwt_jetbrains_pending_file") ))
        echo -e "${YELLOW}⚠ JetBrains IDEが起動中のため、${pending_count}件のRecent Projects削除が保留中です${RESET}"
        echo -e "  ${CYAN}IDE終了後に gwt prune を再実行してください${RESET}"
        return 0
    fi

    echo -e "${BLUE}保留中のJetBrains Recent Projects削除を実行中...${RESET}"
    while IFS= read -r wt_path; do
        [[ -z "$wt_path" ]] && continue
        _gwt_do_remove_from_jetbrains_recent "$wt_path"
    done < <(sort -u "$_gwt_jetbrains_pending_file")
    rm -f "$_gwt_jetbrains_pending_file"
}

# ========================================
# Main command.
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
            _gwt_yolo "$@"
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
# Automatically resolve the base branch.
# ========================================
# When inside a worktree, update the branch in the main directory without -wt-
# and return it as the base branch.
_gwt_resolve_base_branch() {
    local current_repo_name=$(basename $(git rev-parse --show-toplevel))

    # Return the current branch if the directory is not a worktree (does not contain -wt-).
    if [[ "$current_repo_name" != *"-wt-"* ]]; then
        git branch --show-current
        return 0
    fi

    # Find the directory without -wt- in the worktree list.
    local -a main_entries
    while IFS= read -r line; do
        local wt_path=$(echo "$line" | awk '{print $1}')
        local wt_dir=$(basename "$wt_path")
        if [[ "$wt_dir" != *"-wt-"* ]]; then
            main_entries+=("$line")
        fi
    done < <(git worktree list)

    # Warn and exit if multiple directories without -wt- exist.
    if [[ ${#main_entries[@]} -gt 1 ]]; then
        echo -e "${RED}Error: wtなしのディレクトリが複数見つかりました:${RESET}" >&2
        for entry in "${main_entries[@]}"; do
            echo -e "  ${YELLOW}${entry}${RESET}" >&2
        done
        return 1
    fi

    if [[ ${#main_entries[@]} -eq 0 ]]; then
        echo -e "${RED}Error: メインのワークツリーが見つかりません${RESET}" >&2
        return 1
    fi

    # Get the main directory's branch.
    local main_branch=$(echo "${main_entries[1]}" | grep -o '\[.*\]' | tr -d '[]')

    if [[ -z "$main_branch" ]]; then
        echo -e "${RED}Error: メインのワークツリーがdetached HEAD状態です${RESET}" >&2
        return 1
    fi

    # Update the branch.
    echo -e "${BLUE}ベースブランチ '${main_branch}' を最新化中...${RESET}" >&2
    if git fetch origin "$main_branch:$main_branch" 2>/dev/null; then
        echo -e "${GREEN}✓ ${main_branch} を最新化しました${RESET}" >&2
    else
        # If checked out, try merge --ff-only.
        # (Suppress merge stdout such as "Already up to date." with >/dev/null
        # so it does not contaminate the branch name returned on stdout.)
        local main_path=$(echo "${main_entries[1]}" | awk '{print $1}')
        if (cd "$main_path" && git merge --ff-only "origin/$main_branch" >/dev/null 2>&1); then
            echo -e "${GREEN}✓ ${main_branch} を最新化しました${RESET}" >&2
        else
            echo -e "${YELLOW}⚠ ${main_branch} の最新化をスキップしました（fast-forward不可）${RESET}" >&2
        fi
    fi

    echo "$main_branch"
    return 0
}

# ========================================
# 1. Create and enter a new worktree.
# ========================================
_gwt_new() {
    local branch_name="$1"

    if [[ -z "$branch_name" ]]; then
        echo -e "${RED}Error: ブランチ名を指定してください${RESET}"
        echo "Usage: gwt new <branch-name> [base-branch]"
        return 1
    fi

    # Choose the base branch: explicit value > automatic resolution > current branch.
    local base_branch
    if [[ -n "$2" ]]; then
        base_branch="$2"
    else
        base_branch=$(_gwt_resolve_base_branch)
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    fi

    # Check whether this is a Git repository.
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Gitリポジトリではありません${RESET}"
        return 1
    fi

    # Create a worktree alongside the original repository.
    local current_repo_name=$(basename $(git rev-parse --show-toplevel))
    local repo_parent_dir=$(dirname $(git rev-parse --show-toplevel))
    
    # Remove any existing -wt- suffix to get the base repository name.
    local repo_name=$(echo "$current_repo_name" | sed 's/-wt-.*$//')

    # Build the worktree path alongside the original repository.
    local worktree_path="${repo_parent_dir}/${repo_name}-wt-${branch_name}"

    # Check whether the branch already exists.
    if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
        echo -e "${YELLOW}ブランチ '${branch_name}' は既に存在します。worktreeを作成します...${RESET}"
        git worktree add "$worktree_path" "$branch_name"
    else
        echo -e "${GREEN}新しいブランチ '${branch_name}' を '${base_branch}' から作成します...${RESET}"
        git worktree add -b "$branch_name" "$worktree_path" "$base_branch"
    fi

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Worktreeを作成しました: ${worktree_path}${RESET}"

        # Get the base path (main worktree).
        local base_path=$(git worktree list | head -1 | awk '{print $1}')

        # Save the created worktree path in a shared variable.
        _GWT_LAST_WORKTREE_PATH="$worktree_path"

        cd "$worktree_path"
        # Immediately update iTerm2 CWD tracking.
        _iterm2_send_current_dir 2>/dev/null
        # Store the worktree path in an iTerm2 user variable because CWD polling overwrites path.
        _iterm2_set_user_var gwtCwd "$worktree_path" 2>/dev/null
        echo -e "${BLUE}→ 移動しました: $(pwd)${RESET}"

        # Create the .agentsws/issues symlink.
        _gwt_setup_agentsws_issues_link "$worktree_path" "$repo_name"

        # Run the post-create hook.
        _gwt_run_post_create_hook "$worktree_path" "$branch_name" "$base_branch" "$base_path"
        # Notify CWD again after the hook runs.
        _iterm2_send_current_dir 2>/dev/null
        _iterm2_set_user_var gwtCwd "$worktree_path" 2>/dev/null
    else
        echo -e "${RED}Error: Worktreeの作成に失敗しました${RESET}"
        return 1
    fi
}

# ========================================
# 2. Switch worktrees with fzf.
# ========================================
_gwt_switch() {
    # Check whether fzf is installed.
    if ! command -v fzf > /dev/null 2>&1; then
        echo -e "${RED}Error: fzfがインストールされていません${RESET}"
        echo "brew install fzf または apt install fzf でインストールしてください"
        return 1
    fi

    # Get the worktree list.
    local worktree=$(git worktree list | fzf \
        --height=40% \
        --reverse \
        --header="Select worktree to switch")

    if [[ -n "$worktree" ]]; then
        local wt_path=$(echo "$worktree" | awk '{print $1}')
        cd "$wt_path"
#        _iterm2_precmd 2>/dev/null
        echo -e "${GREEN}→ 切り替えました: $(pwd)${RESET}"
    fi
}

# ========================================
# 3. Remove unwanted worktrees.
# ========================================
_gwt_remove() {
    # Protected branches.
    local -a protected_branches=("main" "master" "develop" "development")

    # Select worktrees to remove.
    local worktree=$(git worktree list | grep -v "bare" | fzf \
        --height=40% \
        --reverse \
        --header="Select worktree to remove" \
        --multi)

    if [[ -n "$worktree" ]]; then
        # Store results in an array to avoid a pipeline.
        local -a worktree_lines
        while IFS= read -r line; do
            worktree_lines+=("$line")
        done <<< "$worktree"

        for line in "${worktree_lines[@]}"; do
            local wt_path=$(echo "$line" | awk '{print $1}')
            local branch=$(echo "$line" | grep -o '\[.*\]' | tr -d '[]')

            # Check for protected branches.
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
                # Move to the main directory if currently inside the worktree.
                if [[ "$(pwd)" == "$wt_path"* ]]; then
                    cd $(git worktree list | head -1 | awk '{print $1}')
                fi

                git worktree remove "$wt_path" --force
                echo -e "${GREEN}✓ Worktreeを削除しました: $wt_path${RESET}"

                # Remove from JetBrains Recent Projects.
                _gwt_remove_from_jetbrains_recent "$wt_path"

                # Ask whether to remove the branch too.
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
# 4. Display a readable worktree list.
# ========================================
_gwt_list() {
    echo -e "${CYAN}=== Git Worktrees ===${RESET}"
    git worktree list | while read -r line; do
        local wt_path=$(echo "$line" | awk '{print $1}')
        local commit=$(echo "$line" | awk '{print $2}')
        local branch=$(echo "$line" | grep -o '\[.*\]' | tr -d '[]')

        # Check whether this is the current directory.
        if [[ "$(pwd)" == "$wt_path"* ]]; then
            echo -e "${GREEN}→ ${wt_path} ${YELLOW}[${branch}]${RESET} ${commit}"
        else
            echo -e "  ${wt_path} ${BLUE}[${branch}]${RESET} ${commit}"
        fi

        # Display status.
        if [[ -d "$wt_path" ]]; then
            local changed_files=$(cd "$wt_path" && git status --porcelain | wc -l | tr -d ' ')
            if [[ "$changed_files" -gt 0 ]]; then
                echo -e "    ${YELLOW}⚠ ${changed_files} 個の変更があります${RESET}"
            fi
        fi
    done
}

# ========================================
# 5. Check the status of all worktrees.
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
# 6. Per-worktree notes.
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
# 7. Display information about the current worktree.
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
# 8. Quickly create a worktree with a date suffix.
# ========================================
_gwt_quick() {
    local prefix="$1"

    if [[ -z "$prefix" ]]; then
        echo -e "${RED}Error: プレフィックスを指定してください${RESET}"
        echo "Usage: gwt quick <prefix> [base-branch]"
        echo "Example: gwt quick feature/login"
        return 1
    fi

    # Choose the base branch: explicit value > automatic resolution > current branch.
    local base_branch
    if [[ -n "$2" ]]; then
        base_branch="$2"
    else
        base_branch=$(_gwt_resolve_base_branch)
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    fi

    # Date and time suffix (MMDDHHmm).
    local timestamp=$(date +"%m%d%H%M")
    local branch_name="${prefix}-${timestamp}"

    _gwt_new "$branch_name" "$base_branch"
}

# ========================================
# 9. Prune and clean up.
# ========================================
_gwt_prune() {
    # Skip confirmation prompts with --force / -f.
    local force_mode=false
    for arg in "$@"; do
        [[ "$arg" == "--force" || "$arg" == "-f" ]] && force_mode=true
    done

    echo -e "${CYAN}=== Pruning Worktrees ===${RESET}"

    # Move to the main directory if currently inside a worktree.
    local current_repo_name=$(basename $(git rev-parse --show-toplevel))
    if [[ "$current_repo_name" == *"-wt-"* ]]; then
        local -a _main_entries
        while IFS= read -r _line; do
            local _wt_dir=$(basename "$(echo "$_line" | awk '{print $1}')")
            if [[ "$_wt_dir" != *"-wt-"* ]]; then
                _main_entries+=("$_line")
            fi
        done < <(git worktree list)

        if [[ ${#_main_entries[@]} -eq 1 ]]; then
            local _main_path=$(echo "${_main_entries[1]}" | awk '{print $1}')
            echo -e "${BLUE}→ メインディレクトリに移動: ${_main_path}${RESET}"
            cd "$_main_path"
        elif [[ ${#_main_entries[@]} -gt 1 ]]; then
            echo -e "${RED}Error: wtなしのディレクトリが複数見つかりました${RESET}"
            for _entry in "${_main_entries[@]}"; do
                echo -e "  ${YELLOW}${_entry}${RESET}"
            done
            return 1
        fi
    fi

    _gwt_process_jetbrains_pending

    # Fetch the latest remote information (--prune also removes deleted remote-tracking branches).
    echo -e "${BLUE}リモートから最新の情報を取得中...${RESET}"
    git fetch --prune

    # Update local copies of the main/develop branches.
    local _current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    local -a _fetch_refspecs
    local -a _updated_branches
    for _branch in main master develop; do
        if git show-ref --verify --quiet "refs/remotes/origin/$_branch" 2>/dev/null && \
           git show-ref --verify --quiet "refs/heads/$_branch" 2>/dev/null; then
            if [[ "$_branch" == "$_current_branch" ]]; then
                # Use merge for checked-out branches because fetch cannot update them.
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

    # Clean up deleted worktrees.
    git worktree prune -v

    # Identify the main branch.
    local main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [[ -z "$main_branch" ]]; then
        # Check whether the main branch exists.
        if git show-ref --verify --quiet "refs/heads/main" || git show-ref --verify --quiet "refs/remotes/origin/main"; then
            main_branch="main"
        else
            main_branch="master"
        fi
    fi

    echo -e "\n${YELLOW}=== マージ済みのworktreeとブランチを削除 ===${RESET}"
    echo -e "${CYAN}メインブランチ: ${main_branch}${RESET}"

    # Protected branches.
    local -a protected_branches=("main" "master" "develop" "development" "$main_branch")
    
    # Collect merged worktrees and branches.
    local -a merged_worktrees
    local -a merged_branches
    local -a auto_delete_worktrees
    local -a auto_delete_branches
    local deleted_count=0
    local current_time=$(date +%s)

    # Get the worktree list and check merge status.
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        local wt_path=$(echo "$line" | awk '{print $1}')
        local branch=$(echo "$line" | grep -o '\[.*\]' | tr -d '[]')
        
        # Skip the main repository.
        [[ "$wt_path" == *"[bare]"* ]] && continue
        [[ "$branch" == "$main_branch" ]] && continue
        
        # Skip protected branches.
        local is_protected=false
        for protected in "${protected_branches[@]}"; do
            [[ "$branch" == "$protected" ]] && is_protected=true && break
        done
        [[ "$is_protected" == true ]] && continue
        
        # Check whether merged into master, main, or develop.
        local is_merged=false

        # Detect regular merges and squash merges.
        for check_branch in "master" "main" "develop"; do
            # Check whether origin/$check_branch exists.
            if ! git show-ref --verify --quiet "refs/remotes/origin/$check_branch" 2>/dev/null; then
                continue
            fi

            # Regular merge: check whether the branch HEAD is an ancestor of origin/$check_branch.
            if git merge-base --is-ancestor "$branch" "origin/$check_branch" 2>/dev/null; then
                is_merged=true
                break
            fi

            # Squash merge: check whether the remote main branch contains all branch changes.
            local merge_base=$(git merge-base "origin/$check_branch" "$branch" 2>/dev/null)
            if [[ -n "$merge_base" ]]; then
                # Check whether all changes in merge-base..branch are included in origin/check_branch.
                if git diff --quiet "$branch" "origin/$check_branch" -- $(git diff --name-only "$merge_base" "$branch" 2>/dev/null) 2>/dev/null; then
                    # No differences means squash-merged, but only if the branch had changes.
                    if [[ -n "$(git diff --name-only "$merge_base" "$branch" 2>/dev/null)" ]]; then
                        is_merged=true
                        break
                    fi
                fi
            fi
        done

        # Check merged GitHub PRs as a fallback if the target advanced after a squash merge.
        if [[ "$is_merged" == false ]] && command -v gh > /dev/null 2>&1; then
            local _pr_count=$(gh pr list --head "$branch" --state merged --json number --jq 'length' 2>/dev/null)
            if [[ "$_pr_count" -gt 0 ]]; then
                is_merged=true
            fi
        fi
        
        if [[ "$is_merged" == true ]]; then
            # Check whether at least 30 minutes have elapsed since creation.
            local is_old_enough=false
            if [[ -d "$wt_path" ]]; then
                # Use stat -f %B on macOS or stat -c %W on Linux (%Y if unsupported).
                local creation_time
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    creation_time=$(stat -f %B "$wt_path" 2>/dev/null)
                else
                    creation_time=$(stat -c %W "$wt_path" 2>/dev/null)
                    # Use modification time if creation time is unavailable.
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
                    # Skip for safety if creation time cannot be obtained.
                    echo -e "${BLUE}⏳ スキップ: ${branch} (${wt_path})${RESET}"
                    echo -e "  ${CYAN}作成時間を取得できないためスキップ${RESET}"
                fi
            fi

            if [[ "$is_old_enough" == false ]]; then
                continue
            fi

            # Check for uncommitted changes.
            local has_uncommitted=false
            if [[ -d "$wt_path" ]]; then
                local uncommitted_count=$(cd "$wt_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
                if [[ "$uncommitted_count" -gt 0 ]]; then
                    has_uncommitted=true
                    echo -e "${RED}⚠ スキップ: ${branch} (${wt_path})${RESET}"
                    echo -e "  ${YELLOW}未コミットの変更が ${uncommitted_count} 個あります${RESET}"
                    # Display changes.
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
                # Check whether merged into the current local branch (regular or squash merge).
                local _merged_to_local=false

                # Detect regular merges.
                if git merge-base --is-ancestor "$branch" "$_current_branch" 2>/dev/null; then
                    _merged_to_local=true
                fi

                # Detect squash merges.
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

    # Cache the main repository path.
    local _main_repo_path=$(git worktree list | head -1 | awk '{print $1}')

    # Shared function to remove a worktree and its branch.
    _gwt_delete_worktree_and_branch() {
        local wt_path="$1"
        local branch="$2"

        echo -e "${YELLOW}削除中: ${branch} -> ${wt_path}${RESET}"

        # Move to the main directory if currently inside the worktree.
        if [[ "$(pwd)" == "$wt_path"* ]]; then
            cd "$_main_repo_path"
            echo -e "${BLUE}メインリポジトリに移動: ${_main_repo_path}${RESET}"
        fi

        # Remove the worktree with --force because it is already merged.
        if git worktree remove "$wt_path" --force 2>/dev/null; then
            echo -e "${GREEN}✓ Worktreeを削除: ${wt_path}${RESET}"
            ((deleted_count++))
            _gwt_remove_from_jetbrains_recent "$wt_path"
        else
            echo -e "${RED}✗ Worktreeの削除に失敗: ${wt_path}${RESET}"
            return 1
        fi

        # Remove the branch.
        if git branch -d "$branch" 2>/dev/null; then
            echo -e "${GREEN}✓ ブランチを削除: ${branch}${RESET}"
        elif git branch -D "$branch" 2>/dev/null; then
            echo -e "${GREEN}✓ ブランチを強制削除: ${branch}${RESET}"
        else
            echo -e "${RED}✗ ブランチの削除に失敗: ${branch}${RESET}"
        fi
        echo ""
    }

    # Automatically remove worktrees already merged locally without confirmation.
    if [[ ${#auto_delete_worktrees[@]} -gt 0 ]]; then
        echo -e "\n${GREEN}=== ローカルに取り込み済み: ${#auto_delete_worktrees[@]}個を自動削除 ===${RESET}"
        for ((i=1; i<=$#auto_delete_worktrees; i++)); do
            _gwt_delete_worktree_and_branch "${auto_delete_worktrees[$i]}" "${auto_delete_branches[$i]}"
        done
    fi

    # Ask before removing worktrees merged only on the remote.
    if [[ ${#merged_worktrees[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}=== リモートのみにマージ済み: ${#merged_worktrees[@]}個（確認が必要） ===${RESET}"
        for ((i=1; i<=$#merged_worktrees; i++)); do
            echo -e "  ${YELLOW}${merged_branches[$i]}${RESET} -> ${merged_worktrees[$i]}"
        done

        # Confirmation prompt (skipped with --force).
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
# 10. Create a worktree and start Claude Code.
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

    # Create the worktree with quick.
    _GWT_LAST_WORKTREE_PATH=""
    _gwt_quick "$prefix" ${base_branch:+"$base_branch"}
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Keep the created worktree path.
    local worktree_dir="$_GWT_LAST_WORKTREE_PATH"
    if [[ -n "$worktree_dir" && -d "$worktree_dir" ]]; then
        cd "$worktree_dir"
    fi

    # Defer Claude Code: return from function -> precmd -> CWD update -> start claude.
    echo -e "${CYAN}→ Claude Code を起動します ($(pwd))...${RESET}"
    _GWT_DEFERRED_CMD="claude"
    _GWT_DEFERRED_RETURN="$original_dir"
}

# ========================================
# 11. Create a worktree and start Claude Code with dangerously-skip-permissions.
# ========================================
_gwt_yolo() {
    local original_dir="$(pwd)"
    _gwt_quick $1 && claude --dangerously-skip-permissions && cd ${original_dir} && _iterm2_send_current_dir 2>/dev/null
}

# ========================================
# Display help.
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
  claude, cc <prefix> [base] 日付付きworktreeを作成→通常モードでClaude起動（権限確認あり）
  yolo, y <prefix> [base]    日付付きworktreeを作成→bypassモードでClaude起動（--dangerously-skip-permissions）
  help, h                    このヘルプを表示

${YELLOW}使用例:${RESET}
  gwt new feature/login develop    # developブランチから新しいworktreeを作成
  gwt quick fix/bug                 # 日付付きブランチを素早く作成
  gwt switch                        # worktreeを切り替え
  gwt status                        # 全worktreeの状態を確認
  gwt remove                        # 不要なworktreeを削除
  gwt claude feature/login develop  # worktree作成 → 通常モードでClaude起動（権限確認あり）
  gwt yolo feature/login develop    # worktree作成 → bypassモードでClaude起動（権限スキップ）

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
  gwt cc   = gwt claude  (通常モードでClaude起動)
  gwt y    = gwt yolo    (bypassモードでClaude起動)

${YELLOW}シェルエイリアス (普段これを打つ):${RESET}
  g    = gwt           gn   = gwt new        gq = gwt quick
  gs   = gwt switch    gr   = gwt remove     gl = gwt list
  gp   = gwt prune
  gcc  = gwt cc    → 通常モードでClaude起動（claudew も同じ）
  gy   = gwt yolo  → bypassモードでClaude起動（権限スキップ）

${YELLOW}Post-create Hook:${RESET}
  worktree作成後に自動的にスクリプトを実行できます。

  ${CYAN}スクリプトの配置場所 (実行順序):${RESET}
    1. <repo-root>/.gwt-post-create.sh     (リポジトリ固有)

  ${CYAN}利用可能な環境変数:${RESET}
    GWT_WORKTREE_PATH   作成されたworktreeのパス
    GWT_BRANCH_NAME     ブランチ名
    GWT_BASE_BRANCH     ベースブランチ名
    GWT_BASE_PATH       ベースリポジトリ（メインworktree）のパス

  ${CYAN}例 (.gwt-post-create.sh):${RESET}
    #!/bin/bash
    npm install  # 依存関係をインストール

${YELLOW}.agentsws/issues シンボリックリンク:${RESET}
  環境変数 GWT_ISSUES_REPO_DIR を設定すると、worktree作成時に
  .agentsws/issues を \$GWT_ISSUES_REPO_DIR/<project> へリンクします。
  <project> はベースリポジトリ名で、リンク先フォルダが無ければ自動作成します。
  \$GWT_ISSUES_REPO_DIR/projects/ が存在する場合はそちらを親として
  \$GWT_ISSUES_REPO_DIR/projects/<project> へリンクします。
  GWT_ISSUES_REPO_DIR が未設定、またはディレクトリが存在しない場合は
  何もしません（エラーになりません）。

${YELLOW}iTerm2 Smart Selection (IDE起動連携):${RESET}
  Claude Codeのstatusline等の "Edit" テキストをクリックしてIDEを起動できます。
  iTerm2のpath変数はCWDポーリングで汚染されるため、ユーザー変数 gwtCwd を使用します。

  ${CYAN}設定手順:${RESET}
    1. iTerm2 > Settings > Profiles > Advanced > Smart Selection Actions
       "Use interpolated strings for parameters" を有効にする

    2. Smart Selection Rules に以下を追加:
       - Notes: Edit
       - Regex: Edit
       - Precision: Normal
       - Actions:
         Title: Edit
         Action: Run Command...
         Parameter: "/path/to/land" \\(user.gwtCwd)

  ${CYAN}例 (GoLand + VSCode):${RESET}
    Edit:       "path/to/land" \\(user.gwtCwd)
    Edit VSCode: /usr/local/bin/code \\(user.gwtCwd)
EOF
}

# ========================================
# Completion settings.
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

# Set up zsh completion.
if [[ -n "$ZSH_VERSION" ]]; then
    compdef _gwt_completion gwt
fi

# ========================================
# Aliases.
# ========================================
alias g='gwt'
alias gq='gwt q'
alias gp='gwt p'
alias gr='gwt r'
alias gl='gwt l'
alias gs='gwt s'
alias gn='gwt n'
alias gcc='gwt cc'
alias claudew='gwt cc'
alias gy='gwt y'
