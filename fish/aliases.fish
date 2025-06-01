# Fish-specific aliases
# Converted from common/aliases.sh

# Basic file operations
alias l='ls'
alias ll='ls -l'
alias lla='ls -la'
alias op='open'
alias rm='trash-put'
alias c='clear'

# Applications
alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
alias e='open /Applications/Effortless.app'

# Shell management
alias load='exec $SHELL -l'

# Development
alias pecob='peco --layout bottom-up'
function m; code "$SETUP_DIR/.messages"; end
function setup; code "$SETUP_DIR"; end
alias profile='code ~/.zprofile'
alias run='go run main.go'
alias xbar='code ~/ghq/github.com/nkmr-jp/xbar/plugins'

# GitHub
alias opg='gh repo view --web'
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
alias oura='open https://cloud.ouraring.com/dashboard'
alias wind='windsurf'