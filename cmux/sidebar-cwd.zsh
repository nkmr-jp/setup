#!/usr/bin/env zsh
# cmux サイドバーに現在ディレクトリの basename を pill として表示する。
# pane ごとにユニークな key を使い、複数 pane でそれぞれの pill を並べる。
#
# 強制クローズで残った pill は、各 shell が spawn する独立な sweeper が
# 数秒おきに workspace を sweep して回収する。precmd には何も置かないので
# プロンプト遅延ゼロ、入力不要で追従する。

typeset -gr _CMUX_PILL_PREFIX=cwd_

_cmux_update_cwd_status() {
  (( ${+commands[cmux]} )) || return 0
  cmux set-status "${_CMUX_PILL_PREFIX}${CMUX_PANEL_ID:-default}" \
    "${PWD:t}" --icon folder >/dev/null 2>&1
}

_cmux_clear_cwd_status() {
  (( ${+commands[cmux]} )) || return 0
  cmux clear-status "${_CMUX_PILL_PREFIX}${CMUX_PANEL_ID:-default}" \
    >/dev/null 2>&1
}

_cmux_spawn_gc_sweeper() {
  (( ${+commands[cmux]} )) || return 0
  [[ -n "${CMUX_WORKSPACE_ID:-}" ]] || return 0
  if [[ -n "${_CMUX_GC_SWEEPER_PID:-}" ]] \
       && kill -0 "$_CMUX_GC_SWEEPER_PID" 2>/dev/null; then
    return 0
  fi

  local shell_pid=$$
  local workspace_id="$CMUX_WORKSPACE_ID"
  local socket_path="${CMUX_SOCKET_PATH:-}"
  local cmux_bin="${commands[cmux]}"
  local interval="${CMUX_CWD_SWEEP_INTERVAL:-3}"
  local prefix="$_CMUX_PILL_PREFIX"

  # HUP/INT/TERM を ignore して pane close を生き延びるための独立 process。
  {
    trap '' HUP INT TERM PIPE QUIT
    exec </dev/null >/dev/null 2>&1
    while kill -0 "$shell_pid" 2>/dev/null; do
      [[ -z "$socket_path" || -S "$socket_path" ]] || break

      local -a cwd_keys=()
      local line
      while IFS= read -r line; do
        [[ "$line" == ${prefix}* ]] && cwd_keys+=("${line%%=*}")
      done < <("$cmux_bin" list-status 2>/dev/null)
      (( ${#cwd_keys} == 0 )) && { sleep "$interval"; continue }

      local json
      json="$("$cmux_bin" rpc surface.list \
        "{\"workspace_id\":\"$workspace_id\"}" 2>/dev/null)"
      [[ -z "$json" ]] && { sleep "$interval"; continue }

      local active_ids=$'\n'
      active_ids+="$(print -r -- "$json" \
        | /usr/bin/awk -F'"' '/"id"[[:space:]]*:/{print $4}')"$'\n'

      local key uuid
      for key in "${cwd_keys[@]}"; do
        uuid="${key#$prefix}"
        [[ "$active_ids" == *$'\n'"$uuid"$'\n'* ]] && continue
        "$cmux_bin" clear-status "$key" >/dev/null 2>&1
      done

      sleep "$interval"
    done
  } &!
  _CMUX_GC_SWEEPER_PID=$!
}

if [[ -n "${ZSH_VERSION:-}" ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _cmux_update_cwd_status
  add-zsh-hook zshexit _cmux_clear_cwd_status
  _cmux_update_cwd_status
  _cmux_spawn_gc_sweeper
fi
