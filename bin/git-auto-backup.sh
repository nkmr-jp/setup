#!/bin/bash
# git-auto-backup: 任意の git リポジトリを無人で pull --rebase → add → commit → push する汎用バックアップ。
# launchd から定期起動して使う想定（issues / vault などで共用）。
#
# Usage:
#   git-auto-backup.sh <repo-path> [--llm]
#     <repo-path>  バックアップ対象リポジトリの絶対パス
#     --llm        コミットメッセージをローカル Ollama で生成（失敗時は auto:<日時> に降格）
#
# Env override:
#   BACKUP_BRANCH        対象ブランチ（既定: main）
#   BACKUP_LLM_MODEL     生成モデル（既定: qwen3.5:9b）
#   BACKUP_LLM_TIMEOUT   生成タイムアウト秒（既定: 45）
set -u

REPO="${1:?usage: git-auto-backup.sh <repo-path> [--llm]}"
shift

USE_LLM=0
for arg in "$@"; do
  [ "$arg" = "--llm" ] && USE_LLM=1
done

BRANCH="${BACKUP_BRANCH:-main}"
MODEL="${BACKUP_LLM_MODEL:-qwen3.5:9b}"   # コミットメッセージ生成に使うローカルモデル
GEN_TIMEOUT="${BACKUP_LLM_TIMEOUT:-45}"   # LLM 生成のタイムアウト（秒）
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

cd "$REPO" || { echo "$LOG_PREFIX ERROR: cannot cd to $REPO"; exit 1; }

# --- ステージ済み差分から LLM でコミットメッセージを生成（失敗時は何も出力しない） ---
# Ollama の HTTP API を使う（ollama run の端末制御コード混入を避け、think:false を確実に渡すため）。
gen_commit_msg() {
  command -v curl >/dev/null 2>&1 || return 1
  command -v jq   >/dev/null 2>&1 || return 1

  local stat diff prompt payload resp msg
  stat="$(git diff --cached --stat)"
  diff="$(git diff --cached | head -c 6000)"   # 巨大差分対策に切り詰め

  prompt="You are writing a git commit message.
Output ONE concise line in English, imperative mood (e.g. 'Add ...', 'Fix ...'),
max 72 chars, no quotes, no code fences, no explanation.

Files changed:
${stat}

Diff (truncated):
${diff}"

  # think:false で推論モードを無効化（有効だと思考に時間を使い切り空応答になる）
  payload="$(jq -n --arg m "$MODEL" --arg p "$prompt" \
    '{model:$m, prompt:$p, stream:false, think:false, options:{temperature:0.2}}')" || return 1

  resp="$(curl -s --max-time "$GEN_TIMEOUT" \
    http://localhost:11434/api/generate -d "$payload" 2>/dev/null)" || return 1

  msg="$(printf '%s' "$resp" \
        | jq -r '.response // empty' 2>/dev/null \
        | grep -v '^[[:space:]]*$' \
        | head -n1 \
        | sed 's/^[[:space:]"'\''`]*//; s/[[:space:]"'\''`]*$//')"

  # 妥当性チェック（空でない・暴走していない）を満たした時だけ出力
  [ -n "$msg" ] && [ "${#msg}" -le 100 ] && printf '%s' "$msg"
}

git add -A

if git diff --cached --quiet; then
  echo "$LOG_PREFIX no local changes"
else
  MSG=""
  [ "$USE_LLM" = 1 ] && MSG="$(gen_commit_msg)"
  if [ -z "$MSG" ]; then
    MSG="auto: $(date '+%Y-%m-%d %H:%M:%S %z')"   # LLM 未使用 or 失敗時はフォールバック
    [ "$USE_LLM" = 1 ] && echo "$LOG_PREFIX LLM unavailable, fallback message"
  fi
  git commit -m "$MSG" -q
  echo "$LOG_PREFIX committed: $MSG"
fi

git pull --rebase --autostash origin "$BRANCH" 2>&1 | sed "s/^/$LOG_PREFIX /"

git push origin "$BRANCH" 2>&1 | sed "s/^/$LOG_PREFIX /"
