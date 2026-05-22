#!/usr/bin/env zsh
# cmux サイドバーに pane 別の cwd pill を表示する。値はカレントディレクトリの
# basename。アイコンは Claude Code の状態（claude-status-hook.sh が
# ${TMPDIR}/cmux-pane-state/<panel-id> に書き込む）に応じて切り替わる。
#
#   running  -> bolt.fill (#4C8DFF)  UserPromptSubmit / PreToolUse
#   awaiting -> bell.fill (#FF9500)  Notification
#   idle     -> pause.fill (#8E8E93) Stop (応答完了・次の入力待ち)
#   none     -> folder               state file 不在時のデフォルト
#
# precmd は &! で background 化して prompt 遅延を排除する。
# 強制クローズで残った pill は、各 shell が spawn する独立な sweeper が
# 数秒おきに workspace を sweep して回収する。
#
# pill は workspace スコープで管理される (`workspace:<WS_UUID>:tag:cwd_<SURFACE>`)。
# `cmux set-status` を `--workspace` 無しで呼ぶと daemon は CMUX_WORKSPACE_ID
# 環境変数を見るが、cmux 0.61+ ではこれが子プロセスに継承されないため、
# 結果として「現在 focus している workspace」に pill が紛れ込んでしまう。
# それを避けるため、shell 起動時に一度だけ cmux top から自分のいる surface UUID
# と workspace UUID を解決し、以降の `cmux set-status` / `clear-status` 呼び出しは
# 必ず `--workspace $_CMUX_WORKSPACE_ID` を明示指定する。

typeset -g _CMUX_LAST_SIG=""
typeset -g _CMUX_PANEL_ID=""
typeset -g _CMUX_WORKSPACE_ID=""
typeset -gra _CMUX_PILL_PREFIXES=(cwd_ claude_ run_)  # claude_/run_: 旧版 pill の sweep 用

