#!/bin/zsh
# Test wrapper for iterm2.zsh
# Bypass guards and load only function definitions.

TERM="xterm-256color"
ITERM_SHELL_INTEGRATION_INSTALLED=""
precmd_functions=()

# Extract only function definitions; skip guards, precmd_functions registration, and initial execution.
local src="${0:A:h}/../zsh/iterm2.zsh"
eval "$(awk '/^_get_git_branch\(\)/,/^# precmd_functions/{if(/^# precmd_functions/) exit; print}' "$src")"

# Run the requested function.
func="$1"
shift
"$func" "$@"
