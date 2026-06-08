#!/bin/zsh
# gwt.zsh テスト用ラッパー
# zle/compinit など非対話的環境で動かないビルトインをスタブ化

zle() { : }
compdef() { : }
autoload() { : }
compinit() { : }

# iTerm2 連携関数（iterm2.zsh は読み込まないためスタブ化）
_iterm2_precmd() { : }
_iterm2_send_current_dir() { : }
_iterm2_set_user_var() { : }

# gwt.zsh を読み込み
source "${0:A:h}/../zsh/gwt.zsh"

# 指定された関数を実行
func="$1"
shift
"$func" "$@"
