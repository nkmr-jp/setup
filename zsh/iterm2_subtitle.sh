# ============================================================
# iTerm2 サブタイトルカスタマイズ
# ============================================================
# Settings > Profiles > General > Subtitle → \(user.subtitle) を入力
#   4. Settings > Profiles > Terminal > Allow session to set title ✅
#
# ============================================================

# Check if directory is a git repository
_is_git_repo() {
  local dir="$1"
  [ -n "$dir" ] && ([ -d "$dir/.git" ] || git -C "$dir" rev-parse --git-dir >/dev/null 2>&1)
}

# Get current git branch name
get_git_branch() {
  local dir="$1"
  git -C "$dir" -c core.useReplaceRefs=false -c advice.detachedHead=false \
    symbolic-ref --short HEAD 2>/dev/null || echo ""
}


#
## 基本形
#printf "\033]1337;SetUserVar=%s=%s\007" mysubtitle $(echo -n "hello world" | base64)
#
## 関数化する例（.zshrc に追加）
#function set_subtitle() {
#  printf "\033]1337;SetUserVar=%s=%s\007" subtitle $(echo -n "$1" | base64)
#}
#
## 使用例
#set_subtitle "feature-branch | production"
#
#
## Build directory component
_directory() {
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
#    echo -n "$dir_name" | base64;
    echo "$dir_name"
  fi
}
#
## Build git branch component
_git_branch() {
  local dir="$1"
  if _is_git_repo "$dir"; then
    local branch
    branch=$(get_git_branch "$dir")
    if [ -n "$branch" ]; then
      # If path contains -worktrees/, add wt: prefix to branch name
      if [[ "$dir" == *"-worktrees/"* ]]; then
        branch="wt:$branch"
      fi
#      echo -n "$branch" | base64;
      echo "🌿$branch"
    fi
  fi
}


precmd() {
  #  local branch=$(git branch --show-current 2>/dev/null || echo "-")
  #  printf "\033]1337;SetUserVar=%s=%s\007" subtitle "$(echo -n "${branch} | $(basename $PWD)" | base64)"
#  printf "\033]1337;SetUserVar=%s=%s\007" subtitle "$(echo -n "$(basename $PWD)" | base64)"
  printf "\033]1337;SetUserVar=%s=%s\007" subtitle "$(echo -n "$(_directory $PWD)""$(_git_branch $PWD)" | base64)"
}


