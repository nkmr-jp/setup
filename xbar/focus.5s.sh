#!/usr/bin/env zsh
# <xbar.title>Focus (Horo)</xbar.title>
# <xbar.version>v0.2.0</xbar.version>
# <xbar.author>nkmr-jp</xbar.author>
# <xbar.author.github>nkmr-jp</xbar.author.github>
# <xbar.desc>Show the current Horo task in the menu bar</xbar.desc>
# <xbar.dependencies>sqlite3, Horo.app</xbar.dependencies>
#
# Read the Horo (https://horo.app) SQLite database and show the task name for
# the active timer in the menu bar. Show a coffee icon when no timer is running.

set -u
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
# xbar may launch with LANG unset, making zsh slices such as ${var:0:N} operate
# on bytes and corrupt Japanese text. Explicitly select UTF-8.
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

# Fetch the latest task id, text, and incomplete flag in one query.
# Incomplete means started_at is set and completed_at / saved_at / trashed_at are all null.
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
  # Replace pipes because xbar treats `|` as the menu-item parameter separator.
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
