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
  * [Codex Plugins](#codex-plugins)
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

ghostty / iTerm2 Scripts / cmux / Orca の設定は本リポジトリ配下で管理している。詳細とインストール手順は各 README を参照:

- [ghostty/README.md](ghostty/README.md)
- [cmux/README.md](cmux/README.md)
- [orca/README.md](orca/README.md)
- [iterm2/README.md](iterm2/README.md)

```sh
mkdir -p ~/.config/ghostty ~/.config/cmux ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch
ln -sf ~/ghq/github.com/nkmr-jp/setup/ghostty/config ~/.config/ghostty/config
ln -sf ~/ghq/github.com/nkmr-jp/setup/cmux/cmux.json ~/.config/cmux/cmux.json
ln -sf ~/ghq/github.com/nkmr-jp/setup/iterm2/PaneCount.py ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch/PaneCount.py
```

Orca だけは**ディレクトリごと** symlink する（ファイル単体の symlink は Orca 側の
atomic write で無言で外れるため）。既存の `~/.orca` が残っていると
`ln -s` がその**中に**リンクを作ってしまうので、退避と削除を含む手順は
[orca/README.md](orca/README.md) を参照する。

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

### コミット署名は公開リポジトリのみ

署名鍵は 1Password の SSH agent（`op-ssh-sign`）にあり、署名のたびに生体認証を求める。
エージェントの無人コミットがそこで止まるため、**既定は署名なし・公開リポジトリだけ署名あり**にしている。

```ini
# ~/.gitconfig（この順序に意味がある。後に書いたものが勝つ）
[commit]
    gpgsign = false                      # 既定: 署名なし
[include]
    path = ~/.gitconfig-signing-includes # public リポジトリだけ署名ONに戻す
[includeIf "gitdir:~/ghq/github.com/nkmr-jp/prompt-line-plugins/"]
    path = ~/.gitconfig-scheduler        # agent-scheduler 対象は public でも署名OFF
```

`~/.gitconfig-signing-includes` は生成物。GitHub 上で public なリポジトリすべての
`includeIf "gitdir:..."` を並べ、`gitconfig-signing` を読ませる。
**リポジトリの公開/非公開を切り替えたら再実行する**（public→private のまま放置すると古いエントリが残って署名され続ける）。
未 clone のリポジトリも含めて生成するので、clone しただけなら再実行不要。

```sh
bin/gen-git-signing-config.sh          # 既定 owner: nkmr-jp
```

確認方法（`--show-origin` でどのファイルが効いたか分かる）:

```sh
git -C <repo> config --show-origin --get commit.gpgsign
```

- worktree（`<repo>-wt-<branch>`）は `GIT_DIR` が本体の `.git` 配下を指すため、本体と同じ判定になる。
- 他 org の clone は署名なし。OSS へコントリビュートするときはそのリポジトリで
  `git config commit.gpgsign true` を設定する。

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
│   ├── init.zsh      # 起点。他の設定を読む順序を決める
│   ├── env.zsh       # 環境変数と PATH
│   ├── cache.zsh     # 起動時の重い初期化のキャッシュヘルパー
│   ├── completion.zsh # 補完・プラグイン・プロンプト
│   ├── aliases.zsh   # Shell aliases
│   ├── functions.zsh # Utility functions
│   ├── keybindings.zsh # Key bindings
│   ├── gwt.zsh       # Git worktree utilities
│   ├── ghu.zsh       # ghq + GitHub ユーティリティ
│   ├── gh.zsh        # GitHub CLI
│   ├── github.zsh    # GitHub 関連
│   ├── gcloud.zsh    # Google Cloud SDK
│   ├── anyenv.zsh    # anyenv init のキャッシュ生成
│   ├── goenv.zsh     # GOROOT / GOPATH の解決
│   ├── prompt-line.zsh # PromptLine 用キャッシュの背景更新
│   ├── ai.zsh        # AI ツール
│   └── iterm2.zsh    # iTerm2 シェル統合
├── tools/            # Tool-specific configurations
├── bin/              # Local executables (symlinked into ~/bin)
├── launchd/          # macOS LaunchAgent plists (symlinked into ~/Library/LaunchAgents)
├── gitconfig         # Git configuration
└── gitconfig-signing # 公開リポジトリ用の署名ON設定（includeIf から読まれる）
```

## Codex Plugins

このリポジトリの marketplace を登録し、必要なプラグインをインストールする:

```sh
codex plugin marketplace add ~/ghq/github.com/nkmr-jp/setup
codex plugin add cmux@setup
codex plugin add session-monitor@setup
```

- `cmux`: cmux のワークスペース、ペイン、通知、ブラウザなどを操作するスキルと状態同期 hooks
- `session-monitor`: Codex / Claude Code のセッション状態を集約し、xbar に表示する hooks

インストール後は、新しいスレッドを開始してプラグインを読み込む。個別の前提条件や Claude Code へのインストール方法は、[cmux](plugins/cmux/README.md) と [session-monitor](plugins/session-monitor/README.md) を参照。

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

### 起動時のキャッシュ

`anyenv init` の出力・`uv` / `uvx` の補完・`ghq root` などは、起動のたびに別プロセスを
起こしていると合計で 1 秒近くかかる。値はツールを更新しない限り変わらないので、
`~/.cache/zsh-init/` にキャッシュして依存ファイルが新しくなったときだけ作り直している
（実装は `zsh/cache.zsh`）。

ツールを更新して古い内容が残っていると感じたら、キャッシュを捨てる:

```sh
zsh-cache-clear   # 次のシェル起動で作り直される
```

補完については、生成した `#compdef` スクリプトを `~/.cache/zsh-init/completions/` に置き、
`compinit` の遅延ロードに任せている（起動時に `eval` しない）。`compinit` 自体は
dump が 24 時間より古いときだけフル実行し、それ以外は `-C`（チェック省略）で済ませる。

**新しい実行ファイルを入れた直後は shim / 補完がまだ無い**ことがある:

- `pip install` / `gem install` / `npm i -g` の後は `pyenv rehash` などを明示的に実行する
  （起動時の rehash は廃止済み。ロック残留で全シェル起動が 60 秒ブロックする事故を防ぐため）
- 新しいツールの補完が効かないときは `rm ~/.zcompdump` して起動し直す

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

### check-config-symlinks

リポジトリ管理の設定ファイルの **symlink が外れていないか**を 6 時間ごとに検査する。

設定を「リポジトリに実体を置いてホームから symlink」で管理していると、アプリが
**atomic write（`<path>.tmp` に書いて `rename`）で書き戻したときに symlink が実体ファイルに
置き換わる**。以後リポジトリ側の編集は無言で効かなくなり、エラーも警告も出ない。
実例: `~/.claude/settings.json` が `claude doctor` / `/config` に置換され、
**2026-06-25〜08-16 の約 7 週間、乖離に気づかなかった**（詳細は
[docs/agent-knowledge.md](https://github.com/nkmr-jp/claude/blob/main/docs/agent-knowledge.md)）。
アプリ側の書き方は変えられない＝**予防はできない**ので、代わりに検知する。

**判定** (`bin/check-config-symlinks.sh`):

| 状態 | 意味 | 通知 |
| --- | --- | --- |
| `OK` | 期待どおりのリンク | — |
| `DETACHED` | ホーム側が symlink でなくなっている（本命の壊れ方。中身が乖離しているかも表示） | する |
| `BROKEN` | リンク先が消えている | する |
| `WRONG` | 別のリンク先を向いている | する |
| `NOLINK` | ホーム側にリンクが無い。リポジトリ側には実体がある（＝管理しているつもりが効いていない） | する |
| `PENDING` | ホーム側が実体で、リポジトリ側に実体が無い（まだ管理下に入れていない） | しない |
| `MISSING` | どちらにも実体が無い | しない |

**対象は「ghq 配下のリポジトリを指しているホーム配下の symlink 全部」**。種別で絞らない
（`bin/` のスクリプトも launchd の plist も入れる）。「アプリが書き戻すものだけ」のように
**判断が要る絞り方はしない——判断が入る時点で漏れる**。実際その方針では
`~/.codex/AGENTS.md`・yazi・herdr が抜け、さらに **`~/.prompt-line` が抜けていたために
実際の事故（別セッションの検証スクリプトが誤ってリンクを削除し、以後アプリの書き込みが
リポジトリに届かなくなっていた）を検知できなかった**。

管理対象を増やすときは手で探さず `--suggest` を使う（ホーム配下を走査して、リポジトリを
指しているのに `ENTRIES` に無い symlink を、そのまま貼れる形で出す）。

**自動復旧はしない**。ホーム側とリポジトリ側のどちらが「現行」かは状況次第で、自動で倒すと
編集を失うため、`diff` してから手で直す。**直し方は項目ごとに出力される**（対象がディレクトリなら
`cp -R` と `rm -rf` + `ln -s`。ディレクトリに `ln -sfn` を使うと exit 0 のまま中に入れ子リンクが
できて直ったように見えるため、種別で出し分けている）。

通知は**問題の顔ぶれが前回と変わったとき**、および**顔ぶれが同じでも前回通知から
`RENOTIFY_DAYS`（既定 7 日）経過したとき**に出す。毎回鳴らすと無視されるようになるが、
一度きりにすると通知を見逃したまま永久に黙る（＝7 週間気づかなかった事故の再来）ため。

#### Install

```sh
# 1. ~/bin と ~/Library/LaunchAgents から symlink で参照
ln -sf ~/ghq/github.com/nkmr-jp/setup/bin/check-config-symlinks.sh ~/bin/check-config-symlinks.sh
ln -sf ~/ghq/github.com/nkmr-jp/setup/launchd/com.nkmr.check-config-symlinks.plist ~/Library/LaunchAgents/com.nkmr.check-config-symlinks.plist

# 2. launchd に登録（6 時間ごと・ロード時にも 1 回実行）
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.nkmr.check-config-symlinks.plist

# 3. 動作確認
launchctl kickstart gui/$(id -u)/com.nkmr.check-config-symlinks
tail ~/Library/Logs/check-config-symlinks.log
```

#### Usage（手動実行）

```sh
check-config-symlinks.sh              # 壊れている項目だけ表示。あれば通知して exit 1
check-config-symlinks.sh --list       # 全項目を表示するだけ（通知も状態更新もしない）
check-config-symlinks.sh --suggest    # 管理対象に入っていない repo 向け symlink を探す
check-config-symlinks.sh --no-notify  # 通知しない（状態も更新しない）
check-config-symlinks.sh --help       # 使い方
```

`--list` / `--no-notify` は**状態ファイルを書かない**。書いてしまうと、手で 1 回眺めただけで
定期実行が「前回と同じ＝通知済み」と誤認して黙る（実際にその不具合を踏んだ）。

対象リンクはスクリプト冒頭の `ENTRIES` に宣言的に書いてある。管理するリンクを増やしたら
ここに 1 行足す（テストは `tests/check-config-symlinks.bats`）。

#### Uninstall / 停止

```sh
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.nkmr.check-config-symlinks.plist
rm ~/Library/LaunchAgents/com.nkmr.check-config-symlinks.plist
rm ~/bin/check-config-symlinks.sh
```

#### ログ・状態

- ログ: `~/Library/Logs/check-config-symlinks.log` に追記される。
  問題が無い場合: `OK: 管理対象 N 件に外れているリンクは無い`。
- 状態: `~/Library/Application Support/check-config-symlinks/state`（前回通知した時刻と
  問題の顔ぶれ）。消しても次の実行で作り直される（消すと次回必ず鳴る）。

#### 注意

- **検知だけで復旧はしない**。通知が来たら `--list` で全体を見てから手で直す。
- 6 時間間隔なので検知最大遅延は 6 時間。急ぐなら plist の `StartInterval` を縮める。
- **`~/.orca` は `setup/orca/` をマージした直後、Setup を実行するまで `DETACHED` として鳴る**
  （[orca/README.md](orca/README.md) の Setup を実行すれば `OK` になる）。マージしたら間を
  空けずに移行する。

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
