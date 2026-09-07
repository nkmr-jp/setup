#!/usr/bin/env zsh
# Click handler invoked by xbar. Long bash= expressions embedded in menu items
# are prone to xbar argument parsing errors, so keep the handling here.
#
# Usage: click-handler.sh <mode> <identifier> [workspace_id]
#   mode = cmux   : identifier = panel (= surface) id, workspace_id = optional
#   mode = bundle : identifier = macOS bundle id
#   mode = finder : identifier = path
#   mode = delete : identifier = session_id (remove its line from sessions.jsonl)

mode="${1:-}"
ident="${2:-}"
workspace_id="${3:-}"

CMUX_BUNDLE_ID="com.cmuxterm.app"
CMUX_CLI="${CMUX_BUNDLED_CLI_PATH:-/Applications/cmux.app/Contents/Resources/bin/cmux}"

case "$mode" in
  cmux)
    # The cmux socket API (focus-panel, etc.) only changes focus inside cmux;
    # it does not bring the macOS app to the foreground. Activate the app first
    # with `open -b`, as in claude-notify.
    /usr/bin/open -b "$CMUX_BUNDLE_ID"
    [[ -n "$workspace_id" ]] && "$CMUX_CLI" select-workspace --workspace "$workspace_id" >/dev/null 2>&1
    exec "$CMUX_CLI" focus-panel --panel "$ident"
    ;;
  bundle)
    exec /usr/bin/open -b "$ident"
    ;;
  finder)
    exec /usr/bin/open "$ident"
    ;;
  delete)
    # Allow manual removal of stale sessions left in the menu bar.
    # Resolve the data source using the same anchor-file -> fallback rule as the main script.
    [[ -n "$ident" ]] || exit 1
    command -v jq >/dev/null 2>&1 || exit 1

    ANCHOR="$HOME/.claude/session-monitor/data-dir"
    DATA_DIR=""
    [[ -f "$ANCHOR" ]] && DATA_DIR=$(< "$ANCHOR")
    [[ -z "$DATA_DIR" ]] && DATA_DIR="$HOME/.claude/session-monitor"
    sessions_file="$DATA_DIR/sessions.jsonl"
    [[ -f "$sessions_file" ]] || exit 0

    # Use the same mkdir lock convention as update-session.sh (stale after 1 second).
    lock_dir="$sessions_file.lock"
    attempts=0
    while ! mkdir "$lock_dir" 2>/dev/null; do
      attempts=$((attempts + 1))
      if (( attempts > 50 )); then
        rm -rf "$lock_dir" 2>/dev/null
        attempts=0
      fi
      sleep 0.02
    done
    trap 'rm -rf "$lock_dir" 2>/dev/null' EXIT INT TERM HUP

    tmp_file="$sessions_file.tmp"
    jq -c --arg sid "$ident" 'select(.session_id != $sid)' "$sessions_file" > "$tmp_file" 2>/dev/null || : > "$tmp_file"
    mv "$tmp_file" "$sessions_file"

    # Request an immediate xbar redraw instead of waiting for the 5-second loop.
    /usr/bin/open -g "xbar://app.xbarapp.com/refreshPlugin?path=claude-sessions.5s.sh" >/dev/null 2>&1 &
    exit 0
    ;;
esac

exit 1
