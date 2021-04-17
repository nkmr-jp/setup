<!-- @import "[TOC]" {cmd="toc" depthFrom=1 depthTo=6 orderedList=false} -->
# Setup

<!-- code_chunk_output -->

- [Setup](#setup)
  - [Homebrew Settings (homebrew)](#homebrew-settings-homebrewhttpsbrewshindex_ja)
    - [install homebrew](#install-homebrew)
    - [install commands](#install-commands)
    - [install QucickLook Plugins](#install-qucicklook-plugins)
  - [Git Settings](#git-settings)
    - [set ssh key to github](#set-ssh-key-to-github)
    - [clone this repository](#clone-this-repository)
    - [set .gitconfig](#set-gitconfig)
    - [set git user](#set-git-user)
  - [Fish Settings (fish)](#fish-settings-fishhttpsfishshellcom)
    - [install fisher (fisher)](#install-fisher-fisherhttpsgithubcomjorgebucaranfisher)
    - [install fish plugins](#install-fish-plugins)
    - [set messages](#set-messages)
    - [set ~/.zprofile](#set-~zprofile)
    - [set ~/.config/fish/config.fish](#set-~configfishconfigfish)
    - [fish_config](#fish_config)
  - [Anyenv (anyenv)](#anyenv-anyenvhttpsgithubcomanyenvanyenv)
    - [install env commands](#install-env-commands)
    - [install programing langages and set global version](#install-programing-langages-and-set-global-version)
    - [To get the latest version](#to-get-the-latest-version)
  - [Install Rust](#install-rust)
  - [Install Java](#install-java)
  - [Install Commands for each language](#install-commands-for-each-language)
  - [Install Commands from Binary](#install-commands-from-binary)
  - [Settings](#settings)
    - [tig](#tig)

<!-- /code_chunk_output -->


## Homebrew Settings ([homebrew](https://brew.sh/index_ja))

### install homebrew

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### install commands

```shell
brew install \
fish ghq peco hub fzf trash-cli terminal-notifier  \
jq tig httpie anyenv fx translate-shell tree bat gitmoji coreutils  \
procs golangci/tap/golangci-lint \
exa fd
```

### install QucickLook Plugins

```shell
# https://github.com/sindresorhus/quick-look-plugins
brew install qlcolorcode qlstephen qlmarkdown quicklook-json qlimagesize suspicious-package quicklookase qlvideo
xattr -r ~/Library/QuickLook
xattr -d -r com.apple.quarantine ~/Library/QuickLook
```

## Git Settings

### set ssh key to github

[GitHub Help](https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

### clone this repository
```shell
ghq get -p nkmr-jp/setup
```

### set .gitconfig
```ini
# ~/.gitconfig
[include]
    path = ~/ghq/github.com/nkmr-jp/setup/gitconfig
```

### set git user
```shell
git config --global user.name "username"
git config --global user.email "mailaddress"
```

## Fish Settings ([fish](https://fishshell.com/))

### install fisher ([fisher](https://github.com/jorgebucaran/fisher))
```shell
mkdir -p ~/.config ~/.config/fish ~/.config/fish/functions
curl https://git.io/fisher —create-dirs -sLo ~/.config/fish/functions/fisher.fish
``` 

### install fish plugins
```shell
fish

fisher install \
b4b4r07/enhancd \
decors/fish-ghq \
edc/bass \
fishpkg/fish-humanize-duration \
franciscolourenco/done \
jethrokuan/fzf \
jethrokuan/z \
oh-my-fish/theme-nai

fisher list

exit
```

### set messages
```shell
# A message that is displayed at random when the shell starts.
echo "hello world!" >> ~/ghq/github.com/nkmr-jp/setup/.messages
echo "shut the fuck up and write some code" >> ~/ghq/github.com/nkmr-jp/setup/.messages
echo "stay hungry stay foolish" >> ~/ghq/github.com/nkmr-jp/setup/.messages
```

### set ~/.zprofile
```shell
source $HOME/ghq/github.com/nkmr-jp/setup/zprofile.sh

# write bash scripts here.

exec fish
```

### set ~/.config/fish/config.fish
```shell
source $HOME/ghq/github.com/nkmr-jp/setup/config.fish

# write fish scripts here.
```

### fish_config
```shell
fish
fish_config

# setting in browser
```

## Anyenv ([anyenv](https://github.com/anyenv/anyenv))

### install env commands

```sh
anyenv install --init
anyenv install rbenv
anyenv install pyenv
anyenv install goenv
anyenv install nodenv
exec $SHELL -l
```

### install programing langages and set global version
```sh
goenv install 1.16.3
goenv global 1.16.3
go version
# > go version go1.16.3 darwin/amd64

# rbenv pyenv nodenv ...

```

### To get the latest version
```sh
brew upgrade anyenv
anyenv install --update
anyenv install goenv

# rbenv pyenv nodenv ...
```

## Install Rust
```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup -V
# > rustup 1.23.1 (3df2264a9 2020-11-30)
# > info: This is the version for the rustup toolchain manager, not the rustc compiler.
# > info: The currently active `rustc` version is `rustc 1.51.0 (2fd73fabe 2021-03-23)`
```

## Install Java
```sh
brew install java
java --version
# > openjdk 15.0.2 2021-01-19
# > OpenJDK Runtime Environment (build 15.0.2+7)
# > OpenJDK 64-Bit Server VM (build 15.0.2+7, mixed mode, sharing)
```

## Install Commands for each language
```sh
gem install iStats
npm install -g fkill-cli
pip install yq
```

## Install Commands from Binary
```sh
mkdir -p ~/src ~/src/bin
cd ~/src
curl -OL https://github.com/cheat/cheat/releases/download/4.2.0/cheat-darwin-amd64.gz
gzip -d cheat-darwin-amd64.gz
mv cheat-darwin-amd64 ./bin/cheat
chmod 755 ./bin/cheat
```

## Settings

### tig

See: https://qiita.com/numanomanu/items/513d62fb4a7921880085

```sh
# ~/.tigrc
bind main    B !git rebase -i %(commit)
bind diff    B !git rebase -i %(commit)
```
