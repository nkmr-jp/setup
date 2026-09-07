#!/usr/bin/env sh
# Receive session_id / transcript_path / cwd from Codex / Claude Code hook events
# and upsert sessions.jsonl across all sessions. xbar reads this JSONL file
# to display sessions in the menu bar.
#
# Design:
# - Parse JSON on stdin with jq to extract session_id / transcript_path / cwd /
#   hook_event_name. Exit silently if jq is unavailable.
# - Derive status from the hook event (the same mapping as the cmux pill):
#     SessionStart                                    -> idle
#     UserPromptSubmit / PreToolUse / PostToolUse     -> running
#     Notification / PermissionRequest                -> awaiting
#     Stop                                            -> idle
#     SessionEnd                                      -> ended (remove from sessions.jsonl)
# - Extract extra transcript information (model, gitBranch, latest user prompt, usage)
#   on a best-effort basis. Scan backward with tail -r and use the first match.
# - Use a mkdir lock to prevent concurrent sessions from corrupting sessions.jsonl.
#   - Keep the locked section short because PostToolUse fires frequently.
# - Record the absolute data directory path so xbar can discover CLAUDE_PLUGIN_DATA
#   through the anchor file ~/.claude/session-monitor/data-dir.
#   xbar reads that file to locate sessions.jsonl.
# - SessionEnd must return immediately because Claude Code has a short hook timeout;
#   do its work in a detached child, as with the cmux pill.

exec 2>/dev/null
umask 077

command -v jq >/dev/null 2>&1 || exit 0

# Read stdin JSON once and save it to a file instead of repeatedly piping it to jq.
input_file=$(mktemp "${TMPDIR:-/tmp}/session-monitor-input.XXXXXX") || exit 0
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
  Notification|PermissionRequest) status=awaiting ;;
  Stop) status=idle ;;
  SessionEnd) status=ended ;;
  *) exit 0 ;;
esac

# Prefer CLAUDE_PLUGIN_DATA for the data directory, falling back to
# ~/.claude/session-monitor when it is unset.
data_dir="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/session-monitor}"
mkdir -p "$data_dir" 2>/dev/null
sessions_file="$data_dir/sessions.jsonl"
lock_dir="$sessions_file.lock"

# Anchor file: xbar cannot discover CLAUDE_PLUGIN_DATA directly, so expose
# data_dir through a fixed path.
anchor_dir="$HOME/.claude/session-monitor"
mkdir -p "$anchor_dir" 2>/dev/null
printf '%s\n' "$data_dir" > "$anchor_dir/data-dir" 2>/dev/null

# Detach SessionEnd processing to a child to meet its short time limit.
# The parent exits with 0 immediately to avoid the Claude Code hook timeout.
if [ "$hook_event" = SessionEnd ] && [ -z "$SESSION_MONITOR_BG" ]; then
  # Open before spawning: parent cleanup may unlink the path before the child starts.
  exec 3< "$input_file" || exit 0
  SESSION_MONITOR_BG=1 nohup "$0" <&3 3<&- >/dev/null 2>&1 &
  exec 3<&-
  exit 0
fi

# Extract extra transcript fields on a best-effort basis. macOS BSD tail supports
# reverse reading with -r; try Linux tac as an alternative.
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
model=$(jq -r '.model // empty' < "$input_file" 2>/dev/null)
last_prompt=""
in_tokens=0
out_tokens=0
cache_read=0
last_assistant_ts=""

# Inside cmux, TERM_PROGRAM is ghostty. Record CMUX_* separately so xbar can
# combine cmux select-workspace and focus-panel to jump to the exact
# workspace and pane.
term_program="${TERM_PROGRAM:-}"
cmux_panel_id="${CMUX_PANEL_ID:-}"
cmux_workspace_id="${CMUX_WORKSPACE_ID:-}"

# cmux does not pass CMUX_PANEL_ID and related variables to child processes. When
# running under cmux (TERM_PROGRAM=ghostty and a cmux.app ancestor), use cmux identify
# to obtain the focused pane and workspace. Because focused refers to the pane
# currently in front across cmux, query it only immediately after user interaction
# (SessionStart / UserPromptSubmit). Frequent events such as PostToolUse may occur
# after focus has moved; let the later logic inherit the existing values instead.
if [ -z "$cmux_panel_id" ] && [ "$term_program" = "ghostty" ] \
   && [ "${__CFBundleIdentifier:-}" = "com.cmuxterm.app" ] \
   && { [ "$hook_event" = "SessionStart" ] || [ "$hook_event" = "UserPromptSubmit" ]; }; then
  cmux_cli="${CMUX_BUNDLED_CLI_PATH:-/Applications/cmux.app/Contents/Resources/bin/cmux}"
  if [ -x "$cmux_cli" ]; then
    identify_json=$("$cmux_cli" identify --no-caller 2>/dev/null)
    if [ -n "$identify_json" ]; then
      # focus-panel expects a surface_ref (surface:N). Passing a pane_ref fails
      # with `not_found: Workspace not found`, so always store surface_ref.
      cmux_panel_id=$(printf '%s' "$identify_json" | jq -r '.focused.surface_ref // ""' 2>/dev/null)
      cmux_workspace_id=$(printf '%s' "$identify_json" | jq -r '.focused.workspace_ref // ""' 2>/dev/null)
    fi
  fi
