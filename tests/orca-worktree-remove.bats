#!/usr/bin/env bats
# orca/worktree-remove.sh test suite.
# A fake orca on PATH records calls; the real Orca app is never touched.

SCRIPT="${BATS_TEST_DIRNAME}/../orca/worktree-remove.sh"

setup() {
    export HOME="$BATS_TEST_TMPDIR/home" GIT_CONFIG_GLOBAL=/dev/null
    export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@test.com
    export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@test.com
    mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : > "$CALLS"
    printf '#!/bin/sh\necho "orca $*" >> "$CALLS"\n' > "$BATS_TEST_TMPDIR/bin/orca"
    chmod +x "$BATS_TEST_TMPDIR/bin/orca"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"

    cd "$BATS_TEST_TMPDIR"
    git init -q -b main upstream
    git -C upstream commit -q --allow-empty -m initial
    git clone -q upstream main
    git -C main worktree add -q ../wt
    cd wt
}

@test "removes a clean, merged worktree" {
    run sh "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -qx 'orca worktree rm --worktree current --force' "$CALLS"
}

@test "refuses the main worktree" {
    cd ../main
    run sh "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *メインの作業ツリー* ]]
    [ ! -s "$CALLS" ]
}

@test "refuses untracked files" {
    touch new-file
    run sh "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *未コミットの変更* ]]
    [ ! -s "$CALLS" ]
}

@test "refuses an unmerged branch" {
    git commit -q --allow-empty -m unmerged
    run sh "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *マージされていない* ]]
    [ ! -s "$CALLS" ]
}
