#!/bin/bash
# check-config-symlinks: リポジトリ管理の設定ファイルの symlink が外れていないか検査する
#
# なぜ要るか:
#   設定を「リポジトリに実体を置いてホームから symlink」で管理していると、アプリ側が
#   atomic write（<path>.tmp に書いて rename）で書き戻したときに **symlink が実体ファイルに
#   置き換わる**。以後リポジトリ側の編集は無言で効かなくなり、エラーも警告も出ない。
#   実例: ~/.claude/settings.json が claude doctor / /config に置換され、約7週間気づかなかった。
#   予防はできない（アプリ側の書き方は変えられない）ので、定期的に検知する。
#
# 使い方:
#   check-config-symlinks.sh            # 問題のある項目だけ表示。あれば通知して exit 1
#   check-config-symlinks.sh --list     # OK・未設定も含めて全項目表示
#   check-config-symlinks.sh --no-notify  # macOS 通知を出さない（launchd 以外での実行用）
#
# 直し方は表示されるので、内容を見てから手で直す（自動復旧はしない。ホーム側とリポジトリ側の
# どちらが「現行」かは状況次第で、自動で倒すと編集を失うため）。

set -u

MODE_LIST=0
NOTIFY=1
for arg in "$@"; do
  case "$arg" in
    --list)      MODE_LIST=1 ;;
    --no-notify) NOTIFY=0 ;;
    -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

GHQ="$HOME/ghq/github.com/nkmr-jp"
CLAUDE_REPO="$GHQ/claude"
SETUP_REPO="$GHQ/setup"
APP_SUPPORT="$HOME/Library/Application Support"
# Claude デスクトップの local-agent-mode-sessions はアカウント／セッションの UUID を含む。
# 環境ごとに変わるので固定せず glob で解決する。
# sort するのは、セッションが複数あるとき find の順序が実行ごとに変わりうるため。
# 対象がぶれると「顔ぶれが変わった」と誤判定して 6 時間ごとに鳴り続ける。
SCHEDULED_TASKS="$(/usr/bin/find "$APP_SUPPORT/Claude/local-agent-mode-sessions" \
  -maxdepth 3 -name scheduled-tasks.json 2>/dev/null | sort | head -1)"

# 管理対象: "<ホーム側のパス>|<リポジトリ側の実体>"
# 「アプリが書き戻す設定ファイル」を対象にする（手でしか触らない bin/plist のリンクは対象外）。
ENTRIES=(
  "$HOME/.claude/settings.json|$CLAUDE_REPO/settings.json"
  "$HOME/.claude/CLAUDE.md|$CLAUDE_REPO/HOME_CLAUDE.md"
  "$HOME/.claude/docs|$CLAUDE_REPO/docs"
  "$APP_SUPPORT/Claude/claude_desktop_config.json|$CLAUDE_REPO/claude_desktop_config.json"
  "$HOME/.codex/config.toml|$CLAUDE_REPO/config.toml"
  "$HOME/Documents/Claude|$CLAUDE_REPO/Documents/Claude"
  "$HOME/.zshrc|$SETUP_REPO/.zshrc"
  "$HOME/.config/ghostty/config|$SETUP_REPO/ghostty/config"
  "$HOME/.config/cmux/cmux.json|$SETUP_REPO/cmux/cmux.json"
  "$APP_SUPPORT/iTerm2/Scripts/AutoLaunch/PaneCount.py|$SETUP_REPO/iterm2/PaneCount.py"
  "$HOME/.orca|$SETUP_REPO/orca"
)
[ -n "$SCHEDULED_TASKS" ] && ENTRIES+=("$SCHEDULED_TASKS|$CLAUDE_REPO/scheduled-tasks.json")

# テスト用: 管理対象を外から差し替える（1 行 1 エントリ。tests/check-config-symlinks.bats）
if [ -n "${CHECK_CONFIG_SYMLINKS_ENTRIES:-}" ]; then
  ENTRIES=()
  while IFS= read -r line; do
    [ -n "$line" ] && ENTRIES+=("$line")
  done <<< "$CHECK_CONFIG_SYMLINKS_ENTRIES"
fi

# 定期実行で同じ問題を毎回鳴らすと無視されるようになるので、問題の顔ぶれが前回と
# 変わったときだけ通知する（直したら状態ファイルも消えて、次に壊れたらまた鳴る）。
STATE_FILE="${TMPDIR:-/tmp}/check-config-symlinks.state"

