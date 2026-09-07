#!/usr/bin/env zsh
# Show a per-pane cwd pill in the cmux sidebar, using the basename of the current
# directory. The icon follows the Claude Code state that claude-status-hook.sh
# writes to ${TMPDIR}/cmux-pane-state/<panel-id>.
#
#   running  -> bolt.fill (#4C8DFF)  UserPromptSubmit / PreToolUse
#   awaiting -> bell.fill (#FF9500)  Notification
#   idle     -> pause.fill (#8E8E93) Stop (response complete; awaiting the next input)
#   none     -> folder               default when the state file is absent
#
# Run precmd in the background with &! to avoid delaying the prompt.
# An independent sweeper spawned by each shell scans the workspace every few
# seconds and removes pills left behind by forcibly closed panes.
#
# Pills belong to a workspace (`workspace:<WS_UUID>:tag:cwd_<SURFACE>`).
# Without --workspace, `cmux set-status` uses CMUX_WORKSPACE_ID, but cmux 0.61+
# does not pass that environment variable to child processes. This can place
# a pill in whichever workspace currently has focus.
# Resolve this shell's surface and workspace UUIDs once at startup using cmux top,
# then always pass --workspace $_CMUX_WORKSPACE_ID explicitly to subsequent
# `cmux set-status` and `clear-status` calls.

typeset -g _CMUX_LAST_SIG=""
typeset -g _CMUX_PANEL_ID=""
typeset -g _CMUX_WORKSPACE_ID=""
typeset -gra _CMUX_PILL_PREFIXES=(cwd_ claude_ run_)  # claude_/run_: sweep legacy pills

# Call cmux top once to resolve surface_ref / pane_ref / ws_ref from this PID,
# then convert them to UUIDs with workspace.list / surface.list. Do nothing on
# failure (a static default folder icon is acceptable). This is the same TSV
# walk as claude-status-hook.sh, rewritten in zsh.
_cmux_resolve_ids() {
  (( ${+commands[cmux]} )) || return 1
  [[ "${TERM_PROGRAM:-}" == ghostty ]] || return 1
  [[ "${__CFBundleIdentifier:-}" == com.cmuxterm.app ]] || return 1
  (( ${+commands[jq]} )) || return 1

  local cmux_cli="${CMUX_BUNDLED_CLI_PATH:-/Applications/cmux.app/Contents/Resources/bin/cmux}"
  [[ -x "$cmux_cli" ]] || cmux_cli="${commands[cmux]}"
  [[ -x "$cmux_cli" ]] || return 1

  local top_tsv
  top_tsv=$("$cmux_cli" top --all --processes --format tsv 2>/dev/null) || return 1
  [[ -n "$top_tsv" ]] || return 1

  local surface_ref="" probe_pid=$$ probe_attempts=0 next_pid
  while [[ -n "$probe_pid" && "$probe_pid" != 0 && "$probe_pid" != 1 \
        && "$probe_attempts" -lt 20 ]]; do
    surface_ref=$(/usr/bin/awk -F'\t' -v pid="$probe_pid" '
      $4 == "process" && $5 == pid && $6 ~ /^surface:/ { print $6; exit }' <<<"$top_tsv")
    [[ -n "$surface_ref" ]] && break
    next_pid=$(ps -o ppid= -p "$probe_pid" 2>/dev/null | tr -d ' ')
    [[ -z "$next_pid" || "$next_pid" == "$probe_pid" ]] && break
    probe_pid="$next_pid"
    (( probe_attempts++ ))
  done
  [[ -n "$surface_ref" ]] || return 1

  local pane_ref ws_ref
  pane_ref=$(/usr/bin/awk -F'\t' -v sref="$surface_ref" '
    $4 == "surface" && $5 == sref && $6 ~ /^pane:/ { print $6; exit }' <<<"$top_tsv")
  [[ -n "$pane_ref" ]] || return 1
  ws_ref=$(/usr/bin/awk -F'\t' -v pref="$pane_ref" '
    $4 == "pane" && $5 == pref && $6 ~ /^workspace:/ { print $6; exit }' <<<"$top_tsv")
  [[ -n "$ws_ref" ]] || return 1

  local ws_id
  ws_id=$("$cmux_cli" rpc workspace.list "{}" 2>/dev/null \
    | jq -r --arg ref "$ws_ref" \
      '.workspaces[]? | select(.ref == $ref) | .id // empty' 2>/dev/null \
    | head -n 1)
  [[ -n "$ws_id" ]] || return 1

  local panel_id
  panel_id=$("$cmux_cli" rpc surface.list "{\"workspace_id\":\"$ws_id\"}" 2>/dev/null \
    | jq -r --arg ref "$surface_ref" \
      '.surfaces[]? | select(.ref == $ref) | .id // empty' 2>/dev/null \
    | head -n 1)
  [[ -n "$panel_id" ]] || return 1

  _CMUX_PANEL_ID="$panel_id"
  _CMUX_WORKSPACE_ID="$ws_id"
  return 0
}

_cmux_update_cwd_status() {
  (( ${+commands[cmux]} )) || return 0
  [[ -n "$_CMUX_PANEL_ID" && -n "$_CMUX_WORKSPACE_ID" ]] || return 0
  local sf="${TMPDIR:-/tmp}/cmux-pane-state/${_CMUX_PANEL_ID}"
  local state="" icon=folder color=""
  [[ -r "$sf" ]] && read -r state < "$sf"
  case "$state" in
    running)  icon=bolt.fill;  color='#4C8DFF' ;;
    awaiting) icon=bell.fill;  color='#FF9500' ;;
    idle)     icon=pause.fill; color='#8E8E93' ;;
  esac
  local sig="${PWD}|${state}"
  [[ "$sig" == "$_CMUX_LAST_SIG" ]] && return
  _CMUX_LAST_SIG="$sig"
  local -a args=("cwd_${_CMUX_PANEL_ID}" "${PWD:t}"
    --workspace "$_CMUX_WORKSPACE_ID" --icon "$icon")
  [[ -n "$color" ]] && args+=(--color "$color")
  cmux set-status "${args[@]}" >/dev/null 2>&1 &!
}

