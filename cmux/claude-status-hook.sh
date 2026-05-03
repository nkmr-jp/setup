#!/usr/bin/env sh
# cmux サイドバーの cwd pill のアイコンを Claude Code の状態に合わせて切り替える。
# UserPromptSubmit -> running, Notification -> awaiting の 2 つだけを扱い、
# state file が無い (= 初期状態) のときは zsh 側で folder アイコンに戻る。
#
# Usage: claude-status-hook.sh <running|awaiting>
#
# 状態は ${TMPDIR}/cmux-pane-state/<panel-id> に保存し、zsh 側の precmd/chpwd でも
# 同じアイコンを再描画できるようにする（state→icon の写像は両側で同期）。
#
# 並列・近接して呼ばれた hook が cmux daemon で逆順に処理されると古い state で
# pill が固定化するため、event 時刻 (perl で nanosecond) を各 hook が起動直後に
# 記録し、pane 単位の lock 内で「自分の時刻が直近に適用された時刻より新しい場合
# にのみ set-status する」ことで event 順序を厳密に保つ。

exec >/dev/null 2>&1

state="$1"
[ -n "$CMUX_PANEL_ID" ] || exit 0
command -v cmux >/dev/null 2>&1 || exit 0

case "$state" in
  running)  icon=bolt.fill;  color='#4C8DFF' ;;
  awaiting) icon=bell.fill;  color='#FF9500' ;;
  *) exit 0 ;;
esac

state_dir="${TMPDIR:-/tmp}/cmux-pane-state"
state_file="$state_dir/$CMUX_PANEL_ID"
time_file="$state_file.time"
lock_dir="$state_file.lock"
key="cwd_${CMUX_PANEL_ID}"

mkdir -p "$state_dir" 2>/dev/null

# Lock contention 前に event 時刻を採取する (lock 取得順 ≠ event 順序を補正)。
my_time=$(perl -MTime::HiRes -e 'printf "%d", Time::HiRes::time*1e9' 2>/dev/null)
[ -n "$my_time" ] || my_time=$(($(date +%s) * 1000000000))

# Per-pane mutex (mkdir は POSIX で atomic)。1 秒以上経過したロックは stale。
attempts=0
while ! mkdir "$lock_dir" 2>/dev/null; do
  attempts=$((attempts + 1))
  if [ "$attempts" -gt 50 ]; then
    rm -rf "$lock_dir" 2>/dev/null
    attempts=0
  fi
  sleep 0.02
done
trap 'rmdir "$lock_dir" 2>/dev/null' EXIT INT TERM HUP

# 既に新しい event が反映済みなら自分は古いので set-status をスキップ。
existing_time=$(cat "$time_file" 2>/dev/null)
[ -n "$existing_time" ] || existing_time=0
is_newer=$(awk -v a="$my_time" -v b="$existing_time" 'BEGIN{print (a+0 > b+0) ? 1 : 0}')
[ "$is_newer" = 1 ] || exit 0

printf '%s\n' "$my_time" > "$time_file"
printf '%s\n' "$state" > "$state_file"

# 旧バージョンの per-pane Claude pill が残っていたら回収しておく。
cmux clear-status "claude_${CMUX_PANEL_ID}" 2>/dev/null

cmux set-status "$key" "$(basename "$PWD")" --icon "$icon" --color "$color"
