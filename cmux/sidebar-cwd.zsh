#!/usr/bin/env zsh
# cmux サイドバーに現在ディレクトリの basename を pill として表示する。
# pane ごとにユニークな key を使い、複数 pane でそれぞれの pill を並べる。
#
# 強制クローズで残った pill は、各 shell が spawn する独立な sweeper が
# 数秒おきに workspace を sweep して回収する。precmd には何も置かないので
# プロンプト遅延もなく、ユーザー入力を待たずに自動的に追従する。

_cmux_status_key() {
  print -r -- "cwd_${CMUX_PANEL_ID:-default}"
}

_cmux_update_cwd_status() {
  (( ${+commands[cmux]} )) || return 0
  cmux set-status "$(_cmux_status_key)" "${PWD:t}" --icon folder >/dev/null 2>&1
}

_cmux_clear_cwd_status() {
  (( ${+commands[cmux]} )) || return 0
  cmux clear-status "$(_cmux_status_key)" >/dev/null 2>&1
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

  # 親 shell が生きている間、interval 秒おきに workspace 内の cwd_* pill を
  # sweep する。既存 surface に紐付かない key を clear-status で消す。
  # HUP/INT/TERM を ignore して pane close を生き延びる。
  {
    trap '' HUP INT TERM PIPE QUIT
    exec </dev/null >/dev/null 2>&1
    while kill -0 "$shell_pid" 2>/dev/null; do
      [[ -z "$socket_path" || -S "$socket_path" ]] || break

      local -a cwd_keys=()
      local line
      while IFS= read -r line; do
        [[ "$line" == cwd_* ]] || continue
        cwd_keys+=("${line%%=*}")
      done < <("$cmux_bin" list-status 2>/dev/null)

      if (( ${#cwd_keys} > 0 )); then
        local json
        json="$("$cmux_bin" rpc surface.list "{\"workspace_id\":\"$workspace_id\"}" 2>/dev/null)"
        if [[ -n "$json" ]]; then
          local active_ids=$'\n'
          active_ids+="$(print -r -- "$json" \
            | /usr/bin/grep -oE '"id"[[:space:]]*:[[:space:]]*"[^"]+"' \
            | /usr/bin/awk -F'"' '{print $4}')"$'\n'

          local key uuid
          for key in "${cwd_keys[@]}"; do
            uuid="${key#cwd_}"
            [[ "$active_ids" == *$'\n'"$uuid"$'\n'* ]] && continue
            "$cmux_bin" clear-status "$key" >/dev/null 2>&1
          done
        fi
      fi

      sleep "$interval"
    done
  } &!
  _CMUX_GC_SWEEPER_PID=$!
}

if [[ -n "${ZSH_VERSION:-}" ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _cmux_update_cwd_status
  # 通常終了 (`exit` / EOF) は即座にクリア。強制クローズは sweeper が拾う。
  add-zsh-hook zshexit _cmux_clear_cwd_status
  _cmux_update_cwd_status
  _cmux_spawn_gc_sweeper
fi
