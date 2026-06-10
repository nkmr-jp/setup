#!/usr/bin/env bats
# ai.zsh claude()（tmux ラッパー）テストスイート
#
# claude / tmux / uuidgen を PATH 先頭のモックに差し替え、呼び出され方
# （素通しか tmux 包みか・セッション名・--session-id 付与）を検証する。

WRAPPER="${BATS_TEST_DIRNAME}/claude_tmux_wrapper.zsh"
FIXED_UUID="abcd1234-5678-90ab-cdef-1234567890ab"

setup() {
    export MOCK_DIR="$BATS_TEST_TMPDIR/mocks"
    mkdir -p "$MOCK_DIR"
    export PATH="$MOCK_DIR:$PATH"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : > "$CALLS"

    cat > "$MOCK_DIR/claude" << MOCK_EOF
#!/bin/bash
echo "claude \$*" >> "$CALLS"
MOCK_EOF
    cat > "$MOCK_DIR/tmux" << MOCK_EOF
#!/bin/bash
echo "tmux \$*" >> "$CALLS"
MOCK_EOF
    cat > "$MOCK_DIR/uuidgen" << MOCK_EOF
#!/bin/bash
echo "${FIXED_UUID:u}"
MOCK_EOF
    chmod +x "$MOCK_DIR/claude" "$MOCK_DIR/tmux" "$MOCK_DIR/uuidgen"

    # テスト環境自体が tmux 内でも素の状態から検証できるように外す
    unset TMUX CC_NO_TMUX
}

run_claude() {
    run zsh "$WRAPPER" "$@"
}

@test "通常起動: 採番した sid で tmux new-session -A -s ccdash-<sid8> + --session-id" {
    run_claude
    grep -q "tmux new-session -A -s ccdash-abcd1234" "$CALLS"
    grep -q -- "--session-id $FIXED_UUID" "$CALLS"
    ! grep -q "^claude" "$CALLS"
}

@test "通常起動: 元の引数が tmux のコマンド文字列に引き継がれる" {
    run_claude --model opus
    grep -q -- "--model opus" "$CALLS"
    grep -q "tmux new-session" "$CALLS"
}

@test "--resume <sid>: その sid を tmux 名に使い --session-id は付けない" {
    run_claude --resume "$FIXED_UUID"
    grep -q "tmux new-session -A -s ccdash-abcd1234" "$CALLS"
    ! grep -q -- "--session-id" "$CALLS"
}

@test "--resume 値なし（ピッカー）: 素通しで直接 claude" {
    run_claude --resume
    grep -q "^claude --resume" "$CALLS"
    ! grep -q "^tmux" "$CALLS"
}

@test "tmux 内（TMUX 設定済み）: 素通し" {
    TMUX=/tmp/fake-tmux-socket run zsh "$WRAPPER"
    grep -q "^claude" "$CALLS"
    ! grep -q "^tmux" "$CALLS"
}

@test "CC_NO_TMUX=1: 素通し" {
    CC_NO_TMUX=1 run zsh "$WRAPPER"
    grep -q "^claude" "$CALLS"
    ! grep -q "^tmux" "$CALLS"
}

@test "-p（非対話）: 素通し" {
    run_claude -p "hello"
    grep -q "^claude -p hello" "$CALLS"
    ! grep -q "^tmux" "$CALLS"
}

@test "--continue: 素通し" {
    run_claude --continue
    grep -q "^claude --continue" "$CALLS"
    ! grep -q "^tmux" "$CALLS"
}

@test "tmux が無い環境: 素通し" {
    rm "$MOCK_DIR/tmux"
    # システムの tmux も見えないよう PATH をモックと最小限に絞る
    PATH="$MOCK_DIR:/usr/bin:/bin" run zsh "$WRAPPER"
    grep -q "^claude" "$CALLS"
}
