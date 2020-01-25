<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->
# Setup

<!-- code_chunk_output -->

- [Setup](#setup)
  - [HomeBrew Settings](#homebrew-settings)
    - [Install HomeBrew](#install-homebrew)
    - [Install required commands](#install-required-commands)
  - [Git Settings](#git-settings)
    - [set SSH key to Github](#set-ssh-key-to-github)
    - [clone this repository](#clone-this-repository)
    - [set .gitconfig](#set-gitconfig)
    - [change git user](#change-git-user)
  - [Fish Settings](#fish-settings)
    - [set ~/.zprofile](#set-zprofile)
    - [set ~/.config/fish/config.fish](#set-configfishconfigfish)

<!-- /code_chunk_output -->


## HomeBrew Settings

### Install HomeBrew

```shell
$ /usr/bin/ruby -e “$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

### Install required commands

```shell
$ brew install fish ghq peco hub
```

## Git Settings

### set SSH key to Github

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

### change git user
~/ghq/github.com/nkmr-jp/setup/gitconfig
```
[user]
    name = someone
    email = someone@example.com
```

## Fish Settings

### set ~/.zprofile
```shell
# write shell scripts here.

fish
```

### set ~/.config/fish/config.fish
```shell
source $HOME/ghq/github.com/nkmr-jp/setup/config.fish

# write fish scripts here.
```