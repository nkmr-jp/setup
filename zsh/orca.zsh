#!/usr/bin/env zsh
# ============================================================
# Orca Integration
# ============================================================
# Reset the Orca sidebar workspace name to the branch name after the last
# terminal in the workspace closes. See orca/workspace-name-watch.zsh.
# Let Claude Code's fullscreen renderer use scroll regions in Orca.
# ============================================================

# Returns 0 only for a top-level interactive shell in an Orca terminal.
# TERM_PROGRAM is the main gate: ORCA_* variables leak into apps started from
# an Orca shell, but other terminals override TERM_PROGRAM.
_orca_should_watch_workspace_name() {
  [[ -o interactive ]] || return 1
  [[ ${TERM_PROGRAM-} == Orca ]] || return 1
  [[ -n ${ORCA_TERMINAL_HANDLE-} && -n ${ORCA_WORKTREE_ID-} ]] || return 1
  # Nested shells in the same terminal share the handle; one watcher is enough.
  [[ ${_ORCA_NAME_WATCH_HANDLE-} != "$ORCA_TERMINAL_HANDLE" ]] || return 1
  (( $+commands[orca] && $+commands[jq] && $+commands[perl] )) || return 1
}

_orca_start_workspace_name_watch() {
  _orca_should_watch_workspace_name || return 0
  export _ORCA_NAME_WATCH_HANDLE=$ORCA_TERMINAL_HANDLE
  # Fork and setsid so the watcher leaves the terminal's process tree, group, and
  # session; Orca kills those when the terminal closes.
  perl -MPOSIX -e 'fork and exit; POSIX::setsid(); exec @ARGV or exit 1' \
    zsh -f "$SETUP_DIR/orca/workspace-name-watch.zsh" "$$" "$ORCA_WORKTREE_ID" \
    </dev/null >/dev/null 2>&1
}

# Claude Code uses scroll regions only in terminals it knows support
# synchronized output, and Orca is not one: without them each scroll step
# redraws the whole screen (stablyai/orca#21960). settings.json's env is read
# too late for that check, so it is exported here.
[[ ${TERM_PROGRAM-} == Orca ]] && export CLAUDE_CODE_FORCE_SYNC_OUTPUT=1

_orca_start_workspace_name_watch
