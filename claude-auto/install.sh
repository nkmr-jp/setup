#!/bin/bash
# install.sh — claude-auto の冪等インストーラ。
#   1. スクリプトを ~/bin へ symlink（既存 orphan/stall と同じ作法）
#   2. plist を ~/Library/LaunchAgents へ symlink
#   3. 分離 config の実体 ~/.claude-auto を雛形から seed（未作成時のみ）
#   4. keychain にトークンがあるか確認（無ければ Step 0 を案内。自動発行はしない）
#   5. launchd の bootstrap コマンドを「表示」する（自動実行はしない＝ジョブ有効化はユーザー判断）
#
# 再実行安全。symlink/seed は副作用最小。ジョブ起動（bootstrap）だけは明示的に手動で行う。
set -u

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
MOD_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"          # .../setup/claude-auto
SETUP_DIR="$(cd -P "$MOD_DIR/.." && pwd)"                  # .../setup

BIN_DIR="$HOME/bin"
LA_DIR="$HOME/Library/LaunchAgents"
AUTO_DIR="${CLAUDE_AUTO_CONFIG_DIR:-$HOME/.claude-auto}"
KC_SERVICE="${CLAUDE_AUTO_KEYCHAIN_SERVICE:-claude-auto-oauth}"

mkdir -p "$BIN_DIR" "$LA_DIR"

link() {  # link <target> <linkdir>
  local target="$1" dir="$2" name
  name="$(basename "$target")"
  ln -sfn "$target" "$dir/$name"
  echo "  symlink: $dir/$name -> $target"
}

echo "==> 1. bin scripts -> $BIN_DIR"
link "$SETUP_DIR/bin/git-auto-backup.sh"                  "$BIN_DIR"
link "$MOD_DIR/bin/claude-commit-msg.sh"                  "$BIN_DIR"
link "$MOD_DIR/bin/claude-session-summary.sh"             "$BIN_DIR"

echo "==> 2. launchd plists -> $LA_DIR"
link "$SETUP_DIR/launchd/com.nkmr.issues-autobackup.plist"        "$LA_DIR"
link "$MOD_DIR/launchd/com.nkmr.claude-session-summary.plist"     "$LA_DIR"

echo "==> 3. seed isolated config: $AUTO_DIR"
if [[ -d "$AUTO_DIR" ]]; then
  echo "  already exists, skip"
else
  cp -R "$MOD_DIR/config/claude-auto-skeleton/" "$AUTO_DIR/"
  echo "  seeded from skeleton"
fi

echo "==> 4. keychain token ($KC_SERVICE)"
if security find-generic-password -s "$KC_SERVICE" >/dev/null 2>&1; then
  echo "  OK: token present"
else
  cat <<EOF
  NOT FOUND. Step 0 が未完了です。次を実行してトークンを登録してください:
    CLAUDE_CONFIG_DIR=$AUTO_DIR claude setup-token   # サブスク長期トークンを発行（対話操作）
    security add-generic-password -s $KC_SERVICE -a "\$USER" -w '<発行されたトークン>'
EOF
fi

echo "==> 5. launchd を有効化するには（準備完了後に手動で実行）:"
cat <<EOF
    launchctl bootstrap gui/\$(id -u) $LA_DIR/com.nkmr.issues-autobackup.plist
    launchctl bootstrap gui/\$(id -u) $LA_DIR/com.nkmr.claude-session-summary.plist
  停止/再読込:
    launchctl bootout   gui/\$(id -u) $LA_DIR/com.nkmr.issues-autobackup.plist
EOF
echo "done."
