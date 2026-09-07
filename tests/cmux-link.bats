#!/usr/bin/env bats

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../cmux/link.sh"
    SOURCE_DIR="$(cd "$BATS_TEST_DIRNAME/../cmux" && pwd -P)"
    FIXTURE_HOME="$BATS_TEST_TMPDIR/isolated home"
    CONFIG_DIR="$BATS_TEST_TMPDIR/config with spaces/cmux"
    mkdir -p "$FIXTURE_HOME"
    echo untouched > "$FIXTURE_HOME/sentinel"
}

run_link() {
    run env HOME="$FIXTURE_HOME" CMUX_CONFIG_HOME="$CONFIG_DIR" sh "$SCRIPT" "$@"
}

@test "dry-run and failed check do not create targets or alter HOME" {
    run_link --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"LINK $CONFIG_DIR/cmux.json"* ]]
    [ ! -e "$CONFIG_DIR" ]
    run_link --check
    [ "$status" -eq 1 ]
    [ ! -e "$CONFIG_DIR" ]
    [ ! -e "$FIXTURE_HOME/.config" ]
    [ "$(cat "$FIXTURE_HOME/sentinel")" = untouched ]
}

@test "install links both files individually and check succeeds" {
    run_link --install
    [ "$status" -eq 0 ]
    [ -d "$CONFIG_DIR" ]
    [ ! -L "$CONFIG_DIR" ]
    [ "$(readlink "$CONFIG_DIR/cmux.json")" = "$SOURCE_DIR/cmux.json" ]
    [ "$(readlink "$CONFIG_DIR/sidebar-cwd.zsh")" = "$SOURCE_DIR/sidebar-cwd.zsh" ]
    run_link --check
    [ "$status" -eq 0 ]
    [ ! -e "$FIXTURE_HOME/.config" ]
}

@test "repeated install preserves correct links without additional backups" {
    run_link --install
    [ "$status" -eq 0 ]
    before=$(ls -di "$CONFIG_DIR/cmux.json" "$CONFIG_DIR/sidebar-cwd.zsh")
    run_link --install
    [ "$status" -eq 0 ]
    after=$(ls -di "$CONFIG_DIR/cmux.json" "$CONFIG_DIR/sidebar-cwd.zsh")
    [ "$before" = "$after" ]
    [[ "$output" != *BACKUP* ]]
    [ "$(find "$CONFIG_DIR" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" -eq 2 ]
}

@test "install backs up an existing file and a broken old-repo link" {
    mkdir -p "$CONFIG_DIR"
    echo user-setting > "$CONFIG_DIR/cmux.json"
    ln -s "$BATS_TEST_TMPDIR/old-repo/sidebar-cwd.zsh" "$CONFIG_DIR/sidebar-cwd.zsh"
    run_link --dry-run
    [ "$status" -eq 0 ]
    [ "$(cat "$CONFIG_DIR/cmux.json")" = user-setting ]
    [ "$(readlink "$CONFIG_DIR/sidebar-cwd.zsh")" = "$BATS_TEST_TMPDIR/old-repo/sidebar-cwd.zsh" ]
    run_link --install
    [ "$status" -eq 0 ]
    config_backups=("$CONFIG_DIR"/cmux.json.backup.*)
    sidebar_backups=("$CONFIG_DIR"/sidebar-cwd.zsh.backup.*)
    [ "${#config_backups[@]}" -eq 1 ]
    [ "${#sidebar_backups[@]}" -eq 1 ]
    [ "$(cat "${config_backups[0]}")" = user-setting ]
    [ "$(readlink "${sidebar_backups[0]}")" = "$BATS_TEST_TMPDIR/old-repo/sidebar-cwd.zsh" ]
    run_link --check
    [ "$status" -eq 0 ]
}

@test "an existing directory at a file target is preserved in backup" {
    mkdir -p "$CONFIG_DIR/cmux.json"
    echo keep > "$CONFIG_DIR/cmux.json/user-data"
    run_link --install
    [ "$status" -eq 0 ]
    backups=("$CONFIG_DIR"/cmux.json.backup.*)
    [ "$(cat "${backups[0]}/user-data")" = keep ]
    [ -L "$CONFIG_DIR/cmux.json" ]
}

@test "missing source fails before creating targets or backups" {
    copied="$BATS_TEST_TMPDIR/incomplete source"
    mkdir -p "$copied"
    cp "$SCRIPT" "$copied/link.sh"
    cp "$SOURCE_DIR/cmux.json" "$copied/cmux.json"
    run env HOME="$FIXTURE_HOME" CMUX_CONFIG_HOME="$CONFIG_DIR" sh "$copied/link.sh" --install
    [ "$status" -eq 2 ]
    [ ! -e "$CONFIG_DIR" ]
}

@test "default location uses isolated HOME and invalid options do not write" {
    run env HOME="$FIXTURE_HOME" CMUX_CONFIG_HOME='' sh "$SCRIPT" --install
    [ "$status" -eq 0 ]
    [ -L "$FIXTURE_HOME/.config/cmux/cmux.json" ]
    run_link --unknown
    [ "$status" -eq 2 ]
    run env HOME="$FIXTURE_HOME" CMUX_CONFIG_HOME=relative sh "$SCRIPT" --install
    [ "$status" -eq 2 ]
    [ ! -e "$CONFIG_DIR" ]
    [ "$(cat "$FIXTURE_HOME/sentinel")" = untouched ]
}

@test "a config directory linked to the source is rejected before moving source files" {
    copied="$BATS_TEST_TMPDIR/copied source"
    mkdir -p "$copied" "$(dirname "$CONFIG_DIR")"
    cp "$SCRIPT" "$SOURCE_DIR/cmux.json" "$SOURCE_DIR/sidebar-cwd.zsh" "$copied/"
    ln -s "$copied" "$CONFIG_DIR"
    run env HOME="$FIXTURE_HOME" CMUX_CONFIG_HOME="$CONFIG_DIR" sh "$copied/link.sh" --install
    [ "$status" -eq 2 ]
    [[ "$output" == *"must not be the source directory"* ]]
    [ -f "$copied/cmux.json" ]
    [ ! -L "$copied/cmux.json" ]
    cmp "$copied/cmux.json" "$SOURCE_DIR/cmux.json"
    cmp "$copied/sidebar-cwd.zsh" "$SOURCE_DIR/sidebar-cwd.zsh"
}
