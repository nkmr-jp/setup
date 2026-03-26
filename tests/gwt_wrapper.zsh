#!/bin/zsh
# gwt.zsh テスト用ラッパー
# zle/compinit など非対話的環境で動かないビルトインをスタブ化

zle() { : }
compdef() { : }
autoload() { : }

# gwt.zsh を読み込み
source "${0:A:h}/../zsh/gwt.zsh"

# 指定された関数を実行
func="$1"
shift
"$func" "$@"
