#!/bin/bash

notify_claude() {
    local title="$1"
    local message="$2"
    local sound="${3:-default}"

    terminal-notifier \
        -title "Claude Code" \
        -subtitle "$title" \
        -message "$message" \
        -sound "$sound"
}

