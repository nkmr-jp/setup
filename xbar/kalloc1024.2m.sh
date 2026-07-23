#!/usr/bin/env zsh
# <xbar.title>kalloc1024 Leak Monitor</xbar.title>
# <xbar.version>v0.1.0</xbar.version>
# <xbar.author>nkmr-jp</xbar.author>
# <xbar.author.github>nkmr-jp</xbar.author.github>
# <xbar.desc>Claude Code 起因のカーネルメモリリーク（data.kalloc.1024）の量をメニューバーに常時表示する</xbar.desc>
# <xbar.dependencies>zprint</xbar.dependencies>
#
# data.kalloc.1024 ゾーンは Claude Code 起因のカーネルメモリリークで、ユーザー空間からは
# 解放できず蓄積は再起動でしかリセットできない（詳細は issue #8 参照）。パニック閾値は
# 約21,000,000要素（≈20GiB、1要素=1024バイト固定）。`zprint` の cur #inuse 列を2分毎に
# 読み、閾値に対する進捗% と増加ペースをメニューバーに表示する。

set -u
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
# xbar 経由起動だと LANG が空になり、zsh の ${var:0:N} 等が
# バイト単位になって日本語が壊れるので UTF-8 を明示する。
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# パニック閾値（要素数）。issue #10 の実測に基づく概算値（≈20GiB、1要素=1024バイト）。
THRESHOLD=21000000
STATE_FILE="$HOME/.cache/xbar-kalloc1024.state"

if ! command -v zprint >/dev/null 2>&1; then
  print -- "❓ kalloc"
  print -- "---"
  print -- "zprint が見つかりません | color=red"
  exit 0
fi

# 7列目 = cur #inuse（現在使用中の要素数）
ELEMS=$(zprint 2>/dev/null | awk '$1=="data.kalloc.1024"{print $7}')

if [[ -z "$ELEMS" || ! "$ELEMS" =~ '^[0-9]+$' ]]; then
  print -- "❓ kalloc"
  print -- "---"
  print -- "data.kalloc.1024 の取得に失敗しました | color=red"
  exit 0
fi

NOW_EPOCH=$(date -u +%s)

# 1要素=1024バイト固定なので GiB 換算は elements / 1024 / 1024。
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

# 前回計測（2分間隔想定）との差分から増加ペース（要素/秒）を推定する。
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
