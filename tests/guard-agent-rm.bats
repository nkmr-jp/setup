#!/usr/bin/env bats
# guard-agent-rm.sh テストスイート
#
# ブロックすべきもの（exit 2）と、通すべきもの（exit 0）を両方確認する。
# 通すべきものを止めると日常作業が壊れるので、誤検知側のテストを厚めにする。

GUARD="${BATS_TEST_DIRNAME}/../bin/guard-agent-rm.sh"

run_guard() {
    local cmd="$1"
    run bash -c "printf '%s' '$(printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$cmd" | jq -R -s .)")' | bash '$GUARD'"
}

@test "ブロック: ホーム直下のディレクトリを rm -rf する" {
    run_guard 'rm -rf "$HOME/.prompt-line.verifybak"'
    [ "$status" -eq 2 ]
    [[ "$output" == *"ゴミ箱を経由しない"* ]]
}

@test "ブロック: ~/ 形式でも検出する" {
    run_guard 'rm -rf ~/.orca'
    [ "$status" -eq 2 ]
}

@test "ブロック: 絶対パスのホーム配下でも検出する" {
    run_guard 'rm -f /Users/nkmr/.zshrc'
    [ "$status" -eq 2 ]
}

@test "ブロック: 呼び出されるスクリプトの中身まで見る（今回の事故の形）" {
    script="$BATS_TEST_TMPDIR/verify-edge.sh"
    cat > "$script" <<'SH'
#!/bin/bash
mv "$HOME/.prompt-line" "$HOME/.prompt-line.verifybak" 2>/dev/null
rm -rf "$HOME/.prompt-line.verifybak"
SH
    run_guard "bash $script"
    [ "$status" -eq 2 ]
    [[ "$output" == *"prompt-line.verifybak"* ]]
}

@test "通す: /tmp 配下" {
    run_guard 'rm -rf /tmp/work'
    [ "$status" -eq 0 ]
}

@test "通す: TMPDIR 配下" {
    run_guard 'rm -f "${TMPDIR:-/tmp}/check-config-symlinks.state"'
    [ "$status" -eq 0 ]
}

@test "通す: scratchpad 配下" {
    run_guard 'rm -rf /private/tmp/claude-501/foo/scratchpad/work'
    [ "$status" -eq 0 ]
}

@test "通す: ghq 配下のリポジトリ（git で戻せる）" {
    run_guard 'rm -f /Users/nkmr/ghq/github.com/nkmr-jp/setup/tmpfile'
    [ "$status" -eq 0 ]
}

@test "通す: ホームを指していない rm" {
    run_guard 'rm -f ./build/out.o'
    [ "$status" -eq 0 ]
}

@test "通す: trash を使っている" {
    run_guard 'trash "$HOME/.prompt-line.verifybak"'
    [ "$status" -eq 0 ]
}

@test "通す: rm を含む単語（confirm など）に反応しない" {
    run_guard 'echo "$HOME/confirm-rm-guard"'
    [ "$status" -eq 0 ]
}

@test "通す: コメント行の rm は無視する" {
    script="$BATS_TEST_TMPDIR/commented.sh"
    printf '#!/bin/bash\n# rm -rf $HOME/.foo をやってはいけない\necho ok\n' > "$script"
    run_guard "bash $script"
    [ "$status" -eq 0 ]
}

@test "通す: Bash 以外のツールは対象外" {
    run bash -c "printf '%s' '{\"tool_name\":\"Write\",\"tool_input\":{\"command\":\"rm -rf \$HOME/.foo\"}}' | bash '$GUARD'"
    [ "$status" -eq 0 ]
}

@test "通す: jq が無い環境では黙って通す（hook が作業を止めない）" {
    # PATH を空にすると bash 自体も引けなくなるので、bash は絶対パスで呼ぶ
    mkdir -p "$BATS_TEST_TMPDIR/nojq"
    run /bin/bash -c "PATH='$BATS_TEST_TMPDIR/nojq' /bin/bash '$GUARD' <<< '{}'"
    [ "$status" -eq 0 ]
}
