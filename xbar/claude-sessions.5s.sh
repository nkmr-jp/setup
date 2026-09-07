#!/usr/bin/env zsh
# <xbar.title>Claude Sessions</xbar.title>
# <xbar.version>v0.1.0</xbar.version>
# <xbar.author>nkmr-jp</xbar.author>
# <xbar.author.github>nkmr-jp</xbar.author.github>
# <xbar.desc>Summarize Claude Code sessions as running, awaiting, or idle</xbar.desc>
# <xbar.dependencies>jq, Claude Code (session-monitor plugin)</xbar.dependencies>
#
# The session-monitor plugin hook updates ${CLAUDE_PLUGIN_DATA}/sessions.jsonl.
# Resolve its actual path from the anchor in ~/.claude/session-monitor/data-dir,
# then read the JSONL data to build the menu-bar display.

set -u
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
# xbar may launch with LANG unset, making zsh slices such as ${var:0:N} operate
# on bytes and corrupt Japanese text. Explicitly select UTF-8.
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

SCRIPT_DIR="${0:A:h}"
HANDLER="$SCRIPT_DIR/click-handler.sh"

ANCHOR="$HOME/.claude/session-monitor/data-dir"
DATA_DIR=""
if [[ -f "$ANCHOR" ]]; then
  DATA_DIR=$(< "$ANCHOR")
fi
[[ -z "$DATA_DIR" ]] && DATA_DIR="$HOME/.claude/session-monitor"
SESSIONS_FILE="$DATA_DIR/sessions.jsonl"

if ! command -v jq >/dev/null 2>&1; then
  print -- "⚠️ no jq"
  print -- "---"
  print -- "jq が見つかりません | color=red"
  print -- "brew install jq | bash=brew param1=install param2=jq terminal=true"
  exit 0
fi

# Keep an icon in the bar even if JSONL is missing or empty, so an empty but
# working plugin can be distinguished from a broken, invisible one.
if [[ ! -s "$SESSIONS_FILE" ]]; then
  print -- "💤"
  print -- "---"
  print -- "セッションデータがありません | color=gray"
  print -- "data dir: ${DATA_DIR} | size=11 color=gray"
  print -- "---"
  print -- "Refresh | refresh=true"
  print -- "Open data dir | bash=open param1='${DATA_DIR}' terminal=false"
  exit 0
fi

now_epoch=$(date -u +%s)

# GC: remove records not updated for over a day. The xbar 5-second loop cleans
# up sessions whose SessionEnd never ran, preventing an ever-growing menu.
# updated_at is ISO 8601 UTC, so comparing strings against cutoff is sufficient.
# Acquire the lock only when stale records exist, minimizing contention with
# the hook, which writes frequently.
cutoff_iso=$(date -u -r $(( now_epoch - 86400 )) +%Y-%m-%dT%H:%M:%SZ)
if jq -e --arg cutoff "$cutoff_iso" 'select((.updated_at // "") < $cutoff)' "$SESSIONS_FILE" >/dev/null 2>&1; then
  lock_dir="$SESSIONS_FILE.lock"
  attempts=0
  while ! mkdir "$lock_dir" 2>/dev/null; do
    attempts=$((attempts + 1))
    if (( attempts > 50 )); then
      rm -rf "$lock_dir" 2>/dev/null
      attempts=0
    fi
    sleep 0.02
  done
  tmp_file="$SESSIONS_FILE.tmp"
  if jq -c --arg cutoff "$cutoff_iso" 'select((.updated_at // "") >= $cutoff)' "$SESSIONS_FILE" > "$tmp_file" 2>/dev/null; then
    mv "$tmp_file" "$SESSIONS_FILE"
  else
    rm -f "$tmp_file"
  fi
  rm -rf "$lock_dir" 2>/dev/null
fi

