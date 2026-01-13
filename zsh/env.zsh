# Environment variables and PATH settings

# Setup directory
export SETUP_DIR="$HOME/ghq/github.com/nkmr-jp/setup"

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
export PATH="$HOME/.local/bin:$PATH"
export PATH="/usr/local/Caskroom/miniconda/base/bin:$PATH"

# For installing Command binaries
export PATH="$HOME/src/bin:$PATH"

# Added by Windsurf
export PATH="$HOME/.codeium/windsurf/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/nkmr/.lmstudio/bin"

# aqua https://aquaproj.github.io/docs/install
export PATH="$(aqua root-dir)/bin:$PATH"

# Export PATH to GUI apps (for GoLand, VSCode, etc.)
# This allows GUI apps launched from Dock/Spotlight to access CLI tools
launchctl setenv PATH "$PATH" 2>/dev/null || true
