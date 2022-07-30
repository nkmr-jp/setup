# Golang
# See: https://github.com/golang/go/issues/35164#issuecomment-546503518
export GO111MODULE=on
export GOPROXY=direct
export GOSUMDB=off

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

# For installing Command binaries
export PATH="$HOME/src/bin:$PATH"

# save path order
export ZSH_PATH=$PATH
