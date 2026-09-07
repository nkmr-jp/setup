# Cache initialization that evaluates external command output at shell startup.
#
# anyenv init, uv completion, ghq root, and similar commands start processes on every startup,
# but their output is deterministic and stays unchanged until tools are updated. Save the output
# to files and regenerate it only when a dependency path is newer.
#
# Run `zsh-cache-clear` to discard and rebuild the cache.

ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh-init}"

# True if a dependency is newer than the cache, or the cache is missing or empty.
_zsh_cache_stale() {
    local cache=$1; shift
    [[ -s $cache ]] || return 0
    local dep
    for dep in "$@"; do
        [[ -e $dep && $dep -nt $cache ]] && return 0
    done
    return 1
}

# _zsh_cache_gen <output-path> <dependency-paths...> -- <generator-command...>
#
# Rebuild the cache from the generator's stdout. Preserve the existing cache if generation fails.
# Return 0 if a usable cache exists.
_zsh_cache_gen() {
    local cache=$1; shift
    local -a deps
    while (( $# )) && [[ $1 != -- ]]; do
        deps+=("$1")
        shift
    done
    shift  # Discard --.

    if _zsh_cache_stale "$cache" "${deps[@]}"; then
        # If the generator is missing ($1 is empty), check whether an existing cache is usable.
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

# _zsh_cache_source <cache-name> <dependency-paths...> -- <generator-command...>
#
# Source the generated output. Return 1 if neither generation nor the cache is available,
# so the caller can fall back.
_zsh_cache_source() {
    local cache="$ZSH_CACHE_DIR/$1"; shift
    _zsh_cache_gen "$cache" "$@" || return 1
    source "$cache"
}

# _zsh_cache_var <cache-name> <variable-name> <dependency-paths...> -- <value-command...>
#
# Load values from commands such as `ghq root` that start a process but return a fixed value.
# Cache an assignment rather than raw command output, so sourcing it sets the variable
# without starting another process when using the cache.
_zsh_cache_var() {
    local cache="$ZSH_CACHE_DIR/$1" var=$2; shift 2
    local -a deps
    while (( $# )) && [[ $1 != -- ]]; do
        deps+=("$1")
        shift
    done
    shift  # Discard --.

    if _zsh_cache_stale "$cache" "${deps[@]}"; then
        local value
        if (( $# )) && value=$("$@" 2>/dev/null) && [[ -n $value ]]; then
            mkdir -p "${cache:h}" || return 1
            # Replace the cache through a temporary file so simultaneous shell startups
            # cannot source a partially written file.
            local tmp="$cache.$$.tmp"
            print -r -- "typeset -g $var=${(q)value}" > "$tmp" \
                && mv -f "$tmp" "$cache" \
                || rm -f "$tmp"
        fi
    fi
    [[ -s $cache ]] || return 1
    source "$cache"
}

# _zsh_cache_completion <completion-function-name> <dependency-paths...> -- <generator-command...>
#
# Write a `#compdef` completion script into the cache directory on fpath.
# Let compinit load it lazily instead of evaluating it, avoiding startup cost.
# init.zsh adds the directory to fpath before compinit.
_zsh_cache_completion() {
    _zsh_cache_gen "$ZSH_CACHE_DIR/completions/$1" "${@:2}"
}

# Discard all caches when old content remains after updating tools.
zsh-cache-clear() {
    rm -rf "$ZSH_CACHE_DIR"
    print -r -- "削除しました: $ZSH_CACHE_DIR（次のシェル起動で作り直されます）"
}
