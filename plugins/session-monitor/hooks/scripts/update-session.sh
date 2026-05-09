#!/usr/bin/env sh
# Claude Code の各 hook イベントから session_id / transcript_path / cwd を受け取り、
# 全セッション横断の sessions.jsonl を upsert する。SwiftBar はこの jsonl を読んで
# メニューバーに表示する。
#
# 設計:
# - stdin に JSON が流れてくるので jq で session_id / transcript_path / cwd /
#   hook_event_name を抽出する。jq が無ければ無音で抜ける。
# - hook event から status を導出 (cmux pill と同じ写像):
#     SessionStart                                    -> idle
#     UserPromptSubmit / PreToolUse / PostToolUse     -> running
#     Notification                                    -> awaiting
#     Stop                                            -> idle
#     SessionEnd                                      -> ended (= sessions.jsonl から削除)
# - transcript jsonl から付加情報 (model, gitBranch, 直近ユーザープロンプト, usage)
#   をベストエフォートで抽出。tail -r で末尾から逆順走査して最初に見つかったものを採用。
# - 同時並走する複数セッションが sessions.jsonl を破壊しないよう mkdir lock で排他。
#   - PostToolUse は高頻度発火するため、lock 競合中も lock 内処理を最小限に保つ。
# - SwiftBar 側が CLAUDE_PLUGIN_DATA の実パスを発見できるよう、
#   ~/.claude/session-monitor/data-dir にデータディレクトリの絶対パスを記録する
#   (anchor file)。SwiftBar はそれを読んで sessions.jsonl の場所を解決する。
# - SessionEnd は Claude Code 側の hook タイムアウトが厳しいため、即座に親へ復帰し
#   実処理は detach 子プロセスで行う (cmux pill と同様)。

exec 2>/dev/null

command -v jq >/dev/null 2>&1 || exit 0

# stdin の JSON を一度だけ読む (jq に何度もパイプしないようファイルに保存)。
input_file="${TMPDIR:-/tmp}/session-monitor-input-$$"
trap 'rm -f "$input_file"' EXIT INT TERM HUP
cat > "$input_file"

session_id=$(jq -r '.session_id // empty' < "$input_file" 2>/dev/null)
[ -n "$session_id" ] || exit 0

transcript_path=$(jq -r '.transcript_path // empty' < "$input_file" 2>/dev/null)
cwd=$(jq -r '.cwd // empty' < "$input_file" 2>/dev/null)
hook_event=$(jq -r '.hook_event_name // empty' < "$input_file" 2>/dev/null)
[ -n "$cwd" ] || cwd="$PWD"

case "$hook_event" in
  SessionStart) status=idle ;;
  UserPromptSubmit|PreToolUse|PostToolUse) status=running ;;
  Notification) status=awaiting ;;
  Stop) status=idle ;;
  SessionEnd) status=ended ;;
  *) exit 0 ;;
esac

# データディレクトリ。CLAUDE_PLUGIN_DATA があればそれを優先、無ければ
# ~/.claude/session-monitor をフォールバックにする。
data_dir="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/session-monitor}"
mkdir -p "$data_dir" 2>/dev/null
sessions_file="$data_dir/sessions.jsonl"
lock_dir="$sessions_file.lock"

# anchor file: SwiftBar が $CLAUDE_PLUGIN_DATA の実体を知る手段が無いため、
# 固定パスから data_dir を逆引きできるようにしておく。
anchor_dir="$HOME/.claude/session-monitor"
mkdir -p "$anchor_dir" 2>/dev/null
printf '%s\n' "$data_dir" > "$anchor_dir/data-dir" 2>/dev/null

# SessionEnd は短時間制約があるので detach して子プロセスに処理を任せる。
# 親はすぐに 0 で抜けて Claude Code 側の hook タイムアウトを救済する。
if [ "$hook_event" = SessionEnd ] && [ -z "$SESSION_MONITOR_BG" ]; then
  SESSION_MONITOR_BG=1 nohup "$0" </dev/null >/dev/null 2>&1 < "$input_file" &
  exit 0
fi

# transcript jsonl から付加情報をベストエフォートで抽出。tail -r が macOS の
# BSD 実装にあるので末尾から逆順に読む。Linux の tac とは流儀が違うので両方試す。
reverse() {
  if command -v tail >/dev/null && tail -r /dev/null >/dev/null 2>&1; then
    tail -r "$1"
  elif command -v tac >/dev/null; then
    tac "$1"
  else
    cat "$1"
  fi
}

git_branch=""
model=""
last_prompt=""
in_tokens=0
out_tokens=0
cache_read=0
last_assistant_ts=""

# cmux 内では TERM_PROGRAM=ghostty になるので CMUX_* を別途記録し、
# SwiftBar 側で cmux select-workspace + focus-panel を組み合わせて
# 該当ワークスペース/ペインへ正確にジャンプできるようにする。
term_program="${TERM_PROGRAM:-}"
cmux_panel_id="${CMUX_PANEL_ID:-}"
cmux_workspace_id="${CMUX_WORKSPACE_ID:-}"

