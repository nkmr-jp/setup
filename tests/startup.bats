#!/usr/bin/env bats
# シェル起動のスモークテスト
#
# init.zsh は対話ログインシェルの起動経路そのものなので、壊れると全ターミナルが
# 壊れる。しかも zsh の実行時エラー（glob qualifier の誤りなど）は起動を途中で
# 打ち切るだけで、パッと見は「速く起動した」ように見えてしまう。
# 「エラーを出さずに最後まで走り、必要なものが揃っている」ことを機械的に確かめる。
#
# 実ユーザーの ~/.zprofile を通す（HOMEBREW_PREFIX や PATH がそこで決まるため）。
# 環境依存なので、前提が揃わないマシンでは skip する。

setup() {
    REPO="${BATS_TEST_DIRNAME}/.."
    ZD="$BATS_TEST_TMPDIR/zdotdir"
    mkdir -p "$ZD"
    export ZSH_CACHE_DIR="$BATS_TEST_TMPDIR/cache"

    printf '%s\n' '[[ -f "$HOME/.zshenv" ]] && source "$HOME/.zshenv"' > "$ZD/.zshenv"
    printf '%s\n' '[[ -f "$HOME/.zprofile" ]] && source "$HOME/.zprofile"' > "$ZD/.zprofile"
    {
        printf 'SETUP_DIR=%s\n' "${REPO:A}"
        printf '%s\n' 'source "$SETUP_DIR/zsh/init.zsh"'
    } > "$ZD/.zshrc"
}

# 起動経路が撒くノイズを落として、アサーションしたい出力だけにする。
#   - iTerm2 連携の OSC (ESC ] ... BEL) は終端ごと消す。
#     先に BEL を消すと終端が失われ、後続の本文まで巻き込んで消えてしまう。
#   - init.zsh の zshexit フック（動作確認用の echo）はシェル終了時に必ず 1 行出る。
_strip_noise() {
    sed $'s/\x1b\][^\x07]*\x07//g' | tr -d '\a\r' | grep -av '^\[zshexit\]'
}

# 対話ログインシェルを起動して <コマンド> を実行する。stderr だけを返す。
start_shell_stderr() {
    ZDOTDIR="$ZD" ZSH_CACHE_DIR="$ZSH_CACHE_DIR" \
        timeout 120 zsh -l -i -c "${1:-true}" 2>&1 >/dev/null | _strip_noise
}

# 対話ログインシェルを起動して <コマンド> を実行する。stdout だけを返す。
start_shell_stdout() {
    ZDOTDIR="$ZD" ZSH_CACHE_DIR="$ZSH_CACHE_DIR" \
        timeout 120 zsh -l -i -c "$1" 2>/dev/null | _strip_noise
}

@test "startup: エラーを出さずに起動する" {
    run start_shell_stderr
    [ "$status" -eq 0 ]
    # zsh -i を tty 無しで起動すると出る既知のノイズだけは許容する
    local noise='can.t change option: zle'
    local rest
    rest="$(printf '%s\n' "$output" | grep -avE "$noise" | grep -av '^$' || true)"
    [ -z "$rest" ]
}

@test "startup: 途中で打ち切られず最後まで走る" {
    # init.zsh の末尾で設定されるものが揃っていれば、最後まで到達している
    run start_shell_stdout 'print -r -- "${BUN_INSTALL:-未設定}"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"/.bun"* ]]
}

@test "startup: 各 zsh/*.zsh が読み込まれている" {
    # gwt.zsh / goenv.zsh / cache.zsh / iterm2.zsh の代表的な関数が定義されていること
    run start_shell_stdout 'for f in gwt _goenv_set_paths _zsh_cache_source _iterm2_precmd; do
        print -r -- "$f=${functions[$f]:+ok}"
    done'
    [ "$status" -eq 0 ]
    [[ "$output" == *"gwt=ok"* ]]
    [[ "$output" == *"_goenv_set_paths=ok"* ]]
    [[ "$output" == *"_zsh_cache_source=ok"* ]]
    [[ "$output" == *"_iterm2_precmd=ok"* ]]
}

@test "startup: 補完システムが有効になっている" {
    run start_shell_stdout 'print -r -- "${_comps[git]:-未登録}"'
    [ "$status" -eq 0 ]
    [ "$output" = "_git" ]
}

@test "startup: PATH に重複が無い" {
    # typeset -U は配列だけでなくスカラー PATH にも掛けないと
    # `export PATH="X:$PATH"` 形式の追加が重複除去されない
    run start_shell_stdout 'u=(${(u)path}); print -r -- $(( $#path - $#u ))'
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "startup: anyenv の shim が PATH にある" {
    command -v anyenv >/dev/null || skip "anyenv が無い"
    run start_shell_stdout 'print -l $path'
    [ "$status" -eq 0 ]
    [[ "$output" == *"/.anyenv/envs/pyenv/shims"* ]]
}

# ============================================================
# キャッシュが実際に効いているか
# ============================================================

@test "cache: 起動でキャッシュが作られる" {
    command -v anyenv >/dev/null || skip "anyenv が無い"
    start_shell_stderr >/dev/null
    [ -s "$ZSH_CACHE_DIR/anyenv-init.zsh" ]
}

@test "cache: 2 回目の起動ではキャッシュを作り直さない" {
    command -v anyenv >/dev/null || skip "anyenv が無い"
    start_shell_stderr >/dev/null
    local before
    before="$(stat -f '%m' "$ZSH_CACHE_DIR/anyenv-init.zsh")"
    sleep 1
    start_shell_stderr >/dev/null
    local after
    after="$(stat -f '%m' "$ZSH_CACHE_DIR/anyenv-init.zsh")"
    [ "$before" = "$after" ]
}

@test "cache: uv の補完を eval せず fpath に置いている" {
    command -v uv >/dev/null || skip "uv が無い"
    start_shell_stderr >/dev/null
    [ -s "$ZSH_CACHE_DIR/completions/_uv" ]
    # compinit が fpath から拾って compdef 登録していること
    run start_shell_stdout 'print -r -- "${_comps[uv]:-未登録}"'
    [ "$output" = "_uv" ]
    # 起動時点では関数の実体が読み込まれていない（遅延ロードされている）こと
    run start_shell_stdout 'print -r -- "${functions[_uv__run_commands]:+実体化済み}"'
    [ -z "$output" ]
}
