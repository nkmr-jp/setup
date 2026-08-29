#!/usr/bin/env bats
# check-config-symlinks.sh テストスイート
#
# 管理対象は CHECK_CONFIG_SYMLINKS_ENTRIES で差し替えられるので、実際のホームには触れずに
# 各状態（OK / DETACHED / BROKEN / WRONG / MISSING / PENDING）を作って検証する。

SCRIPT="${BATS_TEST_DIRNAME}/../bin/check-config-symlinks.sh"

setup() {
    # 通知の重複抑止に使う state file をテスト間で隔離する（実環境のものを触らない）
    export STATE_DIR="$BATS_TEST_TMPDIR/state"
    STATE_FILE="$STATE_DIR/state"
    REPO="$BATS_TEST_TMPDIR/repo"
    HOMEDIR="$BATS_TEST_TMPDIR/home"
    mkdir -p "$REPO" "$HOMEDIR"
    echo "managed" > "$REPO/config.json"
}

# 通知を実際に撃つ経路のテスト用に terminal-notifier をダミーへ差し替える。
# 呼ばれた回数を数えるので「鳴ったか / 鳴らなかったか」を検証できる。
stub_notifier() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/terminal-notifier" <<'STUB'
#!/bin/bash
echo "notified" >> "$NOTIFY_LOG"
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/terminal-notifier"
    export NOTIFY_LOG="$BATS_TEST_TMPDIR/notify.log"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

notify_count() {
    [ -f "$NOTIFY_LOG" ] && wc -l < "$NOTIFY_LOG" | tr -d ' ' || echo 0
}

# 通知あり（既定モード）で実行する
run_check_notify() {
    export CHECK_CONFIG_SYMLINKS_ENTRIES="$1"
    shift
    run bash "$SCRIPT" "$@"
}

run_check() {
    export CHECK_CONFIG_SYMLINKS_ENTRIES="$1"
    shift
    run bash "$SCRIPT" --no-notify "$@"
}

@test "OK: リンクが期待どおり張られていれば成功する" {
    ln -s "$REPO/config.json" "$HOMEDIR/config.json"
    run_check "$HOMEDIR/config.json|$REPO/config.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"外れているリンクは無い"* ]]
}

@test "DETACHED: 実体ファイルに置き換わっていたら検出する" {
    echo "overwritten" > "$HOMEDIR/config.json"
    run_check "$HOMEDIR/config.json|$REPO/config.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"DETACHED"* ]]
    [[ "$output" == *"中身が乖離している"* ]]
}

@test "DETACHED: 中身が同じでもリンクが外れていれば検出する" {
    cp "$REPO/config.json" "$HOMEDIR/config.json"
    run_check "$HOMEDIR/config.json|$REPO/config.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"DETACHED"* ]]
    [[ "$output" == *"中身は同じ"* ]]
}

@test "BROKEN: リンク先が消えていたら検出する" {
    ln -s "$REPO/config.json" "$HOMEDIR/config.json"
    rm "$REPO/config.json"
    run_check "$HOMEDIR/config.json|$REPO/config.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"BROKEN"* ]]
}

@test "WRONG: 別のリンク先を向いていたら検出する" {
    echo "other" > "$REPO/other.json"
    ln -s "$REPO/other.json" "$HOMEDIR/config.json"
    run_check "$HOMEDIR/config.json|$REPO/config.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"WRONG"* ]]
}

@test "PENDING: リポジトリ側に実体が無ければ未管理として警告しない" {
    echo "local only" > "$HOMEDIR/notyet.json"
    run_check "$HOMEDIR/notyet.json|$REPO/notyet.json"
    [ "$status" -eq 0 ]
    run_check "$HOMEDIR/notyet.json|$REPO/notyet.json" --list
    [[ "$output" == *"PENDING"* ]]
}

@test "ディレクトリの symlink も同じように扱う" {
    mkdir -p "$REPO/dir"
    echo "x" > "$REPO/dir/a.txt"
    ln -s "$REPO/dir" "$HOMEDIR/dir"
    run_check "$HOMEDIR/dir|$REPO/dir"
    [ "$status" -eq 0 ]

    rm "$HOMEDIR/dir"
    mkdir -p "$HOMEDIR/dir"
    echo "y" > "$HOMEDIR/dir/a.txt"
    run_check "$HOMEDIR/dir|$REPO/dir"
    [ "$status" -eq 1 ]
    [[ "$output" == *"DETACHED"* ]]
    [[ "$output" == *"中身が乖離している"* ]]
}

