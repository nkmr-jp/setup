#!/bin/bash
# git-auto-backup: 指定リポジトリを add -A → commit → pull --rebase → push する汎用バックアップ。
# vault-auto-backup.sh と同型。launchd から無人実行される想定。
#
# 使い方:
#   git-auto-backup.sh <repo-path> [--llm] [--branch <name>] [--remote <name>]
#     --llm           コミットメッセージを分離 Claude で生成（claude-commit-msg.sh / claude-auto）。
#                     生成失敗・トークン未設定時は auto:<日時> に自動降格し、コミットは必ず成功する。
#     --branch <name> push 先ブランチ（既定: 現在のブランチ。取得不能なら main）
#     --remote <name> push 先リモート（既定: origin）
#
# Claude 固有部（--llm）は claude-auto モジュール（ccdash リポジトリ）に分離してある。生成器は
# PATH（`~/bin/claude-commit-msg.sh`）から解決するので、claude-auto の置き場所に依存しない。
# Claude 障害・枠切れが汎用バックアップを壊さない（必ず auto:<日時> 降格でコミット成功）。
set -u

REPO=""
USE_LLM=0
BRANCH=""
REMOTE="origin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --llm)    USE_LLM=1; shift;;
    --branch) BRANCH="${2:-}"; shift 2;;
    --remote) REMOTE="${2:-origin}"; shift 2;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0;;
    -*) echo "unknown option: $1" >&2; exit 2;;
    *)  REPO="$1"; shift;;
  esac
done

[[ -z "$REPO" ]] && { echo "usage: git-auto-backup.sh <repo-path> [--llm] [--branch <name>] [--remote <name>]" >&2; exit 2; }

LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"
cd "$REPO" || { echo "$LOG_PREFIX ERROR: cannot cd to $REPO"; exit 1; }

[[ -z "$BRANCH" ]] && BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo main)"

git add -A

if git diff --cached --quiet; then
  echo "$LOG_PREFIX no local changes"
else
  MSG=""
  if [[ "$USE_LLM" -eq 1 ]]; then
    # claude-auto の生成器を PATH（~/bin の symlink）から解決する。claude-auto モジュールが
    # どのリポジトリに置かれていても疎結合に動く（移設先 ccdash に追従不要）。
    GEN="$(command -v claude-commit-msg.sh 2>/dev/null || true)"
    [[ -z "$GEN" && -x "$HOME/bin/claude-commit-msg.sh" ]] && GEN="$HOME/bin/claude-commit-msg.sh"
    if [[ -n "$GEN" && -x "$GEN" ]]; then
      MSG="$("$GEN" "$REPO" 2>/dev/null || true)"
    fi
  fi
  # フォールバック最優先: 生成できなければ従来形式で必ずコミットする
  [[ -z "$MSG" ]] && MSG="auto: $(date '+%Y-%m-%d %H:%M:%S %z')"
  git commit -m "$MSG" -q
  echo "$LOG_PREFIX committed: $MSG"
fi

git pull --rebase --autostash "$REMOTE" "$BRANCH" 2>&1 | sed "s/^/$LOG_PREFIX /"
git push "$REMOTE" "$BRANCH" 2>&1 | sed "s/^/$LOG_PREFIX /"
