#!/usr/bin/env zsh
# ============================================================
# Redact secrets from commands that print environment variables
# ============================================================
# Tokens are exported from ~/.zprofile, so `env`, `ps eww`, `set`, and similar
# commands print them to the scrollback and to any log or agent transcript.
# Like `rm` -> `trash`, the everyday commands are wrapped so their output goes
# through agent-settings' redact-bash-output.py --filter (secret-looking env
# values and gitleaks findings become [REDACTED]).
#
# - env / printenv / ps / pgrep: functions that filter only the forms that print
#   environment variables; other forms run the real command unchanged.
# - export / set / typeset / declare: not wrapped as functions, because a
#   wrapper would make `typeset x=1` local to the wrapper and `set -- a b` set
#   the wrapper's arguments. Instead, the accept-line widget rewrites a typed
#   listing form (`set`, `export -p`, `typeset -x | grep FOO`) to pipe through
#   `redact`. Scripts and functions are never affected.
# - Raw output: `command env`, `command ps eww`, `builtin set`.
# ============================================================

[[ -o interactive ]] || return 0

: ${REDACT_ENV_FILTER:=$HOME/ghq/github.com/nkmr-jp/agent-settings/claude/bin/redact-bash-output.py}

# Filter stdin. Fails closed: if the filter is missing or fails, print nothing.
redact() {
  if [[ ! -f $REDACT_ENV_FILTER ]]; then
    print -u2 "redact: filter not found: $REDACT_ENV_FILTER (output suppressed)"
    cat >/dev/null
    return 1
  fi
  /usr/bin/python3 "$REDACT_ENV_FILTER" --filter
}

# Run "$@" through redact, returning the command's status (or redact's on failure).
_redact_env_run() {
  "$@" | redact
  local -a st=("${pipestatus[@]}")
  (( st[2] )) && return $st[2]
  return $st[1]
}

# env with no command prints the environment; `env FOO=1 cmd` runs cmd.
env() {
  local -i i=1
  while (( i <= $# )); do
    case ${@[i]} in
      -u|-P|-S|-C) (( i += 2 )) ;;
      -*|*=*) (( i++ )) ;;
      *) command env "$@"; return ;;
    esac
  done
  _redact_env_run command env "$@"
}

printenv() {
  _redact_env_run command printenv "$@"
}

# ps -E and BSD-style words containing e (ps e / ps eww / ps auxe) print environments.
ps() {
  local a
  for a in "$@"; do
    if [[ ( $a == -* && $a != --* && $a == *E* ) || ( $a =~ '^[a-zA-Z]+$' && $a == *e* ) ]]; then
      _redact_env_run command ps "$@"
      return
    fi
  done
  command ps "$@"
}

# pgrep -f / -l can print other processes' arguments and environments.
pgrep() {
  local a
  for a in "$@"; do
    if [[ $a == (--full|--list-full|--list-name) || ( $a == -* && $a != --* && ${a#-} == *[fl]* ) ]]; then
      _redact_env_run command pgrep "$@"
      return
    fi
  done
  command pgrep "$@"
}

# Sets REPLY to $1 with `| redact` inserted after a builtin listing form; returns 1 otherwise.
_redact_env_rewrite_line() {
  local re='^( *(export( +-p)?|set|(typeset|declare)( +-[px]+)?) *)(\|.*)?$'
  [[ $1 =~ $re ]] || return 1
  local head=$match[1]
  REPLY="${head%"${head##*[! ]}"} | redact${match[6]:+ $match[6]}"
}

_redact_env_accept_line() {
  local REPLY
  _redact_env_rewrite_line "$BUFFER" && BUFFER=$REPLY
  zle .accept-line
}
zle -N accept-line _redact_env_accept_line
