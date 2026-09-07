#!/usr/bin/env sh
# Update the cmux sidebar cwd pill icon to reflect Claude Code state.
# UserPromptSubmit / PreToolUse / PostToolUse -> running, Notification -> awaiting,
# Stop -> idle (response finished, awaiting the next input); SessionStart / SessionEnd
# -> clear (restore the folder icon and remove the state file). When no state file
# exists (the initial state), zsh also restores the folder icon. PostToolUse is needed
# to reliably restore awaiting -> running after AskUserQuestion answers or permission
# approvals. SessionStart clears stale state when the previous session missed
# SessionEnd, for example after a crash.
#
# Usage: claude-status-hook.sh <running|awaiting|idle|clear>
#
# Secondary responsibility (setup issue #3): at the same final stage as pill updates,
# upsert the sessionId -> cmux surface/workspace UUID mapping into
# ~/.claude/cmux/hook-sessions.json (sync_sessions_json). Disabling cmux's
# claudeCodeIntegration stops cmux from updating ~/.cmuxterm/claude-hook-sessions.json,
# so generate replacement data for its consumers (ccdash / issues-site).
#
# Store state in ${TMPDIR}/cmux-pane-state/<panel-id> so zsh precmd/chpwd can
# redraw the same icon. Keep the state-to-icon mapping synchronized on both sides.
#
# cmux 0.61+ does not pass CMUX_PANEL_ID / CMUX_SURFACE_ID / CMUX_WORKSPACE_ID
# to child processes. When unset, resolve this hook's surface UUID and save it in
# a per-session_id cache. Pill keys use `cwd_<UUID>` because the sweeper in zsh's
# sidebar-cwd.zsh compares them with the surface.list `id` field. A `surface:N`
# reference instead of a UUID would be swept immediately, making the pill disappear.
#
# Resolution approaches considered:
#   - The `cmux identify` focused field is unusable: if the user moves focus to
#     another pane, it can select a different workspace.
#   - The `cmux identify` caller field is unusable without CMUX_SURFACE_ID /
#     CMUX_WORKSPACE_ID in the hook environment, because caller becomes null.
#   - Selected approach: `cmux top --all --processes --format tsv` returns a tree
#     mapping each process to its surface. Walk parents with ps from this hook's PID
#     until matching a TSV `process <PID> <surface:N>` row.
#     Then walk workspace.list / surface.list to resolve the surface UUID.
# Run this for any hook event while the cache is missing; clear it on SessionEnd.
#
# Inside tmux (when the claude wrapper starts a ccdash-<sid8> session), take an extra
# step: the tmux server is daemonized under launchd, so walking this hook's parents
# cannot reach the cmux surface (hook -> claude -> tmux server ->
# launchd). tmux also overrides TERM_PROGRAM. Instead, start from the PIDs of tmux
# clients attached to this session, which appear in cmux top as children of the
# surface's zsh. If several clients are attached (for example alongside a ccdash panel),
# try all of them and select one that matches cmux top. Clients in other terminals
# do not match and are naturally excluded.
#
# Concurrent or closely timed hooks can be handled out of order by the cmux daemon,
# leaving an old pill state. Each hook records its event time immediately on startup
# (nanoseconds via perl). Within a per-pane lock, update the state file only if
# this timestamp is newer than the last applied one. clear (SessionEnd) must share
# this mechanism; otherwise an older running/awaiting hook could finish later and
# overwrite the pill. Route clear through the same lock and timestamp checks.
#
# Perform `cmux set-status` socket I/O after releasing the lock so concurrent
# PreToolUse hooks do not hold it while waiting for the daemon and unnecessarily
# delay later hooks. Concurrent events may reach cmux out of order, but frequent
# updates such as PreToolUse restore the latest state on a subsequent transition.
#
# Pills are workspace-scoped (`workspace:<WS_UUID>:tag:cwd_<SURFACE>`).
# Without --workspace, `cmux set-status` reads the CMUX_WORKSPACE_ID environment
# variable. cmux 0.61+ does not pass that variable to child processes either,
# causing the daemon to attach the pill to the currently focused workspace.
# When a Claude Code session in another pane becomes running, its pill can then
# appear in the sidebar of the unrelated workspace the user is viewing.
# Always pass `--workspace $CMUX_WORKSPACE_ID` explicitly. Cache WORKSPACE_ID with
# the panel in the second line of the per-session cache to avoid repeated resolution.

