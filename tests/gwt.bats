#!/usr/bin/env bats
# gwt.zsh test suite

setup() {
    load test_helper
    setup_test_repos
    setup_mock_dir
    disable_gh
    # Use a nonexistent fixture path by default to avoid modifying the
    # real issues repository at its default ~/ghq/... location.
    # Only tests that exercise issue links create this directory.
    export GWT_ISSUES_REPO_DIR="$BATS_TEST_TMPDIR/issues"
}

teardown() {
    teardown_test_repos
}

# ============================================================
# Group 1: _gwt_prune() - merge detection
# ============================================================

@test "prune: removes branches merged with a regular merge" {
    create_feature_branch "feat-merged"
    simulate_normal_merge "feat-merged"
    local wt_path=$(create_worktree "feat-merged")
    backdate_worktree "$wt_path"

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"ローカルに取り込み済み"* ]] || [[ "$output" == *"マージ済み検出"* ]]
    [ ! -d "$wt_path" ]
}

@test "prune: removes squash-merged branches" {
    create_feature_branch "feat-squash" "squash-file.txt" "squash content"
    simulate_squash_merge "feat-squash"
    local wt_path=$(create_worktree "feat-squash")
    backdate_worktree "$wt_path"

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"ローカルに取り込み済み"* ]] || [[ "$output" == *"マージ済み検出"* ]]
    [ ! -d "$wt_path" ]
}

@test "prune: keeps unmerged branches whose remote was merely deleted" {
    create_feature_branch "feat-unmerged" "unmerged-file.txt" "unmerged content"
    local wt_path=$(create_worktree "feat-unmerged")
    backdate_worktree "$wt_path"

    # Delete only the remote branch; do not merge it.
    cd "$TEST_REPO"
    git push origin --delete feat-unmerged >/dev/null 2>&1

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [ -d "$wt_path" ]
}

@test "prune: skips branches with uncommitted changes" {
    create_feature_branch "feat-dirty"
    simulate_normal_merge "feat-dirty"
    local wt_path=$(create_worktree "feat-dirty")
    backdate_worktree "$wt_path"

    # Add uncommitted changes to the worktree.
    echo "dirty change" > "$wt_path/dirty.txt"

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"未コミットの変更"* ]]
    [ -d "$wt_path" ]
}

@test "prune: skips branches created less than 30 minutes ago" {
    create_feature_branch "feat-recent"
    simulate_normal_merge "feat-recent"
    local wt_path=$(create_worktree "feat-recent")
    # Do not backdate it: it was just created, less than 30 minutes ago.

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"30分未満のためスキップ"* ]]
    [ -d "$wt_path" ]
}

@test "prune: keeps protected branches such as develop" {
    # Create the develop branch.
    cd "$TEST_REPO"
    git checkout -b develop main >/dev/null 2>&1
    echo "develop content" > develop.txt
    git add develop.txt
    git commit -m "develop commit" >/dev/null 2>&1
    git push -u origin develop >/dev/null 2>&1
    git checkout main >/dev/null 2>&1

    # Merge develop into main.
    simulate_normal_merge "develop"

    # Create a worktree for develop.
    local wt_path=$(create_worktree "develop")
    backdate_worktree "$wt_path"

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [ -d "$wt_path" ]
}

@test "prune: keeps local-only branches without a remote" {
    cd "$TEST_REPO"
    git checkout -b local-only main >/dev/null 2>&1
    echo "local content" > local.txt
    git add local.txt
    git commit -m "local commit" >/dev/null 2>&1
    # Do not push.
    git checkout main >/dev/null 2>&1

    local wt_path=$(create_worktree "local-only")
    backdate_worktree "$wt_path"

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [ -d "$wt_path" ]
}

@test "prune: detects merges through the gh PR fallback" {
    create_feature_branch "feat-gh-merged" "gh-file.txt" "gh content"
    local wt_path=$(create_worktree "feat-gh-merged")
    backdate_worktree "$wt_path"

    # The gh mock reports a merged PR.
    create_gh_mock 1

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"マージ済み検出"* ]] || [[ "$output" == *"ローカルに取り込み済み"* ]]
    [ ! -d "$wt_path" ]
}

@test "prune: reports when no merged worktrees exist" {
    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"マージ済みのworktreeとブランチはありません"* ]]
}

# ============================================================
# Group 2: _gwt_new() - worktree creation
# ============================================================

