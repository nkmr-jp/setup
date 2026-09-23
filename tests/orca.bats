#!/usr/bin/env bats
# zsh/orca.zsh and orca/workspace-name-watch.zsh test suite.
# A fake orca/perl on PATH records calls; the real Orca app is never touched.

ROOT="${BATS_TEST_DIRNAME}/.."
WATCH="${ROOT}/orca/workspace-name-watch.zsh"

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : > "$CALLS"

    cat > "$BATS_TEST_TMPDIR/bin/orca" <<'EOF'
#!/bin/sh
echo "orca $*" >> "$CALLS"
[ -n "$FAKE_FAIL" ] && exit 1
case "$1 $2" in
  "terminal list") printf '{"ok":true,"result":{"terminals":[],"totalCount":%s,"truncated":false}}\n' "${FAKE_COUNT:-0}" ;;
  "worktree show") printf '{"ok":true,"result":{"worktree":{"displayNameMode":"%s"}}}\n' "${FAKE_MODE:-fixed}" ;;
  "worktree set") echo '{"ok":true}' ;;
esac
EOF
    cat > "$BATS_TEST_TMPDIR/bin/perl" <<'EOF'
#!/bin/sh
echo "perl $*" >> "$CALLS"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/orca" "$BATS_TEST_TMPDIR/bin/perl"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    export ORCA_NAME_WATCH_POLL_CS=1 ORCA_NAME_WATCH_SETTLE=0
}

# Prints the PID of a process that has already exited.
dead_pid() {
    sh -c 'exit 0' &
    local pid=$!
    wait "$pid"
    echo "$pid"
}

run_watch() {
    run zsh -f "$WATCH" "$(dead_pid)" "repo::/tmp/wt"
}

# ============================================================
# Watcher
# ============================================================

@test "watch: resets a fixed name when no terminals remain" {
    run_watch
    [ "$status" -eq 0 ]
    grep -qx 'orca worktree set --worktree id:repo::/tmp/wt --display-name   --json' "$CALLS"
}

@test "watch: skips when terminals remain" {
    FAKE_COUNT=1 run_watch
    [ "$status" -eq 0 ]
    ! grep -q 'worktree set' "$CALLS"
}

@test "watch: skips when the name is already automatic" {
    FAKE_MODE=automatic run_watch
    [ "$status" -eq 0 ]
    ! grep -q 'worktree set' "$CALLS"
}

@test "watch: skips when orca is unreachable" {
    FAKE_FAIL=1 run_watch
    [ "$status" -eq 0 ]
    ! grep -q 'worktree set' "$CALLS"
}

@test "watch: waits while the shell is alive" {
    sleep 2 &
    local pid=$!
    local start=$SECONDS
    run zsh -f "$WATCH" "$pid" "repo::/tmp/wt"
    [ $((SECONDS - start)) -ge 1 ]
    grep -q 'worktree set' "$CALLS"
}

@test "watch: does not pass the dead terminal's identity to orca" {
    cat > "$BATS_TEST_TMPDIR/bin/orca" <<'EOF'
#!/bin/sh
echo "handle=${ORCA_TERMINAL_HANDLE-unset}" >> "$CALLS"
exit 1
EOF
    ORCA_TERMINAL_HANDLE=term_x run_watch
    grep -qx 'handle=unset' "$CALLS"
}

# ============================================================
# Shell module gate
# ============================================================

# Sources the module in a clean zsh; extra args are zsh options such as -i.
source_module() {
    run env TERM_PROGRAM="${TERM_PROGRAM_VALUE-Orca}" ORCA_TERMINAL_HANDLE=term_1 \
        ORCA_WORKTREE_ID=repo::/tmp/wt SETUP_DIR="$ROOT" \
        zsh -f "$@" -c 'source "$SETUP_DIR/zsh/orca.zsh"'
}

@test "module: starts one detached watcher in an interactive Orca shell" {
    source_module -i
    [ "$status" -eq 0 ]
    [ "$(grep -c '^perl ' "$CALLS")" -eq 1 ]
    grep -q "workspace-name-watch.zsh" "$CALLS"
}

@test "module: does nothing in a non-interactive shell" {
    source_module
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "module: does nothing outside Orca even with leaked ORCA_* variables" {
    TERM_PROGRAM_VALUE=iTerm.app source_module -i
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "module: nested shells in the same terminal do not start another watcher" {
    run env TERM_PROGRAM=Orca ORCA_TERMINAL_HANDLE=term_1 ORCA_WORKTREE_ID=repo::/tmp/wt \
        _ORCA_NAME_WATCH_HANDLE=term_1 SETUP_DIR="$ROOT" \
        zsh -f -i -c 'source "$SETUP_DIR/zsh/orca.zsh"'
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}
