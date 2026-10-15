#!/usr/bin/env bats
# zsh/redact-env.zsh test suite.
# Every case runs under env -i with a temporary HOME and a dummy token, so the
# real environment never reaches the output even if a wrapper is broken.

ROOT="${BATS_TEST_DIRNAME}/.."
DUMMY="dummyTok3nValue9876543210xyz"
REAL_FILTER="${REAL_FILTER:-$HOME/ghq/github.com/nkmr-jp/agent-settings/claude/bin/redact-bash-output.py}"

setup() {
    export TEST_HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$TEST_HOME"
    # Fake filter: masks the dummy token and records that it ran.
    FAKE_FILTER="$BATS_TEST_TMPDIR/fake-filter.py"
    cat > "$FAKE_FILTER" <<EOF
import sys
open("$BATS_TEST_TMPDIR/filtered", "a").write("x")
sys.stdout.write(sys.stdin.read().replace("$DUMMY", "[REDACTED]"))
EOF
    FILTER="$FAKE_FILTER"
}

# Runs $1 in an interactive zsh with the module loaded.
zrun() {
    run /usr/bin/env -i HOME="$TEST_HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
        MY_SERVICE_TOKEN="$DUMMY" REDACT_ENV_FILTER="$FILTER" ROOT="$ROOT" \
        zsh -f -i -c 'source "$ROOT/zsh/redact-env.zsh"; '"$1"
}

filtered() { [ -f "$BATS_TEST_TMPDIR/filtered" ]; }

@test "env with no command is filtered" {
    zrun 'env'
    [ "$status" -eq 0 ]
    [[ "$output" == *"MY_SERVICE_TOKEN=[REDACTED]"* ]]
    [[ "$output" != *"$DUMMY"* ]]
}

@test "env with options or assignments but no command is filtered" {
    zrun 'env -u HOME FOO=1'
    [[ "$output" == *"FOO=1"* ]]
    [[ "$output" != *"$DUMMY"* ]]
}

@test "env FOO=1 cmd runs cmd unfiltered with its exit status" {
    zrun 'env FOO=1 sh -c '\''echo "$FOO"; exit 3'\'''
    [ "$status" -eq 3 ]
    [ "$output" = "1" ]
    ! filtered
}

@test "printenv is filtered" {
    zrun 'printenv MY_SERVICE_TOKEN'
    [ "$status" -eq 0 ]
    [ "$output" = "[REDACTED]" ]
}

@test "printenv keeps the exit status of a missing variable" {
    zrun 'printenv NO_SUCH_VAR'
    [ "$status" -eq 1 ]
}

@test "ps with BSD e or -E is filtered; other ps is not" {
    zrun 'ps -o pid= -p $$ >/dev/null'
    ! filtered
    zrun 'ps eww -p $$ >/dev/null'
    filtered
}

@test "pgrep -f / -l is filtered and keeps the no-match status" {
    zrun 'pgrep -x no-such-process-xyz'
    [ "$status" -eq 1 ]
    ! filtered
    zrun 'pgrep -fl no-such-process-xyz'
    [ "$status" -eq 1 ]
    filtered
}

@test "missing filter fails closed" {
    FILTER="$BATS_TEST_TMPDIR/missing.py"
    zrun 'env'
    [ "$status" -eq 1 ]
    [[ "$output" != *"$DUMMY"* ]]
    [[ "$output" == *"filter not found"* ]]
}

@test "builtin listing forms are rewritten to pipe through redact" {
    zrun 'for l in "set" "export -p" "typeset -x" "declare" "  set | grep FOO"; do
        _redact_env_rewrite_line "$l" && print -r -- "$REPLY"; done'
    [ "${lines[0]}" = "set | redact" ]
    [ "${lines[1]}" = "export -p | redact" ]
    [ "${lines[2]}" = "typeset -x | redact" ]
    [ "${lines[3]}" = "declare | redact" ]
    [ "${lines[4]}" = "  set | redact | grep FOO" ]
}

