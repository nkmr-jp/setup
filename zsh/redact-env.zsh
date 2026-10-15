#!/usr/bin/env zsh
# ============================================================
# Redact secrets from commands that print environment variables
# ============================================================
# - env / printenv / ps / pgrep: function wrappers from shell/redact-env.sh,
#   shared with bash. Non-interactive shells get them via .zshenv / BASH_ENV
#   (shell/env.sh).
# - export / set / typeset / declare: not wrapped as functions, because a
#   wrapper would make `typeset x=1` local to the wrapper and `set -- a b` set
#   the wrapper's arguments. Instead, the accept-line widget rewrites a typed
#   listing form (`set`, `export -p`, `typeset -x | grep FOO`) to pipe through
#   `redact`. Scripts and functions are never affected.
# - Raw output: `command env`, `command ps eww`, `builtin set`.
# ============================================================

source "${0:A:h}/../shell/redact-env.sh"

# Sets REPLY to $1 with `| redact` inserted after a builtin listing form; returns 1 otherwise.
_redact_env_rewrite_line() {
  local re='^( *(export( +-p)?|set|(typeset|declare)( +-[px]+)?) *)(\|.*)?$'
  [[ $1 =~ $re ]] || return 1
  local head=$match[1]
  REPLY="${head%"${head##*[! ]}"} | redact${match[6]:+ $match[6]}"
}

[[ -o interactive ]] || return 0

_redact_env_accept_line() {
  local REPLY
  _redact_env_rewrite_line "$BUFFER" && BUFFER=$REPLY
  zle .accept-line
}
zle -N accept-line _redact_env_accept_line
