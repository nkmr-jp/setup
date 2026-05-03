#!/usr/bin/env zsh
# cmux サイドバーに現在ディレクトリの basename を pill として表示する。
# pane ごとにユニークな key を使い、複数 pane でそれぞれの pill を並べる。
#
# pane を閉じた際の SIGHUP では zshexit やシグナルトラップから fork した
# `cmux` 子プロセスが SIGHUP で殺され、clear-status RPC が届かないことがある。
# そのため shell とは独立した watcher プロセスを spawn し、parent shell の
# 死を検知してから clear-status を発行する。

_cmux_status_key() {
  # CMUX_PANEL_ID が未設定なら共通 key にフォールバック
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

_cmux_spawn_cwd_cleanup_watcher() {
  (( ${+commands[cmux]} )) || return 0
  if [[ -n "${_CMUX_CWD_WATCHER_PID:-}" ]] \
       && kill -0 "$_CMUX_CWD_WATCHER_PID" 2>/dev/null; then
    return 0
  fi

  local key="$(_cmux_status_key)"
  local shell_pid=$$
  local cmux_bin="${commands[cmux]}"

  # subshell で実行: HUP/INT/TERM を ignore して pane close を生き延び、
  # parent shell の PID を polling して死を検知してから pill を消す。
  {
    trap '' HUP INT TERM PIPE QUIT
    exec </dev/null >/dev/null 2>&1
    while kill -0 "$shell_pid" 2>/dev/null; do
      sleep 1
    done
    "$cmux_bin" clear-status "$key" >/dev/null 2>&1
  } &!
  _CMUX_CWD_WATCHER_PID=$!
}

if [[ -n "${ZSH_VERSION:-}" ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _cmux_update_cwd_status
  # 通常終了 (`exit` / EOF) の高速パス。pane 強制クローズ時は watcher が拾う。
  add-zsh-hook zshexit _cmux_clear_cwd_status
  _cmux_update_cwd_status
  _cmux_spawn_cwd_cleanup_watcher
fi
