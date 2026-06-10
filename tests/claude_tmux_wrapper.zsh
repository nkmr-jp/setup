#!/bin/zsh
# ai.zsh の claude() テスト用ラッパー
# zle/compinit など非対話的環境で動かないビルトインをスタブ化

zle() { : }
compdef() { : }
autoload() { : }
compinit() { : }

# ai.zsh を読み込み（alias はテスト対象外なので無視される）
source "${0:A:h}/../zsh/ai.zsh"

# claude 関数を実行
claude "$@"