if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  # 末尾 400 行に絞ることで巨大セッションでも一定時間で完了する。
  tail_buf=$(tail -n 400 "$transcript_path" 2>/dev/null)

  # 最新 assistant メッセージの usage / model
  last_assistant=$(printf '%s\n' "$tail_buf" | jq -c 'select(.type=="assistant" and (.message.usage // null)!=null)' 2>/dev/null | tail -n 1)
  if [ -n "$last_assistant" ]; then
    model=$(printf '%s' "$last_assistant" | jq -r '.message.model // ""')
    in_tokens=$(printf '%s' "$last_assistant" | jq -r '.message.usage.input_tokens // 0')
    out_tokens=$(printf '%s' "$last_assistant" | jq -r '.message.usage.output_tokens // 0')
    cache_read=$(printf '%s' "$last_assistant" | jq -r '.message.usage.cache_read_input_tokens // 0')
    last_assistant_ts=$(printf '%s' "$last_assistant" | jq -r '.timestamp // ""')
  fi

  # 最新ユーザープロンプト。Claude Code transcript 上で「ユーザーが入力欄から
  # タイプしたメッセージ」だけを残すには、以下を全部除外する必要がある:
  #   - sidechain (subagent 内の user role メッセージ)
  #   - isMeta=true (Stop hook 注入 / Skill 起動 / "Continue from where..." 等)
  #   - toolUseResult あり (Bash 等のツール結果として後付けされた user role)
  # SwiftBar 側で全文表示するため上限は緩めに (極端に長い貼り付けを抑える程度)。
  last_prompt=$(printf '%s\n' "$tail_buf" | jq -r '
    select(.type=="user"
           and (.isSidechain // false)==false
           and (.isMeta // false)==false
           and (.toolUseResult // null)==null)
    | (.message.content // "")
    | if type=="string" then .
      else ([.[] | select(.type=="text") | .text // ""] | join(" ")) end
    | select(. != "")
    | gsub("[\\n\\r\\t]"; " ")
  ' 2>/dev/null | tail -n 1 | head -c 4000)

  # 最新の gitBranch (空文字も来るので非空のみ拾う)
  git_branch=$(printf '%s\n' "$tail_buf" | jq -r 'select((.gitBranch // "") != "") | .gitBranch' 2>/dev/null | tail -n 1)
fi

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

new_record=$(jq -nc \
  --arg sid "$session_id" \
  --arg cwd "$cwd" \
  --arg branch "$git_branch" \
  --arg status "$status" \
  --arg model "$model" \
  --arg prompt "$last_prompt" \
  --arg ts "$now" \
  --arg tp "$transcript_path" \
  --arg event "$hook_event" \
  --arg lats "$last_assistant_ts" \
  --arg term_program "$term_program" \
  --arg cmux_panel_id "$cmux_panel_id" \
  --arg cmux_workspace_id "$cmux_workspace_id" \
  --argjson it "${in_tokens:-0}" \
  --argjson ot "${out_tokens:-0}" \
  --argjson cr "${cache_read:-0}" \
  '{session_id:$sid, cwd:$cwd, git_branch:$branch, status:$status, model:$model,
    last_prompt:$prompt, updated_at:$ts, last_event:$event,
    transcript_path:$tp, last_assistant_at:$lats,
    term_program:$term_program, cmux_panel_id:$cmux_panel_id,
    cmux_workspace_id:$cmux_workspace_id,
    input_tokens:$it, output_tokens:$ot, cache_read_input_tokens:$cr}')

# Per-file mutex (mkdir は POSIX で atomic)。1 秒以上経過したロックは stale。
attempts=0
while ! mkdir "$lock_dir" 2>/dev/null; do
  attempts=$((attempts + 1))
  if [ "$attempts" -gt 50 ]; then
    rm -rf "$lock_dir" 2>/dev/null
    attempts=0
  fi
  sleep 0.02
done
trap 'rm -rf "$lock_dir" 2>/dev/null; rm -f "$input_file"' EXIT INT TERM HUP

tmp_file="$sessions_file.tmp"
if [ -f "$sessions_file" ]; then
  # 当該 session_id の既存行を除いた jsonl を書き出す
  jq -c --arg sid "$session_id" 'select(.session_id != $sid)' "$sessions_file" > "$tmp_file" 2>/dev/null || : > "$tmp_file"
else
  : > "$tmp_file"
fi

# ended なら追記しない (= 削除)
if [ "$status" != "ended" ]; then
  printf '%s\n' "$new_record" >> "$tmp_file"
fi

mv "$tmp_file" "$sessions_file"

# SwiftBar に即時再描画を要求する。`open` は非同期に URL ハンドラへ
# 投げるだけで block しないので hook タイムアウトに影響しない。
# (SwiftBar が動いていない / 未インストールでもエラーは無視される)
/usr/bin/open "swiftbar://refreshplugin?name=claude-sessions.5s.sh" >/dev/null 2>&1 &

exit 0
