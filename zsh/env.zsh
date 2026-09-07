# Environment variables and PATH settings

# Setup directory
# Respect an existing value from .zshrc (needed for verification from a worktree).
export SETUP_DIR="${SETUP_DIR:-$HOME/ghq/github.com/nkmr-jp/setup}"

# Remove duplicate PATH entries automatically, keeping the first, highest-priority entry.
# .zprofile, installers, and env.zsh repeatedly add the same directories;
# without this, 24 of 82 entries were duplicates scanned on every command lookup.
#
# Apply -U to both the array (path) and scalar (PATH).
# `typeset -U path` alone only deduplicates assignments to `path=(...)`,
# not the `export PATH="X:$PATH"` form used for most additions here (verified experimentally).
typeset -U PATH path FPATH fpath

# Golang
export GO111MODULE=on
export GOPROXY=direct
export GOSUMDB="sum.golang.org"

# anyenv and goenv
export GOENV_ROOT="$HOME/.anyenv/envs/goenv/"

# Build PATH with proper order
export PATH="$GOENV_ROOT/bin:$PATH"
export PATH="$HOME/.anyenv/bin:$PATH"

# Add Go paths if GOROOT and GOPATH are set
if [[ -n "$GOROOT" ]]; then
    export PATH="$GOROOT/bin:$PATH"
fi
if [[ -n "$GOPATH" ]]; then
    export PATH="$PATH:$GOPATH/bin"
fi

# Additional paths
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"   # Antigravity CLI is also installed here.
export PATH="$HOME/.grok/bin:$PATH"
export PATH="/usr/local/Caskroom/miniconda/base/bin:$PATH"

# For installing Command binaries
export PATH="$HOME/src/bin:$PATH"

# setup repo scripts (shell functions exposed as commands for GUI apps, cron, other tools)
export PATH="$SETUP_DIR/bin:$PATH"

# Added by Windsurf
export PATH="$HOME/.codeium/windsurf/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:$HOME/.lmstudio/bin"

# aqua https://aquaproj.github.io/docs/install
# Cache `aqua root-dir`: it starts a process each time but returns a fixed value.
_zsh_cache_var aqua-root-dir.zsh AQUA_ROOT_DIR "${commands[aqua]}" -- aqua root-dir
export PATH="${AQUA_ROOT_DIR:-$HOME/.local/share/aquaproj-aqua}/bin:$PATH"

# Export PATH to GUI apps (for GoLand, VSCode, etc.)
# This allows GUI apps launched from Dock/Spotlight to access CLI tools
launchctl setenv PATH "$PATH" 2>/dev/null || true

# See: https://opencode.ai/docs/tui/#editor-setup
export EDITOR="code --wait"

# See: https://codeclaude.com/docs/en/fullscreen
export CLAUDE_CODE_NO_FLICKER=1

# gwt: issues repository targeted by .agentsws/issues when creating a worktree.
# If unset, _gwt_setup_agentsws_issues_link silently skips symlink creation.
# gwt.zsh resolves the projects/ layout (<repo>/projects/<project>/),
# so this value points to the repository root.
export GWT_ISSUES_REPO_DIR="$HOME/ghq/github.com/nkmr-jp/issues"