<!-- @import "[TOC]" {cmd="toc" depthFrom=1 depthTo=6 orderedList=false} -->
# Setup

<!-- code_chunk_output -->

- [Setup](#setup)
  - [Homebrew Settings (homebrew)](#homebrew-settings-homebrew)
    - [install homebrew](#install-homebrew)
    - [install required commands](#install-required-commands)
  - [Git Settings](#git-settings)
    - [set SSH key to Github](#set-ssh-key-to-github)
    - [clone this repository](#clone-this-repository)
    - [set .gitconfig](#set-gitconfig)
    - [change git user](#change-git-user)
  - [Fish Settings (fish)](#fish-settings-fish)
    - [install fisher (fisher)](#install-fisher-fisher)
    - [install fish plugins](#install-fish-plugins)
    - [set ~/.zprofile](#set-zprofile)
    - [set ~/.config/fish/config.fish](#set-configfishconfigfish)

<!-- /code_chunk_output -->


## Homebrew Settings ([homebrew](https://brew.sh/index_ja))

### install homebrew

```shell
$ /usr/bin/ruby -e “$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

### install required commands

```shell
$ brew install fish ghq peco hub fzf ccat rmtrash terminal-notifier jq tig
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

## Fish Settings ([fish](https://fishshell.com/))

### install fisher ([fisher](https://github.com/jorgebucaran/fisher))
```
$ curl https://git.io/fisher —create-dirs -sLo ~/.config/fish/functions/fisher.fish
``` 

### install fish plugins
```
$ fisher add \
jethrokuan/z \
jethrokuan/fzf \
decors/fish-ghq \
b4b4r07/enhancd \
franciscolourenco/done \
fishpkg/fish-prompt-mono \
fishpkg/fish-humanize-duration

$ fisher
```

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