@test "複数エントリのうち壊れているものだけを既定モードで出す" {
    ln -s "$REPO/config.json" "$HOMEDIR/config.json"
    echo "broken" > "$HOMEDIR/other.json"
    echo "managed" > "$REPO/other.json"
    run_check "$HOMEDIR/config.json|$REPO/config.json
$HOMEDIR/other.json|$REPO/other.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"other.json"* ]]
    [[ "$output" != *"OK       "* ]]
}

@test "--no-notify では state file を書かない（次の定期実行の通知を潰さない）" {
    echo "overwritten" > "$HOMEDIR/config.json"
    run_check "$HOMEDIR/config.json|$REPO/config.json"
    [ "$status" -eq 1 ]
    [ ! -f "$STATE_FILE" ]
}

@test "--list も通知せず state file を書かない（棚卸しで監視を止めない）" {
    stub_notifier
    echo "overwritten" > "$HOMEDIR/config.json"
    run_check_notify "$HOMEDIR/config.json|$REPO/config.json" --list
    [ "$status" -eq 1 ]
    [ ! -f "$STATE_FILE" ]
    [ "$(notify_count)" -eq 0 ]
}

@test "問題が解消したら state file を消す（次に壊れたらまた鳴る）" {
    mkdir -p "$STATE_DIR"
    echo "stale" > "$STATE_FILE"
    ln -s "$REPO/config.json" "$HOMEDIR/config.json"
    run_check "$HOMEDIR/config.json|$REPO/config.json"
    [ "$status" -eq 0 ]
    [ ! -f "$STATE_FILE" ]
}

@test "同じ問題が続く間は鳴らし直さない" {
    stub_notifier
    echo "overwritten" > "$HOMEDIR/config.json"
    local entry="$HOMEDIR/config.json|$REPO/config.json"
    run_check_notify "$entry"
    [ "$(notify_count)" -eq 1 ]
    run_check_notify "$entry"
    [ "$(notify_count)" -eq 1 ]
}

@test "同じ問題でも RENOTIFY_DAYS を過ぎたら鳴らし直す（見逃しても永久に黙らない）" {
    stub_notifier
    echo "overwritten" > "$HOMEDIR/config.json"
    local entry="$HOMEDIR/config.json|$REPO/config.json"
    run_check_notify "$entry"
    [ "$(notify_count)" -eq 1 ]
    # 前回通知を 8 日前に見せかける
    mkdir -p "$STATE_DIR"
    { echo "$(( $(date +%s) - 8 * 86400 ))"; tail -n +2 "$STATE_FILE"; } > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"
    run_check_notify "$entry"
    [ "$(notify_count)" -eq 2 ]
}

@test "NOLINK: ホーム側のリンクが消えていてもリポジトリ側に実体があれば検出する" {
    run_check "$HOMEDIR/config.json|$REPO/config.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"NOLINK"* ]]
}

@test "MISSING: 両側とも無ければ警告しない" {
    run_check "$HOMEDIR/none.json|$REPO/none.json"
    [ "$status" -eq 0 ]
    run_check "$HOMEDIR/none.json|$REPO/none.json" --list
    [[ "$output" == *"MISSING"* ]]
}

@test "ディレクトリの直し方には cp -R と rm -rf を出す（ln -sfn の入れ子リンクを避ける）" {
    mkdir -p "$REPO/dir" "$HOMEDIR/dir"
    run_check "$HOMEDIR/dir|$REPO/dir"
    [ "$status" -eq 1 ]
    [[ "$output" == *"cp -R"* ]]
    [[ "$output" == *"rm -rf"* ]]
    [[ "$output" != *"ln -sfn"* ]]
}

@test "末尾スラッシュ付きのリンクを WRONG と誤検知しない" {
    mkdir -p "$REPO/dir"
    ln -sfn "$REPO/dir/" "$HOMEDIR/dir"
    run_check "$HOMEDIR/dir|$REPO/dir"
    [ "$status" -eq 0 ]
    [[ "$output" != *"WRONG"* ]]
}

@test "区切り文字の無い不正なエントリは黙って無視せずエラーにする" {
    run_check "$HOMEDIR/config.json"
    [ "$status" -eq 2 ]
    [[ "$output" == *"invalid entry"* ]]
}
