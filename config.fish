# alias
alias l='ls'
alias lla='ll -a'
alias op='open'
alias rm='rmtrash'
alias pecob='peco --layout bottom-up'
alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
alias load='exec $SHELL -l'
alias c='clear'
alias p='pwd'
alias gmoji='gitmoji'
alias g='hub'
alias m='code ~/ghq/github.com/nkmr-jp/setup/.messages'
alias land='goland'
alias config='code ~/ghq/github.com/nkmr-jp/setup'

# open
alias help-go-mod='open https://github.com/golang/go/wiki/Modules'
function s-go
    open "https://golang.org/search?q=$argv"
end
function s-repo
    open "https://github.com/nkmr-jp?tab=repositories&q=$argv"
end
function s-github
    open "https://github.com/search?q=$argv"
end

# fish settings

## plugin settings
### https://github.com/franciscolourenco/done
set -U __done_min_cmd_duration 5000

## keybind
bind \c] enhancd

## restore path order from zsh
set PATH $ZSH_PATH
    
## messages
function fish_greeting
    gshuf -n 1 $HOME/ghq/github.com/nkmr-jp/setup/.messages
end