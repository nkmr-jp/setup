#!/usr/bin/env sh
# cmux サイドバーに pane 別の Claude Code 状態 pill を反映する。
# Claude Code の hooks (SessionStart / UserPromptSubmit / Stop / SessionEnd / Notification)
# から呼ばれる薄いラッパー。
#
# Usage: claude-status-hook.sh <running|idle|awaiting|clear>
# stdin に JSON が流れてくるが本スクリプトでは未使用。

exec >/dev/null 2>&1

state="$1"
[ -n "$CMUX_PANEL_ID" ] || exit 0
command -v cmux >/dev/null 2>&1 || exit 0

key="claude_${CMUX_PANEL_ID}"

case "$state" in
  running)  cmux set-status "$key" Running  --icon bolt.fill     --color '#4C8DFF' ;;
  idle)     cmux set-status "$key" Idle     --icon moon.zzz.fill ;;
  awaiting) cmux set-status "$key" Awaiting --icon bell.fill     --color '#FF9500' ;;
  clear)    cmux clear-status "$key" ;;
esac
