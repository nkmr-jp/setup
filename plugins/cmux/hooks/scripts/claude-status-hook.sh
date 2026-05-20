#!/usr/bin/env sh
# cmux サイドバーの cwd pill のアイコンを Claude Code の状態に合わせて切り替える。
# UserPromptSubmit / PreToolUse / PostToolUse -> running, Notification -> awaiting,
# Stop -> idle (応答完了・次の入力待ち), SessionStart / SessionEnd -> clear (folder
# アイコンに戻し state file を削除) を扱い、state file が無い (= 初期状態) のとき
# は zsh 側でも folder アイコンに戻る。PostToolUse は AskUserQuestion 回答や
# permission 承認後に awaiting -> running を確実に戻すために必要。SessionStart の
# clear は前セッションがクラッシュ等で SessionEnd を逃した場合の stale state を
# 掃除する。
#
# Usage: claude-status-hook.sh <running|awaiting|idle|clear>
#
# 状態は ${TMPDIR}/cmux-pane-state/<panel-id> に保存し、zsh 側の precmd/chpwd でも
# 同じアイコンを再描画できるようにする（state→icon の写像は両側で同期）。
#
# cmux 0.61+ は子プロセスに CMUX_PANEL_ID 等を継承しなくなったため、空の場合は
# stdin の session_id を cache key にして cmux RPC から focused surface の UUID を
# 取得・保存する。pill key は `cwd_<UUID>` 形式 (zsh 側 sidebar-cwd.zsh の sweeper
# が surface.list の `id` フィールドと照合するため、ref 形式 `surface:N` ではなく
# UUID でなければ即 sweep されて pill が消える)。
# 取得経路: identify -> focused.workspace_ref -> workspace.list で workspace UUID
# -> surface.list で focused:true の surface UUID。
# SessionStart / UserPromptSubmit のタイミングでだけ取得し、PreToolUse 等の高頻度
# hook では cache だけ参照する (focused は cmux 全体で前面なので、ユーザー操作
# 直後でないと別ペインを掴む可能性があるため)。SessionEnd で cache も掃除する。
#
# 並列・近接して呼ばれた hook が cmux daemon で逆順に処理されると古い state で
# pill が固定化するため、event 時刻 (perl で nanosecond) を各 hook が起動直後に
# 記録し、pane 単位の lock 内で「自分の時刻が直近に適用された時刻より新しい場合
# にのみ state file を更新する」ことで最新 event を判定する。clear (SessionEnd)
# も同じ機構を共有しないと、SessionEnd と並走した古い running/awaiting hook が
# 後勝ちして pill を上書きしてしまうため、clear も同じ lock/timestamp を経由する。
#
# `cmux set-status` の socket I/O は lock を解放した後に実行する (PreToolUse の
# 並列発火で daemon 応答待ちが lock を握り続け、後続 hook が無駄に待たされる
# のを避けるため)。並列 event の cmux 配信順は厳密でなくなるが、PreToolUse 等
# で頻繁に最新 state へ上書きされるので、ずれた最終状態は直近の遷移で解消する。

exec >/dev/null 2>&1

state="$1"
command -v cmux >/dev/null 2>&1 || exit 0

case "$state" in
  running)  icon=bolt.fill;  color='#4C8DFF' ;;
  awaiting) icon=bell.fill;  color='#FF9500' ;;
  idle)     icon=pause.fill; color='#8E8E93' ;;
  clear)    icon=folder ;;
  *) exit 0 ;;
esac

state_dir="${TMPDIR:-/tmp}/cmux-pane-state"
mkdir -p "$state_dir" 2>/dev/null

# stdin の JSON を一時ファイルに保存して session_id / hook_event_name を抽出する。
# CMUX_PANEL_ID fallback の cache key と SessionEnd 時の cache 掃除に使う。
input_file="$state_dir/hook-input-$$"
trap 'rm -f "$input_file"' EXIT INT TERM HUP
cat > "$input_file" 2>/dev/null

session_id=""
hook_event=""
if command -v jq >/dev/null 2>&1; then
  session_id=$(jq -r '.session_id // empty' < "$input_file" 2>/dev/null)
  hook_event=$(jq -r '.hook_event_name // empty' < "$input_file" 2>/dev/null)
fi

