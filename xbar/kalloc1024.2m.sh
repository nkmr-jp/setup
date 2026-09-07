#!/usr/bin/env zsh
# <xbar.title>kalloc1024 Leak Monitor</xbar.title>
# <xbar.version>v0.1.0</xbar.version>
# <xbar.author>nkmr-jp</xbar.author>
# <xbar.author.github>nkmr-jp</xbar.author.github>
# <xbar.desc>Continuously show the Claude Code kernel memory leak (data.kalloc.1024) in the menu bar</xbar.desc>
# <xbar.dependencies>zprint</xbar.dependencies>
#
# The data.kalloc.1024 zone accumulates a Claude Code kernel memory leak that
# userspace cannot release; only rebooting resets it (see issue #8). The panic
# threshold is approximately 21,000,000 elements (about 20 GiB, 1024 bytes each).
# Read the zprint cur #inuse column every 2 minutes to show threshold progress and growth rate.

set -u
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
# xbar may launch with LANG unset, making zsh slices such as ${var:0:N} operate
# on bytes and corrupt Japanese text. Explicitly select UTF-8.
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Approximate panic threshold in elements, measured in issue #10 (about 20 GiB, 1024 bytes each).
THRESHOLD=21000000
STATE_FILE="$HOME/.cache/xbar-kalloc1024.state"

if ! command -v zprint >/dev/null 2>&1; then
  print -- "❓ kalloc"
  print -- "---"
  print -- "zprint が見つかりません | color=red"
  exit 0
fi

# Column 7 = cur #inuse (the number of elements currently in use)
ELEMS=$(zprint 2>/dev/null | awk '$1=="data.kalloc.1024"{print $7}')

if [[ -z "$ELEMS" || ! "$ELEMS" =~ '^[0-9]+$' ]]; then
  print -- "❓ kalloc"
  print -- "---"
  print -- "data.kalloc.1024 の取得に失敗しました | color=red"
  exit 0
fi

NOW_EPOCH=$(date -u +%s)

# Each element is exactly 1024 bytes, so GiB = elements / 1024 / 1024.
GB=$(awk -v e="$ELEMS" 'BEGIN{printf "%.1f", e/1048576}')
THRESHOLD_GB=$(awk -v t="$THRESHOLD" 'BEGIN{printf "%.1f", t/1048576}')
PCT=$(awk -v e="$ELEMS" -v t="$THRESHOLD" 'BEGIN{printf "%.1f", (e/t)*100}')
PCT_INT=$(awk -v e="$ELEMS" -v t="$THRESHOLD" 'BEGIN{printf "%d", (e/t)*100}')

if (( PCT_INT < 60 )); then
  COLOR="green"
elif (( PCT_INT < 85 )); then
  COLOR="yellow"
else
  COLOR="red"
fi

# Estimate growth in elements/second from the previous sample (normally 2 minutes earlier).
PACE=""
REMAIN_STR=""
PREV_EPOCH=""
PREV_ELEMS=""
if [[ -f "$STATE_FILE" ]]; then
  read -r PREV_EPOCH PREV_ELEMS < "$STATE_FILE"
fi

if [[ -n "${PREV_EPOCH:-}" && -n "${PREV_ELEMS:-}" ]]; then
  DIFF_EPOCH=$(( NOW_EPOCH - PREV_EPOCH ))
  DIFF_ELEMS=$(( ELEMS - PREV_ELEMS ))
  if (( DIFF_EPOCH > 0 && DIFF_ELEMS >= 0 )); then
    PACE=$(awk -v d="$DIFF_ELEMS" -v s="$DIFF_EPOCH" 'BEGIN{printf "%.1f", d/s}')
    REMAIN_ELEMS=$(( THRESHOLD - ELEMS ))
    if (( REMAIN_ELEMS > 0 )) && awk -v p="$PACE" 'BEGIN{exit !(p>0)}'; then
      REMAIN_SEC=$(awk -v r="$REMAIN_ELEMS" -v p="$PACE" 'BEGIN{printf "%d", r/p}')
      if (( REMAIN_SEC < 3600 )); then
        REMAIN_STR="$(( REMAIN_SEC / 60 ))分"
      elif (( REMAIN_SEC < 86400 )); then
        REMAIN_STR="$(( REMAIN_SEC / 3600 ))時間"
      else
        REMAIN_STR="$(( REMAIN_SEC / 86400 ))日"
      fi
    fi
  fi
fi

print -- "${NOW_EPOCH} ${ELEMS}" > "$STATE_FILE"

print -- "kalloc ${PCT}% | color=${COLOR}"
print -- "---"
print -- "data.kalloc.1024: ${GB}GiB / ${THRESHOLD_GB}GiB (${PCT}%) | size=11 color=gray"
print -- "elements: ${ELEMS} / ${THRESHOLD} | size=11 color=gray"
if [[ -n "$PACE" ]]; then
  print -- "増加ペース: ${PACE} 要素/秒 | size=11 color=gray"
  if [[ -n "$REMAIN_STR" ]]; then
    print -- "閾値到達まで: 約${REMAIN_STR}（このペースが続いた場合） | size=11 color=gray"
  fi
else
  print -- "増加ペース: 計測中（次回更新で表示） | size=11 color=gray"
fi
print -- "最終更新: $(date '+%Y-%m-%d %H:%M:%S') | size=11 color=gray"
print -- "---"
print -- "Refresh | refresh=true"
