#!/usr/bin/env zsh
# xbar から呼ばれるクリックハンドラ。menu item 内に長い bash= 構文を埋めると
# xbar の引数パースで取りこぼしが起きやすいので、ここに集約する。
#
# 使い方: click-handler.sh <mode> <identifier> [workspace_id]
#   mode = cmux   : identifier = panel (= surface) id, workspace_id = 任意
#   mode = bundle : identifier = macOS bundle id
#   mode = finder : identifier = path
#   mode = delete : identifier = session_id (sessions.jsonl から該当行を除去)

mode="${1:-}"
ident="${2:-}"
workspace_id="${3:-}"

CMUX_BUNDLE_ID="com.cmuxterm.app"
CMUX_CLI="${CMUX_BUNDLED_CLI_PATH:-/Applications/cmux.app/Contents/Resources/bin/cmux}"

case "$mode" in
  cmux)
    # 重要: cmux のソケット API (focus-panel など) は cmux 内部のフォーカスを
    # 移すだけで、macOS アプリ自体を前面に上げてくれない。先に `open -b` で
    # アプリを activate する必要がある (claude-notify と同じ知見)。
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
    # メニューバーに古いセッションが残ったときに手動で除去するための入口。
    # データソース解決は xbar 本体スクリプトと同じ規約 (anchor file → fallback)。
    [[ -n "$ident" ]] || exit 1
    command -v jq >/dev/null 2>&1 || exit 1

    ANCHOR="$HOME/.claude/session-monitor/data-dir"
    DATA_DIR=""
    [[ -f "$ANCHOR" ]] && DATA_DIR=$(< "$ANCHOR")
    [[ -z "$DATA_DIR" ]] && DATA_DIR="$HOME/.claude/session-monitor"
    sessions_file="$DATA_DIR/sessions.jsonl"
    [[ -f "$sessions_file" ]] || exit 0

    # update-session.sh と同じ mkdir lock 規約 (1s 超 = stale)。
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

    # xbar に即時再描画を要求 (5s ループでも追従するが UI 反映を早めるため)。
    /usr/bin/open -g "xbar://app.xbarapp.com/refreshPlugin?path=claude-sessions.5s.sh" >/dev/null 2>&1 &
    exit 0
    ;;
esac

exit 1
