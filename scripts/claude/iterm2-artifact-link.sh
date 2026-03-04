#!/usr/bin/env bash
# iterm2 > Settings > Profiles > Advanced > Smart Selection

set -euo pipefail

# 引数チェック
if [ $# -lt 1 ]; then
  echo "Error: No argument provided" >&2
  exit 1
fi

INPUT_ARG="$1"

# スクリプトのディレクトリを取得

# artifact repositoryパスを取得
REPOSITORY_PATH="$HOME/ghq/github.com/nkmr-jp/cclinear-artifact"

if [ -z "$REPOSITORY_PATH" ]; then
  echo "Error: Could not get artifact.repository from .cclinear.yml" >&2
  exit 1
fi

# 引数の形式を判定
if [[ "$INPUT_ARG" == *_* ]]; then
  # {IssueID}_{SessionID8chars} 形式
  ARTIFACT_FOLDER="${REPOSITORY_PATH}/artifacts/${INPUT_ARG}"
else
  # {IssueID} 形式 - 最新のセッションフォルダを探す
  LATEST_SESSION_FOLDER=$(ls -td "${REPOSITORY_PATH}/artifacts/${INPUT_ARG}"_* 2>/dev/null | head -1)

  if [ -z "$LATEST_SESSION_FOLDER" ] || [ ! -d "$LATEST_SESSION_FOLDER" ]; then
    echo "Error: No artifact folders found for issue: $INPUT_ARG" >&2
    exit 1
  fi

  ARTIFACT_FOLDER="$LATEST_SESSION_FOLDER"
fi

if [ ! -d "$ARTIFACT_FOLDER" ]; then
  echo "Error: Artifact folder not found: $ARTIFACT_FOLDER" >&2
  exit 1
fi

# 最新の.mdファイルを取得
LATEST_ARTIFACT=$(ls -t "$ARTIFACT_FOLDER"/*.md 2>/dev/null | head -1)

if [ -z "$LATEST_ARTIFACT" ] || [ ! -f "$LATEST_ARTIFACT" ]; then
  echo "Error: No artifact files found in $ARTIFACT_FOLDER" >&2
  exit 1
fi

# iTerm2用にファイルパスをstdoutに出力
#echo "$LATEST_ARTIFACT"

open -a 'Marked 2' "$LATEST_ARTIFACT"