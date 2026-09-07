#!/usr/bin/env bats
# cache.zsh test suite
#
# Helpers cache expensive startup initialization. Focus on detecting stale
# caches rather than serving outdated settings, and on preserving existing
# cache data when generation fails.

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

@test "source: generates and sources the result on the first call" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=generated'
    [ "$status" -eq 0 ]
    [ -s "$ZSH_CACHE_DIR/out.zsh" ]
    [ "$(cat "$ZSH_CACHE_DIR/out.zsh")" = "MARK=generated" ]
}

@test "source: reuses the cache without running the generator on the second call" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=first'
    [ "$status" -eq 0 ]
    # Changing the generator alone should not invalidate unchanged dependencies.
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=second'
    [ "$status" -eq 0 ]
    [ "$(cat "$ZSH_CACHE_DIR/out.zsh")" = "MARK=first" ]
}

@test "source: regenerates when a dependency is newer" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=old'
    [ "$status" -eq 0 ]
    sleep 1
    touch "$DEP"
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=new'
    [ "$status" -eq 0 ]
    [ "$(cat "$ZSH_CACHE_DIR/out.zsh")" = "MARK=new" ]
}

@test "source: ignores nonexistent dependencies without regenerating" {
    run_cache _zsh_cache_source out.zsh "$BATS_TEST_TMPDIR/nope" -- print -r -- 'MARK=first'
    [ "$status" -eq 0 ]
    run_cache _zsh_cache_source out.zsh "$BATS_TEST_TMPDIR/nope" -- print -r -- 'MARK=second'
    [ "$(cat "$ZSH_CACHE_DIR/out.zsh")" = "MARK=first" ]
}

@test "source: regenerates if any dependency is newer" {
    local dep2="$BATS_TEST_TMPDIR/dep2"
    echo v1 > "$dep2"
    run_cache _zsh_cache_source out.zsh "$DEP" "$dep2" -- print -r -- 'MARK=old'
    [ "$status" -eq 0 ]
    sleep 1
    touch "$dep2"
    run_cache _zsh_cache_source out.zsh "$DEP" "$dep2" -- print -r -- 'MARK=new'
    [ "$(cat "$ZSH_CACHE_DIR/out.zsh")" = "MARK=new" ]
}

@test "source: preserves the existing cache when generation fails" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=good'
    [ "$status" -eq 0 ]
    sleep 1
    touch "$DEP"
    run_cache _zsh_cache_source out.zsh "$DEP" -- false
    # Generation failed, but sourcing the existing cache still counts as success.
    [ "$status" -eq 0 ]
    [ "$(cat "$ZSH_CACHE_DIR/out.zsh")" = "MARK=good" ]
}

@test "source: returns 1 if initial generation fails so the caller can fall back" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- false
    [ "$status" -eq 1 ]
    [ ! -e "$ZSH_CACHE_DIR/out.zsh" ]
}

@test "source: does not cache empty generator output" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- true
    [ "$status" -eq 1 ]
    [ ! -e "$ZSH_CACHE_DIR/out.zsh" ]
}

@test "source: leaves no temporary files" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- false
    run bash -c "ls '$ZSH_CACHE_DIR'/*.tmp 2>/dev/null | wc -l"
    [ "${output// /}" = "0" ]
}

# ============================================================
# _zsh_cache_var
# ============================================================

@test "var: captures command output in a variable" {
    run_cache _zsh_cache_var v.zsh MYVAR "$DEP" -- print -r -- '/some/path'
    [ "$status" -eq 0 ]
    [ "$(cat "$ZSH_CACHE_DIR/v.zsh")" = "typeset -g MYVAR=/some/path" ]
}

@test "var: quotes and stores values containing spaces" {
    run_cache _zsh_cache_var v.zsh MYVAR "$DEP" -- print -r -- '/path with space'
    [ "$status" -eq 0 ]
    run zsh -c "source '$ZSH_CACHE_DIR/v.zsh'; print -r -- \$MYVAR"
    [ "$output" = "/path with space" ]
}

@test "var: returns 1 without caching if the command fails" {
    run_cache _zsh_cache_var v.zsh MYVAR "$DEP" -- false
    [ "$status" -eq 1 ]
    [ ! -e "$ZSH_CACHE_DIR/v.zsh" ]
}

@test "var: does not cache empty output" {
    run_cache _zsh_cache_var v.zsh MYVAR "$DEP" -- true
    [ "$status" -eq 1 ]
}

# ============================================================
# _zsh_cache_completion
# ============================================================

@test "completion: writes completion scripts under completions/" {
    run_cache _zsh_cache_completion _demo "$DEP" -- print -r -- '#compdef demo'
    [ "$status" -eq 0 ]
    [ "$(cat "$ZSH_CACHE_DIR/completions/_demo")" = "#compdef demo" ]
}

# ============================================================
# zsh-cache-clear
# ============================================================

@test "clear: removes the entire cache directory" {
    run_cache _zsh_cache_source out.zsh "$DEP" -- print -r -- 'MARK=x'
    [ -d "$ZSH_CACHE_DIR" ]
    run_cache zsh-cache-clear
    [ "$status" -eq 0 ]
    [ ! -d "$ZSH_CACHE_DIR" ]
}