_cmux_equalize_splits() {
  # Equalize splits in this workspace when a new pane starts.
  # workspace.equalize_splits is a no-op without splits or when already equal,
  # so calling it every time is harmless. Set CMUX_EQUALIZE_SPLITS=0 to disable.
  (( ${+commands[cmux]} )) || return 0
  [[ "${CMUX_EQUALIZE_SPLITS:-1}" != 0 ]] || return 0
  [[ -n "$_CMUX_WORKSPACE_ID" ]] || return 0
  cmux rpc workspace.equalize_splits \
    "{\"workspace_id\":\"$_CMUX_WORKSPACE_ID\"}" >/dev/null 2>&1 &!
}

_cmux_equalize_splits_after_close() {
  # Equalize the remaining workspace splits just after closing a pane.
  # cmux removes the pane from its model shortly after the shell exits, so retry
  # at short intervals. equalize_splits is idempotent and safe to call repeatedly.
  # Spawn a disowned child to survive shell exit and issue the RPC calls.
  (( ${+commands[cmux]} )) || return 0
  [[ "${CMUX_EQUALIZE_SPLITS:-1}" != 0 ]] || return 0
  [[ -n "$_CMUX_WORKSPACE_ID" ]] || return 0
  local ws="$_CMUX_WORKSPACE_ID"
  local cmux_bin="${commands[cmux]}"
  local delays="${CMUX_EQUALIZE_AFTER_CLOSE_DELAYS:-0.1 0.4}"
  {
    trap '' HUP INT TERM PIPE QUIT
    exec </dev/null >/dev/null 2>&1
    local d
    for d in ${=delays}; do
      sleep "$d"
      "$cmux_bin" rpc workspace.equalize_splits \
        "{\"workspace_id\":\"$ws\"}"
    done
  } &!
}

_cmux_clear_pane_status() {
  # Run synchronously from zshexit; &! would not be reaped before shell exit.
  (( ${+commands[cmux]} )) || return 0
  [[ -n "$_CMUX_PANEL_ID" && -n "$_CMUX_WORKSPACE_ID" ]] || return 0
  local p
  for p in "${_CMUX_PILL_PREFIXES[@]}"; do
    cmux clear-status "${p}${_CMUX_PANEL_ID}" \
      --workspace "$_CMUX_WORKSPACE_ID" >/dev/null 2>&1
  done
  local sd="${TMPDIR:-/tmp}/cmux-pane-state"
  rm -rf "${sd}/${_CMUX_PANEL_ID}" "${sd}/${_CMUX_PANEL_ID}.time" \
    "${sd}/${_CMUX_PANEL_ID}.lock" 2>/dev/null
}

