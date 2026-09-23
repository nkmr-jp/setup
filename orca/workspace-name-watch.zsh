#!/bin/zsh -f
# Reset an Orca workspace name to its branch after its last terminal closes.
#
# Usage: workspace-name-watch.zsh <shell-pid> <worktree-id>
#
# Started detached by zsh/orca.zsh. Orca force-kills terminal shells, so zshexit
# and signal traps never run; this process polls the shell PID instead.
# Optional environment:
#   ORCA_NAME_WATCH_POLL_CS  PID poll interval in centiseconds (default 200)
#   ORCA_NAME_WATCH_SETTLE   seconds to wait after the shell exits (default 3)
#   ORCA_NAME_WATCH_LOG      append decisions to this file

emulate -L zsh
zmodload zsh/zselect

local shell_pid=$1 worktree_id=$2
[[ -n $shell_pid && -n $worktree_id ]] || exit 2

_log() {
  [[ -n ${ORCA_NAME_WATCH_LOG-} ]] && print -r -- "$(date '+%H:%M:%S') [$$] $*" >> "$ORCA_NAME_WATCH_LOG"
  return 0
}

# The dead terminal's identity must not leak into the CLI calls.
unset ORCA_TERMINAL_HANDLE ORCA_PANE_KEY ORCA_TAB_ID

while kill -0 "$shell_pid" 2>/dev/null; do
  zselect -t "${ORCA_NAME_WATCH_POLL_CS:-200}"
done
_log "shell $shell_pid exited"
zselect -t $(( ${ORCA_NAME_WATCH_SETTLE:-3} * 100 ))

local selector="id:$worktree_id" list mode
if ! list=$(orca terminal list --worktree "$selector" --json 2>/dev/null); then
  _log "terminal list failed"
  exit 0
fi
if ! jq -e '.ok == true and .result.totalCount == 0 and .result.truncated == false' <<<"$list" >/dev/null; then
  _log "terminals remain: $(jq -c '.result.totalCount' <<<"$list" 2>/dev/null)"
  exit 0
fi

mode=$(orca worktree show --worktree "$selector" --json 2>/dev/null | jq -r '.result.worktree.displayNameMode // empty')
if [[ $mode != fixed ]]; then
  _log "name mode is '$mode'; nothing to reset"
  exit 0
fi

# A whitespace-only name unpins the label; an empty string is ignored by the CLI.
if orca worktree set --worktree "$selector" --display-name " " --json >/dev/null 2>&1; then
  _log "reset name for $worktree_id"
else
  _log "reset failed for $worktree_id"
fi
