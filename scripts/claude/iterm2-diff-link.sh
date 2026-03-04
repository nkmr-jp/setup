#!/usr/bin/env bash
# # iterm2 > Settings > Profiles > Advanced > Smart Selection

dir="$1"

# If second argument exists and starts with wt:, convert to worktrees path
if [[ -n "$2" && "$2" =~ ^wt:(.+)$ ]]; then
  branch="${BASH_REMATCH[1]}"
  dir="${dir}-worktrees/${branch}"
fi

cd "$dir" || exit

# gitの差分があるかチェック
#if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
#    # 差分がある場合はfork statusを実行
#    /usr/local/bin/fork status
#else
#    # 差分がない場合はforkを実行
#    /usr/local/bin/fork
#fi

/opt/homebrew/bin/github