#!/bin/zsh
# Test wrapper for cache.zsh
# Run the requested function; the caller supplies ZSH_CACHE_DIR in the environment.

source "${0:A:h}/../zsh/cache.zsh"

func="$1"
shift
"$func" "$@"
