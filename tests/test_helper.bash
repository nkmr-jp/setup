#!/usr/bin/env bash
# Test helpers for gwt.zsh

GWT_WRAPPER="${BATS_TEST_DIRNAME}/gwt_wrapper.zsh"

# Set up a fixture Git repository.
setup_test_repos() {
    export GIT_AUTHOR_NAME="Test"
    export GIT_AUTHOR_EMAIL="test@test.com"
    export GIT_COMMITTER_NAME="Test"
    export GIT_COMMITTER_EMAIL="test@test.com"

    # Create the bare repository.
    git init --bare "$BATS_TEST_TMPDIR/bare.git" >/dev/null 2>&1

    # Clone it.
    git clone "$BATS_TEST_TMPDIR/bare.git" "$BATS_TEST_TMPDIR/repo" >/dev/null 2>&1

    # Create the initial commit on main.
    cd "$BATS_TEST_TMPDIR/repo"
    git checkout -b main >/dev/null 2>&1
    echo "initial" > README.md
    git add README.md
    git commit -m "initial commit" >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1

    # Set origin/HEAD.
    git remote set-head origin main >/dev/null 2>&1

    export TEST_REPO="$BATS_TEST_TMPDIR/repo"
    export TEST_BARE="$BATS_TEST_TMPDIR/bare.git"
}

# Clean up the fixture repository.
teardown_test_repos() {
    cd "$BATS_TEST_TMPDIR" 2>/dev/null || true
    # Unlock worktrees.
    if [[ -d "$TEST_REPO" ]]; then
        cd "$TEST_REPO" && git worktree prune 2>/dev/null || true
    fi
}

# Create and push a feature branch.
# Arguments: branch_name [file_name] [file_content]
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

# Simulate a regular merge.
simulate_normal_merge() {
    local branch_name="$1"

    cd "$TEST_REPO"
    git checkout main >/dev/null 2>&1
    git merge "$branch_name" --no-edit >/dev/null 2>&1
    git push origin main >/dev/null 2>&1
}

# Simulate a squash merge.
simulate_squash_merge() {
    local branch_name="$1"

    cd "$TEST_REPO"
    git checkout main >/dev/null 2>&1
    git merge --squash "$branch_name" >/dev/null 2>&1
    git commit -m "squash merge $branch_name" >/dev/null 2>&1
    git push origin main >/dev/null 2>&1
}

# Create a worktree.
# Arguments: branch_name
# Output: worktree path
create_worktree() {
    local branch_name="$1"
    local wt_path="$BATS_TEST_TMPDIR/repo-wt-${branch_name}"

    cd "$TEST_REPO"
    git worktree add "$wt_path" "$branch_name" >/dev/null 2>&1
    echo "$wt_path"
}

# Backdate worktree creation by at least 30 minutes.
# On macOS, use SetFile -d to change the creation time.
backdate_worktree() {
    local wt_path="$1"
    local minutes_ago="${2:-60}"

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: change the creation time with SetFile.
        local past_date=$(date -v-${minutes_ago}M "+%m/%d/%Y %H:%M:%S")
        SetFile -d "$past_date" "$wt_path" 2>/dev/null || true
        # Also update the modification time with touch.
        touch -t "$(date -v-${minutes_ago}M '+%Y%m%d%H%M.%S')" "$wt_path"
    else
        # Linux: change the timestamp with touch -d.
        touch -d "${minutes_ago} minutes ago" "$wt_path"
    fi
}

# Set up the mock command directory.
setup_mock_dir() {
    export MOCK_DIR="$BATS_TEST_TMPDIR/mocks"
    mkdir -p "$MOCK_DIR"
    export PATH="$MOCK_DIR:$PATH"
}

# Create a mock gh command.
# Argument: merged_count (number of merged PRs)
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

# Mock gh as unavailable.
disable_gh() {
    cat > "$MOCK_DIR/gh" << 'MOCK_EOF'
#!/bin/bash
exit 1
MOCK_EOF
    chmod +x "$MOCK_DIR/gh"
}

# Run a gwt function in a zsh subprocess.
# Arguments: function_name [args...]
run_gwt() {
    local func="$1"
    shift
    cd "$TEST_REPO"
    run zsh "$GWT_WRAPPER" "$func" "$@"
}

# Run a gwt function from the specified directory.
# Arguments: directory function_name [args...]
run_gwt_from() {
    local dir="$1"
    local func="$2"
    shift 2
    cd "$dir"
    run zsh "$GWT_WRAPPER" "$func" "$@"
}
