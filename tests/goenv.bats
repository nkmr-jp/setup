#!/usr/bin/env bats
# goenv.zsh test suite
#
# _goenv_set_paths replaces upstream goenv rehash --only-manage-paths (190 ms).
# Verify that version resolution follows the same rules as upstream.

GOENV_WRAPPER="${BATS_TEST_DIRNAME}/goenv_wrapper.zsh"

setup() {
    # Minimal test goenv root containing only versions/ and version.
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
# Version resolution
# ============================================================

@test "version: uses the global version when .go-version is absent" {
    run_goenv_from "$WORK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.26.1"* ]]
    [[ "$output" == *"GOPATH=$HOME/go/1.26.1"* ]]
}

@test "version: prefers .go-version in the current directory" {
    echo "1.20.0" > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.20.0"* ]]
    [[ "$output" == *"GOPATH=$HOME/go/1.20.0"* ]]
}

@test "version: searches parent directories for .go-version" {
    echo "1.20.0" > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj/sub"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.20.0"* ]]
}

@test "version: ignores leading and trailing whitespace in .go-version" {
    printf '  1.20.0 \n' > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.20.0"* ]]
}

@test "version: does not set GOROOT or GOPATH for system" {
    echo "system" > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT="* ]]
    [[ "$output" != *"GOROOT=$GOENV_ROOT"* ]]
}

@test "version: sets nothing if the global version file is also absent" {
    rm -f "$GOENV_ROOT/version"
    run_goenv_from "$WORK"
    [ "$status" -eq 0 ]
    [[ "$output" != *"GOROOT=$GOENV_ROOT"* ]]
}

@test "version: normalizes the trailing slash in GOENV_ROOT" {
    export GOENV_ROOT="$GOENV_ROOT/"
    run_goenv_from "$WORK"
    [ "$status" -eq 0 ]
    # Avoid double slashes such as //versions.
    [[ "$output" != *"//versions"* ]]
    [[ "$output" == *"/versions/1.26.1"* ]]
}

# ============================================================
# Resolve installed versions using the same rules as upstream goenv-prefix.
# ============================================================

@test "resolve: resolves major.minor to the latest patch" {
    echo "1.20" > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    # Numeric ordering selects 1.20.10 rather than 1.20.9.
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.20.10"* ]]
    # GOPATH also uses the resolved version, as upstream does.
    [[ "$output" == *"GOPATH=$HOME/go/1.20.10"* ]]
}

@test "resolve: strips the go- prefix before resolution" {
    echo "go-1.20.0" > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.20.0"* ]]
}

@test "resolve: sets nothing for an uninstalled version" {
    # Passing it through would set GOROOT to a nonexistent directory.
    echo "1.99.0" > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    [[ "$output" != *"GOROOT=$GOENV_ROOT"* ]]
    [[ "$output" != *"GOPATH=$HOME/go/1.99.0"* ]]
}

@test "resolve: uses the first line of a multiline .go-version" {
    printf '1.20.0\n1.26.1\n' > "$WORK/proj/.go-version"
    run_goenv_from "$WORK/proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.20.0"* ]]
}

# ============================================================
# GOENV_VERSION (exported by goenv shell)
# ============================================================

@test "GOENV_VERSION: takes precedence over .go-version" {
    echo "1.20.0" > "$WORK/proj/.go-version"
    cd "$WORK/proj"
    run env -u GOROOT -u GOPATH GOENV_VERSION=1.26.1 zsh "$GOENV_WRAPPER"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GOROOT=$GOENV_ROOT/versions/1.26.1"* ]]
}

@test "GOENV_VERSION: sets nothing for system" {
    cd "$WORK"
    run env -u GOROOT -u GOPATH GOENV_VERSION=system zsh "$GOENV_WRAPPER"
    [ "$status" -eq 0 ]
    [[ "$output" != *"GOROOT=$GOENV_ROOT"* ]]
}

# ============================================================
# Guard against deleted working directories (goenv 2.2.39 infinite loop).
# ============================================================

@test "deleted-cwd: returns immediately without looping when PWD is a dot" {
    # PWD becomes a dot when the shell's working directory has been deleted.
    # Walking to its parent does not shorten it, causing a 100% CPU loop without a guard.
    local doomed="$BATS_TEST_TMPDIR/doomed"
    mkdir -p "$doomed"

    run timeout 10 zsh -c "
        cd '$doomed' && rmdir '$doomed'
        export GOENV_ROOT='$GOENV_ROOT'
        exec zsh '$GOENV_WRAPPER'
    "
    # An exit status other than timeout's 124 means the loop did not hang.
    [ "$status" -ne 124 ]
    [[ "$output" == *"cwd が削除されています"* ]]
}
