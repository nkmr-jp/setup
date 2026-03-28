#!/usr/bin/env bats
# iterm2.zsh テストスイート

ITERM2_WRAPPER="${BATS_TEST_DIRNAME}/iterm2_wrapper.zsh"

run_iterm2() {
    local func="$1"
    shift
    run zsh "$ITERM2_WRAPPER" "$func" "$@"
}

# ============================================================
# Group 1: _iterm2_directory_name() - ディレクトリ名抽出
# ============================================================

@test "directory_name: 通常のディレクトリ名を返す" {
    run_iterm2 _iterm2_directory_name "/Users/test/myrepo"
    [ "$status" -eq 0 ]
    [ "$output" = "myrepo" ]
}

@test "directory_name: 空文字を渡すと何も返さない" {
    run_iterm2 _iterm2_directory_name ""
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "directory_name: worktree パスからリポジトリ名を抽出する" {
    run_iterm2 _iterm2_directory_name "/Users/test/myrepo-worktrees/feature-branch"
    [ "$status" -eq 0 ]
    [ "$output" = "myrepo" ]
}

@test "directory_name: -wt- パスからリポジトリ名を抽出する" {
    run_iterm2 _iterm2_directory_name "/Users/test/myrepo-wt-feature"
    [ "$status" -eq 0 ]
    [ "$output" = "myrepo" ]
}

@test "directory_name: ネストしたパスでも末尾のディレクトリ名を返す" {
    run_iterm2 _iterm2_directory_name "/a/b/c/deep-dir"
    [ "$status" -eq 0 ]
    [ "$output" = "deep-dir" ]
}

# ============================================================
# Group 2: _iterm2_git_branch_label() - ブランチラベル
# ============================================================

setup() {
    export GIT_AUTHOR_NAME="Test"
    export GIT_AUTHOR_EMAIL="test@test.com"
    export GIT_COMMITTER_NAME="Test"
    export GIT_COMMITTER_EMAIL="test@test.com"
}

@test "git_branch_label: git リポジトリのブランチ名を返す" {
    local repo="$BATS_TEST_TMPDIR/test-repo"
    git init "$repo" >/dev/null 2>&1
    cd "$repo"
    git checkout -b main >/dev/null 2>&1
    echo "init" > README.md
    git add README.md
    git commit -m "init" >/dev/null 2>&1

    run_iterm2 _iterm2_git_branch_label "$repo"
    [ "$status" -eq 0 ]
    [ "$output" = "main" ]
}

@test "git_branch_label: 非 git ディレクトリでは空を返す" {
    run_iterm2 _iterm2_git_branch_label "$BATS_TEST_TMPDIR"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "git_branch_label: worktree パスで wt: プレフィックスを付ける" {
    local repo="$BATS_TEST_TMPDIR/myrepo"
    git init "$repo" >/dev/null 2>&1
    cd "$repo"
    git checkout -b main >/dev/null 2>&1
    echo "init" > README.md
    git add README.md
    git commit -m "init" >/dev/null 2>&1

    local wt_path="$BATS_TEST_TMPDIR/myrepo-worktrees/feature"
    mkdir -p "$(dirname "$wt_path")"
    git worktree add "$wt_path" -b feature >/dev/null 2>&1

    run_iterm2 _iterm2_git_branch_label "$wt_path"
    [ "$status" -eq 0 ]
    [ "$output" = "wt:feature" ]
}

# ============================================================
# Group 3: _iterm2_set_user_var() - エスケープシーケンス
# ============================================================

@test "set_user_var: 正しいエスケープシーケンスを出力する" {
    run_iterm2 _iterm2_set_user_var testKey "hello"
    [ "$status" -eq 0 ]

    local expected_b64=$(printf '%s' "hello" | base64)
    [[ "$output" == *"SetUserVar=testKey=${expected_b64}"* ]]
}

@test "set_user_var: 空文字を正しくエンコードする" {
    run_iterm2 _iterm2_set_user_var testKey ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"SetUserVar=testKey="* ]]
}

# ============================================================
# Group 4: _iterm2_set_session_name() - セッション名
# ============================================================

