<!-- @import "[TOC]" {cmd="toc" depthFrom=1 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [HomeBrew Settings](#homebrew-settings)
  - [Install HomeBrew](#install-homebrew)
  - [Install required commands](#install-required-commands)
- [Git settings](#git-settings)
  - [Set SSH key to Github](#set-ssh-key-to-github)
  - [Clone this repository](#clone-this-repository)
  - [Set .gitconfig](#set-gitconfig)
  - [Change git user](#change-git-user)
- [Fish settings](#fish-settings)
  - [Set .config/fish/config.fish](#set-configfishconfigfish)
  - [Set .zprofile](#set-zprofile)

<!-- /code_chunk_output -->


# HomeBrew Settings

## Install HomeBrew

```shell
$ /usr/bin/ruby -e “$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

## Install required commands

```shell
$ brew install fish ghq peco hub
```

# Git settings

## Set SSH key to Github

[GitHub Help](https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

## Clone this repository
```shell
$ ghq get -p nkmr-jp/setup
```

## Set .gitconfig
```ini
# ~/.gitconfig
[include]
    path = ~/ghq/github.com/nkmr-jp/setup/gitconfig
```

## Change git user
~/ghq/github.com/nkmr-jp/setup/gitconfig
```
[user]
    name = someone
    email = someone@example.com
```

# Fish settings
## Set .config/fish/config.fish
```sh
# ~/.config/fish/config.fish
source $HOME/ghq/github.com/nkmr-jp/setup/config.fish
```

## Set .zprofile
```sh
# ~/.zprofile
fish
```