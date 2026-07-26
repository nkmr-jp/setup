#!/usr/bin/env bash
# 公開リポジトリだけコミット署名を有効にする includeIf 群を生成する。
#
# 背景:
#   グローバル既定はコミット署名なし（~/.gitconfig）。1Password の
#   op-ssh-sign が署名のたびに生体認証を求め、エージェントの無人コミットが
#   そこで止まるため。公開リポジトリは署名を維持したいので、GitHub 上で
#   public なリポジトリのパスだけを includeIf で列挙して署名を有効に戻す。
#
# 使い方:
#   bin/gen-git-signing-config.sh [owner]   # 既定 owner: nkmr-jp
#
# 出力:
#   ~/.gitconfig-signing-includes （~/.gitconfig から include 済み）
#
# 新しく公開リポジトリを作ったら再実行する。
set -euo pipefail

OWNER="${1:-nkmr-jp}"
OUT="$HOME/.gitconfig-signing-includes"
GHQ_ROOT="${GHQ_ROOT:-$HOME/ghq}"
SIGNING_CONF="~/ghq/github.com/nkmr-jp/setup/gitconfig-signing"

command -v gh >/dev/null || { echo "gh コマンドが必要です" >&2; exit 1; }

# ローカルに clone していない public リポジトリも含めて列挙する。
# 後から clone したときに署名が漏れるのを防ぐため。
repos=$(gh repo list "$OWNER" --limit 1000 --visibility public \
    --json name --jq '.[].name' | sort)

[ -n "$repos" ] || { echo "public リポジトリが取得できませんでした" >&2; exit 1; }

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

{
    echo "# 自動生成ファイル — 直接編集しない。"
    echo "# 生成元: setup/bin/gen-git-signing-config.sh ($OWNER / $(date '+%Y-%m-%d'))"
    echo "#"
    echo "# 公開リポジトリのみコミット署名を有効化する（既定は署名なし）。"
    echo "# worktree（<repo>-wt-<branch>）も GIT_DIR が本体の .git 配下を指すため"
    echo "# この gitdir 条件でマッチする。"
    echo
    while IFS= read -r name; do
        printf '[includeIf "gitdir:%s/github.com/%s/%s/"]\n' \
            "${GHQ_ROOT/#$HOME/\~}" "$OWNER" "$name"
        printf '    path = %s\n' "$SIGNING_CONF"
    done <<<"$repos"
} >"$tmp"

mv "$tmp" "$OUT"
trap - EXIT

echo "生成しました: $OUT （public $(wc -l <<<"$repos" | tr -d ' ') 件）"
