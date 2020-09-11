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
alias setup='code ~/ghq/github.com/nkmr-jp/setup'
alias get='ghq get -p'

# uitl
## TODO: project listと使うIDEを.private.fisで設定できるようにする
function project
    cd ~/ghq/github.com/$argv[1]
    goland .
end

# search
function s
    open "https://www.google.com/search?q=$argv"
end
function sgo
    open "https://pkg.go.dev/search?q=$argv"
end
function srep
    open "https://github.com/nkmr-jp?tab=repositories&q=$argv"
end
function shub
    open "https://github.com/search?q=$argv"
end

# help
alias help-fish='open https://fishshell.com/docs/current/commands.html'
alias help-go-mod='open https://github.com/golang/go/wiki/Modules'
function help-jq
    open https://dev.classmethod.jp/articles/jq-manual-japanese-translation-roughly/;
    open https://stedolan.github.io/jq/manual/;
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

## private
if test -f ~/ghq/github.com/nkmr-jp/setup/.private.fish
   source ~/ghq/github.com/nkmr-jp/setup/.private.fish
end