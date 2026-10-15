# ============================================================
# Redact secrets from commands that print environment variables (bash and zsh)
# ============================================================
# Tokens are exported from ~/.zprofile, so `env`, `ps eww`, and similar
# commands print them to the scrollback and to any log or agent transcript.
# Like `rm` -> `trash`, the everyday commands are wrapped so their output goes
# through agent-settings' redact-bash-output.py --filter (secret-looking env
# values and gitleaks findings become [REDACTED]).
#
# env / printenv / ps / pgrep become functions that filter only the forms that
# print environment variables; other forms run the real command unchanged.
# Raw output: `command env`, `command ps eww`.
#
# Shared by zsh and bash (macOS /bin/bash 3.2, possibly with `set -u`), so it
# sticks to the common subset: no zsh-only expansions, no [[ =~ ]].
# ============================================================

# Filter stdin. Fails closed: if the filter is missing or fails, print nothing.
# The path is resolved here because Claude Code's snapshot keeps functions but
# not unexported variables.
redact() {
  local f="${REDACT_ENV_FILTER:-$HOME/ghq/github.com/nkmr-jp/agent-settings/claude/bin/redact-bash-output.py}"
  if [ ! -f "$f" ]; then
    echo "redact: filter not found: $f (output suppressed)" >&2
    cat >/dev/null
    return 1
  fi
  /usr/bin/python3 "$f" --filter
}

# Run "$@" through redact, returning the command's status (or redact's on failure).
# bash has PIPESTATUS and zsh has pipestatus; only one of them is set.
_redact_env_run() {
  "$@" | redact
  set -- ${PIPESTATUS[@]+"${PIPESTATUS[@]}"} ${pipestatus[@]+"${pipestatus[@]}"}
  [ "$2" -ne 0 ] && return "$2"
  return "$1"
}

# env with no command prints the environment; `env FOO=1 cmd` runs cmd.
env() {
  local -a _orig
  _orig=("$@")
  while [ $# -gt 0 ]; do
    case $1 in
      -u|-P|-S|-C) shift; [ $# -gt 0 ] && shift ;;
      -*|*=*) shift ;;
      *) command env "${_orig[@]}"; return ;;
    esac
  done
  _redact_env_run command env ${_orig[@]+"${_orig[@]}"}
}

printenv() {
  _redact_env_run command printenv "$@"
}

# ps -E and BSD-style words containing e (ps e / ps eww / ps auxe) print environments.
ps() {
  local a
  for a in "$@"; do
    case $a in
      --*) ;;
      -*E*) _redact_env_run command ps "$@"; return ;;
      -*|*[!a-zA-Z]*) ;;
      *e*) _redact_env_run command ps "$@"; return ;;
    esac
  done
  command ps "$@"
}

# pgrep -f / -l can print other processes' arguments and environments.
pgrep() {
  local a filter=
  for a in "$@"; do
    case $a in
      --full|--list-full|--list-name) filter=1 ;;
      --*) ;;
      -*[fl]*) filter=1 ;;
    esac
  done
  if [ -z "$filter" ]; then
    command pgrep "$@"
    return
  fi
  # Not _redact_env_run: bash forks the reading side of a pipeline with this
  # shell's argv, and pgrep -f matches that sibling (it skips only its own
  # ancestors), so `bash -c 'pgrep -f foo'` would find itself.
  local out st
  out=$(command pgrep "$@")
  st=$?
  { [ -n "$out" ] && printf '%s\n' "$out"; } | redact || return
  return "$st"
}