counts=$(jq -s '
  group_by(.status) | map({key:.[0].status, value:length}) | from_entries
' "$SESSIONS_FILE" 2>/dev/null)

if [[ -z "$counts" || "$counts" == "null" ]]; then
  print -- "⏸ 0"
  print -- "---"
  print -- "(jsonl 解析失敗) | color=red"
  print -- "Refresh | refresh=true"
  exit 0
fi

n_running=$(print -r -- "$counts" | jq -r '.running // 0')
n_awaiting=$(print -r -- "$counts" | jq -r '.awaiting // 0')
n_idle=$(print -r -- "$counts" | jq -r '.idle // 0')
n_total=$(( n_running + n_awaiting + n_idle ))

if (( n_total == 0 )); then
  print -- "⏸ 0"
else
  bar=""
  (( n_running  > 0 )) && bar+="⚡${n_running} "
  (( n_awaiting > 0 )) && bar+="🔔${n_awaiting} "
  (( n_idle     > 0 )) && bar+="⏸${n_idle} "
  print -- "${bar% }"
fi
print -- "---"

print -- "Sessions: ${n_total}  (⚡${n_running} 🔔${n_awaiting} ⏸${n_idle}) | size=11 color=gray"
print -- "---"

if (( n_total == 0 )); then
  print -- "アクティブなセッションはありません | color=gray"
  print -- "---"
fi

# Format elapsed time as a short "Ns / Nm / Nh / Nd ago" string
fmt_elapsed() {
  local ts="$1"
  local sec
  sec=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null) || { print -- "?"; return }
  local diff=$(( now_epoch - sec ))
  (( diff < 0 )) && diff=0
  if   (( diff < 60 ));    then print -- "${diff}s"
  elif (( diff < 3600 ));  then print -- "$(( diff / 60 ))m"
  elif (( diff < 86400 )); then print -- "$(( diff / 3600 ))h"
  else                          print -- "$(( diff / 86400 ))d"
  fi
}