notify() {
  local title="$1" message="$2"
  [ "$NOTIFY" -eq 1 ] || return 0
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "$title" -message "$message" \
      -group "config-symlinks" -sound default >/dev/null 2>&1
  else
    # 文字列に埋め込むとパス中の " や \ で AppleScript が構文エラーになり（stderr は捨てられる）
    # 通知が黙って消えるので、引数として渡す。
    osascript -e 'on run {m, t}' \
      -e 'display notification m with title t sound name "Submarine"' \
      -e 'end run' "$message" "$title" >/dev/null 2>&1
  fi
}

# 末尾のスラッシュは指す先が同じなので比較前に落とす（zsh のディレクトリ補完や
# `ln -sfn <dir>/ <link>` で付く）。付いたままだと OK なリンクを WRONG と誤検知する。
strip_slash() {
  local p="$1"
  while [ "${p%/}" != "$p" ] && [ -n "${p%/}" ]; do p="${p%/}"; done
  printf '%s' "$p"
}

# ホーム側が実体になっているとき、リポジトリ側と中身が違うか（＝実際に乖離しているか）
drift_note() {
  local link="$1" target="$2"
  if [ -d "$link" ] || [ -d "$target" ]; then
    if diff -rq "$link" "$target" >/dev/null 2>&1; then echo "中身は同じ"; else echo "中身が乖離している"; fi
  else
    if cmp -s "$link" "$target"; then echo "中身は同じ"; else echo "中身が乖離している"; fi
  fi
}

problems=()
rows=()
for entry in "${ENTRIES[@]}"; do
  # `|` を書き忘れると link と target が同じ文字列になり、MISSING や「中身は同じ DETACHED」に
  # 化けて黙って監視から外れる。宣言ミスは検知したいので落とす。
  case "$entry" in
    *\|*) ;;
    *) echo "invalid entry (期待する形式は '<ホーム側>|<リポジトリ側>'): $entry" >&2; exit 2 ;;
  esac
  link="${entry%%|*}"
  target="${entry#*|}"
  if [ -L "$link" ]; then
    actual="$(readlink "$link")"
    if [ "$(strip_slash "$actual")" != "$(strip_slash "$target")" ]; then
      rows+=("WRONG    $link -> $actual (期待: $target)")
      problems+=("$link はリンク先が違う")
    elif [ ! -e "$link" ]; then
      # symlink はあるが解決できない（リンク切れ）
      rows+=("BROKEN   $link -> $actual")
      problems+=("$link がリンク切れ")
    else
      rows+=("OK       $link")
    fi
  elif [ -e "$link" ]; then
    if [ ! -e "$target" ]; then
      # リポジトリ側に実体がまだ無い＝そもそも管理下に入れていない。外れたのではないので
      # 警告しない（例: リンクを張る前の状態、そのマシンでは使っていない設定）。
      rows+=("PENDING  $link は未管理（リポジトリ側に $target が無い）")
    else
      rows+=("DETACHED $link が symlink でない（$(drift_note "$link" "$target")）")
      problems+=("$link の symlink が外れている")
    fi
  else
    rows+=("MISSING  $link は未設定")
  fi
done

if [ "$MODE_LIST" -eq 1 ]; then
  printf '%s\n' "${rows[@]}"
else
  for row in "${rows[@]}"; do
    case "$row" in OK*|MISSING*|PENDING*) ;; *) printf '%s\n' "$row" ;; esac
  done
fi

if [ "${#problems[@]}" -gt 0 ]; then
  echo
  echo "$(date '+%Y-%m-%d %H:%M:%S') symlink が外れている項目が ${#problems[@]} 件ある。"
  echo "直す前に必ず中身を見比べる（ホーム側が現行なら repo へ取り込んでから張り直す）:"
  echo "  diff <ホーム側> <リポジトリ側>"
  echo "  cp <ホーム側> <リポジトリ側>    # ホーム側が現行の場合"
  echo "  ln -sfn <リポジトリ側> <ホーム側>"
  # 状態ファイルは「前回ユーザーに通知した顔ぶれ」を表す。通知していない実行（--no-notify）で
  # 書くと、次の定期実行が「前回と同じ＝通知済み」と誤認して黙ってしまうので書かない。
  current="$(printf '%s\n' "${problems[@]}")"
  if [ "$NOTIFY" -eq 1 ] && [ "$current" != "$(cat "$STATE_FILE" 2>/dev/null)" ]; then
    notify "設定の symlink が外れている" "${#problems[@]} 件: ${problems[0]}"
    printf '%s\n' "$current" > "$STATE_FILE"
  fi
  exit 1
fi

rm -f "$STATE_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') OK: 管理対象 ${#ENTRIES[@]} 件に外れているリンクは無い"
exit 0
