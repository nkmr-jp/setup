#!/usr/bin/env bats

setup() {
    ROOT="$BATS_TEST_DIRNAME/.."
    FIXTURE_HOME="$BATS_TEST_TMPDIR/home.with regex[chars] and spaces"
    MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin"
    mkdir -p "$FIXTURE_HOME" "$MOCK_BIN"
}

@test "signing generator resolves its symlinked checkout path and current GitHub owner" {
    checkout="$BATS_TEST_TMPDIR/checkout with \"quotes\""
    mkdir -p "$checkout/bin" "$FIXTURE_HOME/bin"
    cp "$ROOT/bin/gen-git-signing-config.sh" "$checkout/bin/generate"
    printf '[commit]\n    gpgsign = true\n' > "$checkout/gitconfig-signing"
    ln -s "$checkout/bin/generate" "$FIXTURE_HOME/bin/generate"
    cat > "$MOCK_BIN/gh" <<'SH'
#!/bin/sh
case "$1 $2" in
    'api user') echo public-owner ;;
    'repo list') [ "$3" = public-owner ] || exit 3; echo demo ;;
    *) exit 4 ;;
esac
SH
    chmod +x "$MOCK_BIN/gh"
    run env HOME="$FIXTURE_HOME" PATH="$MOCK_BIN:$PATH" bash "$FIXTURE_HOME/bin/generate"
    [ "$status" -eq 0 ]
    run git config --file "$FIXTURE_HOME/.gitconfig-signing-includes" --get-regexp '^includeIf\..*\.path$'
    [ "$status" -eq 0 ]
    [[ "$output" == *"$checkout/gitconfig-signing"* ]]
    [[ "$output" == *'public-owner/demo/'* ]]
}
