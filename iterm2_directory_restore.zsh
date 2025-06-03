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

    # Called after each command execution
    iterm2_after_cmd_executes() {
      iterm2_print_state_data
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
  fi
fi