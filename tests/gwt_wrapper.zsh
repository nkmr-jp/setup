#!/bin/zsh
# Test wrapper for gwt.zsh
# Stub builtins such as zle and compinit that do not work noninteractively.

zle() { : }
compdef() { : }
autoload() { : }
compinit() { : }

# Stub iTerm2 integration functions because iterm2.zsh is not sourced.
_iterm2_precmd() { : }
_iterm2_send_current_dir() { : }
_iterm2_set_user_var() { : }

# Load gwt.zsh.
source "${0:A:h}/../zsh/gwt.zsh"

# Run the requested function.
func="$1"
shift
"$func" "$@"
