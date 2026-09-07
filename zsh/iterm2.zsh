#!/usr/bin/env zsh
# ============================================================
# iTerm2 Integration
# ============================================================
# Integrated iTerm2 subtitle, tab title, and directory restoration.
#
# Required settings:
#   1. Set Settings > Profiles > General > Title to \(user.dirIcon) \(user.currentDir).
#   2. Set Settings > Profiles > General > Subtitle to \(user.branch).
#   3. Enable Settings > Profiles > Terminal > Allow session to set title.
#
# References:
#   - https://iterm2.com/documentation-shell-integration.html
#   - https://iterm2.com/shell_integration/zsh
# ============================================================

# Run only in interactive shells.
if [[ ! -o interactive ]]; then
  return
fi

# Do not run in tmux, screen, or dumb terminals.
if [[ "${ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX-}${TERM}" == "tmux-256color" ]] ||
   [[ "${ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX-}${TERM}" == "screen" ]] ||
   [[ "$TERM" == "linux" ]] || [[ "$TERM" == "dumb" ]]; then
  return
fi

# Prevent loading twice.
if [[ "${ITERM_SHELL_INTEGRATION_INSTALLED-}" != "" ]]; then
  return
fi
ITERM_SHELL_INTEGRATION_INSTALLED=Yes

# ============================================================
# Helper functions.
# ============================================================

_get_git_branch() {
  local dir="$1"
  # Output nothing for detached HEAD.
  git -C "$dir" -c core.useReplaceRefs=false -c advice.detachedHead=false \
    symbolic-ref --short HEAD 2>/dev/null
}

# Return the original repository path for a worktree; otherwise return the path unchanged.
_iterm2_resolve_repo_path() {
  local dir="$1"
  if [[ "$dir" == *"-worktrees/"* ]]; then
    echo "${dir%%-worktrees/*}"
  else
    echo "$dir"
  fi
}

# ============================================================
# Subtitle components.
# ============================================================

_iterm2_directory_name() {
  local dir="$1"
  if [ -z "$dir" ]; then
    return
  fi

  dir="$(_iterm2_resolve_repo_path "$dir")"

  local dir_name="${dir##*/}"

  # gwt.zsh worktree naming convention: repo-wt-branch.
  if [[ "$dir_name" == *"-wt-"* ]]; then
    dir_name="${dir_name%%-wt-*}"
  fi

  echo "$dir_name"
}

_iterm2_git_branch_label() {
  local dir="$1"
  local branch
  # No _is_git_repo check needed: non-Git directories return an empty string.
  branch=$(_get_git_branch "$dir")
  if [ -z "$branch" ]; then
    return
  fi

  # Use the wt: prefix to distinguish worktrees.
  if [[ "$dir" == *"-worktrees/"* ]]; then
    branch="wt:$branch"
  fi

  echo "$branch"
}

# ============================================================
# Send information to iTerm2.
# ============================================================

# Required to restore the same directory in new tabs and panes.
_iterm2_send_current_dir() {
  printf "\033]1337;CurrentDir=%s\007" "$PWD"
}

_iterm2_set_user_var() {
  printf "\033]1337;SetUserVar=%s=%s\007" "$1" "$(printf '%s' "$2" | base64)"
}

_iterm2_set_user_current_dir() {
  _iterm2_set_user_var currentDir "$(_iterm2_directory_name "$PWD")"
}

_iterm2_set_user_branch() {
  _iterm2_set_user_var branch "$(_iterm2_git_branch_label "$PWD")"
}

