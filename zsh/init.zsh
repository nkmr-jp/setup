# Zsh initialization and core settings

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY        # Share history between sessions
setopt HIST_IGNORE_SPACE    # Don't record commands starting with space
setopt HIST_IGNORE_DUPS     # Don't record duplicated commands

# 起動時の重い初期化をキャッシュするためのヘルパー (compinit より前に要る)
source "$SETUP_DIR/zsh/cache.zsh"

# 補完スクリプトのキャッシュ置き場。compinit より前に fpath へ足す。
fpath=("$ZSH_CACHE_DIR/completions" $fpath)

# uv の補完は 52 万バイトあり eval に 70ms かかる。#compdef 形式なので
# fpath に置けば compinit が遅延ロードしてくれて起動時のコストがゼロになる。
_zsh_cache_completion _uv  "${commands[uv]}"  -- uv generate-shell-completion zsh
_zsh_cache_completion _uvx "${commands[uvx]}" -- uvx --generate-shell-completion zsh

# Completion system
# フルの compinit は 240ms かかるが -C なら 10ms。ただし -C は dump をそのまま使うため
# 新しく fpath に置いた補完が認識されない。dump が 24 時間より古い (または無い) ときだけ
# フルで作り直す。
autoload -Uz compinit
# glob qualifier は素の形で書く ((#q...) は EXTENDED_GLOB が要る)。
# N=無ければ空 / .=通常ファイル / mh-24=24時間以内に更新
_zcompdump_fresh=("${ZDOTDIR:-$HOME}"/.zcompdump(N.mh-24))
if (( $#_zcompdump_fresh )); then
    compinit -C
else
    compinit
fi
unset _zcompdump_fresh

# Enable colors
autoload -Uz colors
colors

# Load zsh configurations
# Order matters: env.zsh must be first to set up environment
source "$SETUP_DIR/zsh/env.zsh"
source "$SETUP_DIR/zsh/completion.zsh"
source "$SETUP_DIR/zsh/gwt.zsh"
source "$SETUP_DIR/zsh/ghu.zsh"
source "$SETUP_DIR/zsh/gh.zsh"
source "$SETUP_DIR/zsh/github.zsh"
source "$SETUP_DIR/zsh/gcloud.zsh"
source "$SETUP_DIR/zsh/anyenv.zsh"
source "$SETUP_DIR/zsh/goenv.zsh"
source "$SETUP_DIR/zsh/prompt-line.zsh"
source "$SETUP_DIR/zsh/ai.zsh"
source "$SETUP_DIR/zsh/aliases.zsh"
source "$SETUP_DIR/zsh/functions.zsh"
source "$SETUP_DIR/zsh/keybindings.zsh"
source "$SETUP_DIR/zsh/iterm2.zsh"
#test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh" # iTerm公式

# cmux サイドバーへの cwd 表示 (cmux 内でのみ)
if [[ -n "$CMUX_SHELL_INTEGRATION" ]]; then
    source "$SETUP_DIR/cmux/sidebar-cwd.zsh"
fi

# Initialize tools
# rehash はシェル起動時に実行しない (--no-rehash)。理由:
#   1. 5 つの env の rehash で起動が約 1 秒遅くなる
#   2. rehash 中に端末が閉じられるとロック (.pyenv-shim) が残り、
#      以降すべてのシェル起動が 60 秒ブロックして
#      "pyenv: cannot rehash: couldn't acquire lock" を出す
# 新しい実行ファイルを入れた後 (pip install / gem install / npm i -g など) は
# 明示的に `pyenv rehash` などを実行する。
#
# さらに anyenv init 自体が env ごとに別プロセスを起こすため 550ms かかる。出力は
# env の顔ぶれとバージョンが変わらない限り不変なのでキャッシュして source する
# (生成の詳細は zsh/anyenv.zsh)。古い内容が残ったと感じたら `zsh-cache-clear`。
_zsh_cache_source anyenv-init.zsh \
    "$HOME/.anyenv/envs" "$HOME/.anyenv/envs"/*/libexec(N) "${commands[anyenv]}" \
    "$HOMEBREW_PREFIX/Cellar/anyenv"(N) \
    -- _zsh_gen_anyenv_init \
    || eval "$(anyenv init - --no-rehash)"

# --no-rehash は GOROOT/GOPATH を設定する goenv の呼び出しまで落とすので明示的に補う。
# 本家 `goenv rehash --only-manage-paths` は 190ms かかるので、同じ解決を
# サブプロセス無しで行う _goenv_set_paths (zsh/goenv.zsh) を使う。
_goenv_set_paths

eval "$(zoxide init zsh)"

# Call the greeting function when starting an interactive shell
if [[ $- == *i* ]]; then
#    display_greeting
    auto_make_login
fi

# Source local configurations if they exist
if [[ -f ~/.zshrc.local ]]; then
    source ~/.zshrc.local
fi

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# security
# See: https://github.com/AikidoSec/safe-chain
source ~/.safe-chain/scripts/init-posix.sh # Safe-chain Zsh initialization script
# socket.dev
# See: https://docs.socket.dev/docs/safe-npm-faq
#alias npm="socket-npm"
#alias npx="socket-npx"
#compdef \_npm socket-npm

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
*":$PNPM_HOME/bin:"*) ;;
*) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

# Visivo
export PATH="$HOME/.visivo/bin:$PATH"


# PromptLine (キャッシュ更新は zsh/prompt-line.zsh。古いときだけ背後で走る)
_prompt_line_start_refresh


# zshexit の挙動確認
zshexit() {
    echo "[zshexit] shell PID=$$ exiting at $(date '+%H:%M:%S')"
}

iterm-run() {
  osascript -e "
  tell application \"iTerm2\"
    create window with default profile
    tell current session of current window
      delay 0.1
      write text \"$*\"
    end tell
  end tell"
}

# obsidian
export OBSIDIAN_VAULT="$HOME/vault"