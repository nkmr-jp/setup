#!/usr/bin/env sh
# Show a Claude Code-style status line for Devin CLI sessions by appending it to
# the cmux workspace title (the header has far more room than sidebar pills,
# which truncate long labels).
#
# Devin CLI has no native statusLine feature, so the workspace title carries
# the same kind of information the Claude status line shows, after a " ▸ "
# marker that separates it from the base title:
#   <base title> ▸ <dir> · <branch> · <session> · <model> · <elapsed> · <ctx> · <diff>
#
# The base title is whatever the workspace already shows (usually the
# ccdash-generated session title). On every update the existing marker suffix
# is stripped before re-appending, so renames by ccdash's autotitle simply
# revert to the base title until the next refresh stamps the status again.
# SessionEnd strips the marker and leaves the base title behind.
#
# Data sources:
#   - stdin hook payload: session_id, hook_event_name
#   - ~/.claude/cmux/hook-sessions.json: session_id -> workspaceId / surfaceId /
#     cwd mapping written by claude-status-hook.sh (no mapping -> exit, which is
#     the case for Devin sessions outside cmux)
#   - `cmux list-workspaces --json`: current custom_title for the workspace
#   - ~/.local/share/devin/cli/sessions.db: model / created_at / working dir
#   - message_nodes.metadata: num_tokens_preceding (latest context size)
#
# Fires on SessionStart, UserPromptSubmit, PermissionRequest, PostToolUse, Stop,
# and SessionEnd. PostToolUse/PreToolUse are throttled per workspace to one
# update every 15 seconds via a stamp file; all other events always refresh.
# Every failure path exits 0 so the hook can never block or break the session.

exec >/dev/null 2>&1
umask 077

command -v cmux >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

state_dir="${TMPDIR:-/tmp}/devin-statusline"
mkdir -p "$state_dir" 2>/dev/null

input_file=$(mktemp "$state_dir/hook-input.XXXXXX") || exit 0
trap 'rm -f "$input_file"' EXIT INT TERM HUP
cat >"$input_file" 2>/dev/null

session_id=$(jq -r '.session_id // empty' <"$input_file" 2>/dev/null)
hook_event=$(jq -r '.hook_event_name // empty' <"$input_file" 2>/dev/null)
[ -n "$session_id" ] || exit 0

# Resolve the cmux workspace/surface from the mapping the state hook maintains.
sessions_file="$HOME/.claude/cmux/hook-sessions.json"
[ -f "$sessions_file" ] || exit 0
ws_id=$(jq -r --arg s "$session_id" '.sessions[$s].workspaceId // empty' \
  <"$sessions_file" 2>/dev/null)
[ -n "$ws_id" ] || exit 0

marker=" ▸ "
stamp="$state_dir/$ws_id.ts"

# Read the current workspace title once; both refresh and SessionEnd need it.
current_title=$(cmux list-workspaces --json 2>/dev/null | jq -r --arg ws "$ws_id" '
  [.. | objects | select(.id? == $ws and (.custom_title? != null)) | .custom_title]
  | first // ""' 2>/dev/null)
base_title=${current_title%%"$marker"*}

rename_workspace() {
  # $1 = new title. Skip the daemon call when nothing would change.
  [ "$1" != "$current_title" ] || return 0
  cmux workspace-action --workspace "$ws_id" --action rename --title "$1" \
    2>/dev/null
}

if [ "$hook_event" = "SessionEnd" ]; then
  # Leave the base title behind and stop future throttle state from lingering.
  [ -n "$base_title" ] && rename_workspace "$base_title"
  rm -f "$stamp"
  exit 0
fi

# Throttle high-frequency tool events; everything else always refreshes.
now=$(date +%s)
case "$hook_event" in
  PreToolUse | PostToolUse)
    last=$(cat "$stamp" 2>/dev/null || echo 0)
    [ $((now - ${last:-0})) -lt 15 ] && exit 0
    ;;
esac
printf '%s\n' "$now" >"$stamp" 2>/dev/null

cwd=$(jq -r --arg s "$session_id" '.sessions[$s].cwd // empty' \
  <"$sessions_file" 2>/dev/null)
