#!/bin/zsh
# Test wrapper for goenv.zsh
# Run _goenv_set_paths and print the resolved GOROOT and GOPATH.

source "${0:A:h}/../zsh/goenv.zsh"

_goenv_set_paths
print -r -- "GOROOT=${GOROOT:-}"
print -r -- "GOPATH=${GOPATH:-}"
