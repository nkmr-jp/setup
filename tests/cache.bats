#!/usr/bin/env bats
# cache.zsh テストスイート
#
# 起動時の重い初期化をキャッシュするヘルパー。キャッシュが古くなったことを
# 取りこぼす（古い設定を配り続ける）のと、生成失敗で既存のキャッシュを壊すのが
# いちばん怖いので、そこを重点的に見る。

CACHE_WRAPPER="${BATS_TEST_DIRNAME}/cache_wrapper.zsh"

setup() {
    export ZSH_CACHE_DIR="$BATS_TEST_TMPDIR/cache"
    export DEP="$BATS_TEST_TMPDIR/dep"
    echo "v1" > "$DEP"
}

run_cache() {
    run zsh "$CACHE_WRAPPER" "$@"
}

# ============================================================
# _zsh_cache_source
# ============================================================

@test "source: 初回は生成コマンドを実行して結果を source する" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=generated'
    [ "$status" -eq 0 ]
    [ -s "$ZSH_CACHE_DIR/out.zsh" ]
    [ "$(cat "$ZSH_CACHE_DIR/out.zsh")" = "MARK=generated" ]
}

@test "source: 2 回目は生成コマンドを実行しない（キャッシュを使う）" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=first'
    [ "$status" -eq 0 ]
    # 生成コマンドを変えても、依存が更新されていないので古いままのはず
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=second'
    [ "$status" -eq 0 ]
    [ "$(cat "$ZSH_CACHE_DIR/out.zsh")" = "MARK=first" ]
}

@test "source: 依存が新しくなったら作り直す" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=old'
    [ "$status" -eq 0 ]
    sleep 1
    touch "$DEP"
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=new'
    [ "$status" -eq 0 ]
    [ "$(cat "$ZSH_CACHE_DIR/out.zsh")" = "MARK=new" ]
}

@test "source: 存在しない依存は無視する（それだけで作り直さない）" {
    run_cache _zsh_cache_source out.zsh "$BATS_TEST_TMPDIR/nope" -- print -r -- 'MARK=first'
    [ "$status" -eq 0 ]
    run_cache _zsh_cache_source out.zsh "$BATS_TEST_TMPDIR/nope" -- print -r -- 'MARK=second'
    [ "$(cat "$ZSH_CACHE_DIR/out.zsh")" = "MARK=first" ]
}

@test "source: 依存が複数ならどれか 1 つでも新しければ作り直す" {
    local dep2="$BATS_TEST_TMPDIR/dep2"
    echo v1 > "$dep2"
    run_cache _zsh_cache_source out.zsh "$DEP" "$dep2" -- print -r -- 'MARK=old'
    [ "$status" -eq 0 ]
    sleep 1
    touch "$dep2"
    run_cache _zsh_cache_source out.zsh "$DEP" "$dep2" -- print -r -- 'MARK=new'
    [ "$(cat "$ZSH_CACHE_DIR/out.zsh")" = "MARK=new" ]
}

@test "source: 生成に失敗したら既存のキャッシュを壊さない" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=good'
    [ "$status" -eq 0 ]
    sleep 1
    touch "$DEP"
    run_cache _zsh_cache_source out.zsh "$DEP" -- false
    # 生成は失敗したが、古いキャッシュを source できるので成功扱い
    [ "$status" -eq 0 ]
    [ "$(cat "$ZSH_CACHE_DIR/out.zsh")" = "MARK=good" ]
}

@test "source: 初回の生成に失敗したら 1 を返す（呼び出し側がフォールバックできる）" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- false
    [ "$status" -eq 1 ]
    [ ! -e "$ZSH_CACHE_DIR/out.zsh" ]
}

@test "source: 生成コマンドが空を出力したらキャッシュを作らない" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- true
    [ "$status" -eq 1 ]
    [ ! -e "$ZSH_CACHE_DIR/out.zsh" ]
}

@test "source: 一時ファイルを残さない" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- false
    run bash -c "ls '$ZSH_CACHE_DIR'/*.tmp 2>/dev/null | wc -l"
    [ "${output// /}" = "0" ]
}

# ============================================================
# _zsh_cache_var
# ============================================================

@test "var: コマンドの出力を変数に取り込む" {
    run_cache _zsh_cache_var v.zsh MYVAR "$DEP" -- print -r -- '/some/path'
    [ "$status" -eq 0 ]
    [ "$(cat "$ZSH_CACHE_DIR/v.zsh")" = "typeset -g MYVAR=/some/path" ]
}

@test "var: 空白を含む値をクォートして保存する" {
    run_cache _zsh_cache_var v.zsh MYVAR "$DEP" -- print -r -- '/path with space'
    [ "$status" -eq 0 ]
    run zsh -c "source '$ZSH_CACHE_DIR/v.zsh'; print -r -- \$MYVAR"
    [ "$output" = "/path with space" ]
}

@test "var: コマンドが失敗したらキャッシュを作らず 1 を返す" {
    run_cache _zsh_cache_var v.zsh MYVAR "$DEP" -- false
    [ "$status" -eq 1 ]
    [ ! -e "$ZSH_CACHE_DIR/v.zsh" ]
}

@test "var: コマンドが空を返したらキャッシュを作らない" {
    run_cache _zsh_cache_var v.zsh MYVAR "$DEP" -- true
    [ "$status" -eq 1 ]
}

# ============================================================
# _zsh_cache_completion
# ============================================================

@test "completion: completions/ 配下に補完ファイルを書き出す" {
    run_cache _zsh_cache_completion _demo "$DEP" -- print -r -- '#compdef demo'
    [ "$status" -eq 0 ]
    [ "$(cat "$ZSH_CACHE_DIR/completions/_demo")" = "#compdef demo" ]
}

# ============================================================
# zsh-cache-clear
# ============================================================

@test "clear: キャッシュディレクトリごと削除する" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=x'
    [ -d "$ZSH_CACHE_DIR" ]
    run_cache zsh-cache-clear
    [ "$status" -eq 0 ]
    [ ! -d "$ZSH_CACHE_DIR" ]
}
