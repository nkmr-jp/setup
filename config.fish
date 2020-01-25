# alias
alias l='ls'
alias lla='ll -a'
alias op 'open'
alias rm 'rmtrash'
alias pecob 'peco --layout bottom-up'
alias chrome "/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
alias cat 'ccat'
alias load 'exec $SHELL -l'

# fish settings

## plugin settings
### https://github.com/franciscolourenco/done
set -U __done_min_cmd_duration 5000

## keybind
bind \c] enhancd

## restore path order
set PATH $ZSH_PATH