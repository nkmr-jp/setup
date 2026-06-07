#!/bin/bash
# claude-stall-monitor: Claude Code の「tool call parse 失敗による無通知停止」を検知して通知する
#
# 背景:
#   "The model's tool call could not be parsed (retry also failed)." でターンが異常終了すると、
#   Stop / Notification / StopFailure いずれのフックも発火せず、何の通知も来ない。
#   セッション JSONL にも parse 失敗の専用レコードは残らない（assistant の試行レコードだけ）。
#   → フックの「発火の欠落」そのものを外部から捉えるしかない。
#
# 仕組み（ack ハートビート方式）:
#   - 各フック（PreToolUse/PostToolUse/UserPromptSubmit/SessionStart/Stop/StopFailure/Notification）が
#     `ack` モードでこのスクリプトを呼び、`<monitor>/<session_id>.ack` に現在 epoch を書く。
#     = 「直近の JSONL 書き込みの後に、何らかのフックが発火した」ことの記録。
#   - watcher モードは各セッション JSONL を走査し、
#       idle(= now - mtime) >= IDLE_THRESHOLD かつ ack < mtime
#     のものを「異常停止」と判定する。これは「JSONL に書き込まれたのに、その後どのフックも
#     発火していない」状態＝ parse 失敗（や同種のサイレント死）に一意に対応する。
#   誤検知しないケース:
#     - 正常完了 → Stop が ack を書く（ack >= mtime）
#     - API エラー → StopFailure が ack を書く
#     - 権限待ち/idle → Notification が ack を書く（既存 claude-notify も通知済）
#     - 長時間ツール実行中 → tool 開始時に PreToolUse が ack を書く（mtime は据え置き）ため鳴らない
#     - セッション終了/kill（ユーザーが閉じた）→ Stop が発火せず ack < mtime になるが、
#       claude プロセス自体が消えているので「対象プロジェクトに生存プロセスなし」で除外する。
#       parse 失敗は claude プロセスが生きたまま固まる点が決定的に異なる。
#       注: CLAUDE_CODE_SESSION_ID(env) は起動時の元 id で JSONL 名(実 session_id)と
#           一致しないため、プロセス照合は session_id ではなく cwd→プロジェクト名で行う。
#
# 使い方:
#   claude-stall-monitor.sh            # watcher（既定）: 異常停止を検知して通知
#   claude-stall-monitor.sh --watch    # 同上
#   claude-stall-monitor.sh ack        # フックから: stdin の JSON から session_id を読み ack を書く

set -u

MONITOR_DIR="$HOME/.claude/monitor"
PROJECTS_DIR="$HOME/.claude/projects"
IDLE_THRESHOLD=45      # 秒: これ以上 JSONL が更新されなければ「停止」候補
LOOKBACK_MIN=15        # 分: この時間内に更新のあった JSONL だけを対象（効率＆古い放置を除外）

mkdir -p "$MONITOR_DIR"

# --- ack モード: フックから呼ばれ、ハートビートを記録する ---
ack_mode() {
  local input sid
  input="$(cat)"
  sid="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
  [ -n "$sid" ] || exit 0
  date +%s > "$MONITOR_DIR/$sid.ack"
  # 活動が再開したら通知の重複抑止フラグを解除（次の停止で再通知できるように）
  rm -f "$MONITOR_DIR/$sid.alerted"
  exit 0
}

# --- セッションのプロセス生存判定 ---
# 生きている claude プロセスの cwd を JSONL のプロジェクトディレクトリ名と同じ規則
# （'/' と '.' を '-' に変換）でエンコードし、対象プロジェクトに一致する生存プロセスが
# 1つでもあれば「生きている」とみなす。parse 失敗で固まったセッションは true、
# ユーザーが閉じた/kill したセッションは false（＝通知しない）になる。
project_has_live_session() {
  local target="$1" pids cwd enc
  pids="$(pgrep -x claude 2>/dev/null | paste -sd, -)"
  [ -n "$pids" ] || return 1
  while IFS= read -r cwd; do
    [ -n "$cwd" ] || continue
    enc="$(printf '%s' "$cwd" | sed 's#[/.]#-#g')"
    [ "$enc" = "$target" ] && return 0
  done < <(lsof -a -d cwd -p "$pids" -Fn 2>/dev/null | sed -n 's/^n//p')
  return 1
}

# --- 通知 ---
notify() {
  local title="$1" subtitle="$2" message="$3"
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "$title" -subtitle "$subtitle" -message "$message" \
      -group "claude-stall" -sound default >/dev/null 2>&1
  else
    osascript -e "display notification \"$message\" with title \"$title\" subtitle \"$subtitle\" sound name \"Submarine\"" >/dev/null 2>&1
  fi
}

# --- watcher モード ---
watch_mode() {
  local now f sid ack_file mtime idle ack alerted_file project
  now="$(date +%s)"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    sid="$(basename "$f" .jsonl)"
    ack_file="$MONITOR_DIR/$sid.ack"
    # ack が無いセッションは導入前の旧セッション等。基準が無いので判定しない（誤検知防止）。
    [ -f "$ack_file" ] || continue
    mtime="$(stat -f %m "$f" 2>/dev/null)" || continue
    idle=$(( now - mtime ))
    if [ "$idle" -lt "$IDLE_THRESHOLD" ]; then
      rm -f "$MONITOR_DIR/$sid.alerted"   # まだ活動中 → 重複抑止を解除
      continue
    fi
    ack="$(cat "$ack_file" 2>/dev/null || echo 0)"
    # 直近の JSONL 書き込みの後にフックが発火していれば正常（正常完了/エラー/権限待ち/ツール実行中）
    [ "$ack" -ge "$mtime" ] && continue
    # ここに来たら: JSONL は進んだのにどのフックも発火していない＝ parse 失敗の疑い。
    # ただし claude プロセスが既に消えている＝ユーザーがセッションを終了/kill した場合は
    # parse 失敗ではないので鳴らさない（誤検知防止）。
    project="$(basename "$(dirname "$f")")"
    project_has_live_session "$project" || continue
    alerted_file="$MONITOR_DIR/$sid.alerted"
    if [ -f "$alerted_file" ] && [ "$(cat "$alerted_file" 2>/dev/null)" = "$mtime" ]; then
      continue   # この停止については通知済み（mtime が変わらない限り 1 回だけ）
    fi
    notify "Claude Code 停止検知" "${project}" \
      "セッション ${sid:0:8} が ${idle}s 無応答。tool call parse 失敗の可能性（フック未発火）。"
    echo "$mtime" > "$alerted_file"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STALL sid=$sid project=$project idle=${idle}s ack=$ack mtime=$mtime"
  done < <(find "$PROJECTS_DIR" -name '*.jsonl' -type f -mmin "-$LOOKBACK_MIN" 2>/dev/null)
}

case "${1:---watch}" in
  ack)            ack_mode ;;
  --watch|watch)  watch_mode ;;
  *)              echo "usage: $0 [--watch|ack]" >&2; exit 2 ;;
esac