@test "the accept-line widget submits the rewritten line" {
    zrun 'zle() { print -r -- "$1 $BUFFER" }; BUFFER="export -p"; _redact_env_accept_line'
    [ "$output" = ".accept-line export -p | redact" ]
}

@test "builtin forms with arguments are not rewritten" {
    zrun 'for l in "export FOO=1" "typeset x=1" "set -- a b" "set -o" "typeset -p FOO"; do
        _redact_env_rewrite_line "$l" && print -r -- "rewritten: $l"; done; true'
    [ -z "$output" ]
}

@test "typeset and set at top level still work" {
    zrun 'typeset x=1; set -- a b; f() { typeset y=2 }; f; print -r -- "$x $1 $2 ${y-unset}"'
    [ "$output" = "1 a b unset" ]
}

@test "non-interactive zsh gets the wrappers but not the accept-line widget" {
    run /usr/bin/env -i HOME="$TEST_HOME" PATH=/usr/bin:/bin ROOT="$ROOT" \
        MY_SERVICE_TOKEN="$DUMMY" REDACT_ENV_FILTER="$FILTER" \
        zsh -f -c 'source "$ROOT/zsh/redact-env.zsh"; whence -w env redact _redact_env_accept_line; env'
    [ "$status" -eq 0 ]
    [[ "$output" == *"env: function"* ]]
    [[ "$output" == *"_redact_env_accept_line: none"* ]]
    [[ "$output" == *"MY_SERVICE_TOKEN=[REDACTED]"* ]]
    [[ "$output" != *"$DUMMY"* ]]
}

# Runs $1 in a non-interactive /bin/bash (3.2 on macOS) with set -u, loading the
# wrappers through BASH_ENV as agents' bash does.
brun() {
    run /usr/bin/env -i HOME="$TEST_HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
        MY_SERVICE_TOKEN="$DUMMY" REDACT_ENV_FILTER="$FILTER" BASH_ENV="$ROOT/shell/redact-env.sh" \
        /bin/bash -uc "$1"
}

@test "bash wrappers filter the same forms and keep exit statuses" {
    brun 'env'
    [ "$status" -eq 0 ]
    [[ "$output" == *"MY_SERVICE_TOKEN=[REDACTED]"* ]]
    [[ "$output" != *"$DUMMY"* ]]
    brun 'printenv NO_SUCH_VAR'
    [ "$status" -eq 1 ]
    rm -f "$BATS_TEST_TMPDIR/filtered"
    brun 'env FOO=1 sh -c '\''echo "$FOO"; exit 3'\'''
    [ "$status" -eq 3 ]
    [ "$output" = "1" ]
    brun 'ps -o pid= -p $$ >/dev/null; pgrep -x no-such-process-xyz'
    [ "$status" -eq 1 ]
    ! filtered
    brun 'pgrep -fl no-such-process-xyz'
    [ "$status" -eq 1 ]
    filtered
}

@test ".zshenv loads the wrappers and safe-chain into non-interactive zsh and bash" {
    mkdir -p "$TEST_HOME/ghq/github.com/nkmr-jp" "$TEST_HOME/.safe-chain/scripts"
    ln -s "$ROOT" "$TEST_HOME/ghq/github.com/nkmr-jp/setup"
    echo 'npm() { echo fake-safe-chain; }' > "$TEST_HOME/.safe-chain/scripts/init-posix.sh"
    run /usr/bin/env -i HOME="$TEST_HOME" PATH=/usr/bin:/bin ZDOTDIR="$ROOT" \
        zsh -c 'whence -w pgrep npm; bash -c "type -t pgrep npm"'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "pgrep: function" ]
    [ "${lines[1]}" = "npm: function" ]
    [ "${lines[2]}" = "function" ]
    [ "${lines[3]}" = "function" ]
}

@test "real filter masks the dummy token" {
    [ -f "$REAL_FILTER" ] || skip "agent-settings is not cloned"
    FILTER="$REAL_FILTER"
    zrun 'env'
    [ "$status" -eq 0 ]
    [[ "$output" == *"MY_SERVICE_TOKEN=[REDACTED]"* ]]
    [[ "$output" != *"$DUMMY"* ]]
}
