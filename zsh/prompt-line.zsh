# Refresh the PromptLine cache.
#
# Only the PromptLine app reads ~/.prompt-line/*.txt; the shell itself does not use these files.
# Running this synchronously added about 175ms to every shell startup.
# (Measured: mdfind 135ms + ghq list 30ms + zoxide query 9ms.)
# The data covers the last seven days and ghq repositories, so second-level freshness is unnecessary.
# Refresh in the background only when older than one hour.

_prompt_line_refresh() {
    local dir="$HOME/.prompt-line"
    mkdir -p "$dir" || return
    zoxide query -l > "$dir/z.txt" 2>/dev/null
    mdfind -onlyin ~ 'kMDItemLastUsedDate >= $time.today(-7)' 2>/dev/null \
        | head -100 > "$dir/mdfind.txt"
    ghq list > "$dir/ghq.txt" 2>/dev/null
}

# Gate to avoid running on every startup.
# Use plain glob qualifiers ((#q...) requires EXTENDED_GLOB).
# N=empty if absent / .=regular file / mh-1=modified within one hour.
#
# Use a dedicated timestamp file rather than a data file such as ghq.txt as the gate.
# Touching a data file would leave a fresh but empty ghq.txt if the background job failed
# on first startup; PromptLine could not distinguish it from a valid empty list.
# With a timestamp file, a missing data file still indicates that it was never generated.
# (Both approaches retry after one hour; only failure visibility differs.)
_prompt_line_start_refresh() {
    local dir="$HOME/.prompt-line"
    local -a fresh=("$dir"/.refreshed(N.mh-1))
    (( $#fresh )) && return 0

    # Advance the timestamp before starting, preventing simultaneous terminals from
    # running multiple mdfind processes (retry after one hour even on failure).
    mkdir -p "$dir" || return
    touch "$dir/.refreshed"
    _prompt_line_refresh &!
}