# CMUX_PANEL_ID が継承されない cmux 0.61+ 対策: session_id 別 cache + cmux identify。
# 初回 SessionStart / UserPromptSubmit で identify を呼び、surface_ref を cache する。
# 以降の高頻度 hook は cache hit のみで済ませて identify の CLI コストを抑える。
panel_cache=""
if [ -z "${CMUX_PANEL_ID:-}" ] && [ -n "$session_id" ]; then
  panel_cache="$state_dir/session-${session_id}.panel"

  if { [ "$hook_event" = "SessionStart" ] || [ "$hook_event" = "UserPromptSubmit" ]; } \
     && [ "${TERM_PROGRAM:-}" = "ghostty" ] \
     && [ "${__CFBundleIdentifier:-}" = "com.cmuxterm.app" ] \
     && command -v jq >/dev/null 2>&1; then
    cmux_cli="${CMUX_BUNDLED_CLI_PATH:-/Applications/cmux.app/Contents/Resources/bin/cmux}"
    if [ -x "$cmux_cli" ]; then
      # 1. identify で focused workspace_ref (workspace:N) を取得
      ws_ref=$("$cmux_cli" identify --no-caller 2>/dev/null \
        | jq -r '.focused.workspace_ref // empty' 2>/dev/null)
      if [ -n "$ws_ref" ]; then
        # 2. workspace.list で ref -> UUID 変換
        ws_id=$("$cmux_cli" rpc workspace.list "{}" 2>/dev/null \
          | jq -r --arg ref "$ws_ref" \
            '.workspaces[]? | select(.ref == $ref) | .id // empty' 2>/dev/null \
          | head -n 1)
        if [ -n "$ws_id" ]; then
          # 3. surface.list で focused:true の surface UUID を取得 (= zsh 側
          #    sidebar-cwd.zsh が pill key として使う UUID と一致)
          new_panel=$("$cmux_cli" rpc surface.list \
              "{\"workspace_id\":\"$ws_id\"}" 2>/dev/null \
            | jq -r '.surfaces[]? | select(.focused == true) | .id // empty' 2>/dev/null \
            | head -n 1)
          [ -n "$new_panel" ] && printf '%s\n' "$new_panel" > "$panel_cache"
        fi
      fi
    fi
  fi

  if [ -f "$panel_cache" ]; then
    CMUX_PANEL_ID=$(cat "$panel_cache" 2>/dev/null)
    # ref 形式 (surface:N) の旧 cache が残っていたら捨てる。UUID は `:` を含まない。
    case "$CMUX_PANEL_ID" in
      *:*) CMUX_PANEL_ID=""; rm -f "$panel_cache" ;;
    esac
  fi
fi

[ -n "${CMUX_PANEL_ID:-}" ] || exit 0

# SessionEnd は Claude Code 側に時間制約があり (1 秒未満)、lock 競合で sleep
# すると "Hook cancelled" として打ち切られる。clear だけは即時に親へ制御を
# 返し、実処理は detach した子プロセスで race-safe lock を取って実行する。
# 親 session が消えても cmux daemon への set-status は子プロセスから完了する。
# CMUX_PANEL_ID は環境変数で子プロセスに引き継ぐ (stdin は /dev/null になる)。
if [ "$state" = clear ] && [ -z "${CMUX_STATUS_HOOK_BG:-}" ]; then
  # SessionEnd では panel cache も掃除しておく (次回 SessionStart で再取得)。
  [ "$hook_event" = "SessionEnd" ] && [ -n "$panel_cache" ] && rm -f "$panel_cache"
  CMUX_STATUS_HOOK_BG=1 CMUX_PANEL_ID="$CMUX_PANEL_ID" \
    nohup "$0" "$@" </dev/null >/dev/null 2>&1 &
  exit 0
fi

# basename "$PWD" が空 (PWD 未設定など) になると cmux set-status が空 value で
# 失敗し、pill が前回値のまま固定化したり stale 判定で消えたりする。空のとき
# は "." に fallback して pill 名が消えないようにする。
label=$(basename "$PWD" 2>/dev/null)
[ -n "$label" ] || label="."

state_file="$state_dir/$CMUX_PANEL_ID"
time_file="$state_file.time"
lock_dir="$state_file.lock"
key="cwd_${CMUX_PANEL_ID}"

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
trap 'rmdir "$lock_dir" 2>/dev/null; rm -f "$input_file"' EXIT INT TERM HUP

# 既に新しい event が反映済みなら自分は古いので set-status をスキップ。
existing_time=$(cat "$time_file" 2>/dev/null)
[ -n "$existing_time" ] || existing_time=0
is_newer=$(awk -v a="$my_time" -v b="$existing_time" 'BEGIN{print (a+0 > b+0) ? 1 : 0}')
[ "$is_newer" = 1 ] || exit 0

# 自分の時刻を記録 (これ以降に届く古い hook をブロックする)。次の SessionStart
# 以降に飛んでくる新しい event は my_time > 既存値で正しく上書きできる。
printf '%s\n' "$my_time" > "$time_file"

# state file 更新までを lock 内で完結させる。PreToolUse は毎ツール呼び出しで
# 発火するため、既に同じ state なら state file 書き込みも cmux 呼び出しも省く。
existing_state=$(cat "$state_file" 2>/dev/null)
if [ "$state" = clear ]; then
  # SessionEnd: state_file は削除して folder アイコンに戻す。time_file は
  # my_time を保持しているので、まだ実行中の古い running/awaiting hook が
  # 後から pill を上書きすることはない。
  rm -f "$state_file"
elif [ "$state" = "$existing_state" ]; then
  exit 0
else
  printf '%s\n' "$state" > "$state_file"
fi

# Lock を解放してから daemon を叩く (cmux set-status の socket I/O 待ちで
# lock が長く握られ、後続 hook の起動が遅延するのを避ける)。
rmdir "$lock_dir" 2>/dev/null
trap 'rm -f "$input_file"' EXIT INT TERM HUP

if [ "$state" = clear ]; then
  cmux set-status "$key" "$label" --icon "$icon"
  exit 0
fi

# 旧バージョンの per-pane Claude pill が残っていたら回収しておく。
cmux clear-status "claude_${CMUX_PANEL_ID}" 2>/dev/null

cmux set-status "$key" "$label" --icon "$icon" --color "$color"
exit 0
