#!/bin/bash
# StatusLine script with session and git diff information
# Format: directory git_branch session_id model elapsed_time git_diff_stats
#
# Color Theme:
#   Default theme: Blue directory, gray branch, purple session/model, yellow time, green/red diff

set -euo pipefail

# ============================================================================
# Color Themes
# ============================================================================

# ANSI color codes (used in default theme)
readonly COLOR_BLUE='\033[34m'
readonly COLOR_GRAY='\033[90m'
readonly COLOR_DARK_GRAY='\033[38;5;238m'
readonly COLOR_PURPLE='\033[35m'
readonly COLOR_GREEN='\033[32m'
readonly COLOR_RED='\033[31m'
readonly COLOR_YELLOW='\033[93m'
readonly COLOR_ORANGE='\033[38;5;208m'
readonly COLOR_RESET='\033[0m'

# Theme definitions
# Returns theme colors in order: directory git_branch session_id model_name time git_diff_add git_diff_del git_untracked reset
get_theme_colors() {
  local theme="$1"

  # Default theme
  echo "$COLOR_BLUE $COLOR_GRAY $COLOR_PURPLE $COLOR_GRAY $COLOR_GRAY $COLOR_GREEN $COLOR_RED $COLOR_YELLOW $COLOR_RESET"
}

# Apply theme colors
apply_theme() {
  local theme="$1"
  local colors
  colors=$(get_theme_colors "$theme")

  # Parse colors array
  read -r THEME_DIR THEME_BRANCH THEME_SESSION THEME_MODEL THEME_TIME THEME_DIFF_ADD THEME_DIFF_DEL THEME_UNTRACKED THEME_RESET <<<"$colors"

  # Export for use in other functions
  export THEME_DIR THEME_BRANCH THEME_SESSION THEME_MODEL THEME_TIME THEME_DIFF_ADD THEME_DIFF_DEL THEME_UNTRACKED THEME_RESET
}

# ============================================================================
# Utility Functions
# ============================================================================

# Check if current terminal is iTerm2
is_iterm2() {
  # Exclude JetBrains terminals (GoLand, IntelliJ, etc.)
  if [ "${TERMINAL_EMULATOR:-}" = "JetBrains-JediTerm" ]; then
    return 1
  fi

  # Check TERM_PROGRAM environment variable (most reliable for iTerm2)
  [ "${TERM_PROGRAM:-}" = "iTerm.app" ] || [ "${LC_TERMINAL:-}" = "iTerm2" ]
}

# Check if directory is a git repository
is_git_repo() {
  local dir="$1"
  [ -n "$dir" ] && ([ -d "$dir/.git" ] || git -C "$dir" rev-parse --git-dir >/dev/null 2>&1)
}

# Get current git branch name
get_git_branch() {
  local dir="$1"
  git -C "$dir" -c core.useReplaceRefs=false -c advice.detachedHead=false \
    symbolic-ref --short HEAD 2>/dev/null || echo ""
}

# Get git diff statistics (added and deleted lines)
get_git_diff_stats() {
  local dir="$1"
  git -C "$dir" diff --numstat 2>/dev/null |
    awk '{added+=$1; deleted+=$2} END {print (added ? added : 0), (deleted ? deleted : 0)}'
}

# Get count of untracked files
get_untracked_files_count() {
  local dir="$1"
  local count
  count=$(git -C "$dir" status --porcelain 2>/dev/null | grep "^??" | wc -l | tr -d ' ')
  echo "${count:-0}"
}

# Get terminal width
get_terminal_width() {
  # Try to get terminal width, default to 80 if not available
  # Priority: 1. COLUMNS env var, 2. tput cols, 3. Default 80
  local width
  if [ -n "${COLUMNS:-}" ]; then
    width="${COLUMNS}"
  else
    width=$(tput cols 2>/dev/null || echo "80")
  fi
  echo "$width"
}

# Get session status from session-status.jsonl
# Returns: Status from the session-status.jsonl file for the current session
get_session_status() {
  local session_id="$1"
  local status_file="$HOME/.claude/session-status.jsonl"

  if [ -z "$session_id" ] || [ ! -f "$status_file" ]; then
    echo ""
    return
  fi

  # Get the latest status for the current session_id from JSONL file
  # JSONL files have one JSON object per line, so we grep for matching session_id
  # and get the last one (most recent)
  local status
  status=$(grep "\"session_id\":\"$session_id\"" "$status_file" 2>/dev/null | tail -1 | jq -r '.status // ""')

  if [ -n "$status" ] && [ "$status" != "null" ]; then
    echo "$status"
  else
    echo ""
  fi
}

