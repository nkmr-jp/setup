#!/bin/zsh
# iterm2.zsh テスト用ラッパー
# ガードをバイパスして関数定義だけ読み込む

TERM="xterm-256color"
ITERM_SHELL_INTEGRATION_INSTALLED=""
precmd_functions=()

# 関数定義部分だけ抽出（ガード・precmd_functions登録・初回実行をスキップ）
local src="${0:A:h}/../zsh/iterm2.zsh"
eval "$(awk '/^_get_git_branch\(\)/,/^# precmd_functions/{if(/^# precmd_functions/) exit; print}' "$src")"

# 指定された関数を実行
func="$1"
shift
"$func" "$@"
