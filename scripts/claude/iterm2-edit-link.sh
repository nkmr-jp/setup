#!/usr/bin/env bash
# iterm2 > Settings > Profiles > Advanced > Smart Selection
# Note: Uses Bash 3.2 compatible syntax for macOS default bash

# ============================================================
# Configuration
# ============================================================

# Application commands (full paths)
# Format: "app_key:command_path"
APPS=(
  "land:/Users/nkmr/Library/Application Support/JetBrains/Toolbox/scripts/land"
  "code:/usr/local/bin/code"
)

# Repository name to application mappings
# Format: "pattern:app_key"
# Patterns are matched with prefix matching against the repository name from git remote
# Repository name is extracted from: git config --get remote.origin.url
# e.g., "git@github.com:org/xt-repo.git" -> "xt-repo"
APP_MAPPINGS=(
  "xt:land"
  "zl:land"
  "api-client:land"
  "api-struct:land"
  "prompt-line:land"
  "claude:land"
  "setup:land"
  "setupsec:land"
  "knowledge:land"
)
#DEFAULT_APP="code"
DEFAULT_APP="land"

# ============================================================

# Function to get app command by key
get_app_command() {
  local key="$1"
  for app in "${APPS[@]}"; do
    local app_key="${app%%:*}"
    local app_cmd="${app#*:}"
    if [[ "$app_key" == "$key" ]]; then
      echo "$app_cmd"
      return
    fi
  done
}

# Function to get repository name from git remote URL
# Supports both SSH (git@github.com:org/repo.git) and HTTPS (https://github.com/org/repo.git) formats
get_repo_name() {
  local dir="$1"
  local remote_url

  # Get the remote URL from git config
  remote_url=$(git -C "$dir" config --get remote.origin.url 2>/dev/null)

  if [[ -z "$remote_url" ]]; then
    echo ""
    return
  fi

  # Extract repository name from URL
  # Remove .git suffix if present
  remote_url="${remote_url%.git}"
  # Get the last part after / or :
  local repo_name="${remote_url##*/}"

  echo "$repo_name"
}

dir="$1"
override_app=""

# Process second argument
if [[ -n "$2" ]]; then
  if [[ "$2" =~ ^wt:(.+)$ ]]; then
    # wt:branch format -> convert to worktrees path
    branch="${BASH_REMATCH[1]}"
    dir="${dir}-worktrees/${branch}"
  else
    # app key specified directly
    override_app="$2"
  fi
fi

# Determine app to use
if [[ -n "$override_app" ]]; then
  # Use specified app
  selected_app_key="$override_app"
else
  # Get repository name from git remote URL
  repo_name=$(get_repo_name "$dir")

  # Find matching app based on repository name prefix
  selected_app_key="$DEFAULT_APP"
  if [[ -n "$repo_name" ]]; then
    for mapping in "${APP_MAPPINGS[@]}"; do
      pattern="${mapping%%:*}"
      app_key="${mapping#*:}"
      if [[ "$repo_name" == "$pattern"* ]]; then
        selected_app_key="$app_key"
        break
      fi
    done
  fi
fi

# Launch the selected application
selected_cmd=$(get_app_command "$selected_app_key")
"$selected_cmd" "$dir"