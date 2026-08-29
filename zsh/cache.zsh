# シェル起動時に走る「外部コマンドの出力を eval する」初期化のキャッシュ
#
# anyenv init / uv の補完 / ghq root などは、起動のたびに別プロセスを起こしているが
# 出力は決定的で、ツールを更新しない限り変わらない。生成結果をファイルに残し、
# 依存パスのどれかが新しくなったときだけ作り直す。
#
# キャッシュを捨てて作り直したいときは `zsh-cache-clear`。

ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh-init}"

# 依存パスのいずれかがキャッシュより新しい（またはキャッシュが無い・空）なら真
_zsh_cache_stale() {
    local cache=$1; shift
    [[ -s $cache ]] || return 0
    local dep
    for dep in "$@"; do
        [[ -e $dep && $dep -nt $cache ]] && return 0
    done
    return 1
}

# _zsh_cache_gen <出力パス> <依存パス...> -- <生成コマンド...>
#
# 生成コマンドの stdout でキャッシュを作り直す。生成に失敗しても既存のキャッシュは壊さない。
# 使えるキャッシュがあれば 0 を返す。
_zsh_cache_gen() {
    local cache=$1; shift
    local -a deps
    while (( $# )) && [[ $1 != -- ]]; do
        deps+=("$1")
        shift
    done
    shift  # -- を捨てる

    if _zsh_cache_stale "$cache" "${deps[@]}"; then
        # 生成コマンドが見つからない場合 ($1 が空) は既存キャッシュの有無で判断する
        (( $# )) || { [[ -s $cache ]]; return }
        mkdir -p "${cache:h}" || return 1
        local tmp="$cache.$$.tmp"
        if "$@" > "$tmp" 2>/dev/null && [[ -s $tmp ]]; then
            mv -f "$tmp" "$cache"
        else
            rm -f "$tmp"
        fi
    fi
    [[ -s $cache ]]
}

# _zsh_cache_source <キャッシュ名> <依存パス...> -- <生成コマンド...>
#
# 生成結果を source する。生成もキャッシュ利用もできなければ 1 を返すので、
# 呼び出し側でフォールバックできる。
_zsh_cache_source() {
    local cache="$ZSH_CACHE_DIR/$1"; shift
    _zsh_cache_gen "$cache" "$@" || return 1
    source "$cache"
}

# _zsh_cache_var <キャッシュ名> <変数名> <依存パス...> -- <値を出力するコマンド...>
#
# `ghq root` のように「毎回プロセスを起こすが値は固定」なものを変数に取り込む。
# コマンドの出力そのものではなく代入文をキャッシュするので、source した時点で
# 変数に入っている（キャッシュ利用時はプロセスを起こさない）。
_zsh_cache_var() {
    local cache="$ZSH_CACHE_DIR/$1" var=$2; shift 2
    local -a deps
    while (( $# )) && [[ $1 != -- ]]; do
        deps+=("$1")
        shift
    done
    shift  # -- を捨てる

    if _zsh_cache_stale "$cache" "${deps[@]}"; then
        local value
        if (( $# )) && value=$("$@" 2>/dev/null) && [[ -n $value ]]; then
            mkdir -p "${cache:h}" || return 1
            # 端末を同時に何枚も開いたとき、書きかけのファイルを別のシェルが
            # source しないように一時ファイル経由で差し替える
            local tmp="$cache.$$.tmp"
            print -r -- "typeset -g $var=${(q)value}" > "$tmp" \
                && mv -f "$tmp" "$cache" \
                || rm -f "$tmp"
        fi
    fi
    [[ -s $cache ]] || return 1
    source "$cache"
}

# _zsh_cache_completion <補完関数名> <依存パス...> -- <生成コマンド...>
#
# `#compdef` 形式の補完スクリプトを fpath 上のキャッシュディレクトリへ書き出す。
# eval せず compinit の遅延ロードに任せるので、起動時のコストがゼロになる。
# fpath への追加は init.zsh が compinit の前に行う。
_zsh_cache_completion() {
    _zsh_cache_gen "$ZSH_CACHE_DIR/completions/$1" "${@:2}"
}

# キャッシュを全部捨てる（ツールを更新して古い内容が残ったとき用）
zsh-cache-clear() {
    rm -rf "$ZSH_CACHE_DIR"
    print -r -- "削除しました: $ZSH_CACHE_DIR（次のシェル起動で作り直されます）"
}
