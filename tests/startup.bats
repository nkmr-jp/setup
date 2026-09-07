#!/usr/bin/env bats
# Shell startup smoke tests
#
# init.zsh is the interactive login shell startup path, so a failure breaks every terminal.
# Zsh runtime errors, such as invalid glob qualifiers, can abort startup midway
# while making it look as if the shell simply started faster.
# Verify that startup completes without errors and all required features are available.
#
# Load the real user's ~/.zprofile, which sets HOMEBREW_PREFIX and PATH.
# These tests depend on the machine environment; skip when prerequisites are absent.

setup() {
    REPO="${BATS_TEST_DIRNAME}/.."
    ZD="$BATS_TEST_TMPDIR/zdotdir"
    mkdir -p "$ZD"
    export ZSH_CACHE_DIR="$BATS_TEST_TMPDIR/cache"

    printf '%s\n' '[[ -f "$HOME/.zshenv" ]] && source "$HOME/.zshenv"' > "$ZD/.zshenv"
    printf '%s\n' '[[ -f "$HOME/.zprofile" ]] && source "$HOME/.zprofile"' > "$ZD/.zprofile"
    {
        printf 'SETUP_DIR=%s\n' "${REPO:A}"
        printf '%s\n' 'source "$SETUP_DIR/zsh/init.zsh"'
    } > "$ZD/.zshrc"
}

# Remove startup noise and retain only the output needed for assertions.
# - Remove iTerm2 OSC sequences (ESC ] ... BEL), including the terminator.
#   Removing BEL first would lose the boundary and consume subsequent output.
# - The diagnostic zshexit hook in init.zsh always prints one line on exit.
_strip_noise() {
    sed $'s/\x1b\][^\x07]*\x07//g' | tr -d '\a\r' | grep -av '^\[zshexit\]'
}

# Start an interactive login shell, run the command, and return only stderr.
start_shell_stderr() {
    ZDOTDIR="$ZD" ZSH_CACHE_DIR="$ZSH_CACHE_DIR" \
        timeout 120 zsh -l -i -c "${1:-true}" 2>&1 >/dev/null | _strip_noise
}

# Start an interactive login shell, run the command, and return only stdout.
start_shell_stdout() {
    ZDOTDIR="$ZD" ZSH_CACHE_DIR="$ZSH_CACHE_DIR" \
        timeout 120 zsh -l -i -c "$1" 2>/dev/null | _strip_noise
}

@test "startup: starts without errors" {
    run start_shell_stderr
    [ "$status" -eq 0 ]
    # Allow only the known noise from starting zsh -i without a TTY.
    local noise='can.t change option: zle'
    local rest
    rest="$(printf '%s\n' "$output" | grep -avE "$noise" | grep -av '^$' || true)"
    [ -z "$rest" ]
}

@test "startup: completes without aborting midway" {
    # Variables set at the end of init.zsh confirm that startup reached the end.
    run start_shell_stdout 'print -r -- "${BUN_INSTALL:-未設定}"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"/.bun"* ]]
}

@test "startup: loads the zsh modules" {
    # Check representative functions from gwt.zsh, goenv.zsh, cache.zsh, and iterm2.zsh.
    run start_shell_stdout 'for f in gwt _goenv_set_paths _zsh_cache_source _iterm2_precmd; do
        print -r -- "$f=${functions[$f]:+ok}"
    done'
    [ "$status" -eq 0 ]
    [[ "$output" == *"gwt=ok"* ]]
    [[ "$output" == *"_goenv_set_paths=ok"* ]]
    [[ "$output" == *"_zsh_cache_source=ok"* ]]
    [[ "$output" == *"_iterm2_precmd=ok"* ]]
}

@test "startup: enables the completion system" {
    run start_shell_stdout 'print -r -- "${_comps[git]:-未登録}"'
    [ "$status" -eq 0 ]
    [ "$output" = "_git" ]
}

@test "startup: contains no duplicate PATH entries" {
    # Apply typeset -U to the scalar PATH as well as the array;
    # otherwise export PATH="X:$PATH" additions are not deduplicated.
    run start_shell_stdout 'u=(${(u)path}); print -r -- $(( $#path - $#u ))'
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "startup: includes anyenv shims in PATH" {
    command -v anyenv >/dev/null || skip "anyenv が無い"
    run start_shell_stdout 'print -l $path'
    [ "$status" -eq 0 ]
    [[ "$output" == *"/.anyenv/envs/pyenv/shims"* ]]
}

# ============================================================
# Verify that caching actually works.
# ============================================================

@test "cache: creates a cache during startup" {
    command -v anyenv >/dev/null || skip "anyenv が無い"
    start_shell_stderr >/dev/null
    [ -s "$ZSH_CACHE_DIR/anyenv-init.zsh" ]
}

@test "cache: does not regenerate the cache on the second startup" {
    command -v anyenv >/dev/null || skip "anyenv が無い"
    start_shell_stderr >/dev/null
    local before
    before="$(stat -f '%m' "$ZSH_CACHE_DIR/anyenv-init.zsh")"
    sleep 1
    start_shell_stderr >/dev/null
    local after
    after="$(stat -f '%m' "$ZSH_CACHE_DIR/anyenv-init.zsh")"
    [ "$before" = "$after" ]
}

@test "cache: puts uv completions in fpath instead of evaluating them" {
    command -v uv >/dev/null || skip "uv が無い"
    start_shell_stderr >/dev/null
    [ -s "$ZSH_CACHE_DIR/completions/_uv" ]
    # Verify that compinit finds the script in fpath and registers its compdef.
    run start_shell_stdout 'print -r -- "${_comps[uv]:-未登録}"'
    [ "$output" = "_uv" ]
    # Verify that the function body remains unloaded at startup (lazy loading).
    run start_shell_stdout 'print -r -- "${functions[_uv__run_commands]:+実体化済み}"'
    [ -z "$output" ]
}
