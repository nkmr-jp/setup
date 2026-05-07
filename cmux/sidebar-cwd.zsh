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

typeset -g _CMUX_LAST_SIG=""
typeset -gra _CMUX_PILL_PREFIXES=(cwd_ claude_ run_)  # claude_/run_: 旧版 pill の sweep 用

_cmux_update_cwd_status() {
  (( ${+commands[cmux]} )) || return 0
  local panel="${CMUX_PANEL_ID:-default}"
  local sf="${TMPDIR:-/tmp}/cmux-pane-state/${panel}"
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
  local -a args=("cwd_${panel}" "${PWD:t}" --icon "$icon")
  [[ -n "$color" ]] && args+=(--color "$color")
  cmux set-status "${args[@]}" >/dev/null 2>&1 &!
}

_cmux_clear_pane_status() {
  # zshexit から呼ばれるので同期実行。&! だと shell 終了時に reap されない。
  (( ${+commands[cmux]} )) || return 0
  local panel="${CMUX_PANEL_ID:-default}" p
  for p in "${_CMUX_PILL_PREFIXES[@]}"; do
    cmux clear-status "${p}${panel}" >/dev/null 2>&1
  done
  local sd="${TMPDIR:-/tmp}/cmux-pane-state"
  rm -rf "${sd}/${panel}" "${sd}/${panel}.time" "${sd}/${panel}.lock" 2>/dev/null
}

_cmux_spawn_gc_sweeper() {
  (( ${+commands[cmux]} )) || return 0
  [[ -n "${CMUX_WORKSPACE_ID:-}" ]] || return 0
  if [[ -n "${_CMUX_GC_SWEEPER_PID:-}" ]] \
       && kill -0 "$_CMUX_GC_SWEEPER_PID" 2>/dev/null; then
    return 0
  fi

  local shell_pid=$$
  local socket_path="${CMUX_SOCKET_PATH:-}"
  local cmux_bin="${commands[cmux]}"
  local interval="${CMUX_CWD_SWEEP_INTERVAL:-3}"
  local -a prefixes=("${_CMUX_PILL_PREFIXES[@]}")

  # HUP/INT/TERM を ignore して pane close を生き延びるための独立 process。
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
      done < <("$cmux_bin" list-status 2>/dev/null)
      (( ${#pane_keys} == 0 )) && { sleep "$interval"; continue }

      # surface.list は workspace 単位スコープなので、workspace.list で全 workspace
      # を列挙してから集約する。自分の workspace のみで sweep すると、別 workspace
      # の pill を「消えた pane」と判定して clear-status で消してしまい、
      # サイドバーから basename pill が消える原因になる。
      local ws_json
      ws_json="$("$cmux_bin" rpc workspace.list "{}" 2>/dev/null)"
      [[ -z "$ws_json" ]] && { sleep "$interval"; continue }

      local active_ids=$'\n' ws_id sjson
      while IFS= read -r ws_id; do
        [[ -z "$ws_id" ]] && continue
        sjson="$("$cmux_bin" rpc surface.list \
          "{\"workspace_id\":\"$ws_id\"}" 2>/dev/null)"
        [[ -z "$sjson" ]] && continue
        active_ids+="$(print -r -- "$sjson" \
          | /usr/bin/awk -F'"' '/"id"[[:space:]]*:/{print $4}')"$'\n'
      done < <(print -r -- "$ws_json" \
        | /usr/bin/awk -F'"' '/"id"[[:space:]]*:/{print $4}')

      # workspace 列挙が無に帰した場合は誤って全 pill を消さないよう skip。
      [[ "$active_ids" == $'\n' ]] && { sleep "$interval"; continue }

      local i
      for (( i = 1; i <= ${#pane_keys}; i++ )); do
        [[ "$active_ids" == *$'\n'"${pane_uuids[i]}"$'\n'* ]] && continue
        "$cmux_bin" clear-status "${pane_keys[i]}" >/dev/null 2>&1
      done

      sleep "$interval"
    done
  } &!
  _CMUX_GC_SWEEPER_PID=$!
}

# 非対話 zsh (Bash ツールから起動された zsh -c, スクリプト実行など) では何も登録しない。
# 特に zshexit でサブシェル終了の度に pane の pill / state file を消してしまうのを防ぐ。
# 強制クローズで残った pill は sweeper が数秒おきに回収するので副作用はない。
if [[ -n "${ZSH_VERSION:-}" ]] && [[ -o interactive ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _cmux_update_cwd_status
  add-zsh-hook precmd _cmux_update_cwd_status
  add-zsh-hook zshexit _cmux_clear_pane_status
  # 旧 run_<panel> pill が残っていたら回収する (one-time migration)。
  (( ${+commands[cmux]} )) \
    && cmux clear-status "run_${CMUX_PANEL_ID:-default}" >/dev/null 2>&1 &!
  _cmux_update_cwd_status
  _cmux_spawn_gc_sweeper
fi
