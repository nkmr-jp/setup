#!/usr/bin/env zsh
# cmux サイドバーに pane 別の状態 pill を表示する。
#   cwd_<panel-id>    : 現在ディレクトリの basename（chpwd / precmd で更新）
#   claude_<panel-id> : Claude Code セッションの状態
#                       （Claude Code hooks → claude-status-hook.sh で更新）
#
# precmd は &! で background 化して prompt 遅延を排除する。
# 強制クローズや Claude crash で残った pill は、各 shell が spawn する独立な
# sweeper が数秒おきに workspace を sweep して回収する。

typeset -gra _CMUX_PILL_PREFIXES=(cwd_ claude_)

_cmux_set_async() {  # $1=key $2=value $3=icon
  (( ${+commands[cmux]} )) || return 0
  cmux set-status "$1" "$2" --icon "$3" >/dev/null 2>&1 &!
}

_cmux_update_cwd_status() {
  _cmux_set_async "cwd_${CMUX_PANEL_ID:-default}" "${PWD:t}" folder
}

_cmux_clear_pane_status() {
  # zshexit から呼ばれるので同期実行。&! だと shell 終了時に reap されない。
  (( ${+commands[cmux]} )) || return 0
  local p
  for p in "${_CMUX_PILL_PREFIXES[@]}"; do
    cmux clear-status "${p}${CMUX_PANEL_ID:-default}" >/dev/null 2>&1
  done
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
  local -a prefixes=("${_CMUX_PILL_PREFIXES[@]}")

  # HUP/INT/TERM を ignore して pane close を生き延びるための独立 process。
  {
    trap '' HUP INT TERM PIPE QUIT
    exec </dev/null >/dev/null 2>&1
    while kill -0 "$shell_pid" 2>/dev/null; do
      [[ -z "$socket_path" || -S "$socket_path" ]] || break

      local -a pane_keys=() pane_uuids=()
      local line k p
      while IFS= read -r line; do
        k="${line%%=*}"
        for p in "${prefixes[@]}"; do
          [[ "$k" == ${p}* ]] && {
            pane_keys+=("$k"); pane_uuids+=("${k#$p}"); break
          }
        done
      done < <("$cmux_bin" list-status 2>/dev/null)
      (( ${#pane_keys} == 0 )) && { sleep "$interval"; continue }

      local json
      json="$("$cmux_bin" rpc surface.list \
        "{\"workspace_id\":\"$workspace_id\"}" 2>/dev/null)"
      [[ -z "$json" ]] && { sleep "$interval"; continue }

      local active_ids=$'\n'
      active_ids+="$(print -r -- "$json" \
        | /usr/bin/awk -F'"' '/"id"[[:space:]]*:/{print $4}')"$'\n'

      local i
      for (( i = 1; i <= ${#pane_keys}; i++ )); do
        [[ "$active_ids" == *$'\n'"${pane_uuids[i]}"$'\n'* ]] && continue
        "$cmux_bin" clear-status "${pane_keys[i]}" >/dev/null 2>&1
      done

      sleep "$interval"
    done
  } &!
  _CMUX_GC_SWEEPER_PID=$!
}

if [[ -n "${ZSH_VERSION:-}" ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _cmux_update_cwd_status
  add-zsh-hook precmd _cmux_update_cwd_status
  add-zsh-hook zshexit _cmux_clear_pane_status
  _cmux_update_cwd_status
  _cmux_spawn_gc_sweeper
fi