# Get session prompt from session-status.jsonl
# Returns: Full prompt from the session-status.jsonl file for the current session
get_session_prompt() {
  local session_id="$1"
  local status_file="$HOME/.claude/session-status.jsonl"

  if [ -z "$session_id" ] || [ ! -f "$status_file" ]; then
    echo ""
    return
  fi

  # Get the latest prompt for the current session_id from JSONL file
  # Use full prompt instead of prompt_preview for dynamic truncation
  local prompt
  prompt=$(grep "\"session_id\":\"$session_id\"" "$status_file" 2>/dev/null | tail -1 | jq -r '.prompt // .prompt_preview // ""')

  if [ -n "$prompt" ] && [ "$prompt" != "null" ]; then
    echo "$prompt"
  else
    echo ""
  fi
}

# Get auto_commit setting from session-status.jsonl
# Returns: auto_commit value (true/false/null) for the current session
get_session_auto_commit() {
  local session_id="$1"
  local status_file="$HOME/.claude/session-status.jsonl"

  if [ -z "$session_id" ] || [ ! -f "$status_file" ]; then
    echo "null"
    return
  fi

  # Get the latest auto_commit for the current session_id from JSONL file
  local auto_commit
  auto_commit=$(grep "\"session_id\":\"$session_id\"" "$status_file" 2>/dev/null | tail -1 | jq -r '.auto_commit // "null"')

  if [ -n "$auto_commit" ]; then
    echo "$auto_commit"
  else
    echo "null"
  fi
}

# Get session timestamps from session-status.jsonl
# Returns: started_at and updated_at timestamps
get_session_timestamps() {
  local session_id="$1"
  local status_file="$HOME/.claude/session-status.jsonl"

  if [ -z "$session_id" ] || [ ! -f "$status_file" ]; then
    echo ""
    return
  fi

  # Get the session entry for the current session_id
  local entry
  entry=$(grep "\"session_id\":\"$session_id\"" "$status_file" 2>/dev/null | tail -1)

  if [ -n "$entry" ]; then
    local started_at updated_at
    started_at=$(echo "$entry" | jq -r '.started_at // ""')
    updated_at=$(echo "$entry" | jq -r '.updated_at // ""')
    echo "$started_at $updated_at"
  fi
}

# Get issue identifier from cclinear sessions.jsonl
# Returns: Issue identifier (e.g., TOOLS-329) for the current session
get_issue_identifier() {
  local session_id="$1"
  local sessions_file="$HOME/.config/cclinear/sessions.jsonl"

  if [ -z "$session_id" ] || [ ! -f "$sessions_file" ]; then
    echo ""
    return
  fi

  # Get the issue identifier for the current session_id from JSONL file
  local issue_identifier
  issue_identifier=$(grep "\"sessionId\":\"$session_id\"" "$sessions_file" 2>/dev/null | tail -1 | jq -r '.issueIdentifier // ""')

  if [ -n "$issue_identifier" ] && [ "$issue_identifier" != "null" ]; then
    echo "$issue_identifier"
  else
    echo ""
  fi
}

# Parse ISO 8601 timestamp to epoch seconds
parse_timestamp() {
  local timestamp="$1"
  local session_time="${timestamp:0:19}"
  local epoch=""

  # Check if timestamp is UTC or has timezone offset
  if [[ "$timestamp" == *"Z" ]] || [[ "$timestamp" =~ [+-][0-9]{2}:[0-9]{2}$ ]]; then
    # UTC timestamp - parse with TZ=UTC (BSD date for macOS)
    epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$session_time" +%s 2>/dev/null)
  else
    # Local timestamp (BSD date)
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$session_time" +%s 2>/dev/null)
  fi

  # Fallback to GNU date if BSD date failed
  [ -z "$epoch" ] && epoch=$(date -d "$timestamp" +%s 2>/dev/null)

  echo "$epoch"
}

# Format elapsed time as human-readable string
format_elapsed_time() {
  local elapsed="$1"
  local hours=$((elapsed / 3600))
  local minutes=$(((elapsed % 3600) / 60))
  local seconds=$((elapsed % 60))

  if [ $hours -gt 0 ]; then
    printf "%dh%dm" $hours $minutes
  elif [ $minutes -gt 0 ]; then
    printf "%dm" $minutes
  else
    printf "%ds" $seconds
  fi
}

