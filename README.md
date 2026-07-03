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
  * [Zsh Configuration](#zsh-configuration)
    * [Optional: Set greeting messages](#optional-set-greeting-messages)
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
    * [yazi](#yazi)
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

ghostty / iTerm2 Scripts / cmux の設定は本リポジトリ配下で管理している。詳細とインストール手順は各 README を参照:

- [ghostty/README.md](ghostty/README.md)
- [cmux/README.md](cmux/README.md)
- [iterm2/README.md](iterm2/README.md)

```sh
mkdir -p ~/.config/ghostty ~/.config/cmux ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch
ln -sf ~/ghq/github.com/nkmr-jp/setup/ghostty/config ~/.config/ghostty/config
ln -sf ~/ghq/github.com/nkmr-jp/setup/cmux/cmux.json ~/.config/cmux/cmux.json
ln -sf ~/ghq/github.com/nkmr-jp/setup/iterm2/PaneCount.py ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch/PaneCount.py
```

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

### Set gtr
```sh
ghq get coderabbitai/git-worktree-runner
ln -s "$(pwd)/bin/git-gtr" ~/src/bin/git-gtr
```

### opg - Open GitHub repository in browser

`bin/opg` は origin リモートの GitHub リポジトリをブラウザで開く。現在のブランチが `main` / `master` 以外なら、そのブランチの tree ページを開く。

```sh
# カレントディレクトリのリポジトリを開く
opg

# 指定したディレクトリのリポジトリを開く
opg ~/ghq/github.com/nkmr-jp/setup
```

## Repository Structure

This repository uses a modular approach for Zsh configuration:

```
setup/
├── .zshrc            # Main Zsh configuration (symlinked to ~/.zshrc)
├── zsh/              # Modular Zsh configurations
│   ├── core.zsh      # Core Zsh settings and sourcing
│   ├── env_vars.zsh  # Environment variables and PATH
│   ├── aliases.zsh   # Shell aliases
│   ├── functions.zsh # Utility functions
│   ├── gwt.zsh       # Git worktree utilities
│   ├── keybindings.zsh # Key bindings
│   ├── plugins.zsh   # Plugin settings
│   └── theme.zsh     # Theme settings
├── tools/            # Tool-specific configurations
├── bin/              # Local executables (symlinked into ~/bin)
├── launchd/          # macOS LaunchAgent plists (symlinked into ~/Library/LaunchAgents)
└── gitconfig         # Git configuration
```

## Zsh Configuration
Get plugin
```sh
ghq get -p Aloxaf/fzf-tab
```

Create a symlink from this repository's `.zshrc` to your home directory:

```shell
ln -s ~/ghq/github.com/nkmr-jp/setup/.zshrc ~/.zshrc
source ~/.zshrc
```

### Optional: Set greeting messages
```shell
# A message that is displayed at random when the shell starts.
echo "hello world!" >> ~/ghq/github.com/nkmr-jp/setup/.messages
echo "shut the fuck up and write some code" >> ~/ghq/github.com/nkmr-jp/setup/.messages
echo "stay hungry stay foolish" >> ~/ghq/github.com/nkmr-jp/setup/.messages
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
ln -s ~/ghq/github.com/nkmr-jp/setup/yazi/yazi.toml ~/.config/yazi/yazi.toml
```

### pack

See: https://buildpacks.io/docs/tools/pack/

### Google Cloud SDK

See: [クイックスタート: Cloud SDK スタートガイド  |  Cloud SDK のドキュメント  |  Google Cloud](https://cloud.google.com/sdk/docs/quickstart?hl=ja)

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

## LaunchAgents

macOS 上で定期実行される launchd ジョブ。plist は `launchd/` に置き、
`~/Library/LaunchAgents/` から symlink で参照してリポジトリ更新を即反映できるようにする。

### check-claude-orphans

`prompt-line-wt-*` などの worktree から起動した `claude` セッションを終了/削除したあと、
`claude daemon` / `bg-spare` プロセスが launchd に養子化されたまま CPU 100% で
busy-loop してしまうケースがある (v2.1.152 で実例を確認)。
この LaunchAgent は **30 分ごとに孤児を検出し、暴走中のものだけを自動 kill** する。

**判定ロジック** (`bin/check-claude-orphans.sh`):
- 対象: `PPID=1` (launchd 養子化) かつ comm が `/Users/nkmr/.local/{share/claude,bin/claude}` のプロセス (デスクトップ `Claude.app` は除外)
- 「暴走中」: 累積 CPU 時間 ÷ 経過時間 ≥ 20%

#### Install

```sh
# 1. ~/bin と ~/Library/LaunchAgents から symlink で参照
ln -sf ~/ghq/github.com/nkmr-jp/setup/bin/check-claude-orphans.sh ~/bin/check-claude-orphans.sh
ln -sf ~/ghq/github.com/nkmr-jp/setup/launchd/com.nkmr.check-claude-orphans.plist ~/Library/LaunchAgents/com.nkmr.check-claude-orphans.plist

# 2. launchd に登録 (30 分ごとに --kill モードで実行される)
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.nkmr.check-claude-orphans.plist

# 3. 動作確認 (即座に 1 回起動)
launchctl kickstart gui/$(id -u)/com.nkmr.check-claude-orphans
tail ~/Library/Logs/check-claude-orphans.log
```

#### Usage (手動実行)

```sh
check-claude-orphans.sh             # dry-run: 暴走中の孤児を表示するだけ
check-claude-orphans.sh --kill      # SIGTERM → 3 秒後に残ってれば SIGKILL
check-claude-orphans.sh --list-all  # idle 含む全孤児を表示 (棚卸し用)
```

#### Uninstall / 停止

```sh
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.nkmr.check-claude-orphans.plist
rm ~/Library/LaunchAgents/com.nkmr.check-claude-orphans.plist
rm ~/bin/check-claude-orphans.sh
```

#### ログ

`~/Library/Logs/check-claude-orphans.log` に追記される。
孤児が居ない場合: `no orphan claude processes (PPID=1)`。

#### 注意

- idle 化した孤児 (過去に焼いたが現在 0% のもの) は自動 kill 対象外。
  気になったら `--list-all` で確認して手で `kill` する。
- 30 分間隔なので検知最大遅延は 30 分。
  もっと早く反応させたい場合は `launchd/com.nkmr.check-claude-orphans.plist` の `StartInterval` を縮める。

### claude-stall-monitor

Claude Code で `The model's tool call could not be parsed (retry also failed).` により
ターンが異常終了すると、**Stop / Notification / StopFailure いずれのフックも発火せず、何の通知も
来ない**。セッション JSONL にも parse 失敗の専用レコードは残らない（assistant の試行レコードだけ）。
そのため「セッションが止まっていること」に気づけない。この LaunchAgent は **30 秒ごとに各セッションを
監視し、parse 失敗による無通知停止を検知して macOS 通知** を出す。

**仕組み（ack ハートビート方式）** (`bin/claude-stall-monitor.sh`):
- 各フック（`PreToolUse`/`PostToolUse`/`UserPromptSubmit`/`SessionStart`/`Stop`/`StopFailure`/`Notification`）が
  `ack` モードで `~/.claude/monitor/<session_id>.ack` に現在 epoch を書く（= 直近の JSONL 書き込みの後に
  何らかのフックが発火した記録）。`~/.claude/settings.json` の各イベントに ack コマンドを 1 つ追記する。
- watcher は各セッション JSONL を走査し、`idle(now - mtime) >= 45s` かつ `ack < mtime`
  （= JSONL は進んだのにその後どのフックも発火していない）のものを「異常停止」と判定して通知する。
- 誤検知しない: 正常完了→`Stop`、API エラー→`StopFailure`、権限待ち/idle→`Notification`、
  長時間ツール実行中→`PreToolUse` がそれぞれ ack を書く（ack ≥ mtime）ため鳴らない。
  parse 失敗だけがどのフックも発火しない＝唯一鳴るケース。
- 通知は `terminal-notifier`（無ければ `osascript`）。停止 1 回につき 1 通知（活動再開で解除）。

#### Install

```sh
# 1. ~/bin と ~/Library/LaunchAgents から symlink で参照
ln -sf ~/ghq/github.com/nkmr-jp/setup/bin/claude-stall-monitor.sh ~/bin/claude-stall-monitor.sh
ln -sf ~/ghq/github.com/nkmr-jp/setup/launchd/com.nkmr.claude-stall-monitor.plist ~/Library/LaunchAgents/com.nkmr.claude-stall-monitor.plist

# 2. ~/.claude/settings.json の各イベントに ack コマンドを追記（既存フックはそのまま別グループで追加）
#    対象: PreToolUse / PostToolUse / UserPromptSubmit / SessionStart / Stop / StopFailure / Notification
#    例: { "hooks": [ { "type": "command", "command": "/Users/nkmr/bin/claude-stall-monitor.sh ack" } ] }

# 3. launchd に登録 (30 秒ごとに --watch モードで実行される)
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.nkmr.claude-stall-monitor.plist

# 4. 動作確認 (即座に 1 回起動)
launchctl kickstart gui/$(id -u)/com.nkmr.claude-stall-monitor
tail ~/Library/Logs/claude-stall-monitor.log
```

#### Usage (手動実行)

```sh
claude-stall-monitor.sh            # watcher（既定）: 異常停止を検知して通知
claude-stall-monitor.sh ack        # フックから: stdin JSON の session_id で ack を書く
```

#### Uninstall / 停止

```sh
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.nkmr.claude-stall-monitor.plist
rm ~/Library/LaunchAgents/com.nkmr.claude-stall-monitor.plist
rm ~/bin/claude-stall-monitor.sh
# settings.json から ack コマンドの行を削除する
```

#### ログ

`~/Library/Logs/claude-stall-monitor.log` に追記される（`STALL sid=... idle=...` 形式）。
異常停止が無ければ無出力。

#### 注意

- 検知最大遅延は `StartInterval`(30s) + `IDLE_THRESHOLD`(45s)。早めたい場合は plist の `StartInterval` と
  スクリプトの `IDLE_THRESHOLD` を縮める。
- ack が無い旧セッション（導入前）は基準が無いため判定しない（誤検知防止）。

### git-auto-backup

リポジトリを 30 分毎に自動バックアップ（`pull --rebase → add -A → commit → push`）する汎用ジョブ。
`bin/git-auto-backup.sh`（vault と同型）と launchd `com.nkmr.issues-autobackup.plist` で構成する。

`--llm` を付けると Claude でコミットメッセージを生成するが、その Claude 固有部（`claude-auto`）は
**ccdash リポジトリへ移設済み**（`~/ghq/github.com/nkmr-jp/ccdash/claude-auto/`）。
`git-auto-backup.sh --llm` は生成器 `claude-commit-msg.sh` を PATH（`~/bin`）から解決して呼ぶため、
claude-auto の置き場所に依存しない。トークン未登録・生成失敗時は `auto:<日時>` に自動降格し、コミットは必ず成功する。

> 現在の `issues-autobackup` ジョブは `--llm` を付けず固定メッセージ（`auto:<日時>`）で稼働中。

```sh
# 汎用バックアップの symlink 配置（~/bin と ~/Library/LaunchAgents から参照）
ln -sf ~/ghq/github.com/nkmr-jp/setup/bin/git-auto-backup.sh ~/bin/git-auto-backup.sh
ln -sf ~/ghq/github.com/nkmr-jp/setup/launchd/com.nkmr.issues-autobackup.plist ~/Library/LaunchAgents/com.nkmr.issues-autobackup.plist

# launchd 有効化（準備完了後に手動で）
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.nkmr.issues-autobackup.plist

# 手動実行 / ログ
git-auto-backup.sh ~/ghq/github.com/nkmr-jp/issues --llm
tail ~/Library/Logs/issues-autobackup.log
```

> Claude 固有の自動化基盤 `claude-auto`（コミットメッセージ生成・セッション要約・keychain OAuth・
> `~/.claude-auto` 隔離）は ccdash へ移設した。セットアップ（`claude-auto/install.sh` / `setup-token` 発行）と
> 機能B（日次セッション要約）の詳細は ccdash の `claude-auto/README.md` を参照（移設の経緯は ccdash#33）。

