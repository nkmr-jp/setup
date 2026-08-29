#!/bin/zsh
# cache.zsh テスト用ラッパー
# 指定された関数を実行する（ZSH_CACHE_DIR は呼び出し側が環境変数で渡す）

source "${0:A:h}/../zsh/cache.zsh"

func="$1"
shift
"$func" "$@"
