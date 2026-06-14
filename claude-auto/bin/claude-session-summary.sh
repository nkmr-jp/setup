#!/bin/bash
# claude-session-summary: Claude Code セッションログ（~/.claude/projects）を集計し、
#                         分離 Claude で日次サマリを生成して Markdown 出力する。
#
# 二層構成（研究レポート 4 章）:
#   1) 集計層（非LLM）   : 当日のセッション数・プロジェクト数などを軽量集計（ここは常時動く）
#   2) 要約層（分離Claude）: 集計結果を分離 Claude に渡し自然言語サマリを生成（トークン必須）
#
# ⚠️ Step 2/3 の骨組み。集計層は実装済み。要約層は keychain トークン登録後（Step 0 後）に有効化される。
#    本格運用は Agent SDK クレジット開始（2026-06-15）以降を推奨。
#
# 分離必須: 自己汚染回避のため要約は必ず CLAUDE_CONFIG_DIR=~/.claude-auto で実行する
#           （読むのは ~/.claude/projects、書くのは ~/.claude-auto / 出力先）。common.sh が担保。
set -u

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

PROJECTS_DIR="${CLAUDE_AUTO_PROJECTS_DIR:-$HOME/.claude/projects}"
OUT_DIR="${CLAUDE_AUTO_DIGEST_DIR:-$HOME/ghq/github.com/nkmr-jp/issues/reports/digest}"
MODEL="${CLAUDE_AUTO_SUMMARY_MODEL:-claude-haiku-4-5-20251001}"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

[[ -d "$PROJECTS_DIR" ]] || { echo "$LOG_PREFIX ERROR: no projects dir: $PROJECTS_DIR" >&2; exit 1; }

DAY="$(date '+%Y-%m-%d')"
DAY_FILE="$(date '+%y%m%d')"

# --- 1) 集計層（非LLM）---------------------------------------------------------
# 当日更新された .jsonl（=その日に動いたセッション）を対象に軽量集計する。
# 重い分析（トークン/コスト等）は既存スキル duckdb-jsonl-analyzer に委譲する余地を残す（TODO）。
TODAY_SESSIONS="$(find "$PROJECTS_DIR" -name '*.jsonl' -type f -mtime -1 2>/dev/null)"
SESSION_COUNT="$(printf '%s\n' "$TODAY_SESSIONS" | grep -c . || true)"
PROJECT_COUNT="$(printf '%s\n' "$TODAY_SESSIONS" | sed 's#/[^/]*$##' | sort -u | grep -c . || true)"

STATS="$(cat <<EOF
- 日付: $DAY
- 当日アクティブなセッション数: $SESSION_COUNT
- 当日触れたプロジェクト数: $PROJECT_COUNT
EOF
)"

mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/${DAY_FILE}-claude-digest.md"

# --- 2) 要約層（分離 Claude / トークン必須）------------------------------------
SUMMARY=""
if [[ "$SESSION_COUNT" -gt 0 ]]; then
  # 集計対象セッションの先頭プロンプト等を抜粋（長文対策: 量を絞ってから渡す）
  EXCERPT="$(printf '%s\n' "$TODAY_SESSIONS" | head -n 50 | while read -r f; do
    [[ -z "$f" ]] && continue
    # 各セッションの最初の user プロンプトらしき行を1つ抜く（軽量・jq 無しでも動くよう grep ベース）
    grep -m1 '"role":"user"' "$f" 2>/dev/null | head -c 300
    echo
  done)"

  read -r -d '' PROMPT <<EOF || true
あなたは Claude Code の1日のセッション活動を要約するアシスタントです。
以下の集計値と各セッションの抜粋をもとに、日本語で簡潔な日次サマリ（箇条書き5行以内）を出力してください。
何に取り組んだか・主要トピック・気づきに絞り、冗長な前置きは書かないこと。

<stats>
$STATS
</stats>

<excerpts>
$EXCERPT
</excerpts>
EOF

  SUMMARY="$(printf '%s' "$PROMPT" \
              | ca_run_claude -p --model "$MODEL" --max-turns 1 --allowedTools "Read" 2>/dev/null || true)"
fi

# --- 出力 ---------------------------------------------------------------------
{
  echo "# Claude セッション日次ダイジェスト — $DAY"
  echo
  echo "## 集計"
  echo
  echo "$STATS"
  echo
  echo "## 要約"
  echo
  if [[ -n "$SUMMARY" ]]; then
    echo "$SUMMARY"
  else
    echo "_（分離 Claude による要約は未生成: keychain トークン未登録、または当日セッション無し。Step 0 完了後に有効化されます。）_"
  fi
} > "$OUT_FILE"

echo "$LOG_PREFIX wrote: $OUT_FILE (sessions=$SESSION_COUNT projects=$PROJECT_COUNT, summary=$([[ -n "$SUMMARY" ]] && echo yes || echo no))"
