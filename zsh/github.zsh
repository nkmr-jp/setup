#!/bin/zsh
# GitHub-related aliases and functions

# Open GitHub repository in browser
function opg() {
    local remote_url branch url

    remote_url=$(git remote get-url origin 2>/dev/null) || {
        echo "Error: Not a git repository or no remote 'origin' found" >&2
        return 1
    }

    # Convert git URL to https
    case "$remote_url" in
        ssh://git@*)  url="https://${remote_url#ssh://git@}" ;;
        git@*)        url="https://${${remote_url#git@}/://}" ;;
        *)            url="$remote_url" ;;
    esac
    url=${url%.git}

    branch=$(git branch --show-current 2>/dev/null)
    [[ -n "$branch" && "$branch" != "main" && "$branch" != "master" ]] && url+="/tree/$branch"

    open "$url"
}

# ghu (GitHub Utility) aliases
alias get='ghu get'
alias init='ghu init'
