# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
# ===== Import =====
source ${HOME}/ghq/github.com/nkmr-jp/setup/iterm2_directory_restore.zsh
source ${HOME}/ghq/github.com/nkmr-jp/setup/zsh_functions.zsh
source ${HOME}/ghq/github.com/nkmr-jp/setup/gwt.sh
source ${HOME}/ghq/github.com/nkmr-jp/setup/notify_claude.sh
source ${HOME}/ghq/github.com/nkmr-jp/fish-functions/ghu.zsh

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
alias m='code ${HOME}/ghq/github.com/nkmr-jp/setup/.messages'
alias setup='code ${HOME}/ghq/github.com/nkmr-jp/setup'
alias sleepon='sudo pmset -a disablesleep 0'
alias sleepoff='sudo pmset -a disablesleep 1'
alias opg='gh repo view --web'
alias oura='open https://cloud.ouraring.com/dashboard'
alias e='open /Applications/Effortless.app'
alias get='ghu get'
alias init='ghu init'
alias profile='code ${HOME}/.zprofile'
alias run='go run main.go'
alias xbar='code ${HOME}/ghq/github.com/nkmr-jp/xbar/plugins'
alias ops='open https://console.cloud.google.com/storage/browser'
alias opf='open https://console.cloud.google.com/functions/list'
alias opb='open https://console.cloud.google.com/bigquery'
alias opr='open https://console.cloud.google.com/run'
alias ope='open https://console.cloud.google.com/eventarc/triggers'
alias wind='windsurf'
alias cl='claude'
alias g='gwt'
alias gq='gwt q'
alias gp='gwt p'
alias gr='gwt r'
alias gl='gwt l'
alias gs='gwt s'
# See: https://spiess.dev/blog/how-i-use-claude-code
alias yolo="claude --dangerously-skip-permissions"

# ===== Zsh Settings =====
# History configuration
HISTFILE=${HOME}/.zsh_history
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
# if [[ -f ${HOME}/.zshrc.local ]]; then
#     source ${HOME}/.zshrc.local
# fi

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/nkmr/.lmstudio/bin"
# End of LM Studio CLI section


# Amazon Q post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"
