<!-- @import "[TOC]" {cmd="toc" depthFrom=1 depthTo=6 orderedList=false} -->
# Setup

<!-- code_chunk_output -->

- [Setup](#setup)
  - [Homebrew Settings (homebrew)](#homebrew-settings-homebrew)
    - [install homebrew](#install-homebrew)
    - [install commands](#install-commands)
  - [Git Settings](#git-settings)
    - [set ssh key to github](#set-ssh-key-to-github)
    - [clone this repository](#clone-this-repository)
    - [set .gitconfig](#set-gitconfig)
    - [set git user](#set-git-user)
  - [Fish Settings (fish)](#fish-settings-fish)
    - [install fisher (fisher)](#install-fisher-fisher)
    - [install fish plugins](#install-fish-plugins)
    - [set messages](#set-messages)
    - [set ~/.zprofile](#set-zprofile)
    - [set ~/.config/fish/config.fish](#set-configfishconfigfish)
    - [fish_config](#fishconfig)
  - [Anyenv (anyenv)](#anyenv-anyenv)
    - [install env commands](#install-env-commands)
    - [install programing langages and set global version](#install-programing-langages-and-set-global-version)

<!-- /code_chunk_output -->


## Homebrew Settings ([homebrew](https://brew.sh/index_ja))

### install homebrew

```shell
$ /usr/bin/ruby -e “$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

### install commands

```shell
$ brew install fish ghq peco hub fzf rmtrash terminal-notifier jq tig httpie anyenv fx translate-shell tree bat gitmoji coreutils
```

## Git Settings

### set ssh key to github

[GitHub Help](https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

### clone this repository
```shell
$ ghq get -p nkmr-jp/setup
```

### set .gitconfig
```ini
# ~/.gitconfig
[include]
    path = ~/ghq/github.com/nkmr-jp/setup/gitconfig
```

### set git user
```
$ git config --global user.name "username"
$ git config --global user.email "mailaddress"
```

## Fish Settings ([fish](https://fishshell.com/))

### install fisher ([fisher](https://github.com/jorgebucaran/fisher))
```
$ curl https://git.io/fisher —create-dirs -sLo ~/.config/fish/functions/fisher.fish
``` 

### install fish plugins
```
$ fish

$ fisher add \
b4b4r07/enhancd \
decors/fish-ghq \
edc/bass \
fishpkg/fish-humanize-duration \
franciscolourenco/done \
jethrokuan/fzf \
jethrokuan/z \
oh-my-fish/theme-nai

$ fisher
```

### set messages
```shell
# A message that is displayed at random when the shell starts.
echo "hello world!" >> .messages
echo "shut the fuck up and write some code" >> .messages
echo "stay hungry stay foolish" >> .messages
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
$ fish_config

# setting in browser
```

## Anyenv ([anyenv](https://github.com/anyenv/anyenv))

### install env commands

```sh
$ anyenv install --init
$ anyenv install rbenv
$ anyenv install pyenv
$ anyenv install goenv
$ anyenv install nodenv
$ exec $SHELL -l
```

### install programing langages and set global version
```sh
$ goenv install 1.13.6
$ goenv global 1.13.6
$ go version
go version go1.13.6 darwin/amd64

# rbenv pyenv nodenv ...

```

### To get the latest version
```sh
$ brew upgrade anyenv
$ anyenv install --update
$ anyenv install goenv

# rbenv pyenv nodenv ...
```
