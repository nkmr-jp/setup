#!/usr/bin/env zsh
# ============================================================
# iTerm2 Integration
# ============================================================
# iTerm2 のサブタイトル・タブタイトル・ディレクトリ復元を統合したスクリプト
#
# 必要な設定:
#   1. Settings > Profiles > General > Title に \(user.dirIcon) \(user.currentDir) を入力
#   2. Settings > Profiles > General > Subtitle に \(user.branch) を入力
#   3. Settings > Profiles > Terminal > Allow session to set title を有効化
#
# 参考:
#   - https://iterm2.com/documentation-shell-integration.html
#   - https://iterm2.com/shell_integration/zsh
# ============================================================

# インタラクティブシェルでのみ動作
if [[ ! -o interactive ]]; then
  return
fi

# tmux/screen/dumb端末では動作しない
if [[ "${ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX-}${TERM}" == "tmux-256color" ]] ||
   [[ "${ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX-}${TERM}" == "screen" ]] ||
   [[ "$TERM" == "linux" ]] || [[ "$TERM" == "dumb" ]]; then
  return
fi

# 二重読み込み防止
if [[ "${ITERM_SHELL_INTEGRATION_INSTALLED-}" != "" ]]; then
  return
fi
ITERM_SHELL_INTEGRATION_INSTALLED=Yes

# ============================================================
# ヘルパー関数
# ============================================================

_get_git_branch() {
  local dir="$1"
  # detached HEAD の場合は何も出力しない
  git -C "$dir" -c core.useReplaceRefs=false -c advice.detachedHead=false \
    symbolic-ref --short HEAD 2>/dev/null
}

# worktree パスから元リポジトリのパスを返す（非 worktree ならそのまま）
_iterm2_resolve_repo_path() {
  local dir="$1"
  if [[ "$dir" == *"-worktrees/"* ]]; then
    echo "${dir%%-worktrees/*}"
  else
    echo "$dir"
  fi
}

# ============================================================
# サブタイトル用コンポーネント
# ============================================================

_iterm2_directory_name() {
  local dir="$1"
  if [ -z "$dir" ]; then
    return
  fi

  dir="$(_iterm2_resolve_repo_path "$dir")"

  local dir_name="${dir##*/}"

  # gwt.zsh の worktree コピー規約: repo-wt-branch
  if [[ "$dir_name" == *"-wt-"* ]]; then
    dir_name="${dir_name%%-wt-*}"
  fi

  echo "$dir_name"
}

_iterm2_git_branch_label() {
  local dir="$1"
  local branch
  # _is_git_repo チェック不要: 非 git ディレクトリでは空文字が返る
  branch=$(_get_git_branch "$dir")
  if [ -z "$branch" ]; then
    return
  fi

  # worktree で作業中の場合、wt: プレフィックスで区別
  if [[ "$dir" == *"-worktrees/"* ]]; then
    branch="wt:$branch"
  fi

  echo "$branch"
}

# ============================================================
# iTerm2 への情報送信
# ============================================================

# 新しいタブ/ペインで同じディレクトリを復元するために必要
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

_iterm2_directory_icon() {
  local dir="$1"
  [[ -z "$dir" ]] && return

  dir="$(_iterm2_resolve_repo_path "$dir")"

  if [[ -f "$dir/go.mod" ]]; then
    echo "🐹"
  elif [[ -f "$dir/Cargo.toml" ]]; then
    echo "🦀"
  elif [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/setup.py" ]] || [[ -f "$dir/requirements.txt" ]]; then
    echo "🐍"
  elif [[ -f "$dir/Gemfile" ]]; then
    echo "💎"
  elif [[ -f "$dir/dbt_project.yml" ]]; then
    echo "📊"
  elif [[ -f "$dir/package.json" ]]; then
    echo "⬡"
  elif [[ -f "$dir/Dockerfile" ]] || [[ -f "$dir/docker-compose.yml" ]]; then
    echo "🐳"
  elif [[ -f "$dir/Makefile" ]]; then
    echo "⚙️"
  else
    echo "📁"
  fi
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

_iterm2_last_prompt_cache=""

_iterm2_set_user_last_prompt() {
  local dir_name="$(_iterm2_directory_name "$PWD")"
  [[ -z "$dir_name" ]] && dir_name="${PWD##*/}"

  if [[ "$_iterm2_last_prompt_cache" != "$dir_name" ]]; then
    _iterm2_last_prompt_cache="$dir_name"
    _iterm2_set_user_var lastPrompt "$dir_name"
    printf "\033]0;%s\007" "$dir_name"
  fi
}

# ============================================================
# fswatch によるリアルタイム lastPrompt 更新
# ============================================================

_iterm2_prompt_watcher_pid=""

_iterm2_start_prompt_watcher() {
  [[ -z "${ITERM_SESSION_ID-}" ]] && return
  command -v fswatch >/dev/null 2>&1 || return

  local history_file="$HOME/.prompt-line/history.jsonl"
  local session_id="${ITERM_SESSION_ID#*:}"

  (
    exec >/dev/tty 2>/dev/null
    fswatch --event Updated -o "$history_file" 2>/dev/null | while read -r _; do
      text=$(tail -100 "$history_file" | grep "$session_id" | tail -1 \
        | jq -r --arg sid "$session_id" \
          'select(.itermSessionId == $sid) | .text | gsub("\n"; " ")' 2>/dev/null)
      [[ -z "$text" ]] && continue
      _iterm2_set_user_var lastPrompt "$text"
      printf "\033]0;%s\007" "$text"
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
# precmd フック（プロンプト表示前に毎回実行）
# ============================================================

_iterm2_precmd() {
  _iterm2_send_current_dir
  _iterm2_set_user_current_dir
  _iterm2_set_user_branch
  _iterm2_set_user_dir_icon
  _iterm2_set_user_last_prompt
}

# precmd_functions 配列にフックを登録
[[ -z ${precmd_functions-} ]] && precmd_functions=()
precmd_functions=($precmd_functions _iterm2_precmd)

# 初回読み込み時にも情報を送信（シェル起動直後のタブに反映させる）
_iterm2_precmd

# fswatch によるリアルタイム監視を開始
_iterm2_start_prompt_watcher
