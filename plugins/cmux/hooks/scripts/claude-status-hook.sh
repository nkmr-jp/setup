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
# cmux 0.61+ は子プロセスに CMUX_PANEL_ID / CMUX_SURFACE_ID / CMUX_WORKSPACE_ID
# のいずれも継承しないため、空の場合は session_id 別 cache に hook 自身のペインの
# surface UUID を解決して保存する。pill key は `cwd_<UUID>` 形式 (zsh 側
# sidebar-cwd.zsh の sweeper が surface.list の `id` フィールドと照合するため、
# ref 形式 `surface:N` ではなく UUID でなければ即 sweep されて pill が消える)。
#
# 解決アプローチは複数試行した:
#   - `cmux identify` の focused フィールド -> ユーザーが別ペインに focus を
#     移していると別ワークスペースを掴んでしまうため使えない
#   - `cmux identify` の caller フィールド -> CMUX_SURFACE_ID / CMUX_WORKSPACE_ID
#     環境変数が hook プロセスに無いと caller が null になるため使えない
#   - ★採用: `cmux top --all --processes --format tsv` の TSV 出力で各 process が
#     どの surface に属するかをツリーで返してくれる。hook 自身の PID から ps で
#     parent をたどり、TSV の `process <PID> <surface:N>` 行に当たった時点で確定。
#     その後 workspace.list / surface.list を walk して surface UUID に変換する。
# cache が無い間はどの hook event でも実行する。SessionEnd で cache を掃除。
#
# tmux 内 (claude ラッパーが ccdash-<sid8> セッションで起動するケース) は追加の
# 迂回が必要: tmux server はデーモン化されて親が launchd になるため、hook 自身の
# PID から親を辿っても cmux surface に到達しない (hook → claude → tmux server →
# launchd)。また TERM_PROGRAM も tmux に上書きされる。代わりに、このセッションに
# attach している tmux client の PID (cmux surface の zsh の子として cmux top に
# 載る) を起点に辿る。複数 client が attach している場合 (ccdash パネル併用等) は
# 全 client を試し、cmux top にヒットしたものを採用する。cmux 以外のターミナルの
# client はヒットしないので自然に除外される。
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
#
# pill は workspace スコープで管理される (`workspace:<WS_UUID>:tag:cwd_<SURFACE>`)。
# `cmux set-status` を `--workspace` 無しで呼ぶと `$CMUX_WORKSPACE_ID` 環境変数を
# 参照するが、cmux 0.61+ は CMUX_WORKSPACE_ID も子プロセスに継承しないため、
# 結果として daemon は「現在 focus している workspace」に pill を attach してしまう。
# 別 pane の Claude Code セッションが running になった瞬間、その pill が
# ユーザーが今見ている (別) workspace のサイドバーに混入する原因となるため、
# 必ず `--workspace $CMUX_WORKSPACE_ID` を明示指定する。WORKSPACE_ID は panel と
# 一緒に session 別 cache (2 行目) に保存して再解決コストを抑える。

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
# cache が無ければ caller ベースで identify を呼んで作る。SessionStart に限らず
# どの hook event でも安全 (caller は呼び出したプロセス自身のペインを返すので
# focused のような「ユーザーが今前面にしているペイン = 別ペインの可能性」リスクが
# 無い)。SessionStart 限定にすると、既に動いているセッションでスクリプトが更新
# された場合に永遠に cache が作られなくなるため、event を限定しない。
panel_cache=""
if [ -n "$session_id" ]; then
  panel_cache="$state_dir/session-${session_id}.panel"
fi

# 既存 cache を読み込む。format は 1 行目=surface UUID, 2 行目=workspace UUID。
# 旧 format (1 行のみ) は workspace 未指定で set-status を呼んでしまい今回のバグの
# 原因となるので、workspace UUID が欠けている cache は無効として再生成する。
load_panel_cache() {
  [ -n "$panel_cache" ] && [ -f "$panel_cache" ] || return 0
  cached_panel=$(awk 'NR==1{print; exit}' "$panel_cache" 2>/dev/null)
  cached_ws=$(awk 'NR==2{print; exit}' "$panel_cache" 2>/dev/null)
  case "$cached_panel" in
    ""|*:*) cached_panel=""; cached_ws="" ;;
  esac
  case "$cached_ws" in
    *:*) cached_ws="" ;;
  esac
  if [ -z "$cached_panel" ] || [ -z "$cached_ws" ]; then
    rm -f "$panel_cache"
    return 0
  fi
  CMUX_PANEL_ID="$cached_panel"
  CMUX_WORKSPACE_ID="$cached_ws"
}

# 環境変数で渡されていない場合は cache を試す。
if [ -z "${CMUX_PANEL_ID:-}" ] || [ -z "${CMUX_WORKSPACE_ID:-}" ]; then
  # SessionStart のときは cache を強制再生成する。過去の壊れた実装で書き込まれた
  # 別 workspace の UUID が残っている可能性があるため。
  [ "$hook_event" = "SessionStart" ] && [ -n "$panel_cache" ] && rm -f "$panel_cache"
  load_panel_cache
fi