# cmux top を一度だけ呼んで自分の PID から surface_ref / pane_ref / ws_ref を確定し、
# workspace.list / surface.list で UUID に変換する。失敗時は何もしない (default の
# folder アイコンで動かない状態が許容される)。claude-status-hook.sh と同じ TSV walk
# ロジックを zsh で書き直したもの。
_cmux_resolve_ids() {
  (( ${+commands[cmux]} )) || return 1
  [[ "${TERM_PROGRAM:-}" == ghostty ]] || return 1
  [[ "${__CFBundleIdentifier:-}" == com.cmuxterm.app ]] || return 1
  (( ${+commands[jq]} )) || return 1

  local cmux_cli="${CMUX_BUNDLED_CLI_PATH:-/Applications/cmux.app/Contents/Resources/bin/cmux}"
  [[ -x "$cmux_cli" ]] || cmux_cli="${commands[cmux]}"
  [[ -x "$cmux_cli" ]] || return 1

  local top_tsv
  top_tsv=$("$cmux_cli" top --all --processes --format tsv 2>/dev/null) || return 1
  [[ -n "$top_tsv" ]] || return 1

  local surface_ref="" probe_pid=$$ probe_attempts=0 next_pid
  while [[ -n "$probe_pid" && "$probe_pid" != 0 && "$probe_pid" != 1 \
        && "$probe_attempts" -lt 20 ]]; do
    surface_ref=$(/usr/bin/awk -F'\t' -v pid="$probe_pid" '
      $4 == "process" && $5 == pid && $6 ~ /^surface:/ { print $6; exit }' <<<"$top_tsv")
    [[ -n "$surface_ref" ]] && break
    next_pid=$(ps -o ppid= -p "$probe_pid" 2>/dev/null | tr -d ' ')
    [[ -z "$next_pid" || "$next_pid" == "$probe_pid" ]] && break
    probe_pid="$next_pid"
    (( probe_attempts++ ))
  done
  [[ -n "$surface_ref" ]] || return 1

  local pane_ref ws_ref
  pane_ref=$(/usr/bin/awk -F'\t' -v sref="$surface_ref" '
    $4 == "surface" && $5 == sref && $6 ~ /^pane:/ { print $6; exit }' <<<"$top_tsv")
  [[ -n "$pane_ref" ]] || return 1
  ws_ref=$(/usr/bin/awk -F'\t' -v pref="$pane_ref" '
    $4 == "pane" && $5 == pref && $6 ~ /^workspace:/ { print $6; exit }' <<<"$top_tsv")
  [[ -n "$ws_ref" ]] || return 1

  local ws_id
  ws_id=$("$cmux_cli" rpc workspace.list "{}" 2>/dev/null \
    | jq -r --arg ref "$ws_ref" \
      '.workspaces[]? | select(.ref == $ref) | .id // empty' 2>/dev/null \
    | head -n 1)
  [[ -n "$ws_id" ]] || return 1

  local panel_id
  panel_id=$("$cmux_cli" rpc surface.list "{\"workspace_id\":\"$ws_id\"}" 2>/dev/null \
    | jq -r --arg ref "$surface_ref" \
      '.surfaces[]? | select(.ref == $ref) | .id // empty' 2>/dev/null \
    | head -n 1)
  [[ -n "$panel_id" ]] || return 1

  _CMUX_PANEL_ID="$panel_id"
  _CMUX_WORKSPACE_ID="$ws_id"
  return 0
}

_cmux_update_cwd_status() {
  (( ${+commands[cmux]} )) || return 0
  [[ -n "$_CMUX_PANEL_ID" && -n "$_CMUX_WORKSPACE_ID" ]] || return 0
  local sf="${TMPDIR:-/tmp}/cmux-pane-state/${_CMUX_PANEL_ID}"
  local state="" icon=folder color=""
  [[ -r "$sf" ]] && read -r state < "$sf"
  case "$state" in
    running)  icon=bolt.fill;  color='#4C8DFF' ;;
    awaiting) icon=bell.fill;  color='#FF9500' ;;
    idle)     icon=pause.fill; color='#8E8E93' ;;
  esac
  local sig="${PWD}|${state}"
  [[ "$sig" == "$_CMUX_LAST_SIG" ]] && return
  _CMUX_LAST_SIG="$sig"
  local -a args=("cwd_${_CMUX_PANEL_ID}" "${PWD:t}"
    --workspace "$_CMUX_WORKSPACE_ID" --icon "$icon")
  [[ -n "$color" ]] && args+=(--color "$color")
  cmux set-status "${args[@]}" >/dev/null 2>&1 &!
}

_cmux_clear_pane_status() {
  # zshexit から呼ばれるので同期実行。&! だと shell 終了時に reap されない。
  (( ${+commands[cmux]} )) || return 0
  [[ -n "$_CMUX_PANEL_ID" && -n "$_CMUX_WORKSPACE_ID" ]] || return 0
  local p
  for p in "${_CMUX_PILL_PREFIXES[@]}"; do
    cmux clear-status "${p}${_CMUX_PANEL_ID}" \
      --workspace "$_CMUX_WORKSPACE_ID" >/dev/null 2>&1
  done
  local sd="${TMPDIR:-/tmp}/cmux-pane-state"
  rm -rf "${sd}/${_CMUX_PANEL_ID}" "${sd}/${_CMUX_PANEL_ID}.time" \
    "${sd}/${_CMUX_PANEL_ID}.lock" 2>/dev/null
}

