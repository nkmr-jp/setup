#!/usr/bin/env bash
# gwt.zsh テスト用ヘルパー

GWT_WRAPPER="${BATS_TEST_DIRNAME}/gwt_wrapper.zsh"

# テスト用 git リポジトリをセットアップ
setup_test_repos() {
    export GIT_AUTHOR_NAME="Test"
    export GIT_AUTHOR_EMAIL="test@test.com"
    export GIT_COMMITTER_NAME="Test"
    export GIT_COMMITTER_EMAIL="test@test.com"

    # bare リポジトリ作成
    git init --bare "$BATS_TEST_TMPDIR/bare.git" >/dev/null 2>&1

    # クローン
    git clone "$BATS_TEST_TMPDIR/bare.git" "$BATS_TEST_TMPDIR/repo" >/dev/null 2>&1

    # 初期コミット（main ブランチ）
    cd "$BATS_TEST_TMPDIR/repo"
    git checkout -b main >/dev/null 2>&1
    echo "initial" > README.md
    git add README.md
    git commit -m "initial commit" >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1

    # origin/HEAD を設定
    git remote set-head origin main >/dev/null 2>&1

    export TEST_REPO="$BATS_TEST_TMPDIR/repo"
    export TEST_BARE="$BATS_TEST_TMPDIR/bare.git"
}

# テスト用リポジトリをクリーンアップ
teardown_test_repos() {
    cd "$BATS_TEST_TMPDIR" 2>/dev/null || true
    # worktree のロックを解放
    if [[ -d "$TEST_REPO" ]]; then
        cd "$TEST_REPO" && git worktree prune 2>/dev/null || true
    fi
}

# フィーチャーブランチを作成してプッシュ
# 引数: branch_name [file_name] [file_content]
create_feature_branch() {
    local branch_name="$1"
    local file_name="${2:-${branch_name}.txt}"
    local file_content="${3:-content of $branch_name}"

    cd "$TEST_REPO"
    git checkout -b "$branch_name" main >/dev/null 2>&1
    echo "$file_content" > "$file_name"
    git add "$file_name"
    git commit -m "add $file_name on $branch_name" >/dev/null 2>&1
    git push -u origin "$branch_name" >/dev/null 2>&1
    git checkout main >/dev/null 2>&1
}

# 通常マージをシミュレート
simulate_normal_merge() {
    local branch_name="$1"

    cd "$TEST_REPO"
    git checkout main >/dev/null 2>&1
    git merge "$branch_name" --no-edit >/dev/null 2>&1
    git push origin main >/dev/null 2>&1
}

# スカッシュマージをシミュレート
simulate_squash_merge() {
    local branch_name="$1"

    cd "$TEST_REPO"
    git checkout main >/dev/null 2>&1
    git merge --squash "$branch_name" >/dev/null 2>&1
    git commit -m "squash merge $branch_name" >/dev/null 2>&1
    git push origin main >/dev/null 2>&1
}

# worktree を作成
# 引数: branch_name
# 出力: worktree パス
create_worktree() {
    local branch_name="$1"
    local wt_path="$BATS_TEST_TMPDIR/repo-wt-${branch_name}"

    cd "$TEST_REPO"
    git worktree add "$wt_path" "$branch_name" >/dev/null 2>&1
    echo "$wt_path"
}

# worktree の作成時刻を古くする（30分以上前）
# macOS では SetFile -d で creation time を変更
backdate_worktree() {
    local wt_path="$1"
    local minutes_ago="${2:-60}"

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: SetFile で creation time を変更
        local past_date=$(date -v-${minutes_ago}M "+%m/%d/%Y %H:%M:%S")
        SetFile -d "$past_date" "$wt_path" 2>/dev/null || true
        # touch で modification time も変更
        touch -t "$(date -v-${minutes_ago}M '+%Y%m%d%H%M.%S')" "$wt_path"
    else
        # Linux: touch -d で変更
        touch -d "${minutes_ago} minutes ago" "$wt_path"
    fi
}

# モックディレクトリをセットアップ
setup_mock_dir() {
    export MOCK_DIR="$BATS_TEST_TMPDIR/mocks"
    mkdir -p "$MOCK_DIR"
    export PATH="$MOCK_DIR:$PATH"
}

# gh コマンドのモックを作成
# 引数: merged_count（マージ済み PR 数）
create_gh_mock() {
    local merged_count="${1:-0}"
    cat > "$MOCK_DIR/gh" << MOCK_EOF
#!/bin/bash
# gh mock
if [[ "\$1" == "pr" && "\$2" == "list" && "\$*" == *"--state merged"* ]]; then
    echo "$merged_count"
    exit 0
fi
exit 1
MOCK_EOF
    chmod +x "$MOCK_DIR/gh"
}

# gh コマンドを無効化するモック
disable_gh() {
    cat > "$MOCK_DIR/gh" << 'MOCK_EOF'
#!/bin/bash
exit 1
MOCK_EOF
    chmod +x "$MOCK_DIR/gh"
}

# gwt 関数を zsh サブプロセスで実行
# 引数: function_name [args...]
run_gwt() {
    local func="$1"
    shift
    cd "$TEST_REPO"
    run zsh "$GWT_WRAPPER" "$func" "$@"
}

# gwt 関数を指定ディレクトリから実行
# 引数: directory function_name [args...]
run_gwt_from() {
    local dir="$1"
    local func="$2"
    shift 2
    cd "$dir"
    run zsh "$GWT_WRAPPER" "$func" "$@"
}
