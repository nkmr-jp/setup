#!/usr/bin/env bats
# goenv.zsh テストスイート
#
# _goenv_set_paths は本家 `goenv rehash --only-manage-paths` (190ms) の置き換えなので、
# 解決規則が本家と同じであることを担保する。

GOENV_WRAPPER="${BATS_TEST_DIRNAME}/goenv_wrapper.zsh"

setup() {
    # テスト用の goenv ルート（versions/ と version を持つだけの最小構成）
    export GOENV_ROOT="$BATS_TEST_TMPDIR/goenv"
    mkdir -p "$GOENV_ROOT/versions/1.20.0" "$GOENV_ROOT/versions/1.20.9" \
             "$GOENV_ROOT/versions/1.20.10" "$GOENV_ROOT/versions/1.26.1"
    echo "1.26.1" > "$GOENV_ROOT/version"

    export WORK="$BATS_TEST_TMPDIR/work"
    mkdir -p "$WORK/proj/sub"
}

run_goenv_from() {
    cd "$1"
    run env -u GOROOT -u GOPATH zsh "$GOENV_WRAPPER"
}

# ============================================================
# バージョンの解決
# ============================================================

@test "version: .go-version が無ければ global を使う" {
    run_goenv_from "$WORK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.26.1"* ]]
    [[ "$output" == *"GOPATH=$HOME/go/1.26.1"* ]]
}

@test "version: カレントの .go-version を優先する" {
    echo "1.20.0" > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.20.0"* ]]
    [[ "$output" == *"GOPATH=$HOME/go/1.20.0"* ]]
}

@test "version: 親ディレクトリの .go-version を辿って見つける" {
    echo "1.20.0" > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj/sub"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.20.0"* ]]
}

@test "version: .go-version の前後の空白・改行を無視する" {
    printf '  1.20.0 \n' > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.20.0"* ]]
}

@test "version: system なら GOROOT / GOPATH を設定しない" {
    echo "system" > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT="* ]]
    [[ "$output" != *"GOROOT=$GOENV_ROOT"* ]]
}

@test "version: global の version ファイルも無ければ何も設定しない" {
    rm -f "$GOENV_ROOT/version"
    run_goenv_from "$WORK"
    [ "$status" -eq 0 ]
    [[ "$output" != *"GOROOT=$GOENV_ROOT"* ]]
}

@test "version: GOENV_ROOT の末尾スラッシュを正規化する" {
    export GOENV_ROOT="$GOENV_ROOT/"
    run_goenv_from "$WORK"
    [ "$status" -eq 0 ]
    # //versions のような二重スラッシュにならないこと
    [[ "$output" != *"//versions"* ]]
    [[ "$output" == *"/versions/1.26.1"* ]]
}

# ============================================================
# インストール済みバージョンへの解決（本家 goenv-prefix と同じ規則）
# ============================================================

@test "resolve: major.minor 指定は最新パッチに解決する" {
    echo "1.20" > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    # 数値順なので 1.20.9 ではなく 1.20.10 が選ばれる
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.20.10"* ]]
    # GOPATH も解決後の版で決まる（本家と同じ）
    [[ "$output" == *"GOPATH=$HOME/go/1.20.10"* ]]
}

@test "resolve: go- 接頭辞を落として解決する" {
    echo "go-1.20.0" > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.20.0"* ]]
}

@test "resolve: 未インストールの版なら何も設定しない" {
    # 素通しすると存在しないディレクトリを GOROOT に入れてしまう
    echo "1.99.0" > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    [[ "$output" != *"GOROOT=$GOENV_ROOT"* ]]
    [[ "$output" != *"GOPATH=$HOME/go/1.99.0"* ]]
}

@test "resolve: .go-version が複数行なら先頭を使う" {
    printf '1.20.0\n1.26.1\n' > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.20.0"* ]]
}

# ============================================================
# GOENV_VERSION（`goenv shell` が export する）
# ============================================================

@test "GOENV_VERSION: .go-version より優先する" {
    echo "1.20.0" > "$WORK/proj/.go-version"
    cd "$WORK/proj"
    run env -u GOROOT -u GOPATH GOENV_VERSION=1.26.1 zsh "$GOENV_WRAPPER"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.26.1"* ]]
}

@test "GOENV_VERSION: system なら何も設定しない" {
    cd "$WORK"
    run env -u GOROOT -u GOPATH GOENV_VERSION=system zsh "$GOENV_WRAPPER"
    [ "$status" -eq 0 ]
    [[ "$output" != *"GOROOT=$GOENV_ROOT"* ]]
}

# ============================================================
# 削除済み cwd のガード（goenv 2.2.39 の無限ループ対策）
# ============================================================

@test "deleted-cwd: PWD が \".\" でも無限ループせず即座に返る" {
    # cwd が削除されたシェルでは PWD が "." になる。親を辿るループが
    # "." では縮まないため、ガードが無いと 100% CPU で無限ループする。
    local doomed="$BATS_TEST_TMPDIR/doomed"
    mkdir -p "$doomed"

    run timeout 10 zsh -c "
        cd '$doomed' && rmdir '$doomed'
        export GOENV_ROOT='$GOENV_ROOT'
        exec zsh '$GOENV_WRAPPER'
    "
    # timeout の 124 で終わらない = 無限ループしていない
    [ "$status" -ne 124 ]
    [[ "$output" == *"cwd が削除されています"* ]]
}
