#!/usr/bin/env zsh
# ============================================================
# iTerm2 Integration
# ============================================================
# iTerm2 のサブタイトル・タブタイトル・ディレクトリ復元を統合したスクリプト
#
# 必要な設定:
#   1. Settings > Profiles > General > Title に \(user.currentDir) を入力
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

# ============================================================
# サブタイトル用コンポーネント
# ============================================================

_iterm2_directory_name() {
  local dir="$1"
  if [ -z "$dir" ]; then
    return
  fi

  # gwt.zsh の worktree パス規約: repo-worktrees/branch
  if [[ "$dir" == *"-worktrees/"* ]]; then
    dir="${dir%%-worktrees/*}"
  fi

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

_iterm2_set_user_last_activity() {
  _iterm2_set_user_var lastActivity "$EPOCHSECONDS"
}

_iterm2_set_tab_title() {
  local dir_name="${PWD##*/}"
  if [[ "$PWD" == "$HOME" ]]; then
    dir_name="~"
  fi
  printf "\033]0;%s\007" "$dir_name"
}

# ============================================================
# precmd フック（プロンプト表示前に毎回実行）
# ============================================================

_iterm2_precmd() {
  _iterm2_send_current_dir
  _iterm2_set_user_current_dir
  _iterm2_set_user_branch
  _iterm2_set_user_last_activity
  _iterm2_set_tab_title
}

# precmd_functions 配列にフックを登録
[[ -z ${precmd_functions-} ]] && precmd_functions=()
precmd_functions=($precmd_functions _iterm2_precmd)

# 初回読み込み時にも情報を送信（シェル起動直後のタブに反映させる）
_iterm2_send_current_dir
_iterm2_set_user_current_dir
_iterm2_set_user_branch
_iterm2_set_user_last_activity
_iterm2_set_tab_title
