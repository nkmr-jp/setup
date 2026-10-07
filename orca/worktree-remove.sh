#!/bin/sh
# Force-remove the current Orca worktree when nothing would be lost.
#
# Run from an Orca quick command inside the worktree. The sidebar delete button
# fails on worktrees with initialized submodules because it omits --force.
#
# --force alone is unsafe: `orca worktree rm` deleted an unmerged branch in
# testing despite its help text, so merge state is checked here.

if [ "$(git rev-parse --path-format=absolute --git-dir)" = "$(git rev-parse --path-format=absolute --git-common-dir)" ]; then
  echo "メインの作業ツリーなので中止しました"
  exit 1
fi
if [ -n "$(git status --porcelain --ignore-submodules=dirty)" ]; then
  echo "未コミットの変更があるため中止しました"
  exit 1
fi
if ! git merge-base --is-ancestor HEAD origin/HEAD 2>/dev/null; then
  echo "origin のデフォルトブランチにマージされていないため中止しました"
  exit 1
fi
exec orca worktree rm --worktree current --force
