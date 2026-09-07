# Set GOROOT / GOPATH for goenv.
#
# Upstream `goenv rehash --only-manage-paths` only exports GOROOT/GOPATH without
# rehashing shims, but goenv-version-name / goenv-prefix start a chain of bash subprocesses,
# taking about 190ms. Resolve the same values without subprocesses.
#
# Use the same resolution rules as upstream:
#   0. Use $GOENV_VERSION if set (exported by `goenv shell`).
#   1. Otherwise, use the first .go-version found while walking up from the current directory.
#   2. Otherwise, use $GOENV_ROOT/version (global).
#   3. Do nothing for system (use the system go).
#   4. Resolve the selected version to an installed version.
#      Map major.minor values such as `1.24` to the latest patch; do nothing if unresolved.
#
# tests/goenv.bats verifies parity with upstream.
_goenv_set_paths() {
    local root="${GOENV_ROOT:-$HOME/.anyenv/envs/goenv}" dir="$PWD" version=""
    root="${root%/}"

    # Give $GOENV_VERSION highest priority, as upstream goenv-version-name does.
    # `goenv shell <version>` exports it, so child shells inherit it too.
    version="${GOENV_VERSION%%:*}"

    if [[ -z "$version" ]]; then
        # If cwd has been deleted, PWD becomes ".". Walking up from there would loop forever
        # because "${dir%/*}" does not shorten "." (an actual bug in goenv 2.2.39).
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

    # As upstream does, use only the first line and trim surrounding whitespace.
    version="${version%%$'\n'*}"
    version="${version//[[:space:]]/}"
    [[ -z "$version" || "$version" == system ]] && return 0

    # Resolve to an installed version using the same rules as upstream goenv-prefix.
    #   - If there is no exact match, remove the `go-` prefix and retry.
    #   - Otherwise, treat it as major.minor and choose the latest patch (1.24 -> 1.24.5).
    #   - Leave everything unset if no version can be resolved.
    #     (Upstream goenv-prefix also exits 1 without emitting GOROOT/GOPATH.
    #      Passing an unresolved value through would set GOROOT to a nonexistent directory.)
    if [[ ! -d "$root/versions/$version" ]]; then
        local base="${version#go-}"
        local -a candidates=(
            "$root"/versions/${base}(N/:t)
            "$root"/versions/${base}.<->(N/:t)
        )
        (( $#candidates )) || return 0
        candidates=(${(n)candidates})   # Sort numerically so 1.20.9 < 1.20.10.
        version="${candidates[-1]}"
    fi

    # Only export values, without changing PATH, as upstream does.
    # (env.zsh adds paths based on GOROOT/GOPATH.)
    export GOROOT="$root/versions/$version"
    export GOPATH="$HOME/go/$version"
}