exec >/dev/null 2>&1
umask 077

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

# Save stdin JSON to a temporary file and extract session_id / hook_event_name.
# Use them for the CMUX_PANEL_ID fallback cache key and SessionEnd cache cleanup.
input_file=$(mktemp "$state_dir/hook-input.XXXXXX") || exit 0
trap 'rm -f "$input_file" "${sessions_tmp:-}"' EXIT INT TERM HUP
cat > "$input_file" 2>/dev/null

session_id=""
hook_event=""
hook_cwd=""
if command -v jq >/dev/null 2>&1; then
  session_id=$(jq -r '.session_id // .sessionId // .conversationId // empty' < "$input_file" 2>/dev/null)
  hook_event=$(jq -r '.hook_event_name // .hookEventName // empty' < "$input_file" 2>/dev/null)
  hook_cwd=$(jq -r '.cwd // (.workspacePaths[0]?) // empty' < "$input_file" 2>/dev/null)
fi

if [ -z "$hook_event" ]; then
  case "$state" in
    running)  hook_event="PreInvocation" ;;
    awaiting) hook_event="Notification" ;;
    idle)     hook_event="Stop" ;;
    clear)    hook_event="SessionEnd" ;;
  esac
fi

# Automated and summary sessions (claude-auto / codex-auto / agy-auto, etc.) have
# no cmux workspace, so do not update their session mappings or pills.
if [ -n "${CCDASH_AUTO:-}" ] || [ -n "${CLAUDE_AUTO:-}" ]; then
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  auto_indicator=$(jq -r '[(.transcriptPath // ""), (.artifactDirectoryPath // ""), (.cwd // "")] | join(" ")' < "$input_file" 2>/dev/null)
  case "$auto_indicator" in
    *-auto*|*antigravity-cli-auto*|*/.gemini/config*) exit 0 ;;
  esac
fi

# The detached clear child has /dev/null as stdin. Pass the values already extracted
# by the parent through environment variables for sessions JSON upserts and deletion.
[ -n "$session_id" ] || session_id="${CMUX_STATUS_HOOK_SID:-}"
[ -n "$hook_event" ] || hook_event="${CMUX_STATUS_HOOK_EVENT:-}"
[ -n "$hook_cwd" ] || hook_cwd="${CMUX_STATUS_HOOK_CWD:-$PWD}"

# Handle cmux 0.61+ not passing CMUX_PANEL_ID with a per-session cache and cmux identify.
# If the cache is missing, build it using caller-based identification. This is safe
# for any hook event, not just SessionStart: caller refers to the invoking process's
# pane, unlike focused, which can refer to another pane the user has brought forward.
# Do not restrict cache creation to SessionStart: otherwise updating this script
# during an existing session could leave that session without a cache indefinitely.
panel_cache=""
if [ -n "$session_id" ]; then
  panel_cache="$state_dir/session-${session_id}.panel"
fi

# Read the existing cache: line 1 is the surface UUID; line 2 is the workspace UUID.
# The old single-line format causes set-status calls without a workspace, producing
# this bug. Treat caches without a workspace UUID as invalid and regenerate them.
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

# Try the cache when environment variables did not supply the values.
if [ -z "${CMUX_PANEL_ID:-}" ] || [ -z "${CMUX_WORKSPACE_ID:-}" ]; then
  # Force cache regeneration on SessionStart: an older broken implementation
  # may have stored a UUID belonging to a different workspace.
  [ "$hook_event" = "SessionStart" ] && [ -n "$panel_cache" ] && rm -f "$panel_cache"
  load_panel_cache
fi