@test "new: creates a worktree at the correct path" {
    run_gwt _gwt_new "my-feature"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Worktreeを作成しました"* ]]
    [ -d "$BATS_TEST_TMPDIR/repo-wt-my-feature" ]
}

@test "new: handles a worktree for an existing branch" {
    create_feature_branch "existing-branch"

    run_gwt _gwt_new "existing-branch"

    [ "$status" -eq 0 ]
    [[ "$output" == *"既に存在します"* ]]
    [ -d "$BATS_TEST_TMPDIR/repo-wt-existing-branch" ]
}

@test "new: fails when the branch name is missing" {
    run_gwt _gwt_new

    [ "$status" -eq 1 ]
    [[ "$output" == *"ブランチ名を指定してください"* ]]
}

@test "new: fails outside a Git repository" {
    run_gwt_from "$BATS_TEST_TMPDIR" _gwt_new "test-branch"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Gitリポジトリではありません"* ]]
}

@test "new: does not duplicate the -wt- suffix" {
    # Create the first worktree.
    run_gwt _gwt_new "first"
    [ "$status" -eq 0 ]

    local wt_first="$BATS_TEST_TMPDIR/repo-wt-first"
    [ -d "$wt_first" ]

    # Create another worktree from inside the first.
    run_gwt_from "$wt_first" _gwt_new "second"
    [ "$status" -eq 0 ]

    # Expect repo-wt-second, not repo-wt-first-wt-second.
    [ -d "$BATS_TEST_TMPDIR/repo-wt-second" ]
    [ ! -d "$BATS_TEST_TMPDIR/repo-wt-first-wt-second" ]
}

@test "new: creates a worktree from the specified base branch" {
    create_feature_branch "base-branch" "base.txt" "base content"

    run_gwt _gwt_new "derived-branch" "base-branch"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Worktreeを作成しました"* ]]
    [ -d "$BATS_TEST_TMPDIR/repo-wt-derived-branch" ]

    # Verify that files from the base branch are present.
    [ -f "$BATS_TEST_TMPDIR/repo-wt-derived-branch/base.txt" ]
}

@test "new: creates the .agentsws/issues symlink" {
    mkdir -p "$GWT_ISSUES_REPO_DIR"

    run_gwt _gwt_new "link-test"
    [ "$status" -eq 0 ]

    local wt="$BATS_TEST_TMPDIR/repo-wt-link-test"
    # Verify that the symlink was created.
    [ -L "$wt/.agentsws/issues" ]
    # Verify that it targets the base repository's project directory (repo).
    [ "$(readlink "$wt/.agentsws/issues")" = "$GWT_ISSUES_REPO_DIR/repo" ]
    # Verify that the target project directory was created automatically.
    [ -d "$GWT_ISSUES_REPO_DIR/repo" ]
}

@test "new: links under projects/ when the issues repository uses that layout" {
    # The projects/ layout stores each project at <repo>/projects/<project>.
    mkdir -p "$GWT_ISSUES_REPO_DIR/projects"

    run_gwt _gwt_new "projects-layout-test"
    [ "$status" -eq 0 ]

    local wt="$BATS_TEST_TMPDIR/repo-wt-projects-layout-test"
    [ -L "$wt/.agentsws/issues" ]
    # The link must point under projects/, not at the repository root.
    [ "$(readlink "$wt/.agentsws/issues")" = "$GWT_ISSUES_REPO_DIR/projects/repo" ]
    [ -d "$GWT_ISSUES_REPO_DIR/projects/repo" ]
    # Do not create an empty project directory at the repository root.
    [ ! -d "$GWT_ISSUES_REPO_DIR/repo" ]
}

@test "new: does not append projects twice when GWT_ISSUES_REPO_DIR already points there" {
    GWT_ISSUES_REPO_DIR="$GWT_ISSUES_REPO_DIR/projects"
    mkdir -p "$GWT_ISSUES_REPO_DIR"

    run_gwt _gwt_new "projects-idempotent-test"
    [ "$status" -eq 0 ]

    local wt="$BATS_TEST_TMPDIR/repo-wt-projects-idempotent-test"
    [ -L "$wt/.agentsws/issues" ]
    [ "$(readlink "$wt/.agentsws/issues")" = "$GWT_ISSUES_REPO_DIR/repo" ]
    [ ! -d "$GWT_ISSUES_REPO_DIR/projects" ]
}

