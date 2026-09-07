#!/usr/bin/env bats
# iterm2.zsh test suite

ITERM2_WRAPPER="${BATS_TEST_DIRNAME}/iterm2_wrapper.zsh"

run_iterm2() {
    local func="$1"
    shift
    run zsh "$ITERM2_WRAPPER" "$func" "$@"
}

# ============================================================
# Group 1: _iterm2_directory_name() - directory name extraction
# ============================================================

@test "directory_name: returns a normal directory name" {
    run_iterm2 _iterm2_directory_name "/Users/test/myrepo"
    [ "$status" -eq 0 ]
    [ "$output" = "myrepo" ]
}

@test "directory_name: returns nothing for an empty string" {
    run_iterm2 _iterm2_directory_name ""
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "directory_name: extracts the repository name from a worktree path" {
    run_iterm2 _iterm2_directory_name "/Users/test/myrepo-worktrees/feature-branch"
    [ "$status" -eq 0 ]
    [ "$output" = "myrepo" ]
}

@test "directory_name: extracts the repository name from a -wt- path" {
    run_iterm2 _iterm2_directory_name "/Users/test/myrepo-wt-feature"
    [ "$status" -eq 0 ]
    [ "$output" = "myrepo" ]
}

@test "directory_name: returns the final directory name for nested paths" {
    run_iterm2 _iterm2_directory_name "/a/b/c/deep-dir"
    [ "$status" -eq 0 ]
    [ "$output" = "deep-dir" ]
}

# ============================================================
# Group 2: _iterm2_git_branch_label() - branch labels
# ============================================================

setup() {
    export GIT_AUTHOR_NAME="Test"
    export GIT_AUTHOR_EMAIL="test@test.com"
    export GIT_COMMITTER_NAME="Test"
    export GIT_COMMITTER_EMAIL="test@test.com"
}

@test "git_branch_label: returns the branch name in a Git repository" {
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

@test "git_branch_label: returns empty outside a Git repository" {
    run_iterm2 _iterm2_git_branch_label "$BATS_TEST_TMPDIR"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "git_branch_label: adds the wt: prefix for a worktree path" {
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
# Group 3: _iterm2_set_user_var() - escape sequences
# ============================================================

@test "set_user_var: emits the correct escape sequence" {
    run_iterm2 _iterm2_set_user_var testKey "hello"
    [ "$status" -eq 0 ]

    local expected_b64=$(printf '%s' "hello" | base64)
    [[ "$output" == *"SetUserVar=testKey=${expected_b64}"* ]]
}

@test "set_user_var: encodes an empty string correctly" {
    run_iterm2 _iterm2_set_user_var testKey ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"SetUserVar=testKey="* ]]
}

# ============================================================
# Group 3.5: _iterm2_directory_icon() - directory icons
# ============================================================

@test "directory_icon: returns 🐹 for Go projects" {
    local dir="$BATS_TEST_TMPDIR/go-project"
    mkdir -p "$dir"
    touch "$dir/go.mod"

    run_iterm2 _iterm2_directory_icon "$dir"
    [ "$status" -eq 0 ]
    [ "$output" = "🐹" ]
}

@test "directory_icon: returns ⬡ for Node.js projects" {
    local dir="$BATS_TEST_TMPDIR/node-project"
    mkdir -p "$dir"
    touch "$dir/package.json"

    run_iterm2 _iterm2_directory_icon "$dir"
    [ "$status" -eq 0 ]
    [ "$output" = "⬡" ]
}

@test "directory_icon: returns 🐍 for Python projects" {
    local dir="$BATS_TEST_TMPDIR/py-project"
    mkdir -p "$dir"
    touch "$dir/pyproject.toml"

    run_iterm2 _iterm2_directory_icon "$dir"
    [ "$status" -eq 0 ]
    [ "$output" = "🐍" ]
}

@test "directory_icon: returns 🦀 for Rust projects" {
    local dir="$BATS_TEST_TMPDIR/rust-project"
    mkdir -p "$dir"
    touch "$dir/Cargo.toml"

    run_iterm2 _iterm2_directory_icon "$dir"
    [ "$status" -eq 0 ]
    [ "$output" = "🦀" ]
}

@test "directory_icon: returns 📁 for unknown projects" {
    local dir="$BATS_TEST_TMPDIR/unknown-project"
    mkdir -p "$dir"

    run_iterm2 _iterm2_directory_icon "$dir"
    [ "$status" -eq 0 ]
    [ "$output" = "📁" ]
}

@test "directory_icon: returns nothing for an empty string" {
    run_iterm2 _iterm2_directory_icon ""
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "directory_icon: detects project type using the original repository for worktree paths" {
    local repo="$BATS_TEST_TMPDIR/myrepo"
    mkdir -p "$repo"
    touch "$repo/go.mod"
    local wt_path="${repo}-worktrees/feature"
    mkdir -p "$wt_path"

    run_iterm2 _iterm2_directory_icon "$wt_path"
    [ "$status" -eq 0 ]
    [ "$output" = "🐹" ]
}

# ============================================================
# Group 4: _iterm2_set_user_last_prompt() - lastPrompt
# ============================================================

@test "set_user_last_prompt: sets the directory name" {
    run_iterm2 _iterm2_set_user_last_prompt
    [ "$status" -eq 0 ]
    # lastPrompt contains the directory name.
    [[ "$output" == *"SetUserVar=lastPrompt="* ]]
    # The session name (OSC 0) is also set.
    [[ "$output" == *"]0;"* ]]
}

# ============================================================
# Group 6: _iterm2_send_current_dir() - CurrentDir reporting
# ============================================================

@test "send_current_dir: emits PWD in an escape sequence" {
    run_iterm2 _iterm2_send_current_dir
    [ "$status" -eq 0 ]
    [[ "$output" == *"CurrentDir="* ]]
}

# ============================================================
# Group 7: _iterm2_precmd() - precmd hook
# ============================================================

@test "precmd: emits every component" {
    export ITERM_SESSION_ID="w0t0p0:precmd-test"
    export HOME="$BATS_TEST_TMPDIR/precmd-home"
    mkdir -p "$HOME"

    run_iterm2 _iterm2_precmd
    [ "$status" -eq 0 ]
    # Includes CurrentDir.
    [[ "$output" == *"CurrentDir="* ]]
    # Includes the currentDir user variable.
    [[ "$output" == *"SetUserVar=currentDir="* ]]
    # Includes the branch user variable.
    [[ "$output" == *"SetUserVar=branch="* ]]
    # Includes the dirIcon user variable.
    [[ "$output" == *"SetUserVar=dirIcon="* ]]
    # Includes lastPrompt, falling back to the directory name on the first call.
    [[ "$output" == *"SetUserVar=lastPrompt="* ]]
}
