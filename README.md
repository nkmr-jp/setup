# Setup

## Install HomeBrew

```shell
$ /usr/bin/ruby -e “$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

```shell
$ brew install fish ghq peco hub
```

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

## Set .zprofile
```sh
# ~/.zprofile
fish
```