fi

# If lookup fails, inherit values from the existing JSONL record. Once discovered,
# they remain valid throughout the session unless the user moves the pane.
if [ -z "$cmux_panel_id" ] && [ -f "$sessions_file" ]; then
  existing=$(jq -r --arg sid "$session_id" \
    'select(.session_id == $sid)
     | [(.cmux_panel_id // ""), (.cmux_workspace_id // "")] | @tsv' \
    "$sessions_file" 2>/dev/null | head -n 1)
  if [ -n "$existing" ]; then
    cmux_panel_id=$(printf '%s' "$existing" | cut -f1)
    [ -z "$cmux_workspace_id" ] && cmux_workspace_id=$(printf '%s' "$existing" | cut -f2)
  fi
fi

# UserPromptSubmit includes .prompt directly in hook stdin. This is the text the
# user just entered; the hook may run before it is written to the transcript.
# Extract it here for immediate display and prefer it over transcript parsing
# when overriding last_prompt below.
hook_prompt=""
if [ "$hook_event" = "UserPromptSubmit" ]; then
  hook_prompt=$(jq -r '(.prompt // "") | gsub("[\\n\\r\\t]"; " ")' \
    < "$input_file" 2>/dev/null | head -c 4000)
fi

if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  # Limit the scan to the last 400 lines to bound work even for large sessions.
  tail_buf=$(tail -n 400 "$transcript_path" 2>/dev/null)

  # Usage and model from the latest assistant message
  last_assistant=$(printf '%s\n' "$tail_buf" | jq -c 'select(.type=="assistant" and (.message.usage // null)!=null)' 2>/dev/null | tail -n 1)
  if [ -n "$last_assistant" ]; then
    transcript_model=$(printf '%s' "$last_assistant" | jq -r '.message.model // ""')
    [ -n "$transcript_model" ] && model="$transcript_model"
    in_tokens=$(printf '%s' "$last_assistant" | jq -r '.message.usage.input_tokens // 0')
    out_tokens=$(printf '%s' "$last_assistant" | jq -r '.message.usage.output_tokens // 0')
    cache_read=$(printf '%s' "$last_assistant" | jq -r '.message.usage.cache_read_input_tokens // 0')
    last_assistant_ts=$(printf '%s' "$last_assistant" | jq -r '.timestamp // ""')
  fi

  # Latest user prompt. To retain only messages typed by the user in Claude Code,
  # exclude all of the following transcript entries:
  #   - sidechain (user-role messages within subagents)
  #   - isMeta=true (Stop hook injections, skill invocations, "Continue from where...", etc.)
  #   - toolUseResult present (user-role entries appended as Bash or other tool results)
  # Use a generous limit for xbar's full-text display, only restricting extreme pastes.
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

  # Latest nonempty gitBranch (empty strings can also occur)
  git_branch=$(printf '%s\n' "$tail_buf" | jq -r 'select((.gitBranch // "") != "") | .gitBranch' 2>/dev/null | tail -n 1)
fi

# Prefer a prompt supplied by the UserPromptSubmit hook over transcript extraction:
# the hook can arrive before the transcript write, making this value newer.
[ -n "$hook_prompt" ] && last_prompt="$hook_prompt"

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

# Per-file mutex (mkdir is atomic on POSIX). Locks older than one second are stale.
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

tmp_file=$(mktemp "$sessions_file.tmp.XXXXXX") || exit 0
trap 'rm -rf "$lock_dir" 2>/dev/null; rm -f "$input_file" "$tmp_file"' EXIT INT TERM HUP
if [ -f "$sessions_file" ]; then
  # Write JSONL without the existing entry for this session_id.
  jq -c --arg sid "$session_id" 'select(.session_id != $sid)' "$sessions_file" > "$tmp_file" 2>/dev/null || : > "$tmp_file"
else
  : > "$tmp_file"
fi

# Do not append ended sessions; removing their existing entry deletes them.
if [ "$status" != "ended" ]; then
  printf '%s\n' "$new_record" >> "$tmp_file"
fi

mv "$tmp_file" "$sessions_file"

# Request an immediate xbar refresh. `open -g` dispatches to the URL handler without
# bringing the application to the foreground, preserving input focus in the current
# foreground application, such as the terminal. Without `-g`, xbar becomes active
# and steals input focus every time a hook fires.
# Ignore errors if xbar is not running or is not installed.
/usr/bin/open -g "xbar://app.xbarapp.com/refreshPlugin?path=claude-sessions.5s.sh" >/dev/null 2>&1 &

exit 0