# Format colored output
format_colored() {
  local color="$1"
  local text="$2"
  printf "%b%b%s%b" "$THEME_RESET" "$color" "$text" "$THEME_RESET"
}

# ============================================================================
# Input Processing
# ============================================================================

# Read and parse JSON input
input=$(cat)
echo "$input" >/tmp/statusline-debug.json 2>/dev/null

# Debug: Log environment variables for terminal detection
{
  echo "=== Terminal Detection Debug ==="
  echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "TERM_PROGRAM: ${TERM_PROGRAM:-not set}"
  echo "LC_TERMINAL: ${LC_TERMINAL:-not set}"
  echo "TERMINAL_EMULATOR: ${TERMINAL_EMULATOR:-not set}"
  echo "TERM: ${TERM:-not set}"
  if is_iterm2; then
    echo "Result: iTerm2 detected"
  else
    echo "Result: NOT iTerm2"
  fi
  echo "=========================="
} >>/tmp/statusline-terminal-debug.log 2>/dev/null

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
model_id=$(echo "$input" | jq -r '.model.id // ""')
session_id=$(echo "$input" | jq -r '.session_id // ""')
# transcript_path
# eg. ~/.claude/projects/-Users-nkmr-ghq-github-com-nkmr-jp-claude/[session id].jsonl
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')
theme=$(echo "$input" | jq -r '.theme // ""')
total_cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // ""')
total_duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // ""')
total_api_duration_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // ""')

# Get session start time from transcript
session_start=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  session_start=$(head -10 "$transcript_path" | jq -r 'select(.timestamp) | .timestamp' | head -1)
fi

# Apply color theme
# Priority: 1. Environment variable, 2. JSON input, 3. Default
selected_theme="${STATUSLINE_THEME:-${theme:-default}}"
apply_theme "$selected_theme"

# ============================================================================
# Status Line Components
# ============================================================================

# Build directory component
build_directory_component() {
  local dir="$1"
  if [ -n "$dir" ]; then
    local dir_name
    # If path contains -worktrees/, truncate from -worktrees/ and get basename
    if [[ "$dir" == *"-worktrees/"* ]]; then
      dir="${dir%%-worktrees/*}"
    fi
    dir_name="$(basename "$dir")"
    # If directory name contains -wt-, show only the part before -wt-
    if [[ "$dir_name" == *"-wt-"* ]]; then
      dir_name="${dir_name%%-wt-*}"
    fi
    format_colored "$THEME_DIR" "$dir_name"
  fi
}

# Build git branch component
build_git_branch_component() {
  local dir="$1"
  if is_git_repo "$dir"; then
    local branch
    branch=$(get_git_branch "$dir")
    if [ -n "$branch" ]; then
      # If path contains -worktrees/, add wt: prefix to branch name
      if [[ "$dir" == *"-worktrees/"* ]]; then
        branch="wt:$branch"
      fi
      format_colored "$THEME_BRANCH" "$branch"
    fi
  fi
}

# Build session ID component
build_session_id_component() {
  local session_id="$1"
  [ -n "$session_id" ] && format_colored "$THEME_SESSION" "${session_id:0:8}"
}

# Build model name component
build_model_name_component() {
  local model_name="$1"
  [ -n "$model_name" ] && format_colored "$THEME_MODEL" "$model_name"
}

# Build session elapsed time component
build_elapsed_time_component() {
  local session_start="$1"

  if [ -n "$session_start" ]; then
    local start_epoch
    start_epoch=$(parse_timestamp "$session_start")

    if [ -n "$start_epoch" ]; then
      local current_epoch elapsed elapsed_str
      current_epoch=$(date +%s)
      elapsed=$((current_epoch - start_epoch))
      elapsed_str=$(format_elapsed_time "$elapsed")
      format_colored "$THEME_TIME" "$elapsed_str"
    fi
  fi
}

# Format timestamp to HH:MM:SS (local time)
format_timestamp_time() {
  local timestamp="$1"
  if [ -z "$timestamp" ] || [ "$timestamp" = "null" ]; then
    echo ""
    return
  fi

  local epoch
  epoch=$(parse_timestamp "$timestamp")

  if [ -n "$epoch" ]; then
    # Convert to local time and format as HH:MM:SS
    date -r "$epoch" +"%H:%M" 2>/dev/null || date -d "@$epoch" +"%H:%M" 2>/dev/null
  fi
}