# Format all records together in jq, then read one record per line.
# Field: rank | status | session_id | cwd | git_branch | model | last_prompt | in_tokens | out_tokens | cache_read | updated_at | transcript_path | term_program | cmux_panel_id | cmux_workspace_id
# Replace newlines/tabs in last_prompt with spaces to preserve rows; xbar wraps the display.
#
# Use ASCII Unit Separator (\x1f) as the delimiter. With tabs, zsh read collapses
# consecutive delimiters via IFS_WHITE, shifting fields after an empty value
# such as git_branch="". A non-whitespace IFS preserves empty fields.
SEP=$'\x1f'
records=$(jq -r '
  def rank: if .status=="running" then 0 elif .status=="awaiting" then 1 elif .status=="idle" then 2 else 3 end;
  [(rank|tostring),
   (.status // ""),
   (.session_id // ""),
   (.cwd // ""),
   (.git_branch // ""),
   (.model // ""),
   ((.last_prompt // "") | gsub("[\\t\\n\\r]"; " ")),
   ((.input_tokens // 0)|tostring),
   ((.output_tokens // 0)|tostring),
   ((.cache_read_input_tokens // 0)|tostring),
   (.updated_at // ""),
   (.transcript_path // ""),
   (.term_program // ""),
   (.cmux_panel_id // ""),
   (.cmux_workspace_id // "")
  ] | join("")
' "$SESSIONS_FILE" 2>/dev/null | sort -t"$SEP" -k1,1n -k11,11r)  # k11 = updated_at

# Map TERM_PROGRAM to macOS bundle IDs (use bundle IDs to avoid spaces).
bundle_for_term() {
  case "$1" in
    iTerm.app)      print -- "com.googlecode.iterm2" ;;
    Apple_Terminal) print -- "com.apple.Terminal" ;;
    vscode)         print -- "com.microsoft.VSCode" ;;
    cursor)         print -- "com.todesktop.230313mzl4w4u92" ;;
    ghostty)        print -- "com.mitchellh.ghostty" ;;
    WezTerm)        print -- "com.github.wez.wezterm" ;;
    *) ;;
  esac
}

print -r -- "$records" | while IFS="$SEP" read -r rank s_status session_id cwd branch model prompt in_tokens out_tokens cache_read updated_at transcript term_program cmux_panel_id cmux_workspace_id; do
  [[ -z "$s_status" ]] && continue

  # xbar menu items use `text | k=v ...`, so pipes in prompts would conflict
  # with parameters. Replace them once here.
  prompt="${prompt//|/ }"

  # Status emoji (use s_status to avoid the zsh reserved variable $status)
  case "$s_status" in
    running)  icon="⚡" ;;
    awaiting) icon="🔔" ;;
    idle)     icon="⏸" ;;
    *)        icon="•" ;;
  esac

  short_cwd="${cwd##*/}"
  [[ -z "$short_cwd" ]] && short_cwd="?"
  id8="${session_id:0:8}"

  elapsed=$(fmt_elapsed "$updated_at")

  # Main click: focus a cmux pane if available; otherwise foreground the TERM_PROGRAM app.
  # If neither is known, fall back to opening cwd in Finder.
  if [[ -n "$cmux_panel_id" ]]; then
    click_action="bash=${HANDLER} param1=cmux param2=${cmux_panel_id}"
    [[ -n "$cmux_workspace_id" ]] && click_action+=" param3=${cmux_workspace_id}"
    click_action+=" terminal=false"
    launcher_label="cmux"
  else
    bundle_id=$(bundle_for_term "$term_program")
    if [[ -n "$bundle_id" ]]; then
      click_action="bash=${HANDLER} param1=bundle param2=${bundle_id} terminal=false"
      launcher_label="$term_program"
    else
      click_action="bash=${HANDLER} param1=finder param2='${cwd}' terminal=false"
      launcher_label=""
    fi
  fi

  # First line: icon + [id8] + shortened prompt + elapsed time. Keep it short;
  # the submenu wraps and displays the complete prompt.
  if [[ -n "$prompt" ]]; then
    short_prompt="${prompt:0:40}"
    [[ ${#prompt} -gt 40 ]] && short_prompt+="…"
    label="${short_prompt}"
  else
    label="${short_cwd}"
  fi
  print -- "${icon} [${id8}] ${label} · ${elapsed} ago | ${click_action}"

  # Submenu (-- prefix)
  print -- "-- session: ${session_id} | size=11 color=gray"
  print -- "-- cwd: ${short_cwd} | size=11"
  [[ -n "$launcher_label" ]] && print -- "-- launcher: ${launcher_label} | size=11"
  [[ -n "$branch" ]] && print -- "-- branch: ${branch} | size=11"
  [[ -n "$model" ]]  && print -- "-- model:  ${model} | size=11"

  if [[ -n "$prompt" ]]; then
    print -- "-- 💬 last prompt: | size=11 color=gray"
    remaining="$prompt"
    while [[ -n "$remaining" ]]; do
      print -- "-- ${remaining:0:80} | size=11"
      remaining="${remaining:80}"
    done
  fi

  if [[ "$in_tokens" != "0" || "$out_tokens" != "0" ]]; then
    print -- "-- tokens: in ${in_tokens} / out ${out_tokens} / cache ${cache_read} | size=11 color=gray"
  fi

  print -- "-- updated: ${updated_at} | size=11 color=gray"

  if [[ -n "$transcript" ]]; then
    print -- "-- Open transcript | bash=${HANDLER} param1=finder param2='${transcript}' terminal=false"
  fi
  print -- "-- Open cwd in Finder | bash=${HANDLER} param1=finder param2='${cwd}' terminal=false"
  # Manually clean up sessions whose SessionEnd hook never ran after a hang or crash.
  # refresh=true rebuilds the menu and removes the entry immediately.
  print -- "-- 🗑 Delete from list | bash=${HANDLER} param1=delete param2=${session_id} terminal=false refresh=true color=red"
done

print -- "---"
print -- "Refresh | refresh=true"
print -- "Open data dir | bash=open param1=${DATA_DIR} terminal=false"