_iterm2_hash_icon() {
  local name="$1"
  local icons=(
    "🔴" "🟠" "🟡" "🟢" "🔵" "🟣" "🟤" "⚫" "⚪"
    "🔶" "🔷" "🔸" "🔹" "💠" "🔲" "🔳"
    "❤️" "🧡" "💛" "💚" "💙" "💜" "🖤" "🤍" "🤎"
    "♠️" "♣️" "♥️" "♦️"
    "⭐" "🌙" "☀️" "⚡" "🔥" "💧" "🌊" "🍀"
    "🎯" "🎪" "🎭" "🎨" "🎲" "🎵" "🎸" "🎺"
    "🌸" "🌺" "🌻" "🌷" "🌹" "🍁" "🍂" "🌿"
    "🍎" "🍊" "🍋" "🍇" "🍉" "🍓" "🫐" "🥝"
    "🐝" "🦋" "🐞" "🦊" "🐧" "🦉" "🐙" "🦑"
    "🏔️" "🌋" "🏝️" "🗻" "🌈" "❄️" "🌪️" "☁️"
    "💎" "🔮" "🪐" "🛸" "🚀" "⚓" "🧲" "🔔"
    "📐" "📌" "✏️" "🖊️" "🧪" "🔬" "🔭" "🧬"
  )
  local hash=$(printf '%s' "$name" | cksum | awk '{print $1}')
  local index=$(( hash % ${#icons[@]} + 1 ))
  echo "${icons[$index]}"
}

_iterm2_directory_icon() {
  local dir="$1"
  [[ -z "$dir" ]] && return

  _iterm2_hash_icon "$(_iterm2_directory_name "$dir")"
}

_iterm2_dir_icon_cache=""
_iterm2_dir_icon_cache_dir=""

_iterm2_set_user_dir_icon() {
  if [[ "$_iterm2_dir_icon_cache_dir" != "$PWD" ]]; then
    _iterm2_dir_icon_cache_dir="$PWD"
    _iterm2_dir_icon_cache="$(_iterm2_directory_icon "$PWD")"
    _iterm2_set_user_var dirIcon "$_iterm2_dir_icon_cache"
  fi
}

_iterm2_set_user_last_prompt() {
  local dir_name="$(_iterm2_directory_name "$PWD")"
  [[ -z "$dir_name" ]] && dir_name="${PWD##*/}"

  _iterm2_set_user_var lastPrompt "$dir_name"
  printf "\033]0;%s\007" "$dir_name"
}

# ============================================================
# Update lastPrompt in real time with fswatch.
# ============================================================

_iterm2_prompt_watcher_pid=""

_iterm2_start_prompt_watcher() {
  [[ -z "${ITERM_SESSION_ID-}" ]] && return
  command -v fswatch >/dev/null 2>&1 || return

  local history_file="$HOME/.prompt-line/history.jsonl"
  local session_id="${ITERM_SESSION_ID#*:}"
  local my_tty
  my_tty=$(tty) || return

  (
    local last_count
    last_count=$(wc -l < "$history_file" 2>/dev/null || echo 0)

    fswatch --event Updated -o "$history_file" 2>/dev/null | while read -r _; do
      local current_count
      current_count=$(wc -l < "$history_file" 2>/dev/null || echo 0)
      (( current_count <= last_count )) && { last_count=$current_count; continue; }

      # Read only newly appended lines belonging to this session.
      local new_lines=$((current_count - last_count))
      local text
      text=$(tail -n "$new_lines" "$history_file" \
        | jq -r --arg sid "$session_id" \
          'select(.itermSessionId == $sid) | .text | gsub("\n"; " ")' 2>/dev/null \
        | tail -1)
      last_count=$current_count
      [[ -z "$text" ]] && continue

      _iterm2_set_user_var lastPrompt " > $text" > "$my_tty"
      printf "\033]0;%s\007" " > $text" > "$my_tty"
    done
  ) &!
  _iterm2_prompt_watcher_pid=$!
}

_iterm2_stop_prompt_watcher() {
  [[ -n "$_iterm2_prompt_watcher_pid" ]] && kill "$_iterm2_prompt_watcher_pid" 2>/dev/null
  _iterm2_prompt_watcher_pid=""
}

trap '_iterm2_stop_prompt_watcher' EXIT

# ============================================================
# precmd hook (runs before every prompt).
# ============================================================

_iterm2_precmd() {
#  echo "_iterm2_precmd"
  _iterm2_send_current_dir
  _iterm2_set_user_current_dir
  _iterm2_set_user_branch
  _iterm2_set_user_dir_icon
  _iterm2_set_user_last_prompt
  # CWD for Smart Selection: use a user variable because CWD polling overwrites path.
  _iterm2_set_user_var gwtCwd "$PWD"
}

# precmd_functions: register the hook in this array.
[[ -z ${precmd_functions-} ]] && precmd_functions=()
precmd_functions=($precmd_functions _iterm2_precmd)

# Send information on initial load too, so the tab updates immediately after shell startup.
_iterm2_precmd

# Start real-time monitoring with fswatch.
#_iterm2_start_prompt_watcher
