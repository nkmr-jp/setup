#!/bin/bash
# Common functions for both Zsh and Fish shells

# Display bash colors
function bash_colors() {
    # See: https://gist.github.com/rsperl/d2dfe88a520968fbc1f49db0a29345b9
    bash -c 'for c in {0..255}; do tput setaf $c; tput setaf $c | cat -v; echo =$c; done'
}

# Display system stats
function stats() {
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
}

# Display greeting message
function display_greeting() {
    if [[ -f "$SETUP_DIR/.messages" ]]; then
        gshuf -n 1 "$SETUP_DIR/.messages"
    fi
}

# Git worktree functions
# Create a worktree and immediately change to it
function wtc() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: wtc <branch-name>" >&2
        return 1
    fi
    git worktree add "$1" && cd "$1" || return 1
}

# Interactively select and change to a worktree
function wts() {
    local worktree
    worktree=$(git worktree list | fzf | awk '{print $1}')
    if [[ -n "$worktree" ]]; then
        cd "$worktree" || return 1
    fi
}

# Clean up unnecessary worktrees
function wtclean() {
    git worktree list | grep -E '\[.*gone\]' | awk '{print $1}' | xargs -I {} git worktree remove {}
}