#!/bin/zsh

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
    system_profiler SPHardwareDataType

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

# Run Prompt Line plugin commands from anywhere
# Usage: prompt-line-plugin install github.com/user/repo[@ref]
function prompt-line-plugin() {
    pnpm --dir "$(ghq root)/github.com/nkmr-jp/prompt-line" run "plugin:$1" "${@:2}"
}

# Auto-run make login if Makefile exists with login target
function auto_make_login() {
    if [[ -f "Makefile" ]] && grep -q '^login:' Makefile; then
        make login
    fi
}
