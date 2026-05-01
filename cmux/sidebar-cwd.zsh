#!/usr/bin/env zsh
# cmux サイドバーに現在ディレクトリの basename を pill として表示する。
# `cmux set-status cwd <basename>` を chpwd フック / プロンプト前に呼ぶ。

_cmux_update_cwd_status() {
  (( ${+commands[cmux]} )) || return 0
  cmux set-status cwd "${PWD:t}" --icon folder >/dev/null 2>&1
}

if [[ -n "${ZSH_VERSION:-}" ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _cmux_update_cwd_status
  _cmux_update_cwd_status
fi