@test "set_session_name: キャッシュが空ならディレクトリ名を表示する" {
    run_iterm2 _iterm2_set_session_name
    [ "$status" -eq 0 ]
    # キャッシュ未設定なのでディレクトリ名にフォールバック
    [[ "$output" == *"]0;"* ]]
    # 空のセッション名ではないこと
    [[ "$output" != *"]0;]"* ]]
}

# ============================================================
# Group 5: _iterm2_set_user_last_prompt() - lastPrompt
# ============================================================

@test "set_user_last_prompt: ITERM_SESSION_ID 未設定なら何もしない" {
    unset ITERM_SESSION_ID
    run_iterm2 _iterm2_set_user_last_prompt
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "set_user_last_prompt: history_file がなければディレクトリ名にフォールバック" {
    export ITERM_SESSION_ID="w0t0p0:fake-session-id"
    export HOME="$BATS_TEST_TMPDIR/no-history-home"
    mkdir -p "$HOME"
    # history.jsonl は作成しない

    run_iterm2 _iterm2_set_user_last_prompt
    [ "$status" -eq 0 ]
    # lastPrompt にディレクトリ名がセットされる
    [[ "$output" == *"SetUserVar=lastPrompt="* ]]
    # 空ではない base64 値が含まれる
    [[ "$output" != *"SetUserVar=lastPrompt=]"* ]]
}

@test "set_user_last_prompt: history_file から該当セッションのテキストを取得する" {
    export ITERM_SESSION_ID="w0t0p0:test-session-123"
    export HOME="$BATS_TEST_TMPDIR/prompt-home"
    mkdir -p "$HOME/.prompt-line"

    cat > "$HOME/.prompt-line/history.jsonl" << 'EOF'
{"itermSessionId":"other-session","text":"other prompt"}
{"itermSessionId":"test-session-123","text":"my test prompt"}
EOF

    run_iterm2 _iterm2_set_user_last_prompt
    [ "$status" -eq 0 ]

    local expected_b64=$(printf '%s' "my test prompt" | base64)
    [[ "$output" == *"SetUserVar=lastPrompt=${expected_b64}"* ]]
}

@test "set_user_last_prompt: 該当セッションがなければディレクトリ名にフォールバック" {
    export ITERM_SESSION_ID="w0t0p0:nonexistent-session"
    export HOME="$BATS_TEST_TMPDIR/prompt-home2"
    mkdir -p "$HOME/.prompt-line"

    cat > "$HOME/.prompt-line/history.jsonl" << 'EOF'
{"itermSessionId":"other-session","text":"other prompt"}
EOF

    run_iterm2 _iterm2_set_user_last_prompt
    [ "$status" -eq 0 ]
    # ディレクトリ名にフォールバック
    [[ "$output" == *"SetUserVar=lastPrompt="* ]]
}

# ============================================================
# Group 6: _iterm2_send_current_dir() - CurrentDir 送信
# ============================================================

@test "send_current_dir: PWD をエスケープシーケンスで出力する" {
    run_iterm2 _iterm2_send_current_dir
    [ "$status" -eq 0 ]
    [[ "$output" == *"CurrentDir="* ]]
}

# ============================================================
# Group 7: _iterm2_precmd() - precmd フック
# ============================================================

@test "precmd: 全コンポーネントが出力される" {
    export ITERM_SESSION_ID="w0t0p0:precmd-test"
    export HOME="$BATS_TEST_TMPDIR/precmd-home"
    mkdir -p "$HOME"

    run_iterm2 _iterm2_precmd
    [ "$status" -eq 0 ]
    # CurrentDir が含まれる
    [[ "$output" == *"CurrentDir="* ]]
    # currentDir ユーザー変数が含まれる
    [[ "$output" == *"SetUserVar=currentDir="* ]]
    # branch ユーザー変数が含まれる
    [[ "$output" == *"SetUserVar=branch="* ]]
    # lastPrompt ユーザー変数が含まれる
    [[ "$output" == *"SetUserVar=lastPrompt="* ]]
    # セッション名（OSC 0）が含まれる
    [[ "$output" == *"]0;"* ]]
}