# Follow this PID through cmux top surface/pane/workspace references, resolve UUIDs,
# and write the cache. If resolution fails, leave it unchanged for the caller to handle.
resolve_and_cache_panel() {
  [ -n "$panel_cache" ] || return 0
  # Choose starting PIDs: attached client PIDs inside tmux, otherwise this hook's PID.
  # TERM_PROGRAM / __CFBundleIdentifier cannot be trusted through the tmux server,
  # so determine whether a client belongs to cmux by whether cmux top matches it.
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

  # 1. Obtain the process / surface / pane / workspace hierarchy from cmux top.
  #    Walk ancestors from each starting PID until a `process <PID> <surface:N>`
  #    row identifies the surface reference.
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

  # 2. Follow surface -> pane -> workspace in the TSV to identify the workspace.
  #    Surface references (`surface:N`) are local to a workspace and can repeat
  #    in another workspace. Blindly walking workspace.list and matching only `ref`
  #    when resolving the UUID can therefore select the wrong pane.
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

# Claude Code gives SessionEnd less than a second. Sleeping on lock contention can
# trigger "Hook cancelled". For clear, immediately return control to the parent
# and perform the work in a detached child using the race-safe lock.
# The child can finish set-status calls to the cmux daemon after the parent exits.
# Pass CMUX_PANEL_ID / CMUX_WORKSPACE_ID through the child's environment because
# its stdin becomes /dev/null and it cannot resolve them again through the cache.
if [ "$state" = clear ] && [ -z "${CMUX_STATUS_HOOK_BG:-}" ]; then
  # Also clear the panel cache on SessionEnd; the next SessionStart will rebuild it.
  [ "$hook_event" = "SessionEnd" ] && [ -n "$panel_cache" ] && rm -f "$panel_cache"
  CMUX_STATUS_HOOK_BG=1 CMUX_PANEL_ID="$CMUX_PANEL_ID" \
    CMUX_WORKSPACE_ID="$CMUX_WORKSPACE_ID" \
    CMUX_STATUS_HOOK_SID="$session_id" \
    CMUX_STATUS_HOOK_EVENT="$hook_event" \
    CMUX_STATUS_HOOK_CWD="$hook_cwd" \
    nohup "$0" "$@" </dev/null >/dev/null 2>&1 &
  exit 0
fi

# Persist the sessionId -> cmux surface/workspace UUID mapping ourselves
# (setup issue #3). cmux automation.claudeCodeIntegration is false to avoid the
# stuck claude_code pill bug (upstream #1027), so cmux no longer updates
# ~/.cmuxterm/claude-hook-sessions.json. Instead, upsert only the `sessions` map
# actually read by consumers (ccdash / issues-site), using a compatible schema subset
# (sessionId / workspaceId / surfaceId / cwd / agentLifecycle /
# startedAt / updatedAt) in ~/.claude/cmux/hook-sessions.json.
# Match upstream cmux agentLifecycle values: running / needsInput / idle.
# Remove entries on SessionEnd. Prune entries whose SessionEnd was missed because
# of a crash or a forced workspace close during subsequent writes (issue #5):
#   - Liveness pruning: obtain live surface UUIDs with workspace.list + surface.list
#     and remove entries whose surfaceId is absent. Throttle RPC calls (~200 ms)
#     to once every 60 seconds. Skip pruning on lookup failure to avoid accidentally
#     removing all entries, following the zsh sweeper's safeguard. Fetch the live set
#     under the per-file lock so every previously written entry predates the lookup;
#     a stale live set cannot incorrectly prune newly created sessions.
#   - Seven-day expiration: fall back to this if liveness pruning cannot run, such
#     as when the cmux daemon is unreachable (the same lifetime as cmux pruneExpired).
# Call this only at the final set-status stage so the caller's existing early exits
# for non-cmux environments, old events, or unchanged state also apply here.
sync_sessions_json() {
  [ -n "$session_id" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  sessions_file="${CMUX_HOOK_SESSIONS_FILE:-$HOME/.claude/cmux/hook-sessions.json}"
  mkdir -p "$(dirname "$sessions_file")" 2>/dev/null || return 0

  case "$state" in
    running)  lifecycle=running ;;
    awaiting) lifecycle=needsInput ;;
    idle)     lifecycle=idle ;;
    clear)
      # Upsert SessionStart as idle; remove the entry on SessionEnd.
      if [ "$hook_event" = "SessionEnd" ]; then lifecycle=ended; else lifecycle=idle; fi ;;
    *) return 0 ;;
  esac

  # Per-file mutex, separate from the state-file lock. Locks older than one second are stale.
  sessions_lock="$sessions_file.lock.d"
  s_attempts=0
  while ! mkdir "$sessions_lock" 2>/dev/null; do
    s_attempts=$((s_attempts + 1))
    if [ "$s_attempts" -gt 50 ]; then
      rm -rf "$sessions_lock" 2>/dev/null
      s_attempts=0
    fi
    sleep 0.02
  done

  now=$(date +%s)

  # Live surface UUIDs for liveness pruning, as a JSON array. null means skip
  # liveness pruning this time because of throttling or an RPC failure.
  live_json=null
  prune_marker="$sessions_file.pruned"
  last_prune=$(cat "$prune_marker" 2>/dev/null)
  case "$last_prune" in ''|*[!0-9]*) last_prune=0 ;; esac
  if [ $((now - last_prune)) -ge 60 ]; then
    ws_ids=$(cmux rpc workspace.list "{}" 2>/dev/null \
      | jq -r '.workspaces[]?.id // empty' 2>/dev/null)
    if [ -n "$ws_ids" ]; then
      live_ids=""
      fetch_ok=1
      for ws_id in $ws_ids; do
        sf_json=$(cmux rpc surface.list "{\"workspace_id\":\"$ws_id\"}" 2>/dev/null)
        if ! printf '%s' "$sf_json" | jq -e '.surfaces' >/dev/null 2>&1; then
          fetch_ok=0
          break
        fi
        live_ids="$live_ids