[ -n "$cwd" ] || cwd="${DEVIN_PROJECT_DIR:-$PWD}"

# --- session data from sessions.db (model, created_at, context tokens) ---
db="$HOME/.local/share/devin/cli/sessions.db"
model=""
created_at=0
ctx_tokens=""
if [ -f "$db" ] && command -v sqlite3 >/dev/null 2>&1; then
  row=$(sqlite3 "$db" \
    "SELECT COALESCE(model,''), COALESCE(created_at,0) FROM sessions WHERE id='$session_id';" \
    2>/dev/null)
  if [ -n "$row" ]; then
    model=${row%%|*}
    created_at=${row##*|}
  fi
  ctx_tokens=$(sqlite3 "$db" \
    "SELECT COALESCE(MAX(CAST(json_extract(metadata,'\$.num_tokens_preceding') AS INTEGER)),0) FROM message_nodes WHERE session_id='$session_id';" \
    2>/dev/null)
fi
if [ -z "$model" ]; then
  model=$(jq -r '.agent.model // empty' "$HOME/.config/devin/config.json" 2>/dev/null)
fi

# --- directory component (worktree-aware basename, same rules as the Claude status line) ---
dir_name=""
if [ -n "$cwd" ]; then
  dir_part=$cwd
  case "$dir_part" in *-worktrees/*) dir_part=${dir_part%%-worktrees/*} ;; esac
  dir_name=$(basename "$dir_part" 2>/dev/null)
  case "$dir_name" in *-wt-*) dir_name=${dir_name%%-wt-*} ;; esac
fi

# --- git components ---
branch=""
diff_part=""
if [ -d "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" -c core.useReplaceRefs=false -c advice.detachedHead=false \
    symbolic-ref --short HEAD 2>/dev/null)
  case "$cwd" in *-worktrees/*) branch="wt:$branch" ;; esac
  read -r added deleted <<EOF
$(git -C "$cwd" diff --numstat 2>/dev/null | awk '{a+=$1; d+=$2} END {print (a?a:0), (d?d:0)}')
EOF
  untracked=$(git -C "$cwd" status --porcelain 2>/dev/null | grep -c '^??')
  diff_part="+${added:-0}/-${deleted:-0}"
  [ "${untracked:-0}" -gt 0 ] 2>/dev/null && diff_part="$diff_part ?$untracked"
fi

# --- elapsed time from session creation ---
elapsed=""
case "$created_at" in '' | *[!0-9]*) created_at=0 ;; esac
if [ "$created_at" -gt 0 ] 2>/dev/null; then
  secs=$((now - created_at))
  [ "$secs" -lt 0 ] && secs=0
  if [ "$secs" -ge 3600 ]; then
    elapsed="$((secs / 3600))h$((secs % 3600 / 60))m"
  elif [ "$secs" -ge 60 ]; then
    elapsed="$((secs / 60))m"
  else
    elapsed="${secs}s"
  fi
fi

# --- context token count, compact (71509 -> 72k, 2400000 -> 2.4M) ---
ctx=""
case "$ctx_tokens" in '' | *[!0-9]*) ctx_tokens=0 ;; esac
if [ "$ctx_tokens" -gt 0 ] 2>/dev/null; then
  ctx=$(awk -v n="$ctx_tokens" 'BEGIN {
    if (n >= 1000000) printf "%.1fM", n / 1000000;
    else if (n >= 1000) printf "%.0fk", n / 1000;
    else printf "%d", n;
  }')
fi

status=""
for part in "$dir_name" "$branch" "$session_id" "$model" "$elapsed" "$ctx" "$diff_part"; do
  [ -n "$part" ] || continue
  if [ -n "$status" ]; then
    status="$status · $part"
  else
    status="$part"
  fi
done
[ -n "$status" ] || exit 0

# Fall back to the directory name when the workspace has no title yet.
[ -n "$base_title" ] || base_title="$dir_name"
[ -n "$base_title" ] || exit 0

rename_workspace "$base_title$marker$status"
exit 0
