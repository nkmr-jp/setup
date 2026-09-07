# Setup

<!-- TOC -->
- [Setup](#setup)
  - [Shared and Local Settings](#shared-and-local-settings)
  - [Homebrew Settings (homebrew)](#homebrew-settings-homebrew)
    - [Install homebrew](#install-homebrew)
    - [Install commands](#install-commands)
    - [Setup Starship preset](#setup-starship-preset)
    - [Iterm2](#iterm2)
    - [Terminal app configs](#terminal-app-configs)
    - [Install QucickLook Plugins](#install-qucicklook-plugins)
  - [Git Settings](#git-settings)
    - [Set ssh key to github](#set-ssh-key-to-github)
    - [Clone this repository](#clone-this-repository)
    - [Set .gitconfig](#set-gitconfig)
    - [Set git user](#set-git-user)
    - [Sign Commits Only in Public Repositories](#sign-commits-only-in-public-repositories)
    - [Set gtr](#set-gtr)
    - [opg - Open GitHub repository in browser](#opg---open-github-repository-in-browser)
  - [Repository Structure](#repository-structure)
  - [Claude Code Plugins](#claude-code-plugins)
  - [Codex Plugins](#codex-plugins)
  - [Antigravity (AGY) Plugins](#antigravity-agy-plugins)
  - [Zsh Configuration](#zsh-configuration)
    - [Optional: Set greeting messages](#optional-set-greeting-messages)
    - [Startup Cache](#startup-cache)
  - [Anyenv (anyenv)](#anyenv-anyenv)
    - [Install env commands](#install-env-commands)
    - [Install programing langages and set global version](#install-programing-langages-and-set-global-version)
    - [To get the latest version](#to-get-the-latest-version)
  - [Install Rust](#install-rust)
  - [Install Java](#install-java)
  - [Install AWS CLI v2](#install-aws-cli-v2)
    - [Install](#install)
    - [Setup](#setup-1)
  - [Install Commands for each language](#install-commands-for-each-language)
  - [Install Commands from Binary](#install-commands-from-binary)
  - [Settings](#settings)
    - [yazi](#yazi)
    - [pack](#pack)
    - [Google Cloud SDK](#google-cloud-sdk)
    - [tig](#tig)
    - [obsidian](#obsidian)
<!-- TOC -->

## Shared and Local Settings

This repository contains shared macOS settings. Agent-specific settings and personal jobs are managed separately.
Shell portability changes are deferred to preserve existing terminal behavior.
The current `.zshrc` loads `~/ghq/github.com/nkmr-jp/setup`.

Install Homebrew and ghq using the steps below. After configuring GitHub SSH access,
follow [Clone this repository](#clone-this-repository) to fetch the repository with ghq.

The examples use the default ghq checkout. Include its Git settings with
`git config --global --add include.path "$HOME/ghq/github.com/nkmr-jp/setup/gitconfig"`.
Git configuration files do not expand shell variables such as `${SETUP_DIR}`.

Put machine-specific shell overrides in `~/.zshrc.local`.
Do not add personal settings or credentials to this public repository.

Shell initialization, PATH, aliases, and exit hooks retain their existing behavior.
Automatic `make login`, GUI PATH propagation, PromptLine updates, and AGY aliases are unchanged.
Support for missing tools and separation of personal shell settings will be considered separately.


## Homebrew Settings ([homebrew](https://brew.sh/index_ja))

### Install homebrew

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Install commands

```shell
brew install \
ghq peco gh fzf trash-cli terminal-notifier  \
jq tig anyenv fx translate-shell tree bat gitmoji coreutils  \
procs fd tesseract-lang google-cloud-sdk pre-commit \
tflint buildpacks/tap/pack grep helm \
parallel lefthook htop tmux duckdb deno bottom starship \
font-fira-code-nerd-font zsh-syntax-highlighting zoxide \
ripgrep mpv yq pnpm secretive sleepwatcher aqua gitleaks git-delta \
lazygit

#brew install --cask miniconda warp
brew install --cask rectangle
# brew install --cask hyper@canary
# brew install --cask wezterm
brew tap redis-stack/redis-stack
brew install redis-stack
brew install --cask iterm2
brew install --cask github
brew install --cask licecap
brew install orbstack amazon-q miniserve
brew install --cask ghostty
brew tap manaflow-ai/cmux
brew install --cask cmux
sudo ln -sf "/Applications/cmux.app/Contents/Resources/bin/cmux" /usr/local/bin/cmux

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

### Terminal app configs

Ghostty, iTerm2 scripts, cmux, and Orca settings live in this repository. See their READMEs for details and installation:

- [ghostty/README.md](ghostty/README.md)
- [cmux/README.md](cmux/README.md) — User settings, sidebar integration, and plugins are managed in setup.
- [orca/README.md](orca/README.md)
- [iterm2/README.md](iterm2/README.md)

```sh
mkdir -p ~/.config/ghostty ~/.config/cmux ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch
ln -sf "$HOME/ghq/github.com/nkmr-jp/setup/ghostty/config" ~/.config/ghostty/config
./cmux/link.sh --install # Run from the setup repository root
ln -sf "$HOME/ghq/github.com/nkmr-jp/setup/iterm2/PaneCount.py" ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch/PaneCount.py
```

For Orca, symlink the **entire directory**: atomic writes silently replace individual file symlinks.
If `~/.orca` already exists, `ln -s` creates a link **inside** it.
Follow [orca/README.md](orca/README.md) for the backup and replacement procedure.

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

### Clone this repository
```shell
ghq get -p nkmr-jp/setup
cd ~/ghq/github.com/nkmr-jp/setup
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

### Sign Commits Only in Public Repositories

The signing key uses the 1Password SSH agent (`op-ssh-sign`), which requests biometric authentication for each signature.
To avoid blocking unattended agent commits, **signing is disabled by default and enabled only for public repositories**.

```ini
# ~/.gitconfig (order matters: later settings take precedence)
[commit]
    gpgsign = false                      # Default: no signing
[include]
    path = ~/.gitconfig-signing-includes # Enable signing only for public repositories
```

`~/.gitconfig-signing-includes` is generated. It lists `includeIf "gitdir:..."` entries for all public
GitHub repositories and loads `gitconfig-signing`.
**Regenerate it whenever repository visibility changes**: stale public entries keep signing enabled after a repository becomes private.
Repositories that have not been cloned are included, so cloning alone does not require regeneration.

```sh
bin/gen-git-signing-config.sh          # Default owner: the authenticated gh user
```

Check the effective setting; `--show-origin` identifies the configuration file:

```sh
git -C <repo> config --show-origin --get commit.gpgsign
```

- Worktrees (`<repo>-wt-<branch>`) use the same rules because their `GIT_DIR` points inside the main checkout's `.git`.
- Clones from other organizations are unsigned. Enable signing with
  `git config commit.gpgsign true` in a repository when contributing to open source.

### Set gtr
```sh
ghq get coderabbitai/git-worktree-runner
ln -s "$(pwd)/bin/git-gtr" ~/src/bin/git-gtr
```

### opg - Open GitHub repository in browser

`bin/opg` opens the origin GitHub repository in a browser. For branches other than `main` or `master`, it opens that branch's tree page.

```sh
# Open the repository in the current directory
opg

# Open the repository at the specified path
opg "$HOME/ghq/github.com/nkmr-jp/setup"
```

## Repository Structure

This repository uses a modular approach for Zsh configuration:

```
setup/
├── .zshrc            # Main Zsh configuration (symlinked to ~/.zshrc)
├── zsh/              # Modular Zsh configurations
│   ├── init.zsh      # Entry point; controls module loading order
│   ├── env.zsh       # Environment variables and PATH
│   ├── cache.zsh     # Cache helpers for expensive initialization
│   ├── completion.zsh # Completions, plugins, and prompt
│   ├── aliases.zsh   # Shell aliases
│   ├── functions.zsh # Utility functions
│   ├── keybindings.zsh # Key bindings
│   ├── gwt.zsh       # Git worktree utilities
│   ├── ghu.zsh       # ghq + GitHub utilities
│   ├── gh.zsh        # GitHub CLI
│   ├── github.zsh    # GitHub integration
│   ├── gcloud.zsh    # Google Cloud SDK
│   ├── anyenv.zsh    # Cached anyenv initialization
│   ├── goenv.zsh     # GOROOT / GOPATH resolution
│   ├── prompt-line.zsh # Background PromptLine cache refresh
│   ├── ai.zsh        # AI tools
│   └── iterm2.zsh    # iTerm2 shell integration
├── tools/            # Tool-specific configurations
├── bin/              # Local executables (symlinked into ~/bin)
├── gitconfig         # Git configuration
└── gitconfig-signing # Signing settings for public repositories (loaded by includeIf)
```

## Claude Code Plugins

Register this repository as a marketplace and install the plugins you need.
Run these commands from `~/ghq/github.com/nkmr-jp/setup`.

```sh
claude plugin marketplace add . --scope user
claude plugin install cmux@setup --scope user
claude plugin install session-monitor@setup --scope user
```

- `cmux`: Workspace, pane, and notification commands, with hooks that synchronize Claude Code status to the sidebar.
- `session-monitor`: Hooks that aggregate Claude Code session states for display in xbar.

`--scope user` installs plugins for your user account. Install only the plugins you need.
See [cmux](plugins/cmux/README.md) and [session-monitor](plugins/session-monitor/README.md) for prerequisites and integration settings.

## Codex Plugins

Register this repository's marketplace and install the plugins you need:

```sh
codex plugin marketplace add "$HOME/ghq/github.com/nkmr-jp/setup"
codex plugin add cmux@setup
codex plugin add session-monitor@setup
```

- `cmux`: Skills for cmux workspaces, panes, notifications, and browsers, plus status synchronization hooks
- `session-monitor`: Hooks that aggregate Codex / Claude Code session states for display in xbar

Start a new thread after installation to load the plugins. See [cmux](plugins/cmux/README.md) and [session-monitor](plugins/session-monitor/README.md) for prerequisites and Claude Code installation instructions.

## Antigravity (AGY) Plugins

For Google Antigravity (AGY CLI / IDE), use the AGY CLI native importer:

```sh
agy plugin install "$HOME/ghq/github.com/nkmr-jp/setup/plugins/cmux"
agy plugin install "$HOME/ghq/github.com/nkmr-jp/setup/plugins/session-monitor"
```

## Zsh Configuration
Get plugin
```sh
ghq get -p Aloxaf/fzf-tab
```

Create a symlink from this repository's `.zshrc` to your home directory:

```shell
ln -s "$HOME/ghq/github.com/nkmr-jp/setup/.zshrc" ~/.zshrc
source ~/.zshrc
```

### Optional: Set greeting messages
```shell
# A message that is displayed at random when the shell starts.
echo "hello world!" >> "$HOME/ghq/github.com/nkmr-jp/setup/.messages"
echo "shut the fuck up and write some code" >> "$HOME/ghq/github.com/nkmr-jp/setup/.messages"
echo "stay hungry stay foolish" >> "$HOME/ghq/github.com/nkmr-jp/setup/.messages"
```

### Startup Cache

Spawning processes for `anyenv init`, `uv` / `uvx` completions, and `ghq root` on every startup
adds nearly a second. Their output is stable until tools change, so it is cached in
`~/.cache/zsh-init/` and regenerated only when dependencies are newer.
The implementation is in `zsh/cache.zsh`.

If cached output appears stale after updating a tool, clear the cache:

```sh
zsh-cache-clear   # Regenerated on the next shell startup
```

Generated `#compdef` scripts are stored in `~/.cache/zsh-init/completions/` and loaded lazily
by `compinit`, rather than evaluated at startup. A full `compinit` runs only when the dump is
more than 24 hours old; otherwise `-C` skips the checks.

**Shims or completions may be missing immediately after installing new executables**:

- Run `pyenv rehash` or its equivalent explicitly after `pip install`, `gem install`, or `npm i -g`.
  Startup rehashing was removed because stale locks could block every shell startup for 60 seconds.
- If a new tool's completions are unavailable, run `rm ~/.zcompdump` and start a new shell.

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
# * system (set by $HOME/.anyenv/envs/jenv/version)
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

```aiignore
curl -LsSf https://astral.sh/uv/install.sh | sh
```

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

### yazi

```sh
mkdir -p ~/.config/yazi
ln -s "$HOME/ghq/github.com/nkmr-jp/setup/yazi/yazi.toml" ~/.config/yazi/yazi.toml
```

### pack

See: https://buildpacks.io/docs/tools/pack/

### Google Cloud SDK

See: [Quickstart: Get Started with the Cloud SDK | Google Cloud](https://cloud.google.com/sdk/docs/quickstart?hl=ja)

### tig

See: https://qiita.com/numanomanu/items/513d62fb4a7921880085

```sh
# ~/.tigrc
bind main    B !git rebase -i %(commit)
bind diff    B !git rebase -i %(commit)
```

### obsidian
```sh
ln -s "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/vault" "$HOME/vault"
```

`iterm-run <command>` remains defined in `zsh/init.zsh`.

Git retains the existing `gitconfig`; `~/.config/setup/gitconfig` is not loaded.
