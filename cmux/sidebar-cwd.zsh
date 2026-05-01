#!/usr/bin/env zsh
# cmux サイドバーに現在ディレクトリの basename を pill として表示する。
# pane ごとにユニークな key を使い、複数 pane でそれぞれの pill を並べる。

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

if [[ -n "${ZSH_VERSION:-}" ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _cmux_update_cwd_status
  add-zsh-hook zshexit _cmux_clear_cwd_status
  _cmux_update_cwd_status
fi
