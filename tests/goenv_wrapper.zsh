#!/bin/zsh
# goenv.zsh テスト用ラッパー
# _goenv_set_paths を実行し、解決された GOROOT / GOPATH を出力する

source "${0:A:h}/../zsh/goenv.zsh"

_goenv_set_paths
print -r -- "GOROOT=${GOROOT:-}"
print -r -- "GOPATH=${GOPATH:-}"