# cmux top で自分の PID から surface/pane/workspace ref を辿り UUID に変換して
# cache に書き込む。途中で何も解決できなければ何もしない (caller が判断)。
resolve_and_cache_panel() {
  [ -n "$panel_cache" ] || return 0
  # 探索起点の PID 一覧を決める。tmux 内なら attach 中の client PID 群
  # (TERM_PROGRAM/__CFBundleIdentifier は tmux server 経由で信頼できないため、
  # 判定は cmux top でのヒット有無に委ねる)、そうでなければ hook 自身の PID。
  if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
    if [ -n "${TMUX_PANE:-}" ]; then
      tmux_session=$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null)
    else
      tmux_session=$(tmux display-message -p '#{session_name}' 2>/dev/null)
    fi
    [ -n "$tmux_session" ] || return 0
    probe_pids=$(tmux list-clients -t "=$tmux_session" -F '#{client_pid}' 2>/dev/null)
    [ -n "$probe_pids" ] || return 0
  else
    [ "${TERM_PROGRAM:-}" = "ghostty" ] || return 0
    [ "${__CFBundleIdentifier:-}" = "com.cmuxterm.app" ] || return 0
    probe_pids=$$
  fi
  command -v jq >/dev/null 2>&1 || return 0
  cmux_cli="${CMUX_BUNDLED_CLI_PATH:-/Applications/cmux.app/Contents/Resources/bin/cmux}"
  [ -x "$cmux_cli" ] || return 0

  # 1. cmux top で全 process / surface / pane / workspace の階層を取得し、
  #    各起点 PID から親方向に辿って `process <PID> <surface:N>` 行に当たった
  #    surface ref を確定する。
  top_tsv=$("$cmux_cli" top --all --processes --format tsv 2>/dev/null)
  surface_ref=""
  for start_pid in $probe_pids; do
    probe_pid=$start_pid
    probe_attempts=0
    while [ -n "$probe_pid" ] && [ "$probe_pid" != "0" ] \
       && [ "$probe_pid" != "1" ] && [ "$probe_attempts" -lt 20 ]; do
      surface_ref=$(printf '%s\n' "$top_tsv" | awk -F'\t' -v pid="$probe_pid" '
        $4 == "process" && $5 == pid && $6 ~ /^surface:/ { print $6; exit }')
      [ -n "$surface_ref" ] && break
      next_pid=$(ps -o ppid= -p "$probe_pid" 2>/dev/null | tr -d ' ')
      { [ -z "$next_pid" ] || [ "$next_pid" = "$probe_pid" ]; } && break
      probe_pid="$next_pid"
      probe_attempts=$((probe_attempts + 1))
    done
    [ -n "$surface_ref" ] && break
  done
  [ -n "$surface_ref" ] || return 0

  # 2. surface -> pane -> workspace を TSV 上で辿って workspace ref を確定する。
  #    surface ref (`surface:N`) は workspace 内ローカル番号で別 workspace に
  #    同名の surface ref が存在しうるため、workspace.list を盲目的に walk
  #    して `ref` 一致だけで UUID を取ると別ペインを掴むリスクがある。
  pane_ref=$(printf '%s\n' "$top_tsv" | awk -F'\t' -v sref="$surface_ref" '
    $4 == "surface" && $5 == sref && $6 ~ /^pane:/ { print $6; exit }')
  [ -n "$pane_ref" ] || return 0
  ws_ref=$(printf '%s\n' "$top_tsv" | awk -F'\t' -v pref="$pane_ref" '
    $4 == "pane" && $5 == pref && $6 ~ /^workspace:/ { print $6; exit }')
  [ -n "$ws_ref" ] || return 0

  # 3. workspace ref -> UUID -> surface UUID
  new_ws=$("$cmux_cli" rpc workspace.list "{}" 2>/dev/null \
    | jq -r --arg ref "$ws_ref" \
      '.workspaces[]? | select(.ref == $ref) | .id // empty' 2>/dev/null \
    | head -n 1)
  [ -n "$new_ws" ] || return 0
  new_panel=$("$cmux_cli" rpc surface.list \
      "{\"workspace_id\":\"$new_ws\"}" 2>/dev/null \
    | jq -r --arg ref "$surface_ref" \
      '.surfaces[]? | select(.ref == $ref) | .id // empty' 2>/dev/null \
    | head -n 1)
  [ -n "$new_panel" ] || return 0

  printf '%s\n%s\n' "$new_panel" "$new_ws" > "$panel_cache"
  load_panel_cache
}

if [ -z "${CMUX_PANEL_ID:-}" ] || [ -z "${CMUX_WORKSPACE_ID:-}" ]; then
  resolve_and_cache_panel
fi

[ -n "${CMUX_PANEL_ID:-}" ] || exit 0
[ -n "${CMUX_WORKSPACE_ID:-}" ] || exit 0

# SessionEnd は Claude Code 側に時間制約があり (1 秒未満)、lock 競合で sleep
# すると "Hook cancelled" として打ち切られる。clear だけは即時に親へ制御を
# 返し、実処理は detach した子プロセスで race-safe lock を取って実行する。
# 親 session が消えても cmux daemon への set-status は子プロセスから完了する。
# CMUX_PANEL_ID / CMUX_WORKSPACE_ID は環境変数で子プロセスに引き継ぐ
# (stdin は /dev/null になるので cache 経由の再解決はできない)。
if [ "$state" = clear ] && [ -z "${CMUX_STATUS_HOOK_BG:-}" ]; then
  # SessionEnd では panel cache も掃除しておく (次回 SessionStart で再取得)。
  [ "$hook_event" = "SessionEnd" ] && [ -n "$panel_cache" ] && rm -f "$panel_cache"
  CMUX_STATUS_HOOK_BG=1 CMUX_PANEL_ID="$CMUX_PANEL_ID" \
    CMUX_WORKSPACE_ID="$CMUX_WORKSPACE_ID" \
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
  cmux set-status "$key" "$label" --workspace "$CMUX_WORKSPACE_ID" --icon "$icon"
  exit 0
fi

# 旧バージョンの per-pane Claude pill が残っていたら回収しておく。
cmux clear-status "claude_${CMUX_PANEL_ID}" --workspace "$CMUX_WORKSPACE_ID" 2>/dev/null

cmux set-status "$key" "$label" --workspace "$CMUX_WORKSPACE_ID" \
  --icon "$icon" --color "$color"
exit 0
