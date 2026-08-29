#!/usr/bin/env bats
# check-config-symlinks.sh テストスイート
#
# 管理対象は CHECK_CONFIG_SYMLINKS_ENTRIES で差し替えられるので、実際のホームには触れずに
# 各状態（OK / DETACHED / BROKEN / WRONG / MISSING / PENDING）を作って検証する。

SCRIPT="${BATS_TEST_DIRNAME}/../bin/check-config-symlinks.sh"

setup() {
    export TMPDIR="$BATS_TEST_TMPDIR"   # 通知の重複抑止に使う state file をテスト間で隔離する
    REPO="$BATS_TEST_TMPDIR/repo"
    HOMEDIR="$BATS_TEST_TMPDIR/home"
    mkdir -p "$REPO" "$HOMEDIR"
    echo "managed" > "$REPO/config.json"
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

@test "MISSING: ホーム側に何も無ければ警告しない（--list には出る）" {
    run_check "$HOMEDIR/config.json|$REPO/config.json"
    [ "$status" -eq 0 ]
    run_check "$HOMEDIR/config.json|$REPO/config.json" --list
    [[ "$output" == *"MISSING"* ]]
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
    [ ! -f "$BATS_TEST_TMPDIR/check-config-symlinks.state" ]
}

@test "問題が解消したら state file を消す（次に壊れたらまた鳴る）" {
    echo "stale" > "$BATS_TEST_TMPDIR/check-config-symlinks.state"
    ln -s "$REPO/config.json" "$HOMEDIR/config.json"
    run_check "$HOMEDIR/config.json|$REPO/config.json"
    [ "$status" -eq 0 ]
    [ ! -f "$BATS_TEST_TMPDIR/check-config-symlinks.state" ]
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
