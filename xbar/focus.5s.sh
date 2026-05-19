#!/usr/bin/env zsh
# <xbar.title>Focus (Horo)</xbar.title>
# <xbar.version>v0.2.0</xbar.version>
# <xbar.author>nkmr-jp</xbar.author>
# <xbar.author.github>nkmr-jp</xbar.author.github>
# <xbar.desc>Horo の進行中タスクをメニューバーに表示する</xbar.desc>
# <xbar.dependencies>sqlite3, Horo.app</xbar.dependencies>
#
# Horo (https://horo.app) の SQLite を読み、現在動いている timer があれば
# そのタスク名をメニューバーに表示する。動いていなければ ☕️ を出す。

set -u
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
# xbar 経由起動だと LANG が空になり、zsh の ${var:0:N} 等が
# バイト単位になって日本語が壊れるので UTF-8 を明示する。
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

DB="$HOME/Library/Containers/net.matthewpalmer.Horo/Data/Library/Application Support/Horo/horo.db"

if [[ ! -f "$DB" ]]; then
  print -- "❓"
  print -- "---"
  print -- "Horo DB が見つかりません | color=red"
  print -- "${DB} | size=11 color=gray"
  exit 0
fi

# 最新タスクの id / text / 未完了フラグを 1 クエリで取得。
# 未完了 = started_at はあるが completed_at / saved_at / trashed_at がいずれも null。
ROW=$(sqlite3 -separator $'\t' "$DB" "
  select
    timer_id,
    text,
    case when completed_at is null and saved_at is null and trashed_at is null then 1 else 0 end
  from timer_history
  order by timer_id desc
  limit 1;"
)

LATEST=""; DOING=""; UNFINISHED=0
[[ -n "$ROW" ]] && IFS=$'\t' read -r LATEST DOING UNFINISHED <<< "$ROW"

if [[ -n "$LATEST" && "$UNFINISHED" == "1" ]]; then
  if [[ "$DOING" =~ '#[a-z0-9]+' ]]; then
    HASH="$MATCH"
    MSG="${DOING//$HASH/}"
  else
    HASH=""
    MSG="$DOING"
  fi
  # xbar の menu item は `|` を param 区切りとして扱うので潰す。
  MSG="${MSG//|/ }"
  print -- "🧑‍💻${MSG} | size=16"
  print -- "---"
  [[ -n "$HASH" ]] && print -- "tag: ${HASH} | size=11 color=gray"
  print -- "timer_id: ${LATEST} | size=11 color=gray"
else
  print -- " ☕️"
  print -- "---"
  print -- "進行中のタスクはありません | color=gray"
fi

print -- "---"
print -- "Open Horo | bash=/usr/bin/open param1=-b param2=net.matthewpalmer.Horo terminal=false"
print -- "Refresh | refresh=true"
