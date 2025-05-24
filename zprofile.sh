# Starship
eval "$(starship init zsh)"

# Golang
# See: https://github.com/golang/go/issues/35164#issuecomment-546503518
export GO111MODULE=on
export GOPROXY=direct
export GOSUMDB="sum.golang.org"

# anyenv
# goenv
# https://github.com/syndbg/goenv/blob/master/INSTALL.md
export GOENV_ROOT="$HOME/.anyenv/envs/goenv/"
export PATH="$GOENV_ROOT/bin:$PATH"
export PATH="$HOME/.anyenv/bin:$PATH"
eval "$(anyenv init - zsh)"
export PATH="$GOROOT/bin:$PATH"
export PATH="$PATH:$GOPATH/bin"

# path
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="/usr/local/Caskroom/miniconda/base/bin:$PATH"

# For installing Command binaries
export PATH="$HOME/src/bin:$PATH"

# Added by Windsurf
export PATH="$HOME/.codeium/windsurf/bin:$PATH"

# save path order
export ZSH_PATH=$PATH
