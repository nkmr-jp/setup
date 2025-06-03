#!/bin/bash

notify_claude() {
    local title="$1"
    local message="$2"
    local sound="${3:-default}"
    
    # Trace parent processes to find the originating application
    local pid=$$
    local bundle_id=""
    
    while [ -n "$pid" ] && [ "$pid" -ne 1 ]; do
        # Get parent PID
        local ppid=$(ps -p $pid -o ppid= | tr -d ' ')
        
        # Get process command
        local cmd=$(ps -p $ppid -o comm= 2>/dev/null || echo "")
        
        # Check if this is an app process
        if [[ "$cmd" =~ "Applications" ]] || [[ "$cmd" == *".app"* ]]; then
            # Try to get bundle ID from the process
            local app_path=$(ps -p $ppid -o comm= | grep -o '/Applications/.*\.app' | head -1)
            if [ -n "$app_path" ]; then
                bundle_id=$(osascript -e "id of app \"${app_path}\"" 2>/dev/null || "")
                if [ -n "$bundle_id" ]; then
                    break
                fi
            fi
        fi
        
        # Special cases for known apps
        case "$cmd" in
            *"Visual Studio Code"*|*"Code Helper"*|*"Electron"*)
                bundle_id="com.microsoft.VSCode"
                break
                ;;
            *"iTerm"*|*"iTerm2"*)
                bundle_id="com.googlecode.iterm2"
                break
                ;;
            *"Terminal"*)
                bundle_id="com.apple.Terminal"
                break
                ;;
        esac
        
        pid=$ppid
    done
    
    # Fallback to frontmost app if bundle ID not found
    if [ -z "$bundle_id" ]; then
        bundle_id=$(osascript -e 'tell application "System Events" to get bundle identifier of (first application process whose frontmost is true)')
    fi

    terminal-notifier \
        -title "Claude Code" \
        -subtitle "$title" \
        -message "$message" \
        -sound "$sound" \
        -activate "$bundle_id"
}

