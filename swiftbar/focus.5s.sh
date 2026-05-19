#!/usr/bin/env zsh
# <bitbar.title>Focus (Horo)</bitbar.title>
# <bitbar.version>v0.2.0</bitbar.version>
# <bitbar.author>nkmr-jp</bitbar.author>
# <bitbar.author.github>nkmr-jp</bitbar.author.github>
# <bitbar.desc>Horo の進行中タスクをメニューバーに表示する</bitbar.desc>
# <bitbar.dependencies>sqlite3, Horo.app</bitbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
#
# Horo (https://horo.app) の SQLite を読み、現在動いている timer があれば
# そのタスク名をメニューバーに表示する。動いていなければ ☕️ を出す。

set -u
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
# SwiftBar 経由起動だと LANG が空になり、zsh の ${var:0:N} 等が
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

######################################################################
# horo からデータ取得
######################################################################

# 最新のタスクの ID を取得
LATEST=$(sqlite3 "$DB" "select timer_id from timer_history order by timer_id desc limit 1")

# started_at があるが、completed_at, saved_at, trashed_at が無いタスク ID を取得
UN_FINISHED=$(sqlite3 "$DB" "
    select timer_id from timer_history
    where completed_at is null and saved_at is null and trashed_at is null
    order by timer_id desc
    limit 1;"
)

######################################################################
# 表示
######################################################################

# ID が一致するときのみタスクを表示する。
if [[ -n "$LATEST" && "$LATEST" == "$UN_FINISHED" ]]; then
  DOING=$(sqlite3 "$DB" "select text from timer_history order by timer_id desc limit 1")
  HASH=$(print -r -- "$DOING" | grep -Eo '#([a-z]|[0-9])+' | head -n1)
  if [[ -n "$HASH" ]]; then
    MSG=$(print -r -- "$DOING" | sed -e "s|${HASH}||g")
  else
    MSG="$DOING"
  fi
  # SwiftBar の menu item は `|` を param 区切りとして扱うので潰す。
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
