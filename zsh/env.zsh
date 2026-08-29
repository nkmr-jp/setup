# Environment variables and PATH settings

# Setup directory
# .zshrc が既に設定していればそれを尊重する (worktree から検証するときに要る)
export SETUP_DIR="${SETUP_DIR:-$HOME/ghq/github.com/nkmr-jp/setup}"

# PATH の重複を自動で取り除く (先に出てきた方＝優先度の高い方が残る)。
# .zprofile・各種インストーラ・env.zsh が同じディレクトリを何度も足すため、
# これが無いと 82 エントリ中 24 個が重複したままになり、コマンド解決のたびに走査される。
#
# 配列 (path) だけでなくスカラー (PATH) にも -U を付けること。
# `typeset -U path` だけだと `path=(...)` の代入しか重複除去されず、
# この設定でほぼ全ての追加に使っている `export PATH="X:$PATH"` には効かない (実測)。
typeset -U PATH path FPATH fpath

# Golang
export GO111MODULE=on
export GOPROXY=direct
export GOSUMDB="sum.golang.org"

# anyenv and goenv
export GOENV_ROOT="$HOME/.anyenv/envs/goenv/"

# Build PATH with proper order
export PATH="$GOENV_ROOT/bin:$PATH"
export PATH="$HOME/.anyenv/bin:$PATH"

# Add Go paths if GOROOT and GOPATH are set
if [[ -n "$GOROOT" ]]; then
    export PATH="$GOROOT/bin:$PATH"
fi
if [[ -n "$GOPATH" ]]; then
    export PATH="$PATH:$GOPATH/bin"
fi

# Additional paths
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="/usr/local/Caskroom/miniconda/base/bin:$PATH"

# For installing Command binaries
export PATH="$HOME/src/bin:$PATH"

# setup repo scripts (shell functions exposed as commands for GUI apps, cron, other tools)
export PATH="$SETUP_DIR/bin:$PATH"

# Added by Windsurf
export PATH="$HOME/.codeium/windsurf/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/nkmr/.lmstudio/bin"

# aqua https://aquaproj.github.io/docs/install
# `aqua root-dir` は毎回プロセスを起こすが値は固定なのでキャッシュする
_zsh_cache_var aqua-root-dir.zsh AQUA_ROOT_DIR "${commands[aqua]}" -- aqua root-dir
export PATH="${AQUA_ROOT_DIR:-$HOME/.local/share/aquaproj-aqua}/bin:$PATH"

# Export PATH to GUI apps (for GoLand, VSCode, etc.)
# This allows GUI apps launched from Dock/Spotlight to access CLI tools
launchctl setenv PATH "$PATH" 2>/dev/null || true

# See: https://opencode.ai/docs/tui/#editor-setup
export EDITOR="code --wait"

# See: https://codeclaude.com/docs/en/fullscreen
export CLAUDE_CODE_NO_FLICKER=1

# gwt: worktree 作成時に .agentsws/issues を張る先の issues リポジトリ
# 未設定だと _gwt_setup_agentsws_issues_link が黙ってスキップし、symlink が作られない。
# projects/ レイアウト（実体が <repo>/projects/<project>/）は gwt.zsh 側で解決するので
# ここではリポジトリのルートを指す。
export GWT_ISSUES_REPO_DIR="$HOME/ghq/github.com/nkmr-jp/issues"