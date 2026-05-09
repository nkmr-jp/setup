#!/usr/bin/env zsh
# SwiftBar から呼ばれるクリックハンドラ。menu item 内に長い shell= 構文を埋めると
# SwiftBar の引数パースで取りこぼしが起きやすいので、ここに集約する。
#
# 使い方: click-handler.sh <mode> <identifier>
#   mode = cmux   : identifier = cmux panel id  → cmux focus-panel
#   mode = bundle : identifier = macOS bundle id → open -b
#   mode = finder : identifier = path           → open <path>

mode="${1:-}"
ident="${2:-}"

case "$mode" in
  cmux)
    exec /Applications/cmux.app/Contents/Resources/bin/cmux focus-panel --panel "$ident"
    ;;
  bundle)
    exec /usr/bin/open -b "$ident"
    ;;
  finder)
    exec /usr/bin/open "$ident"
    ;;
esac

exit 1
