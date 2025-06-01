# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
# ===== Import =====
source ~/ghq/github.com/nkmr-jp/setup/zsh_functions.zsh
source ~/ghq/github.com/nkmr-jp/setup/gwt.zsh
source ~/ghq/github.com/nkmr-jp/fish-functions/ghu.zsh

# ===== Aliases =====
alias l='ls'
alias ll='ls -l'
alias lla='ls -la'
alias op='open'
alias rm='trash-put'
alias pecob='peco --layout bottom-up'
alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
alias load='exec $SHELL -l'
alias c='clear'
alias m='code ~/ghq/github.com/nkmr-jp/setup/.messages'
alias setup='code ~/ghq/github.com/nkmr-jp/setup'
alias sleepon='sudo pmset -a disablesleep 0'
alias sleepoff='sudo pmset -a disablesleep 1'
alias opg='gh repo view --web'
alias oura='open https://cloud.ouraring.com/dashboard'
alias e='open /Applications/Effortless.app'
alias get='ghu get'
alias init='ghu init'
alias profile='code ~/.zprofile'
alias run='go run main.go'
alias xbar='code ~/ghq/github.com/nkmr-jp/xbar/plugins'
alias ops='open https://console.cloud.google.com/storage/browser'
alias opf='open https://console.cloud.google.com/functions/list'
alias opb='open https://console.cloud.google.com/bigquery'
alias opr='open https://console.cloud.google.com/run'
alias ope='open https://console.cloud.google.com/eventarc/triggers'
alias wind='windsurf'
alias cl='claude'

# ===== Zsh Settings =====
# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY        # Share history between sessions
setopt HIST_IGNORE_SPACE    # Don't record commands starting with space
setopt HIST_IGNORE_DUPS     # Don't record duplicated commands

# Completion system
autoload -Uz compinit
compinit

# Enable colors
autoload -Uz colors

# Call the greeting function when starting an interactive shell
# if [[ $- == *i* ]]; then
#     display_greeting
# fi

# Source additional configuration files if they exist
# if [[ -f ~/.zshrc.local ]]; then
#     source ~/.zshrc.local
# fi

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/nkmr/.lmstudio/bin"
# End of LM Studio CLI section
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# Amazon Q post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"
