# goenv の GOROOT / GOPATH 設定
#
# 本家の `goenv rehash --only-manage-paths` は shim の rehash はせず GOROOT/GOPATH を
# export するだけだが、goenv-version-name / goenv-prefix が bash のサブプロセスを
# 連鎖的に起こすため 190ms 前後かかる。同じ解決をサブプロセス無しで行う。
#
# 解決規則は本家と同じ:
#   0. $GOENV_VERSION が設定されていればそれ（`goenv shell` が export する）
#   1. 無ければカレントから親へ辿って最初に見つかった .go-version
#   2. 無ければ $GOENV_ROOT/version（global）
#   3. system なら何もしない（システムの go を使う）
#   4. 得られた版は実際にインストールされているものへ解決する
#      （`1.24` のような major.minor 指定は最新パッチへ。解決できなければ何もしない）
#
# 本家との一致は setup/tests/goenv.bats で検証している。
_goenv_set_paths() {
    local root="${GOENV_ROOT:-$HOME/.anyenv/envs/goenv}" dir="$PWD" version=""
    root="${root%/}"

    # 本家 goenv-version-name と同じく $GOENV_VERSION が最優先。
    # `goenv shell <version>` が export するので、そこから起こした子シェルにも効く。
    version="${GOENV_VERSION%%:*}"

    if [[ -z "$version" ]]; then
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
    fi

    # 複数行が書かれていたら本家と同じく先頭だけを使い、前後の空白を落とす
    version="${version%%$'\n'*}"
    version="${version//[[:space:]]/}"
    [[ -z "$version" || "$version" == system ]] && return 0

    # 実際にインストールされている版へ解決する（本家 goenv-prefix と同じ規則）。
    #   - 完全一致が無ければ `go-` 接頭辞を落として再試行
    #   - それも無ければ major.minor 指定とみなして最新パッチを選ぶ (1.24 -> 1.24.5)
    #   - どれにも解決できなければ何も設定しない
    #     （本家も goenv-prefix が exit 1 して GOROOT/GOPATH を出力しない。
    #       ここで素通しすると存在しないディレクトリを GOROOT に入れてしまう）
    if [[ ! -d "$root/versions/$version" ]]; then
        local base="${version#go-}"
        local -a candidates=(
            "$root"/versions/${base}(N/:t)
            "$root"/versions/${base}.<->(N/:t)
        )
        (( $#candidates )) || return 0
        candidates=(${(n)candidates})   # 1.20.9 < 1.20.10 になるよう数値順
        version="${candidates[-1]}"
    fi

    # 本家と同じく export だけ行い PATH は触らない
    # (PATH への追加は env.zsh が GOROOT/GOPATH を見て行う)
    export GOROOT="$root/versions/$version"
    export GOPATH="$HOME/go/$version"
}