_cmux_spawn_gc_sweeper() {
  (( ${+commands[cmux]} )) || return 0
  [[ -n "$_CMUX_WORKSPACE_ID" ]] || return 0
  if [[ -n "${_CMUX_GC_SWEEPER_PID:-}" ]] \
       && kill -0 "$_CMUX_GC_SWEEPER_PID" 2>/dev/null; then
    return 0
  fi

  local shell_pid=$$
  local socket_path="${CMUX_SOCKET_PATH:-}"
  local cmux_bin="${commands[cmux]}"
  local interval="${CMUX_CWD_SWEEP_INTERVAL:-3}"
  local my_ws="$_CMUX_WORKSPACE_ID"
  local -a prefixes=("${_CMUX_PILL_PREFIXES[@]}")

  # HUP/INT/TERM を ignore して pane close を生き延びるための独立 process。
  # sweeper は「自分の workspace に紐づく pill」だけを掃除する。全 workspace 横断で
  # sweep すると、別 shell が管理している別 workspace の pill を誤って削除してしまう。
  {
    trap '' HUP INT TERM PIPE QUIT
    exec </dev/null >/dev/null 2>&1
    while kill -0 "$shell_pid" 2>/dev/null; do
      [[ -z "$socket_path" || -S "$socket_path" ]] || break

      local -a pane_keys=() pane_uuids=()
      local line k p
      while IFS= read -r line; do
        k="${line%%=*}"
        for p in "${prefixes[@]}"; do
          [[ "$k" == ${p}* ]] && {
            pane_keys+=("$k"); pane_uuids+=("${k#$p}"); break
          }
        done
      done < <("$cmux_bin" list-status --workspace "$my_ws" 2>/dev/null)
      (( ${#pane_keys} == 0 )) && { sleep "$interval"; continue }

      # 自分の workspace に居る surface のみ取得 (cmux 単一 workspace の surface.list)。
      local sjson active_ids=$'\n'
      sjson="$("$cmux_bin" rpc surface.list \
        "{\"workspace_id\":\"$my_ws\"}" 2>/dev/null)"
      [[ -z "$sjson" ]] && { sleep "$interval"; continue }
      active_ids+="$(/usr/bin/awk -F'"' '/"id"[[:space:]]*:/{print $4}' \
        <<<"$sjson")"$'\n'

      # workspace 列挙が無に帰した場合は誤って全 pill を消さないよう skip。
      [[ "$active_ids" == $'\n' ]] && { sleep "$interval"; continue }

      local i
      for (( i = 1; i <= ${#pane_keys}; i++ )); do
        [[ "$active_ids" == *$'\n'"${pane_uuids[i]}"$'\n'* ]] && continue
        "$cmux_bin" clear-status "${pane_keys[i]}" \
          --workspace "$my_ws" >/dev/null 2>&1
      done

      sleep "$interval"
    done
  } &!
  _CMUX_GC_SWEEPER_PID=$!
}

# 既存の cmux 環境変数があれば優先 (将来 cmux 側が再び継承するようになった場合や
# 子 shell が親から export を受け継いだ場合のため)。
if [[ -n "${CMUX_PANEL_ID:-}" && -n "${CMUX_WORKSPACE_ID:-}" ]]; then
  _CMUX_PANEL_ID="$CMUX_PANEL_ID"
  _CMUX_WORKSPACE_ID="$CMUX_WORKSPACE_ID"
fi

# 非対話 zsh (Bash ツールから起動された zsh -c, スクリプト実行など) では何も登録しない。
# 特に zshexit でサブシェル終了の度に pane の pill / state file を消してしまうのを防ぐ。
# 強制クローズで残った pill は sweeper が数秒おきに回収するので副作用はない。
if [[ -n "${ZSH_VERSION:-}" ]] && [[ -o interactive ]]; then
  # まず一度だけ cmux top で自分の panel/workspace UUID を解決する。
  [[ -z "$_CMUX_PANEL_ID" || -z "$_CMUX_WORKSPACE_ID" ]] && _cmux_resolve_ids

  # 子プロセス (claude-status-hook.sh など) からも見えるように export しておく。
  if [[ -n "$_CMUX_PANEL_ID" && -n "$_CMUX_WORKSPACE_ID" ]]; then
    export CMUX_PANEL_ID="$_CMUX_PANEL_ID"
    export CMUX_WORKSPACE_ID="$_CMUX_WORKSPACE_ID"
  fi

  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _cmux_update_cwd_status
  add-zsh-hook precmd _cmux_update_cwd_status
  add-zsh-hook zshexit _cmux_clear_pane_status
  # 旧 run_<panel> pill が残っていたら回収する (one-time migration)。
  if [[ -n "$_CMUX_PANEL_ID" && -n "$_CMUX_WORKSPACE_ID" ]] \
     && (( ${+commands[cmux]} )); then
    cmux clear-status "run_${_CMUX_PANEL_ID}" \
      --workspace "$_CMUX_WORKSPACE_ID" >/dev/null 2>&1 &!
  fi
  _cmux_update_cwd_status
  _cmux_spawn_gc_sweeper
fi