# Build session timestamps component (started_at, updated_at, elapsed)
build_session_timestamps_component() {
  local session_id="$1"

  local timestamps
  timestamps=$(get_session_timestamps "$session_id")

  if [ -z "$timestamps" ]; then
    return
  fi

  local started_at updated_at
  read -r started_at updated_at <<<"$timestamps"

  if [ -z "$started_at" ] || [ "$started_at" = "null" ]; then
    return
  fi

  local start_time update_time elapsed_str
  start_time=$(format_timestamp_time "$started_at")

  if [ -n "$updated_at" ] && [ "$updated_at" != "null" ]; then
    update_time=$(format_timestamp_time "$updated_at")

    # Calculate elapsed time between started_at and updated_at
    local start_epoch update_epoch
    start_epoch=$(parse_timestamp "$started_at")
    update_epoch=$(parse_timestamp "$updated_at")

    if [ -n "$start_epoch" ] && [ -n "$update_epoch" ]; then
      local elapsed=$((update_epoch - start_epoch))
      elapsed_str=$(format_elapsed_time "$elapsed")
    fi
  fi

  # Build output: S:HH:MM U:HH:MM (Xm)
  local output=""
  if [ -n "$start_time" ]; then
    output="$start_time"
  fi
  if [ -n "$update_time" ]; then
    output="${output:+$output} - $update_time"
  fi
  if [ -n "$elapsed_str" ]; then
    output="${output:+$output }($elapsed_str)"
  fi

  if [ -n "$output" ]; then
    format_colored "$THEME_TIME" "$output"
  fi
}

# Build cost component
build_cost_component() {
  local cost="$1"

  if [ -n "$cost" ] && [ "$cost" != "null" ] && [ "$cost" != "0" ]; then
    local formatted_cost
    formatted_cost=$(printf "%.2f" "$cost" 2>/dev/null || echo "$cost")
    format_colored "$THEME_TIME" "\$$formatted_cost"
  fi
}

# Build duration component (converts milliseconds to human-readable format)
build_duration_component() {
  local duration_ms="$1"
  local label="$2"

  if [ -n "$duration_ms" ] && [ "$duration_ms" != "null" ] && [ "$duration_ms" != "0" ]; then
    # Convert milliseconds to seconds
    local total_seconds=$((duration_ms / 1000))

    if [ "$total_seconds" -eq 0 ]; then
      # Less than 1 second, show milliseconds
      format_colored "$THEME_TIME" "${label}${duration_ms}ms"
    else
      # Use the same format as elapsed time (Xh Ym, Xm Ys, or Xs)
      local hours=$((total_seconds / 3600))
      local minutes=$(((total_seconds % 3600) / 60))
      local seconds=$((total_seconds % 60))
      local formatted=""

      if [ $hours -gt 0 ]; then
        formatted=$(printf "%dh%dm" $hours $minutes)
      elif [ $minutes -gt 0 ]; then
        formatted=$(printf "%dm%ds" $minutes $seconds)
      else
        formatted=$(printf "%ds" $seconds)
      fi

      format_colored "$THEME_TIME" "${label}${formatted}"
    fi
  fi
}

# Build session status component
build_session_status_component() {
  local session_id="$1"
  local status
  status=$(get_session_status "$session_id")

  if [ -n "$status" ]; then
    local colored_status
    if [ "$status" = "In Progress" ]; then
      colored_status=$(format_colored "$COLOR_YELLOW" "$status")
    else
      colored_status=$(format_colored "$COLOR_GREEN" "$status")
    fi
    echo "$colored_status"
  else
    colored_status=$(format_colored "$COLOR_GREEN" "Start")
    echo "$colored_status"
  fi
}

