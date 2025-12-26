#!/bin/zsh
# Basic aliases

# File operations
alias l='ls'
alias ll='ls -l'
alias lla='ls -la'
alias o='open'
alias rm='trash'
alias c='clear'
alias e='exit'

# Applications
alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
alias wind='windsurf'
alias md="open -a 'Marked 2'"
alias ob='open "obsidian://open?path=$(pwd)"'

# Shell management
alias load='exec $SHELL -l'

# Development
alias pecob='peco --layout bottom-up'
alias m='code "$SETUP_DIR/.messages"'
alias setup='code "$SETUP_DIR"'
alias run='go run main.go'
alias xbar='code ~/ghq/github.com/nkmr-jp/xbar/plugins'

# System
alias sleepon='sudo pmset -a disablesleep 0'
alias sleepoff='sudo pmset -a disablesleep 1'

# See: https://oraios.github.io/serena/02-usage/020_running.html
alias serena='uvx --from git+https://github.com/oraios/serena serena'