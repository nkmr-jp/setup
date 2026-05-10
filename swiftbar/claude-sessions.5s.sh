#!/usr/bin/env zsh
# <bitbar.title>Claude Sessions</bitbar.title>
# <bitbar.version>v0.1.0</bitbar.version>
# <bitbar.author>nkmr-jp</bitbar.author>
# <bitbar.author.github>nkmr-jp</bitbar.author.github>
# <bitbar.desc>Claude Code の進行中セッションを ⚡running / 🔔awaiting / ⏸idle で集約表示する</bitbar.desc>
# <bitbar.dependencies>jq, Claude Code (session-monitor plugin)</bitbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
#
# session-monitor プラグインの hook が ${CLAUDE_PLUGIN_DATA}/sessions.jsonl を更新する。
# ここでは ~/.claude/session-monitor/data-dir に書かれた anchor からその実パスを解決し、
# jsonl を読んでメニューバー表示を組み立てる。

set -u
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
# SwiftBar 経由で起動されると LANG が空になり、zsh の ${var:0:N} 等が
# バイト単位になって日本語が壊れるので UTF-8 を明示する。
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
  print -- "brew install jq | shell=brew param1=install param2=jq terminal=true"
  exit 0
fi

# jsonl が無い / 空 (0 行) の場合でも、バーにアイコンだけは出して
# 「動いているが空」だと分かるようにする (完全非表示だと故障と区別できない)。
if [[ ! -s "$SESSIONS_FILE" ]]; then
  print -- "⏸ 0"
  print -- "---"
  print -- "セッションデータがありません | color=gray"
  print -- "data dir: ${DATA_DIR} | size=11 color=gray"
  print -- "---"
  print -- "Refresh | refresh=true"
  print -- "Open data dir | shell=open param1=${DATA_DIR} terminal=false"
  exit 0
fi

# ステータス別カウント
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

# メニューバー: 0 件なら淡く、件数があればステータスを並べる
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

# ヘッダ
print -- "Sessions: ${n_total}  (⚡${n_running} 🔔${n_awaiting} ⏸${n_idle}) | size=11 color=gray"
print -- "---"

if (( n_total == 0 )); then
  print -- "アクティブなセッションはありません | color=gray"
  print -- "---"
fi

# ステータス順 (running -> awaiting -> idle) → updated_at 降順 で並べる
status_rank() {
  case "$1" in
    running)  print 0 ;;
    awaiting) print 1 ;;
    idle)     print 2 ;;
    *)        print 3 ;;
  esac
}

now_epoch=$(date -u +%s)

# 経過時間を "Ns / Nm / Nh / Nd ago" の短い文字列に整形
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

# 整形ロジックは jq に集約してまとめて出す。各レコードを 1 行 TSV にして読み込む。
# Field: rank \t status \t session_id \t cwd \t git_branch \t model \t last_prompt \t in_tokens \t out_tokens \t cache_read \t updated_at \t transcript_path \t term_program \t cmux_panel_id \t cmux_workspace_id
# last_prompt 内の改行/タブは TSV を壊すので space に潰す (SwiftBar 表示時に折り返す)。
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
  ] | @tsv
' "$SESSIONS_FILE" 2>/dev/null | sort -t$'\t' -k1,1n -k11,11r)  # k11 = updated_at

# TERM_PROGRAM → macOS bundle ID へのマッピング (空白を避けるため bundle ID を使う)。
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

print -r -- "$records" | while IFS=$'\t' read -r rank s_status session_id cwd branch model prompt in_tokens out_tokens cache_read updated_at transcript term_program cmux_panel_id cmux_workspace_id; do
  [[ -z "$s_status" ]] && continue

  # SwiftBar の menu item は `text | k=v ...` 形式なので、prompt 内の `|` は
  # param と衝突する。一度だけ潰しておく。
  prompt="${prompt//|/ }"

  # ステータス絵文字 (zsh の予約変数 $status と衝突しないよう s_status を使う)
  case "$s_status" in
    running)  icon="⚡" ;;
    awaiting) icon="🔔" ;;
    idle)     icon="⏸" ;;
    *)        icon="•" ;;
  esac

  short_cwd=$(basename -- "$cwd" 2>/dev/null)
  [[ -z "$short_cwd" ]] && short_cwd="?"
  id8="${session_id:0:8}"

  elapsed=$(fmt_elapsed "$updated_at")

  # メインクリック動作: cmux pane があればそこへフォーカス、なければ TERM_PROGRAM のアプリを前面に。
  # どちらも分からなければ Finder で cwd を開く (従来挙動にフォールバック)。
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
      click_action="bash=${HANDLER} param1=finder param2=${cwd} terminal=false"
      launcher_label=""
    fi
  fi

  # 一行目: アイコン + [id8] + 短縮プロンプト + 経過時間。全文はサブメニューに
  # 折り返し表示されるので、ここは短く保つ。
  if [[ -n "$prompt" ]]; then
    short_prompt="${prompt:0:40}"
    [[ ${#prompt} -gt 40 ]] && short_prompt+="…"
    label="${short_prompt}"
  else
    label="${short_cwd}"
  fi
  print -- "${icon} [${id8}] ${label} · ${elapsed} ago | ${click_action}"

  # サブメニュー (-- prefix)
  print -- "-- session: ${session_id} | size=11 color=gray"
  print -- "-- cwd: ${short_cwd} | size=11"
  [[ -n "$launcher_label" ]] && print -- "-- launcher: ${launcher_label} | size=11"
  [[ -n "$branch" ]] && print -- "-- branch: ${branch} | size=11"
  [[ -n "$model" ]]  && print -- "-- model:  ${model} | size=11"

  # 最後のユーザープロンプト全文を 80 文字単位で折り返し表示。
  if [[ -n "$prompt" ]]; then
    print -- "-- 💬 last prompt: | size=11 color=gray"
    remaining="$prompt"
    while [[ -n "$remaining" ]]; do
      print -- "-- ${remaining:0:80} | size=11"
      remaining="${remaining:80}"
    done
  fi

  # トークン: cache_read を含めて表示
  if [[ "$in_tokens" != "0" || "$out_tokens" != "0" ]]; then
    print -- "-- tokens: in ${in_tokens} / out ${out_tokens} / cache ${cache_read} | size=11 color=gray"
  fi

  print -- "-- updated: ${updated_at} | size=11 color=gray"

  if [[ -n "$transcript" ]]; then
    print -- "-- Open transcript | bash=${HANDLER} param1=finder param2=${transcript} terminal=false"
  fi
  print -- "-- Open cwd in Finder | bash=${HANDLER} param1=finder param2=${cwd} terminal=false"
done

print -- "---"
print -- "Refresh | refresh=true"
print -- "Open data dir | shell=open param1=${DATA_DIR} terminal=false"