# Build prompt component
build_prompt_component() {
  local session_id="$1"
  local terminal_width="${2:-120}"  # Default to 120 if not provided
  local prompt
  prompt=$(get_session_prompt "$session_id")

  if [ -n "$prompt" ]; then
    # Remove all newlines and carriage returns, replace with space
    prompt=$(echo "$prompt" | tr '\n\r' ' ' | tr -s ' ')

    # Calculate max length based on terminal width
    # Reserve space for links (GoLand + Linear issue + spaces = ~30-50 chars)
    # Increased margin to accommodate links on the same line
    local margin=60
    local max_length=$((terminal_width - margin))

    # Ensure minimum length (reduced from 40 to 30 for better space management)
    if [ $max_length -lt 30 ]; then
      max_length=30
    fi

    # Cap maximum length at 60 characters for readability
    if [ $max_length -gt 60 ]; then
      max_length=60
    fi

    # Truncate prompt if it's too long
    if [ ${#prompt} -gt $max_length ]; then
      prompt="${prompt:0:$max_length}..."
    fi
    printf "$prompt"
  fi
}

# Build Linear issue link component
build_link_component() {
  local session_id="$1"

  local issue_identifier
  issue_identifier=$(get_issue_identifier "$session_id")

  if [ -n "$issue_identifier" ]; then
    if is_iterm2; then
      printf "Edit Diff $issue_identifier |"
    else
      local workspace="${LINEAR_WORKSPACE:-nkmr-jp}"
      local linear_url="https://linear.app/${workspace}/issue/${issue_identifier}"
      format_colored "$COLOR_PURPLE" "$linear_url"
    fi
  elif [ -n "$session_id" ] && is_iterm2; then
    printf "Edit Diff NO_ISSUE"
  fi
}

# Build git diff stats component
build_git_diff_component() {
  local dir="$1"
  local session_id="$2"

  # Always show diff stats regardless of auto_commit setting

  if is_git_repo "$dir"; then
    local diff_stats added deleted untracked_count
    diff_stats=$(get_git_diff_stats "$dir")
    untracked_count=$(get_untracked_files_count "$dir")

    # Read diff stats (now guaranteed to be "0 0" or "N M" format)
    read -r added deleted <<<"$diff_stats"

    # Build status parts
    local status_parts=()

    # Add diff stats if there are changes (now added and deleted are always numeric)
    if [ "${added:-0}" -ne 0 ] || [ "${deleted:-0}" -ne 0 ]; then
      local add_part del_part
      add_part=$(format_colored "$THEME_DIFF_ADD" "+$added")
      del_part=$(format_colored "$THEME_DIFF_DEL" "-$deleted")
      status_parts+=("$add_part" "$del_part")
    fi

    # Add untracked files count if there are any
    if [ "$untracked_count" -gt 0 ]; then
      local untracked_part
      untracked_part=$(format_colored "$THEME_UNTRACKED" "?$untracked_count")
      status_parts+=("$untracked_part")
    fi

    # Output combined status if any changes exist
    if [ ${#status_parts[@]} -gt 0 ]; then
      local IFS=" "
      echo "(${status_parts[*]})"
    fi
  fi
}

# ============================================================================
# Main
# ============================================================================

# Get terminal width
terminal_width=$(get_terminal_width)

# Build status line components (first line)
components=(
#  "$(format_colored "$COLOR_GRAY" "")"
  "$(build_directory_component "$cwd")"
  "$(build_git_branch_component "$cwd")"
#  "$(format_colored "$COLOR_GRAY" " ")"
  "$(build_session_id_component "$session_id")"
  #    "$(build_model_name_component "$model_name")"
#  "$(build_elapsed_time_component "$session_start")"
#  "$(format_colored "$COLOR_GRAY" " ")"
  "$(build_session_timestamps_component "$session_id")"
  "$(build_session_status_component "$session_id")"
#  "$(format_colored "$COLOR_GRAY" " ")"
  "$(build_git_diff_component "$cwd" "$session_id")"
#  "$(build_cost_component "$total_cost_usd")"
#  "$(build_duration_component "$total_duration_ms" "total:")"
#  "$(build_duration_component "$total_api_duration_ms" "api:")"
)

# Join non-empty components with spaces for first line
output=""
for component in "${components[@]}"; do
  [ -n "$component" ] && output="${output:+$output }$component"
done

# Build prompt text (second line)
prompt_output="$(build_prompt_component "$session_id" "$terminal_width")"

# Combine links and prompt for second line
second_line="$(build_link_component "$session_id")"

# Add prompt if available
if [ -n "$prompt_output" ]; then
  second_line="${second_line:+$second_line }$prompt_output"
fi

# Output the final status line (line 1)
echo -e "$output"

# Output the links and prompt on second line if any exist and not just whitespace
# Remove all whitespace and check if the result is non-empty
if [ -n "$second_line" ] && [ -n "$(echo "$second_line" | tr -d '[:space:]')" ]; then
  echo -e "$second_line"
fi