# Fish-specific functions
# Converted from common/functions.sh

# Display bash colors
function bash_colors
    # See: https://gist.github.com/rsperl/d2dfe88a520968fbc1f49db0a29345b9
    bash -c 'for c in {0..255}; do tput setaf $c; tput setaf $c | cat -v; echo =$c; done'
end

# Display Fish colors
function colors
    for x in (string split "\n" (set_color --print-colors))
        set_color $x; echo $x; set_color reset;
    end 
end

# Display system stats
function stats
    echo ""
    echo "[ Programming Languages ]"
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

# Git worktree functions for Fish
# Create a worktree and immediately change to it
function wtc
    if test (count $argv) -eq 0
        echo "Usage: wtc <branch-name>"
        return 1
    end
    git worktree add $argv[1]; and cd $argv[1]
end

# Interactively select and change to a worktree
function wts
    set worktree (git worktree list | fzf | awk '{print $1}')
    if test -n "$worktree"
        cd "$worktree"
    end
end

# Clean up unnecessary worktrees
function wtclean
    git worktree list | grep -E '\[.*gone\]' | awk '{print $1}' | xargs -I {} git worktree remove {}
end