#!/usr/bin/env bash
# Generate includeIf entries to enable commit signing only for public repositories.
#
# The global default (~/.gitconfig) disables signing because 1Password's
# op-ssh-sign requests biometric authentication and blocks unattended commits.
# List public GitHub repositories with includeIf to re-enable signing for them.
#
# Usage: bin/gen-git-signing-config.sh [owner]
# Default owner: the authenticated gh user.
# Output: ~/.gitconfig-signing-includes (already included by ~/.gitconfig).
# Run again after creating a public repository or changing repository visibility.
set -euo pipefail

OWNER="${1:-}"
OUT="$HOME/.gitconfig-signing-includes"
GHQ_ROOT="${GHQ_ROOT:-$HOME/ghq}"
# Resolve symlinked ~/bin entry points to this checkout, without a fixed repo path.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
    script_dir=$(CDPATH='' cd -- "$(dirname -- "$script_path")" && pwd -P)
    script_path=$(readlink "$script_path")
    [[ "$script_path" = /* ]] || script_path="$script_dir/$script_path"
done
setup_dir=$(CDPATH='' cd -- "$(dirname -- "$script_path")/.." && pwd -P)
SIGNING_CONF="$setup_dir/gitconfig-signing"
# Quote Git configuration values, including checkouts with spaces or quotes.
SIGNING_CONF=${SIGNING_CONF//\\/\\\\}
SIGNING_CONF=${SIGNING_CONF//\"/\\\"}

command -v gh >/dev/null || { echo "gh コマンドが必要です" >&2; exit 1; }
[ -n "$OWNER" ] || OWNER=$(gh api user --jq .login)
[[ "$OWNER" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]] || { echo "invalid GitHub owner" >&2; exit 2; }

# Include public repositories that have not been cloned yet, so signing
# is enabled automatically when they are cloned later.
repos=$(gh repo list "$OWNER" --limit 1000 --visibility public \
    --json name --jq '.[].name' | sort)

[ -n "$repos" ] || { echo "public リポジトリが取得できませんでした" >&2; exit 1; }

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

{
    echo "# Generated file - do not edit directly."
    echo "# Source: ~/ghq/github.com/nkmr-jp/setup/bin/gen-git-signing-config.sh ($OWNER / $(date '+%Y-%m-%d'))"
    echo "#"
    echo "# Enable signing only for public repositories; the default is unsigned."
    echo "# Worktrees (<repo>-wt-<branch>) also use a GIT_DIR inside the main .git,"
    echo "# so they match these gitdir conditions."
    echo
    while IFS= read -r name; do
        printf '[includeIf "gitdir:%s/github.com/%s/%s/"]\n' \
            "${GHQ_ROOT/#$HOME/\~}" "$OWNER" "$name"
        printf '    path = "%s"\n' "$SIGNING_CONF"
    done <<<"$repos"
} >"$tmp"

mv "$tmp" "$OUT"
trap - EXIT

echo "生成しました: $OUT （public $(wc -l <<<"$repos" | tr -d ' ') 件）"
