#!/bin/bash
# common.sh — claude-auto 共有ライブラリ
#
# 分離 Claude（CLAUDE_CONFIG_DIR=~/.claude-auto）を keychain 保管のサブスク長期トークンで
# 起動する定型を 1 箇所に集約する。機能A（コミットメッセージ）/ 機能B（要約）が共有する。
#
# #8473 回避: トークンはグローバル env / plist には絶対に置かず、対象の claude プロセスにだけ
# インライン注入する。ログインシェル・対話セッションには存在しないので通常の Claude を壊さない。
#
# このファイルは source 専用（直接実行しない）。

# 既定値（呼び出し側 env で上書き可）
: "${CLAUDE_AUTO_CONFIG_DIR:=$HOME/.claude-auto}"
: "${CLAUDE_AUTO_KEYCHAIN_SERVICE:=claude-auto-oauth}"

# claude バイナリの実体を解決する。
# launchd の PATH には ~/.local/bin が含まれないため、PATH 解決に失敗しても既知の場所を探す。
# 環境変数 CLAUDE_BIN で明示指定も可。
ca_claude_bin() {
  if [[ -n "${CLAUDE_BIN:-}" && -x "${CLAUDE_BIN}" ]]; then
    printf '%s\n' "$CLAUDE_BIN"
    return 0
  fi
  local c
  if c="$(command -v claude 2>/dev/null)" && [[ -n "$c" ]]; then
    printf '%s\n' "$c"
    return 0
  fi
  for c in "$HOME/.local/bin/claude" /opt/homebrew/bin/claude /usr/local/bin/claude; do
    [[ -x "$c" ]] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}

# keychain から setup-token のトークンを取得する。
# 取得できれば stdout にトークンを出して 0、無ければ何も出さず非ゼロ。
ca_get_token() {
  security find-generic-password -s "$CLAUDE_AUTO_KEYCHAIN_SERVICE" -w 2>/dev/null
}

# 分離 Claude を headless 実行する。
#   - 標準入力: プロンプト本文（呼び出し側が pipe する）
#   - 引数:     追加フラグ（例: -p --model ... --max-turns 1）
# トークン or バイナリが無ければ非ゼロで即終了する（呼び出し側がフォールバックする前提）。
ca_run_claude() {
  local bin tok
  bin="$(ca_claude_bin)" || return 127
  tok="$(ca_get_token)" || return 1
  [[ -z "$tok" ]] && return 1
  CLAUDE_CODE_OAUTH_TOKEN="$tok" \
  CLAUDE_CONFIG_DIR="$CLAUDE_AUTO_CONFIG_DIR" \
    "$bin" "$@"
}
