#!/bin/bash
# check-claude-orphans: 孤児化した claude daemon を検出し、暴走中のものを kill する
#
# 判定:
#   「孤児」    = PPID=1 (launchd 養子化) かつ comm に "claude" を含む
#   「暴走中」  = 上記のうち、累積 CPU 時間 / 経過時間 >= THRESHOLD_PCT (%)
#
# 使い方:
#   check-claude-orphans.sh             # dry-run (デフォルト): 暴走中の孤児を表示
#   check-claude-orphans.sh --kill      # 暴走中の孤児を SIGTERM、3秒後に残ってれば SIGKILL
#   check-claude-orphans.sh --list-all  # 全 PPID=1 な claude プロセスを表示 (idle 含む)

set -u

MODE="${1:-dry-run}"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"
THRESHOLD_PCT=20

etime_to_sec() {
  local e="$1"
  local d=0 h=0 m=0 s=0
  if [[ "$e" == *-* ]]; then d="${e%%-*}"; e="${e#*-}"; fi
  IFS=: read -ra parts <<< "$e"
  case ${#parts[@]} in
    3) h="${parts[0]}"; m="${parts[1]}"; s="${parts[2]}";;
    2) m="${parts[0]}"; s="${parts[1]}";;
    1) s="${parts[0]}";;
  esac
  echo $(( 10#$d * 86400 + 10#$h * 3600 + 10#$m * 60 + 10#$s ))
}

cputime_to_sec() {
  local t="${1%.*}"
  local h=0 m=0 s=0
  IFS=: read -ra parts <<< "$t"
  case ${#parts[@]} in
    3) h="${parts[0]}"; m="${parts[1]}"; s="${parts[2]}";;
    2) m="${parts[0]}"; s="${parts[1]}";;
    1) s="${parts[0]}";;
  esac
  echo $(( 10#$h * 3600 + 10#$m * 60 + 10#$s ))
}

# PPID=1 (launchd 養子) かつ Claude Code CLI/daemon バイナリのプロセス。
# デスクトップアプリ (/Applications/Claude.app/) は対象外。
ALL_ORPHANS=$(ps -axo pid,ppid,etime,time,%cpu,comm | awk '
  NR>1 && $2==1 && $6 ~ "^/Users/nkmr/\\.local/(share/claude|bin/claude)"
')

if [[ -z "$ALL_ORPHANS" ]]; then
  echo "$LOG_PREFIX no orphan claude processes (PPID=1)"
  exit 0
fi

if [[ "$MODE" == "--list-all" ]]; then
  echo "$LOG_PREFIX orphan claude processes (PPID=1):"
  printf '%s\n' "PID    PPID  ELAPSED         CPUTIME      %CPU  COMMAND"
  echo "$ALL_ORPHANS"
  exit 0
fi

RUNAWAY_PIDS=()
RUNAWAY_LINES=()
while read -r pid ppid etime cputime pcpu comm; do
  [[ -z "$pid" ]] && continue
  esec=$(etime_to_sec "$etime")
  csec=$(cputime_to_sec "$cputime")
  if (( esec > 0 )); then
    ratio=$(( csec * 100 / esec ))
    if (( ratio >= THRESHOLD_PCT )); then
      RUNAWAY_PIDS+=("$pid")
      RUNAWAY_LINES+=("PID=$pid ELAPSED=$etime CPUTIME=$cputime (${ratio}% of elapsed) %CPU=$pcpu CMD=$comm")
    fi
  fi
done <<< "$ALL_ORPHANS"

if [[ ${#RUNAWAY_PIDS[@]} -eq 0 ]]; then
  ALL_COUNT=$(echo "$ALL_ORPHANS" | wc -l | tr -d ' ')
  echo "$LOG_PREFIX ${ALL_COUNT} orphan claude process(es) exist but none are runaway (>=${THRESHOLD_PCT}% CPU/elapsed). Pass --list-all to inspect."
  exit 0
fi

echo "$LOG_PREFIX runaway orphan claude processes detected:"
for line in "${RUNAWAY_LINES[@]}"; do
  echo "$LOG_PREFIX   $line"
done

if [[ "$MODE" != "--kill" ]]; then
  echo "$LOG_PREFIX dry-run: pass --kill to actually terminate"
  exit 1
fi

echo "$LOG_PREFIX sending SIGTERM to: ${RUNAWAY_PIDS[*]}"
kill -TERM "${RUNAWAY_PIDS[@]}" 2>&1 | sed "s/^/$LOG_PREFIX /"
sleep 3

STILL_ALIVE=()
for p in "${RUNAWAY_PIDS[@]}"; do
  if kill -0 "$p" 2>/dev/null; then STILL_ALIVE+=("$p"); fi
done
if [[ ${#STILL_ALIVE[@]} -gt 0 ]]; then
  echo "$LOG_PREFIX sending SIGKILL to stragglers: ${STILL_ALIVE[*]}"
  kill -9 "${STILL_ALIVE[@]}" 2>&1 | sed "s/^/$LOG_PREFIX /"
fi
echo "$LOG_PREFIX done"
