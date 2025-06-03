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
                # Special handling for JetBrains apps which may have version-specific paths
                if [[ "$app_path" =~ "JetBrains" ]]; then
                    # Extract the base app name from path like "/Applications/IntelliJ IDEA.app"
                    local base_app_name=$(basename "$app_path" .app)
                    bundle_id=$(osascript -e "id of app \"$base_app_name\"" 2>/dev/null || "")
                else
                    bundle_id=$(osascript -e "id of app \"${app_path}\"" 2>/dev/null || "")
                fi
                if [ -n "$bundle_id" ]; then
                    break
                fi
            fi
        fi
        
        # Special cases for known apps
        case "$cmd" in
            # IDEs and Editors
            *"Visual Studio Code"*|*"Code Helper"*|*"Electron"*)
                bundle_id="com.microsoft.VSCode"
                break
                ;;
            *"Cursor"*)
                bundle_id="com.todesktop.230313mzl4w4u92"
                break
                ;;
            *"Zed"*)
                bundle_id="dev.zed.Zed"
                break
                ;;
            *"Fleet"*)
                bundle_id="com.jetbrains.fleet"
                break
                ;;
            *"IntelliJ IDEA"*|*"idea"*)
                bundle_id="com.jetbrains.intellij"
                break
                ;;
            *"PyCharm"*|*"pycharm"*)
                bundle_id="com.jetbrains.pycharm"
                break
                ;;
            *"WebStorm"*|*"webstorm"*)
                bundle_id="com.jetbrains.webstorm"
                break
                ;;
            *"GoLand"*|*"goland"*)
                bundle_id="com.jetbrains.goland"
                break
                ;;
            *"RubyMine"*|*"rubymine"*)
                bundle_id="com.jetbrains.rubymine"
                break
                ;;
            *"PhpStorm"*|*"phpstorm"*)
                bundle_id="com.jetbrains.phpstorm"
                break
                ;;
            *"DataGrip"*|*"datagrip"*)
                bundle_id="com.jetbrains.datagrip"
                break
                ;;
            *"CLion"*|*"clion"*)
                bundle_id="com.jetbrains.clion"
                break
                ;;
            *"Rider"*|*"rider"*)
                bundle_id="com.jetbrains.rider"
                break
                ;;
            *"Android Studio"*)
                bundle_id="com.google.android.studio"
                break
                ;;
            
            # Terminal Apps
            *"iTerm"*|*"iTerm2"*)
                bundle_id="com.googlecode.iterm2"
                break
                ;;
            *"Terminal"*)
                bundle_id="com.apple.Terminal"
                break
                ;;
            *"Alacritty"*)
                bundle_id="io.alacritty"
                break
                ;;
            *"kitty"*)
                bundle_id="net.kovidgoyal.kitty"
                break
                ;;
            *"Warp"*)
                bundle_id="dev.warp.Warp-Stable"
                break
                ;;
            *"Hyper"*)
                bundle_id="co.zeit.hyper"
                break
                ;;
            
            # Other Editors
            *"Sublime Text"*)
                bundle_id="com.sublimetext.4"
                break
                ;;
            *"Atom"*)
                bundle_id="com.github.atom"
                break
                ;;
            *"Nova"*)
                bundle_id="com.panic.Nova"
                break
                ;;
            *"TextMate"*)
                bundle_id="com.macromates.TextMate"
                break
                ;;
                
            # Java-based apps (often JetBrains)
            *"java"*)
                # Check if it's a JetBrains app by looking at the full command
                local full_cmd=$(ps -p $ppid -o args= 2>/dev/null || echo "")
                if [[ "$full_cmd" =~ "jetbrains" ]]; then
                    # Try to extract the actual app from the command line
                    if [[ "$full_cmd" =~ "idea" ]]; then
                        bundle_id="com.jetbrains.intellij"
                    elif [[ "$full_cmd" =~ "pycharm" ]]; then
                        bundle_id="com.jetbrains.pycharm"
                    elif [[ "$full_cmd" =~ "webstorm" ]]; then
                        bundle_id="com.jetbrains.webstorm"
                    elif [[ "$full_cmd" =~ "goland" ]]; then
                        bundle_id="com.jetbrains.goland"
                    elif [[ "$full_cmd" =~ "rubymine" ]]; then
                        bundle_id="com.jetbrains.rubymine"
                    elif [[ "$full_cmd" =~ "phpstorm" ]]; then
                        bundle_id="com.jetbrains.phpstorm"
                    elif [[ "$full_cmd" =~ "datagrip" ]]; then
                        bundle_id="com.jetbrains.datagrip"
                    elif [[ "$full_cmd" =~ "clion" ]]; then
                        bundle_id="com.jetbrains.clion"
                    elif [[ "$full_cmd" =~ "rider" ]]; then
                        bundle_id="com.jetbrains.rider"
                    fi
                    if [ -n "$bundle_id" ]; then
                        break
                    fi
                fi
                ;;
        esac
        
        pid=$ppid
    done
    
    # Fallback to frontmost app if bundle ID not found
    if [ -z "$bundle_id" ]; then
        bundle_id=$(osascript -e 'tell application "System Events" to get bundle identifier of (first application process whose frontmost is true)')
    fi

    # Get app name from bundle ID
    local app_name=""
    case "$bundle_id" in
        # IDEs and Editors
        "com.microsoft.VSCode"|"com.microsoft.VSCode.helper")
            app_name="VSCode"
            ;;
        "com.todesktop.230313mzl4w4u92")
            app_name="Cursor"
            ;;
        "dev.zed.Zed")
            app_name="Zed"
            ;;
        "com.jetbrains.fleet")
            app_name="Fleet"
            ;;
        "com.jetbrains.intellij"*|"com.jetbrains.intellij-EAP"*)
            app_name="IntelliJ IDEA"
            ;;
        "com.jetbrains.pycharm"*|"com.jetbrains.pycharm-EAP"*)
            app_name="PyCharm"
            ;;
        "com.jetbrains.webstorm"*|"com.jetbrains.webstorm-EAP"*)
            app_name="WebStorm"
            ;;
        "com.jetbrains.goland"*|"com.jetbrains.goland-EAP"*)
            app_name="GoLand"
            ;;
        "com.jetbrains.rubymine"*|"com.jetbrains.rubymine-EAP"*)
            app_name="RubyMine"
            ;;
        "com.jetbrains.phpstorm"*|"com.jetbrains.phpstorm-EAP"*)
            app_name="PhpStorm"
            ;;
        "com.jetbrains.datagrip"*|"com.jetbrains.datagrip-EAP"*)
            app_name="DataGrip"
            ;;
        "com.jetbrains.clion"*|"com.jetbrains.clion-EAP"*)
            app_name="CLion"
            ;;
        "com.jetbrains.rider"*|"com.jetbrains.rider-EAP"*)
            app_name="Rider"
            ;;
        "com.google.android.studio")
            app_name="Android Studio"
            ;;
        "com.sublimetext."*)
            app_name="Sublime Text"
            ;;
        "com.github.atom"*)
            app_name="Atom"
            ;;
        "com.panic.Nova")
            app_name="Nova"
            ;;
        "com.macromates.TextMate"*)
            app_name="TextMate"
            ;;
            
        # Terminal Apps
        "com.googlecode.iterm2")
            app_name="iTerm2"
            ;;
        "com.apple.Terminal")
            app_name="Terminal"
            ;;
        "io.alacritty")
            app_name="Alacritty"
            ;;
        "net.kovidgoyal.kitty")
            app_name="Kitty"
            ;;
        "dev.warp.Warp-Stable"|"dev.warp.Warp")
            app_name="Warp"
            ;;
        "co.zeit.hyper")
            app_name="Hyper"
            ;;
            
        *)
            # Try to get app name dynamically
            app_name=$(osascript -e "tell application \"System Events\" to get name of (first application process whose bundle identifier is \"$bundle_id\")" 2>/dev/null || echo "")
            
            # If still empty, try to extract from bundle ID
            if [ -z "$app_name" ]; then
                # Extract potential app name from bundle ID (e.g., com.company.AppName -> AppName)
                app_name=$(echo "$bundle_id" | sed -E 's/^com\.[^.]+\.(.+)$/\1/' | sed 's/-/ /g')
                
                # Capitalize first letter of each word
                app_name=$(echo "$app_name" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
            fi
            ;;
    esac
    
    # Build title with app name if available
    local notification_title="Claude Code"
    if [ -n "$app_name" ]; then
        notification_title="Claude Code - $app_name"
    fi
    
    terminal-notifier \
        -title "$notification_title" \
        -subtitle "$title" \
        -message "$message" \
        -sound "$sound" \
        -activate "$bundle_id"
}

