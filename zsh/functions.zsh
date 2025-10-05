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