@test "new: creates no link if the issues repository does not exist" {
    # GWT_ISSUES_REPO_DIR is set, but the directory is absent, as in default test setup.
    run_gwt _gwt_new "no-link-test"
    [ "$status" -eq 0 ]

    local wt="$BATS_TEST_TMPDIR/repo-wt-no-link-test"
    [ ! -e "$wt/.agentsws/issues" ]
}

@test "new: creates no link when GWT_ISSUES_REPO_DIR is unset" {
    unset GWT_ISSUES_REPO_DIR

    run_gwt _gwt_new "no-env-test"
    [ "$status" -eq 0 ]

    local wt="$BATS_TEST_TMPDIR/repo-wt-no-env-test"
    [ ! -e "$wt/.agentsws/issues" ]
}

@test "new: does not overwrite an existing .agentsws/issues entry" {
    mkdir -p "$GWT_ISSUES_REPO_DIR/repo"

    run_gwt _gwt_new "preexist-test"
    [ "$status" -eq 0 ]

    local wt="$BATS_TEST_TMPDIR/repo-wt-preexist-test"
    [ -L "$wt/.agentsws/issues" ]
    [ "$(readlink "$wt/.agentsws/issues")" = "$GWT_ISSUES_REPO_DIR/repo" ]
}

# ============================================================
# Group 3: _gwt_quick() - quick creation
# ============================================================

@test "quick: creates a branch name containing a timestamp" {
    run_gwt _gwt_quick "feature/test"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Worktreeを作成しました"* ]]

    # Verify that a directory matching the timestamp pattern exists.
    local found=$(ls -d "$BATS_TEST_TMPDIR"/repo-wt-feature/test-* 2>/dev/null | head -1)
    [ -n "$found" ]
}

@test "quick: fails when the prefix is missing" {
    run_gwt _gwt_quick

    [ "$status" -eq 1 ]
    [[ "$output" == *"プレフィックスを指定してください"* ]]
}

# ============================================================
# Group 4: _gwt_list(), _gwt_status(), _gwt_info()
# ============================================================

@test "list: displays worktrees" {
    run_gwt _gwt_new "list-test"

    run_gwt _gwt_list

    [ "$status" -eq 0 ]
    [[ "$output" == *"=== Git Worktrees ==="* ]]
    [[ "$output" == *"list-test"* ]]
}

@test "status: displays the status of all worktrees" {
    run_gwt _gwt_new "status-test"

    run_gwt _gwt_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"=== Worktree Status ==="* ]]
}

@test "info: displays information about the current worktree" {
    # On macOS, /var points to /private/var, so pwd can differ from git worktree list.
    # Change into the physical path to keep the paths consistent.
    local real_repo=$(cd "$TEST_REPO" && pwd -P)
    run_gwt_from "$real_repo" _gwt_info

    [ "$status" -eq 0 ]
    [[ "$output" == *"=== Current Worktree Info ==="* ]]
    [[ "$output" == *"main"* ]]
}

@test "info: fails outside a Git repository" {
    run_gwt_from "$BATS_TEST_TMPDIR" _gwt_info

    [ "$status" -eq 1 ]
    [[ "$output" == *"Gitリポジトリではありません"* ]]
}

# ============================================================
# Group 5: gwt() command dispatch
# ============================================================

@test "dispatch: supports the help command" {
    run_gwt gwt help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Git Worktree Manager"* ]]
}

@test "dispatch: supports the h alias" {
    run_gwt gwt h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Git Worktree Manager"* ]]
}

@test "dispatch: shows help with no arguments" {
    run_gwt gwt ""

    [ "$status" -eq 0 ]
    [[ "$output" == *"Git Worktree Manager"* ]]
}

@test "dispatch: rejects unknown commands" {
    run_gwt gwt "nonexistent"

    [ "$status" -eq 1 ]
    [[ "$output" == *"不明なコマンド"* ]]
}

@test "dispatch: n fails without a branch name" {
    run_gwt gwt n

    [ "$status" -eq 1 ]
    [[ "$output" == *"ブランチ名を指定してください"* ]]
}

@test "dispatch: q fails without a prefix" {
    run_gwt gwt q

    [ "$status" -eq 1 ]
    [[ "$output" == *"プレフィックスを指定してください"* ]]
}
