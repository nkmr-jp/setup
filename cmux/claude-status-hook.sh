#!/usr/bin/env sh
# cmux サイドバーの cwd pill のアイコンを Claude Code の状態に合わせて切り替える。
# Claude Code の hooks (SessionStart / UserPromptSubmit / Stop / Notification / SessionEnd)
# から呼ばれる薄いラッパー。
#
# Usage: claude-status-hook.sh <running|idle|awaiting|clear>
#
# 状態は ${TMPDIR}/cmux-pane-state/<panel-id> に保存し、zsh 側の precmd/chpwd でも
# 同じアイコンを再描画できるようにする（state→icon の写像は両側で同期）。

exec >/dev/null 2>&1

state="$1"
[ -n "$CMUX_PANEL_ID" ] || exit 0
command -v cmux >/dev/null 2>&1 || exit 0

state_dir="${TMPDIR:-/tmp}/cmux-pane-state"
state_file="$state_dir/$CMUX_PANEL_ID"
key="cwd_${CMUX_PANEL_ID}"

case "$state" in
  running)    icon=bolt.fill; color='#4C8DFF' ;;
  awaiting)   icon=bell.fill; color='#FF9500' ;;
  idle|clear) icon=pause.circle; color=''     ;;
  *) exit 0 ;;
esac

if [ "$state" = clear ]; then
  rm -f "$state_file"
else
  mkdir -p "$state_dir" 2>/dev/null
  printf '%s\n' "$state" > "$state_file"
fi

# 旧バージョンの per-pane Claude pill が残っていたら回収しておく。
cmux clear-status "claude_${CMUX_PANEL_ID}" 2>/dev/null

set -- --icon "$icon"
[ -n "$color" ] && set -- "$@" --color "$color"
cmux set-status "$key" "$(basename "$PWD")" "$@"
