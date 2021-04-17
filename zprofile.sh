export PATH="$HOME/.anyenv/bin:$PATH"
eval "$(anyenv init - zsh)"

# path
export PATH="$GOPATH/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="/usr/local/opt/openjdk/bin:$PATH"

# For installing Command binaries
export PATH="$HOME/src/bin:$PATH"

# export PATH="$HOME/ghq/github.com/nkmr-jp/setup/bin:$PATH"
# chmod a+x $HOME/ghq/github.com/nkmr-jp/setup/bin/*

# save path order
export ZSH_PATH=$PATH
