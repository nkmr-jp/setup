#!/usr/bin/env zsh
# iTerm2 Directory Restore
# Minimal iTerm2 shell integration for directory restoration functionality only
#
# See: 
# - https://iterm2.com/documentation-shell-integration.html
# - https://iterm2.com/shell_integration/zsh

if [[ -o interactive ]]; then
  if [ "${ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX-}""$TERM" != "tmux-256color" -a "${ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX-}""$TERM" != "screen" -a "${ITERM_SHELL_INTEGRATION_INSTALLED-}" = "" -a "$TERM" != linux -a "$TERM" != dumb ]; then
    ITERM_SHELL_INTEGRATION_INSTALLED=Yes
    
    # Send current directory to iTerm2
    iterm2_print_state_data() {
      printf "\033]1337;CurrentDir=%s\007" "$PWD"
    }

    # カスタム変数を定義する関数 - ディレクトリ名のみを表示
    iterm2_print_user_vars() {
      printf "\033]1337;SetUserVar=%s=%s\007" "currentDir" "$(echo -n "${PWD##*/}" | base64)"
    }
    
    # タイトルを設定する関数 - ディレクトリ名のみを表示
    iterm2_set_tab_title() {
      # ホームディレクトリの場合は「~」を表示
      local dir_name="${PWD##*/}"
      if [[ "$PWD" == "$HOME" ]]; then
        dir_name="~"
      fi
      # タブのタイトルを設定
      printf "\033]1;%s\007" "$dir_name"
    }

    # Called after each command execution
    iterm2_after_cmd_executes() {
      iterm2_print_state_data
      iterm2_print_user_vars
      iterm2_set_tab_title
    }

    # Hook that runs before each prompt
    iterm2_precmd() {
      local STATUS="$?"
      iterm2_after_cmd_executes "$STATUS"
    }

    # Register the precmd hook
    [[ -z ${precmd_functions-} ]] && precmd_functions=()
    precmd_functions=($precmd_functions iterm2_precmd)

    # Send initial directory
    iterm2_print_state_data
    iterm2_print_user_vars
    iterm2_set_tab_title
  fi
fi