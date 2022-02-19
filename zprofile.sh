export PATH="$HOME/.anyenv/bin:$PATH"
eval "$(anyenv init - zsh)"

# path
export PATH="$GOPATH/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# For installing Command binaries
export PATH="$HOME/src/bin:$PATH"

# save path order
export ZSH_PATH=$PATH
