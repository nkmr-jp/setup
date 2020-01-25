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

## Change git user
~/ghq/github.com/nkmr-jp/setup/gitconfig
```
[user]
    name = someone
    email = someone@example.com
```

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