$(printf '%s' "$sf_json" | jq -r '.surfaces[]?.id // empty' 2>/dev/null)"
      done
      # An empty surface list is unexpected because this hook is itself in a surface.
      # Skip pruning to avoid accidentally deleting every entry.
      [ -n "$(printf '%s' "$live_ids" | tr -d '[:space:]')" ] || fetch_ok=0
      if [ "$fetch_ok" = 1 ]; then
        live_json=$(printf '%s\n' "$live_ids" \
          | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null)
        [ -n "$live_json" ] || live_json=null
        [ "$live_json" = null ] || printf '%s' "$now" > "$prune_marker"
      fi
    fi
  fi

  sessions_tmp=$(mktemp "$sessions_file.tmp.XXXXXX") || {
    rmdir "$sessions_lock" 2>/dev/null
    return 0
  }
  base='{"version":1,"sessions":{}}'
  [ -s "$sessions_file" ] && base=$(cat "$sessions_file" 2>/dev/null)
  if [ "$lifecycle" = ended ]; then
    printf '%s' "$base" | jq --arg sid "$session_id" --argjson now "$now" \
      --argjson live "$live_json" '
      {version: 1,
       sessions: ((.sessions // {})
         | with_entries((.value.surfaceId // "") as $s
             | select(.key != $sid
                 and (.value.updatedAt // 0) > ($now - 604800)
                 and ($live == null or ($live | index($s)) != null))))}
    ' > "$sessions_tmp" 2>/dev/null
  else
    printf '%s' "$base" | jq --arg sid "$session_id" --arg ws "$CMUX_WORKSPACE_ID" \
      --arg sf "$CMUX_PANEL_ID" --arg cwd "$hook_cwd" --arg lc "$lifecycle" \
      --argjson now "$now" --argjson live "$live_json" '
      {version: 1,
       sessions: ((.sessions // {})
         | .[$sid] = ((.[$sid] // {startedAt: $now})
             + {sessionId: $sid, workspaceId: $ws, surfaceId: $sf, cwd: $cwd,
                agentLifecycle: $lc, updatedAt: $now})
         | with_entries((.value.surfaceId // "") as $s
             | select((.value.updatedAt // 0) > ($now - 604800)
                 and ($live == null or ($live | index($s)) != null))))}
    ' > "$sessions_tmp" 2>/dev/null
  fi
  # If jq fails (for example on corrupt existing JSON), preserve the original file
  # and remove only the empty temporary file. A later successful write can recover.
  if [ -s "$sessions_tmp" ]; then
    mv "$sessions_tmp" "$sessions_file"
  else
    rm -f "$sessions_tmp"
    # Reinitialize here if corrupt existing JSON could not be parsed by jq.
    if [ -s "$sessions_file" ] && ! jq empty "$sessions_file" >/dev/null 2>&1; then
      printf '{"version":1,"sessions":{}}\n' > "$sessions_file"
    fi
  fi
  rmdir "$sessions_lock" 2>/dev/null
}

# If basename "$PWD" is empty (for example when PWD is unset), cmux set-status fails
# with an empty value, leaving the previous pill frozen or removed as stale.
# Fall back to "." to keep a nonempty pill label.
label=$(basename "$PWD" 2>/dev/null)
[ -n "$label" ] || label="."

state_file="$state_dir/$CMUX_PANEL_ID"
time_file="$state_file.time"
lock_dir="$state_file.lock"
key="cwd_${CMUX_PANEL_ID}"

# Capture event time before lock contention to account for lock order differing from event order.
my_time=$(perl -MTime::HiRes -e 'printf "%d", Time::HiRes::time*1e9' 2>/dev/null)
[ -n "$my_time" ] || my_time=$(($(date +%s) * 1000000000))

# Per-pane mutex (mkdir is atomic on POSIX). Locks older than one second are stale.
attempts=0
while ! mkdir "$lock_dir" 2>/dev/null; do
  attempts=$((attempts + 1))
  if [ "$attempts" -gt 50 ]; then
    rm -rf "$lock_dir" 2>/dev/null
    attempts=0
  fi
  sleep 0.02
done
trap 'rmdir "$lock_dir" 2>/dev/null; rm -f "$input_file" "${sessions_tmp:-}"' EXIT INT TERM HUP

# Skip set-status if a newer event has already been applied.
existing_time=$(cat "$time_file" 2>/dev/null)
[ -n "$existing_time" ] || existing_time=0
is_newer=$(awk -v a="$my_time" -v b="$existing_time" 'BEGIN{print (a+0 > b+0) ? 1 : 0}')
[ "$is_newer" = 1 ] || exit 0

# Record this timestamp to block older hooks arriving later. New events from the next
# SessionStart onward have my_time greater than this value and can overwrite it normally.
printf '%s\n' "$my_time" > "$time_file"

# Update the state file under the lock. PreToolUse fires for every tool call, so skip
# both the state-file write and cmux call when the state is already unchanged.
existing_state=$(cat "$state_file" 2>/dev/null)
if [ "$state" = clear ]; then
  # SessionEnd removes state_file to restore the folder icon. time_file retains
  # my_time, preventing older running/awaiting hooks still in progress from
  # overwriting the pill afterward.
  rm -f "$state_file"
elif [ "$state" = "$existing_state" ]; then
  exit 0
else
  printf '%s\n' "$state" > "$state_file"
fi

# Release the lock before calling the daemon so cmux set-status socket I/O does not
# hold the lock for an extended period and delay subsequent hooks.
rmdir "$lock_dir" 2>/dev/null
trap 'rm -f "$input_file" "${sessions_tmp:-}"' EXIT INT TERM HUP

if [ "$state" = clear ]; then
  cmux set-status "$key" "$label" --workspace "$CMUX_WORKSPACE_ID" --icon "$icon"
  sync_sessions_json
  exit 0
fi

# Remove any per-pane Claude pill left by an older version.
cmux clear-status "claude_${CMUX_PANEL_ID}" --workspace "$CMUX_WORKSPACE_ID" 2>/dev/null

cmux set-status "$key" "$label" --workspace "$CMUX_WORKSPACE_ID" \
  --icon "$icon" --color "$color"
sync_sessions_json
exit 0
