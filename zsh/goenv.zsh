# goenv の GOROOT / GOPATH 設定
#
# 本家の `goenv rehash --only-manage-paths` は shim の rehash はせず GOROOT/GOPATH を
# export するだけだが、goenv-version-name / goenv-prefix が bash のサブプロセスを
# 連鎖的に起こすため 190ms 前後かかる。同じ解決をサブプロセス無しで行う。
#
# 解決規則は本家と同じ:
#   1. カレントから親へ辿って最初に見つかった .go-version
#   2. 無ければ $GOENV_ROOT/version（global）
#   3. system なら何もしない（システムの go を使う）
#
# 本家との一致は setup/tests/test-goenv-paths.zsh で検証している。
_goenv_set_paths() {
    local root="${GOENV_ROOT:-$HOME/.anyenv/envs/goenv}" dir="$PWD" version=""
    root="${root%/}"

    # cwd が削除されていると PWD が "." になる。この状態で親を辿ると
    # "." は "${dir%/*}" で縮まないため無限ループする（goenv 2.2.39 の実バグ）。
    [[ "$dir" == /* ]] || {
        print -u2 -r -- "goenv: cwd が削除されています (PWD=$PWD)。GOROOT/GOPATH は未設定です。有効なディレクトリへ cd してください。"
        return 0
    }

    while [[ -n "$dir" ]]; do
        if [[ -r "$dir/.go-version" ]]; then
            version="$(<"$dir/.go-version")"
            break
        fi
        dir="${dir%/*}"
    done
    [[ -z "$version" && -r "$root/version" ]] && version="$(<"$root/version")"

    version="${version//[[:space:]]/}"
    [[ -z "$version" || "$version" == system ]] && return 0

    # 本家と同じく export だけ行い PATH は触らない
    # (PATH への追加は env.zsh が GOROOT/GOPATH を見て行う)
    export GOROOT="$root/versions/$version"
    export GOPATH="$HOME/go/$version"
}
