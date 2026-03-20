#!/usr/bin/env zsh
# iTerm2 Shell Integration with Directory Restore
# Based on official iTerm2 shell integration with custom enhancements
#
# Features:
# - OSC 133 prompt markers (A/B/C/D) for full Shell Integration
# - RemoteHost reporting
# - CurrentDir (OSC 1337) + OSC 7 for directory tracking
# - chpwd hook for immediate directory change notification
# - Custom tab title (directory name only)
#
# See:
# - https://iterm2.com/documentation-shell-integration.html
# - https://iterm2.com/shell_integration/zsh

if [[ -o interactive ]]; then
  if [ "${ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX-}""$TERM" != "tmux-256color" -a "${ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX-}""$TERM" != "screen" -a "${ITERM_SHELL_INTEGRATION_INSTALLED-}" = "" -a "$TERM" != linux -a "$TERM" != dumb ]; then
    ITERM_SHELL_INTEGRATION_INSTALLED=Yes
    _iterm2_is_decorated=0

    # --- State data functions ---

    iterm2_print_remote_host() {
      printf "\033]1337;RemoteHost=%s@%s\007" "$USER" "$HOST"
    }

    iterm2_print_state_data() {
      printf "\033]1337;CurrentDir=%s\007" "$PWD"
    }

    iterm2_print_osc7() {
      printf "\033]7;file://%s%s\a" "${HOST}" "$PWD"
    }

    iterm2_print_user_vars() {
      printf "\033]1337;SetUserVar=%s=%s\007" "currentDir" "$(echo -n "${PWD##*/}" | base64)"
    }

    iterm2_set_title() {
      local dir_name="${PWD##*/}"
      if [[ "$PWD" == "$HOME" ]]; then
        dir_name="~"
      fi
      printf "\033]0;%s\007" "$dir_name"
    }

    # --- Hook functions ---

    # precmd: runs before each prompt display
    iterm2_precmd() {
      local STATUS="$?"

      # Mark: previous command finished (D;status)
      printf "\033]133;D;%s\007" "$STATUS"

      # Send state data
      iterm2_print_remote_host
      iterm2_print_state_data
      iterm2_print_osc7
      iterm2_print_user_vars
      iterm2_set_title

      # Restore PS1 if still decorated from previous prompt (no command was run)
      if [[ $_iterm2_is_decorated -eq 1 ]]; then
        PS1="$_iterm2_clean_ps1"
      fi

      # Save clean PS1 and decorate with prompt markers
      _iterm2_clean_ps1="$PS1"
      PS1="%{$(printf '\033]133;A\007')%}${PS1}%{$(printf '\033]133;B\007')%}"
      _iterm2_is_decorated=1
    }

    # preexec: runs before each command execution
    iterm2_preexec() {
      # Restore clean PS1
      if [[ $_iterm2_is_decorated -eq 1 ]]; then
        PS1="$_iterm2_clean_ps1"
        _iterm2_is_decorated=0
      fi
      # Mark: command output starts (C)
      printf "\033]133;C\007"
    }

    # chpwd: runs immediately when directory changes (cd, pushd, popd)
    iterm2_chpwd() {
      iterm2_print_remote_host
      iterm2_print_state_data
      iterm2_print_osc7
      iterm2_print_user_vars
      iterm2_set_title
    }

    # --- Register hooks ---

    [[ -z ${precmd_functions-} ]] && precmd_functions=()
    precmd_functions=($precmd_functions iterm2_precmd)

    [[ -z ${preexec_functions-} ]] && preexec_functions=()
    preexec_functions=($preexec_functions iterm2_preexec)

    [[ -z ${chpwd_functions-} ]] && chpwd_functions=()
    chpwd_functions=($chpwd_functions iterm2_chpwd)

    # Also register Terminal.app's update_terminal_cwd as chpwd hook if available
    if (( $+functions[update_terminal_cwd] )); then
      chpwd_functions=($chpwd_functions update_terminal_cwd)
    fi

    # --- Initial state ---
    iterm2_print_remote_host
    iterm2_print_state_data
    iterm2_print_osc7
    iterm2_print_user_vars
    iterm2_set_title
  fi
fi
