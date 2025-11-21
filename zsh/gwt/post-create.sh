#!/bin/bash
# gwt post-create hook
# worktree 作成後に自動的に実行されるスクリプト
#
# 利用可能な環境変数:
#   GWT_WORKTREE_PATH   作成されたworktreeのパス
#   GWT_BRANCH_NAME     ブランチ名
#   GWT_BASE_BRANCH     ベースブランチ名
#   GWT_BASE_PATH       ベースリポジトリ（メインworktree）のパス

# 例: 依存関係のインストール
# if [[ -f "package.json" ]]; then
#     npm install
# fi

# 例: 仮想環境の作成
# if [[ -f "requirements.txt" ]]; then
#     python -m venv .venv
#     source .venv/bin/activate
#     pip install -r requirements.txt
# fi

# .cclinear.yml をベースパスからコピー
if [[ -n "$GWT_BASE_PATH" && -f "${GWT_BASE_PATH}/.cclinear.yml" ]]; then
    cp "${GWT_BASE_PATH}/.cclinear.yml" "${GWT_WORKTREE_PATH}/.cclinear.yml"
    echo "Copied .cclinear.yml from base repository"
fi

echo "Worktree created: $GWT_BRANCH_NAME"
