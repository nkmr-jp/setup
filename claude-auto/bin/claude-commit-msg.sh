#!/bin/bash
# claude-commit-msg: ステージ済み差分から英語1行のコミットメッセージを生成する（分離 Claude / Haiku）。
#
# 入力: 第1引数=リポジトリパス（省略時は CWD）。対象は「ステージ済み」の差分。
# 出力: 成功時はメッセージを stdout に1行出力して exit 0。
#       失敗（トークン未設定 / 生成失敗 / 空 / バイナリ無し / ステージ無し）時は
#       何も出力せず非ゼロ。→ 呼び出し側（git-auto-backup.sh）が auto:<日時> に降格する。
#
# 設計方針: 無人ジョブのためフォールバック最優先。ここでは決してコミットしない（メッセージ生成のみ）。
set -u

# 自身の実体ディレクトリを解決（~/bin の symlink 経由でも lib/common.sh を見つける）
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

REPO="${1:-$PWD}"
MODEL="${CLAUDE_AUTO_COMMIT_MODEL:-claude-haiku-4-5-20251001}"
MAX_DIFF_CHARS="${CLAUDE_AUTO_COMMIT_MAX_DIFF:-6000}"

cd "$REPO" 2>/dev/null || exit 1

# ステージ済み差分が無ければ何もしない
git diff --cached --quiet 2>/dev/null && exit 1

STAT="$(git diff --cached --stat 2>/dev/null)"
DIFF="$(git diff --cached 2>/dev/null | head -c "$MAX_DIFF_CHARS")"
[[ -z "$DIFF" ]] && exit 1

read -r -d '' PROMPT <<EOF || true
You are generating a git commit message. Read the staged diff below and output EXACTLY ONE
concise commit message line in English, imperative mood, Conventional Commits style
(e.g. "fix: ...", "feat: ...", "docs: ..."). Output ONLY that single line — no quotes,
no code fences, no body, no explanation.

<stat>
$STAT
</stat>

<diff>
$DIFF
</diff>
EOF

MSG="$(printf '%s' "$PROMPT" \
        | ca_run_claude -p --model "$MODEL" --max-turns 1 2>/dev/null \
        | head -n 1 \
        | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

[[ -z "$MSG" ]] && exit 1
# 念のため過剰に長い出力は切り詰める（暴走防止）
[[ ${#MSG} -gt 200 ]] && MSG="${MSG:0:200}"
printf '%s\n' "$MSG"