_cmux_spawn_gc_sweeper() {
  (( ${+commands[cmux]} )) || return 0
  [[ -n "$_CMUX_WORKSPACE_ID" ]] || return 0
  if [[ -n "${_CMUX_GC_SWEEPER_PID:-}" ]] \
       && kill -0 "$_CMUX_GC_SWEEPER_PID" 2>/dev/null; then
    return 0
  fi

  local shell_pid=$$
  local socket_path="${CMUX_SOCKET_PATH:-}"
  local cmux_bin="${commands[cmux]}"
  local interval="${CMUX_CWD_SWEEP_INTERVAL:-3}"
  local my_ws="$_CMUX_WORKSPACE_ID"
  local -a prefixes=("${_CMUX_PILL_PREFIXES[@]}")

  # Independent process that ignores HUP/INT/TERM to survive pane closure.
  # Sweep only pills in this shell's workspace. Scanning every workspace could
  # incorrectly delete pills managed by another shell in a different workspace.
  {
    trap '' HUP INT TERM PIPE QUIT
    exec </dev/null >/dev/null 2>&1
    while kill -0 "$shell_pid" 2>/dev/null; do
      [[ -z "$socket_path" || -S "$socket_path" ]] || break

      local -a pane_keys=() pane_uuids=()
      local line k p
      while IFS= read -r line; do
        k="${line%%=*}"
        for p in "${prefixes[@]}"; do
          [[ "$k" == ${p}* ]] && {
            pane_keys+=("$k"); pane_uuids+=("${k#$p}"); break
          }
        done
      done < <("$cmux_bin" list-status --workspace "$my_ws" 2>/dev/null)
      (( ${#pane_keys} == 0 )) && { sleep "$interval"; continue }

      # Get only surfaces in this workspace (cmux surface.list for one workspace).
      local sjson active_ids=$'\n'
      sjson="$("$cmux_bin" rpc surface.list \
        "{\"workspace_id\":\"$my_ws\"}" 2>/dev/null)"
      [[ -z "$sjson" ]] && { sleep "$interval"; continue }
      active_ids+="$(/usr/bin/awk -F'"' '/"id"[[:space:]]*:/{print $4}' \
        <<<"$sjson")"$'\n'

      # Skip failed workspace enumeration to avoid accidentally deleting every pill.
      [[ "$active_ids" == $'\n' ]] && { sleep "$interval"; continue }

      local i
      for (( i = 1; i <= ${#pane_keys}; i++ )); do
        [[ "$active_ids" == *$'\n'"${pane_uuids[i]}"$'\n'* ]] && continue
        "$cmux_bin" clear-status "${pane_keys[i]}" \
          --workspace "$my_ws" >/dev/null 2>&1
      done

      sleep "$interval"
    done
  } &!
  _CMUX_GC_SWEEPER_PID=$!
}

# Prefer existing cmux environment variables if present (for future versions that
# restore inheritance, or child shells receiving exports from a parent).
if [[ -n "${CMUX_PANEL_ID:-}" && -n "${CMUX_WORKSPACE_ID:-}" ]]; then
  _CMUX_PANEL_ID="$CMUX_PANEL_ID"
  _CMUX_WORKSPACE_ID="$CMUX_WORKSPACE_ID"
fi

# Register nothing in noninteractive zsh (zsh -c from the Bash tool, scripts, etc.).
# In particular, do not let zshexit remove the pane pill/state file on every subshell exit.
# The sweeper collects pills from forcibly closed panes every few seconds anyway.
if [[ -n "${ZSH_VERSION:-}" ]] && [[ -o interactive ]]; then
  # Start equalization immediately with the workspace_ref from cmux identify,
  # without waiting for expensive _cmux_resolve_ids (top + workspace.list + surface.list).
  # This saves roughly 100 ms increments after pane creation.
  if (( ${+commands[cmux]} )) && [[ "${CMUX_EQUALIZE_SPLITS:-1}" != 0 ]]; then
    {
      ws_ref=$(cmux identify --json 2>/dev/null \
        | /usr/bin/awk -F'"' '/"workspace_ref"[[:space:]]*:/ {print $4; exit}')
      [[ -n "$ws_ref" ]] && cmux rpc workspace.equalize_splits \
        "{\"workspace_id\":\"$ws_ref\"}" >/dev/null 2>&1
    } &!
  fi

  # Resolve this panel/workspace UUID once using cmux top.
  [[ -z "$_CMUX_PANEL_ID" || -z "$_CMUX_WORKSPACE_ID" ]] && _cmux_resolve_ids

  # Export for child processes such as claude-status-hook.sh.
  if [[ -n "$_CMUX_PANEL_ID" && -n "$_CMUX_WORKSPACE_ID" ]]; then
    export CMUX_PANEL_ID="$_CMUX_PANEL_ID"
    export CMUX_WORKSPACE_ID="$_CMUX_WORKSPACE_ID"
  fi

  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _cmux_update_cwd_status
  add-zsh-hook precmd _cmux_update_cwd_status
  add-zsh-hook zshexit _cmux_clear_pane_status
  add-zsh-hook zshexit _cmux_equalize_splits_after_close
  # Collect any legacy run_<panel> pill (one-time migration).
  if [[ -n "$_CMUX_PANEL_ID" && -n "$_CMUX_WORKSPACE_ID" ]] \
     && (( ${+commands[cmux]} )); then
    cmux clear-status "run_${_CMUX_PANEL_ID}" \
      --workspace "$_CMUX_WORKSPACE_ID" >/dev/null 2>&1 &!
  fi
  _cmux_update_cwd_status
  _cmux_spawn_gc_sweeper
  _cmux_equalize_splits
fi
