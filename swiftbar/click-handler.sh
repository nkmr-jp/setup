#!/usr/bin/env zsh
# SwiftBar から呼ばれるクリックハンドラ。menu item 内に長い shell= 構文を埋めると
# SwiftBar の引数パースで取りこぼしが起きやすいので、ここに集約する。
#
# 使い方: click-handler.sh <mode> <identifier> [workspace_id]
#   mode = cmux   : identifier = panel (= surface) id, workspace_id = 任意
#   mode = bundle : identifier = macOS bundle id
#   mode = finder : identifier = path

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
esac

exit 1
