#!/usr/bin/env zsh
# cmux サイドバーに現在ディレクトリの basename を pill として表示する。
# pane ごとにユニークな key を使い、複数 pane でそれぞれの pill を並べる。
#
# pane を強制クローズしても pill が残るケースがあるため、各 shell の precmd で
# workspace 内の cwd_* pill を GC する: 既存 surface に対応しない key を
# clear-status で消す。focus が当たっていれば必ず precmd が走るので、
# どの pane を開いても自動的にサイドバーが最新状態に追従する。

_cmux_status_key() {
  print -r -- "cwd_${CMUX_PANEL_ID:-default}"
}

_cmux_update_cwd_status() {
  (( ${+commands[cmux]} )) || return 0
  cmux set-status "$(_cmux_status_key)" "${PWD:t}" --icon folder >/dev/null 2>&1
}

_cmux_clear_cwd_status() {
  (( ${+commands[cmux]} )) || return 0
  cmux clear-status "$(_cmux_status_key)" >/dev/null 2>&1
}

zmodload -F zsh/datetime b:strftime p:EPOCHSECONDS 2>/dev/null

typeset -g _CMUX_CWD_GC_LAST_RUN=0

_cmux_gc_stale_cwd_pills() {
  (( ${+commands[cmux]} )) || return 0
  [[ -n "${CMUX_WORKSPACE_ID:-}" ]] || return 0

  # precmd ごとに RPC を叩かないよう throttle (3 秒)。初回 (last_run==0) は素通し。
  local now="${EPOCHSECONDS:-$SECONDS}"
  if (( _CMUX_CWD_GC_LAST_RUN > 0 && now - _CMUX_CWD_GC_LAST_RUN < 3 )); then
    return 0
  fi
  _CMUX_CWD_GC_LAST_RUN=${now:-1}

  # 現在の cwd_* な status key を抽出
  local -a cwd_keys=()
  local line
  while IFS= read -r line; do
    [[ "$line" == cwd_* ]] || continue
    cwd_keys+=("${line%%=*}")
  done < <(cmux list-status 2>/dev/null)
  (( ${#cwd_keys} > 0 )) || return 0

  # workspace の生存している surface ID 一覧を取得
  local json
  json="$(cmux rpc surface.list "{\"workspace_id\":\"$CMUX_WORKSPACE_ID\"}" 2>/dev/null)"
  [[ -n "$json" ]] || return 0
  local active_ids=$'\n'
  active_ids+="$(print -r -- "$json" \
    | /usr/bin/grep -oE '"id"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | /usr/bin/awk -F'"' '{print $4}')"$'\n'

  # 既存 surface に紐付かない pill を消す
  local key uuid
  for key in "${cwd_keys[@]}"; do
    uuid="${key#cwd_}"
    [[ "$active_ids" == *$'\n'"$uuid"$'\n'* ]] && continue
    cmux clear-status "$key" >/dev/null 2>&1
  done
}

if [[ -n "${ZSH_VERSION:-}" ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _cmux_update_cwd_status
  add-zsh-hook precmd _cmux_gc_stale_cwd_pills
  # 通常終了 (`exit` / EOF) は即座にクリア。強制クローズ時は他 pane の GC が拾う。
  add-zsh-hook zshexit _cmux_clear_cwd_status
  _cmux_update_cwd_status
fi
