#!/bin/zsh
# Common aliases for both Zsh and Fish shells

# Basic file operations
alias l='ls'
alias ll='ls -l'
alias lla='ls -la'
alias o='open'
alias rm='trash'
alias c='clear'
alias e='exit'

# Applications
alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"

# Shell management
alias load='exec $SHELL -l'

# Development
alias pecob='peco --layout bottom-up'
alias m='code "$SETUP_DIR/.messages"'
alias setup='code "$SETUP_DIR"'
alias run='go run main.go'
alias xbar='code ~/ghq/github.com/nkmr-jp/xbar/plugins'

# GitHub
alias opg='open "https://$(pwd | sed "s|$(ghq root)/||")"'
alias get='ghu get'
alias init='ghu init'

# Google Cloud
alias ops='open https://console.cloud.google.com/storage/browser'
alias opf='open https://console.cloud.google.com/functions/list'
alias opb='open https://console.cloud.google.com/bigquery'
alias opr='open https://console.cloud.google.com/run'
alias ope='open https://console.cloud.google.com/eventarc/triggers'

# System
alias sleepon='sudo pmset -a disablesleep 0'
alias sleepoff='sudo pmset -a disablesleep 1'

# Other
alias wind='windsurf'

# AI Agents
alias cl='claude'
alias co='codex'
alias ge='gemini'
# See: https://spiess.dev/blog/how-i-use-claude-code
alias yolo="claude --dangerously-skip-permissions"
alias ep='edge-playback --rate "+25%" -v ja-JP-NanamiNeural --text'
# alias ep='edge-playback --rate "+25%" -v ja-JP-KeitaNeural --text'
alias md="open -a 'Marked 2'"
alias ob='open "obsidian://open?path=$(pwd)"'

# Git worktree
alias g='gwt'
alias gq='gwt q'
alias gp='gwt p'
alias gr='gwt r'
alias gl='gwt l'
alias gs='gwt s'


# See: https://github.com/AikidoSec/safe-chain
source ~/.safe-chain/scripts/init-posix.sh # Safe-chain Zsh initialization script
# socket.dev
# See: https://docs.socket.dev/docs/safe-npm-faq
#alias npm="socket-npm"
#alias npx="socket-npx"
#compdef \_npm socket-npm
