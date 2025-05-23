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
alias xbar='code ~/ghq/github.com/nkmr-jp/xbar/plugins'
alias ops='open https://console.cloud.google.com/storage/browser'
alias opf='open https://console.cloud.google.com/functions/list'
alias opb='open https://console.cloud.google.com/bigquery'
alias opr='open https://console.cloud.google.com/run'
alias ope='open https://console.cloud.google.com/eventarc/triggers'
alias wind='windsurf'


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


# fish settings
## plugin settings
### https://github.com/franciscolourenco/done
set -U __done_min_cmd_duration 5000

## keybind
# bind \c] enhancd

## restore path order from zsh
set PATH $ZSH_PATH
    
## messages
function fish_greeting
    gshuf -n 1 $HOME/ghq/github.com/nkmr-jp/setup/.messages
end

## pack 
## See: https://buildpacks.io/docs/tools/pack/
# source (pack completion --shell fish)