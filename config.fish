# alias
alias l='ls'
alias lla='ll -a'
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
alias xbar='code "/Users/nkmr/Library/Application Support/xbar/plugins"'

# util

function todo
    if count $argv > /dev/null
        if test $argv[1] = "all"
            echo
            echo
            for x in (string split "\n" (echo $ACTIVE_REPO))
                if test -f ~/ghq/github.com/nkmr-jp/$x/.todo.txt
                    set_color blue; echo "▶ https://github.com/nkmr-jp/$x"; set_color reset; 
                    echo
                    set_color yellow;
                    sed  's/^/     • /'  ~/ghq/github.com/nkmr-jp/$x/.todo.txt
                    set_color reset;
                    echo
                end
            end
        else
            echo "$argv[1]" >> .todo.txt
        end
    else if test -f .todo.txt
        echo
        set_color yellow;
        sed  's/^/     • /' .todo.txt
        set_color reset;
        echo
    end
end

function ql 
    qlmanage -p $argv[1] > /dev/null ^&1
end

function bash_colors
    # See: https://gist.github.com/rsperl/d2dfe88a520968fbc1f49db0a29345b9
    bash -c 'for c in {0..255}; do tput setaf $c; tput setaf $c | cat -v; echo =$c; done'
end

function colors
    for x in (string split "\n" (set_color --print-colors))
        set_color $x; echo $x; set_color reset;
    end 
end

function stats
    echo ""
    echo "[ Programing Languages ]"
    go version 
    node -v
    python -V
    ruby -v

    echo ""
    echo ""
    echo "[ macOS ]"
    system_profiler SPSoftwareDataType 
    # system_profiler SPHardwareDataType

    echo ""
    echo ""
    echo "[ iStats ]"
    istats
end

# query
function query
    open "https://www.google.com/search?q=$argv"
end
function query-go
    open "https://pkg.go.dev/search?q=$argv"
end
function query-repo
    open "https://github.com/nkmr-jp?tab=repositories&q=$argv"
end
function query-github
    open "https://github.com/search?q=$argv"
end

# help  
alias help-fish='open https://fishshell.com/docs/current/commands.html'
alias help-go-mod='open https://github.com/golang/go/wiki/Modules'
alias help-gh='open https://cli.github.com/manual/'
alias help-gcloud='open https://cloud.google.com/sdk/docs/cheatsheet'
alias help-docker='open https://docs.docker.com/engine/reference/commandline/docker/'
function help-jq
    open https://dev.classmethod.jp/articles/jq-manual-japanese-translation-roughly/;
    open https://stedolan.github.io/jq/manual/;
end
function help-go-zap
    open https://pkg.go.dev/go.uber.org/zap?tab=doc
    open https://qiita.com/emonuh/items/28dbee9bf2fe51d28153
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