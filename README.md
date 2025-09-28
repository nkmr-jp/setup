# Setup

<!-- TOC -->
* [Setup](#setup)
  * [Homebrew Settings (homebrew)](#homebrew-settings-homebrew)
    * [Install homebrew](#install-homebrew)
    * [Install commands](#install-commands)
    * [Setup Starship preset](#setup-starship-preset)
    * [Iterm2](#iterm2)
    * [Install QucickLook Plugins](#install-qucicklook-plugins)
  * [Git Settings](#git-settings)
    * [Set ssh key to github](#set-ssh-key-to-github)
    * [clone this repository](#clone-this-repository)
    * [Set .gitconfig](#set-gitconfig)
    * [Set git user](#set-git-user)
  * [Repository Structure](#repository-structure)
  * [Shell Settings](#shell-settings)
    * [Automated Installation](#automated-installation)
      * [Set messages](#set-messages)
    * [Zsh Settings](#zsh-settings)
      * [Manual Zsh Setup](#manual-zsh-setup)
  * [Anyenv (anyenv)](#anyenv-anyenv)
    * [Install env commands](#install-env-commands)
    * [Install programing langages and set global version](#install-programing-langages-and-set-global-version)
    * [To get the latest version](#to-get-the-latest-version)
  * [Install Rust](#install-rust)
  * [Install Java](#install-java)
  * [Install AWS CLI v2](#install-aws-cli-v2)
    * [Install](#install)
    * [Setup](#setup-1)
  * [Install Commands for each language](#install-commands-for-each-language)
  * [Install Commands from Binary](#install-commands-from-binary)
  * [Settings](#settings)
    * [pack](#pack)
    * [Google Cloud SDK](#google-cloud-sdk)
    * [tig](#tig)
<!-- TOC -->


## Homebrew Settings ([homebrew](https://brew.sh/index_ja))

### Install homebrew

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Install commands

```shell
brew install \
fish ghq peco gh fzf trash-cli terminal-notifier  \
jq tig httpie anyenv fx translate-shell tree bat gitmoji coreutils  \
procs fd tesseract-lang google-cloud-sdk pre-commit \
tflint buildpacks/tap/pack tgenv grep miniserve orbstack helm \
parallel lefthook htop tmux duckdb deno bottom starship \
font-fira-code-nerd-font amazon-q zsh-syntax-highlighting zoxide \
ripgrep mpv yq uv pnpm secretive

#brew install --cask miniconda warp
brew install --cask rectangle
# brew install --cask hyper@canary
# brew install --cask wezterm
brew tap redis-stack/redis-stack
brew install redis-stack
brew install --cask iterm2
brew install --cask github
brew install --cask licecap

# Install fzf widget
# See: https://junegunn.github.io/fzf/
$(brew --prefix)/opt/fzf/install
```

### Setup Starship preset
```sh
starship preset pure-preset -o ~/.config/starship.toml
```

### Iterm2

menu -> Install Shell Integration 

### Install QucickLook Plugins

```shell
# https://github.com/sindresorhus/quick-look-plugins
brew install qlcolorcode qlstephen qlmarkdown quicklook-json qlimagesize suspicious-package quicklookase qlvideo
xattr -r ~/Library/QuickLook
xattr -d -r com.apple.quarantine ~/Library/QuickLook
```

## Git Settings

### Set ssh key to github

[GitHub Help](https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

### clone this repository
```shell
ghq get -p nkmr-jp/setup
```

### Set .gitconfig
```ini
# ~/.gitconfig
[include]
    path = ~/ghq/github.com/nkmr-jp/setup/gitconfig
```

### Set git user
```shell
git config --global user.name "username"
git config --global user.email "mailaddress"
```

## Repository Structure

This repository has been refactored to use a modular approach for better maintainability:

```
setup/
├── common/           # Shared configurations for all shells
│   ├── aliases.sh    # Common aliases
│   ├── functions.sh  # Common functions
│   ├── paths.sh      # Common PATH settings
│   └── env_vars.sh   # Common environment variables
├── zsh/              # Zsh-specific configurations
│   ├── core.zsh      # Core Zsh settings
│   ├── keybindings.zsh # Zsh key bindings
│   ├── plugins.zsh   # Zsh plugin settings
│   └── theme.zsh     # Zsh theme settings
├── fish/             # Fish-specific configurations
│   ├── core.fish     # Core Fish settings
│   ├── keybindings.fish # Fish key bindings
│   ├── plugins.fish  # Fish plugin settings
│   └── theme.fish    # Fish theme settings
├── tools/            # Tool-specific configurations
├── install.sh        # Main installation script
├── setup_zsh.sh      # Zsh setup script
├── setup_fish.sh     # Fish setup script
└── setup_git.sh      # Git setup script
```

## Shell Settings

### Automated Installation

The easiest way to set up everything is to use the automated installation script:

```shell
cd ~/ghq/github.com/nkmr-jp/setup
./install.sh
```

This will set up both Zsh configurations, as well as Git settings.

#### Set messages
```shell
# A message that is displayed at random when the shell starts.
echo "hello world!" >> ~/ghq/github.com/nkmr-jp/setup/.messages
echo "shut the fuck up and write some code" >> ~/ghq/github.com/nkmr-jp/setup/.messages
echo "stay hungry stay foolish" >> ~/ghq/github.com/nkmr-jp/setup/.messages
```

### Zsh Settings

#### Manual Zsh Setup
If you prefer to set up Zsh manually:

```shell
cd ~/ghq/github.com/nkmr-jp/setup
./setup_zsh.sh
```

## Anyenv ([anyenv](https://github.com/anyenv/anyenv))

### Install env commands

```sh
anyenv install --init
anyenv install rbenv
anyenv install pyenv
anyenv install goenv
anyenv install nodenv
anyenv install tfenv
exec $SHELL -l
```

### Install programing langages and set global version
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

# rbenv pyenv nodenv jenv ...
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
/usr/libexec/java_home --request
# > Unable to find any JVMs matching version "(null)".
# > No Java runtime present, requesting install.

#
# Download Java installer and install.
#

/usr/libexec/java_home -V
# > Matching Java Virtual Machines (1):
# >     16, x86_64: "Java SE 16"    /Library/Java/JavaVirtualMachines/jdk-16.jdk/Contents/Home

# > /Library/Java/JavaVirtualMachines/jdk-16.jdk/Contents/Home
```

```sh
brew install java
sudo ln -sfn /usr/local/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk

/usr/libexec/java_home -V
# > Matching Java Virtual Machines (2):
# >     16, x86_64: "Java SE 16"    /Library/Java/JavaVirtualMachines/jdk-16.jdk/Contents/Home
# >     15.0.2, x86_64:     "OpenJDK 15.0.2"        /Library/Java/JavaVirtualMachines/openjdk.jdk/Contents/Home

# Add ~/.path.sh
# export PATH="/usr/local/opt/openjdk/bin:$PATH"
```

```sh
brew install temurin
brew install temurin@8

/usr/libexec/java_home -V
# Matching Java Virtual Machines (2):
#     22.0.2 (arm64) "Eclipse Adoptium" - "OpenJDK 22.0.2" /Library/Java/JavaVirtualMachines/temurin-22.jdk/Contents/Home
#     1.8.0_422 (x86_64) "Eclipse Temurin" - "Eclipse Temurin 8" /Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
# /Library/Java/JavaVirtualMachines/temurin-22.jdk/Contents/Home
```

```sh
jenv add (/usr/libexec/java_home -v "22")
jenv add (/usr/libexec/java_home -v "1.8")

jenv global system
jenv versions
# * system (set by /Users/nkmr/.anyenv/envs/jenv/version)
#   1.8
#   1.8.0.422
#   22
#   22.0
#   22.0.2
#   temurin64-1.8.0.422
#   temurin64-22.0.2
```

## Install AWS CLI v2

### Install
[Install and update the AWS CLI version 2 using the macOS command line](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-mac.html#cliv2-mac-install-cmd)

```sh
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
aws --version
#> aws-cli/2.2.34 Python/3.8.8 Darwin/19.6.0 exe/x86_64 prompt/off
```

### Setup
[Access key ID and secret access key](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-creds)
```sh
# Create key https://console.aws.amazon.com/iamv2/home#/users

aws configure
#> AWS Access Key ID [None]: xxxx
#> AWS Secret Access Key [None]: xxxx
#> Default region name [None]: ap-northeast-1
#> Default output format [None]: json

aws iam list-users --output table
#> ---------------------------------------------------------------
#> |                          ListUsers                          |
#> +-------------------------------------------------------------+
#> ||                           Users                           ||
#> |+-------------------+---------------------------------------+|
#> ||  Arn              |  arn:aws:iam::xxxxxxxxxxxx:user/hoge  ||
#> ||  CreateDate       |  2019-05-21T13:05:41+00:00            ||
#> ||  PasswordLastUsed |  2021-09-01T02:07:31+00:00            ||
#> ||  Path             |  /                                    ||
#> ||  UserId           |  XXXXXXXXXXXXXXXXXXXXX                ||
#> ||  UserName         |  hoge                                 ||
#> |+-------------------+---------------------------------------+|
```

## Install Commands for each language
```sh
gem install iStats
# See: https://zenn.dev/azu/articles/ad168118524135
# See: https://socket.dev/blog/pnpm-10-16-adds-new-setting-for-delayed-dependency-updates
pnpm config set minimumReleaseAge=1440 --global
npm config set ignore-scripts true --global
npm install -g @aikidosec/safe-chain
npm install -g fkill-cli
pip install jupyterlab notebook voila iplantuml edge-tts
```

## Install Commands from Binary

```sh
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b (go env GOPATH)/bin v1.46.2
```

```sh
mkdir -p ~/src ~/src/bin
cd ~/src
curl -OL https://github.com/cheat/cheat/releases/download/4.2.0/cheat-darwin-amd64.gz
gzip -d cheat-darwin-amd64.gz
mv cheat-darwin-amd64 ./bin/cheat
chmod 755 ./bin/cheat
```

```sh
mkdir -p ~/src ~/src/bin
cd ~/src
curl -OL https://github.com/buildkite/terminal-to-html/releases/download/v3.6.1/terminal-to-html-3.6.1-darwin-amd64.gz
gzip -d terminal-to-html-3.6.1-darwin-amd64.gz
mv terminal-to-html-3.6.1-darwin-amd64 ./bin/terminal-to-html
chmod 755 ./bin/terminal-to-html
```

```sh
curl -sS https://starship.rs/install.sh | sh
```

## Settings

### pack

See: https://buildpacks.io/docs/tools/pack/

```sh
source (pack completion --shell fish)
```

### Google Cloud SDK

See: [クイックスタート: Cloud SDK スタートガイド  |  Cloud SDK のドキュメント  |  Google Cloud](https://cloud.google.com/sdk/docs/quickstart?hl=ja)

### tig

See: https://qiita.com/numanomanu/items/513d62fb4a7921880085

```sh
# ~/.tigrc
bind main    B !git rebase -i %(commit)
bind diff    B !git rebase -i %(commit)
```
