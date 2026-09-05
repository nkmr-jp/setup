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
#   check-config-symlinks.sh --list     # 全項目を表示するだけ（通知も状態更新もしない）
#   check-config-symlinks.sh --suggest  # 管理対象に入っていない repo 向け symlink を探す
#   check-config-symlinks.sh --no-notify  # 通知を出さない（状態も更新しない）
#
# 直し方は項目ごとに出力されるので、内容を見てから手で直す（自動復旧はしない。ホーム側と
# リポジトリ側のどちらが「現行」かは状況次第で、自動で倒すと編集を失うため）。

set -u

MODE_LIST=0
MODE_SUGGEST=0
NOTIFY=1
for arg in "$@"; do
  case "$arg" in
    --list)      MODE_LIST=1 ;;
    --suggest)   MODE_SUGGEST=1 ;;
    --no-notify) NOTIFY=0 ;;
    -h|--help)   sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done
# --list は棚卸し用の閲覧コマンド。ここで通知したり「通知済み」状態を書いたりすると、
# 手で 1 回眺めただけで以後の定期実行が黙る（実際にその不具合があった）。
[ "$MODE_LIST" -eq 1 ] && NOTIFY=0

GHQ="$HOME/ghq/github.com/nkmr-jp"
CLAUDE_REPO="$GHQ/claude"
CODEX_REPO="$GHQ/codex"
SETUP_REPO="$GHQ/setup"
APP_SUPPORT="$HOME/Library/Application Support"

# 管理対象: "<ホーム側のパス>|<リポジトリ側の実体>"
#
# 方針: **ghq 配下のリポジトリを指しているホーム配下の symlink は、種別を問わず全部入れる**。
# 「アプリが書き戻すものだけ」「bin と plist は除く」のように**判断が要る絞り方はしない**
# ——判断が入る時点で漏れる。実際、絞り込みのせいで ~/.codex/AGENTS.md・yazi・herdr が抜け、
# さらに **~/.prompt-line が抜けていて実際の事故を検知できなかった**
# （別セッションの検証スクリプトが誤ってリンクを削除し、以後アプリの書き込みが
# リポジトリに届かなくなっていたのに、誰も気づかなかった）。
#
# 増やすときは手で探さず `--suggest` を使う（ホームを走査して、リポジトリを指しているのに
# ここに無い symlink を挙げる）。テストは tests/check-config-symlinks.bats。
ENTRIES=(
  "$HOME/.claude/settings.json|$CLAUDE_REPO/settings.json"
  "$HOME/.claude/CLAUDE.md|$CLAUDE_REPO/HOME_CLAUDE.md"
  "$HOME/.claude/docs|$CLAUDE_REPO/docs"
  "$HOME/.codex/AGENTS.md|$CODEX_REPO/home/AGENTS.md"
  "$HOME/.codex/config.toml|$CODEX_REPO/home/config.toml"
  "$HOME/.codex/auto.config.toml|$CODEX_REPO/home/auto.config.toml"
  "$HOME/.codex/hooks.json|$CODEX_REPO/home/hooks.json"
  "$HOME/.codex/rules/default.rules|$CODEX_REPO/home/rules/default.rules"
  "$HOME/.codex/docs|$CODEX_REPO/home/docs"
  "$APP_SUPPORT/Claude/claude_desktop_config.json|$CLAUDE_REPO/claude_desktop_config.json"
  "$HOME/Documents/Claude|$CLAUDE_REPO/Documents/Claude"
  # Claude デスクトップの local-agent-mode-sessions のパスはアカウント／セッションの UUID を
  # 含む。find で拾うと、セッションが増えたときに黙って別のファイルを監視しに行って本命が
  # 無検査になるので、claude/README.md と同じくパスを固定する。UUID が変わったら
  # NOLINK として鳴るので、そのとき張り直してここも直す。
  "$APP_SUPPORT/Claude/local-agent-mode-sessions/d3428c2b-f6cc-4363-a78f-6557cbe8c927/f606b23b-39a1-482e-98f1-ea0c737b8052/scheduled-tasks.json|$CLAUDE_REPO/scheduled-tasks.json"
  "$HOME/.zshrc|$SETUP_REPO/.zshrc"
  "$HOME/.config/ghostty/config|$SETUP_REPO/ghostty/config"
  "$HOME/.config/cmux/cmux.json|$SETUP_REPO/cmux/cmux.json"
  "$HOME/.config/yazi/yazi.toml|$SETUP_REPO/yazi/yazi.toml"
  "$HOME/.config/herdr/config.toml|$SETUP_REPO/herdr/config.toml"
  "$APP_SUPPORT/iTerm2/Scripts/AutoLaunch/PaneCount.py|$SETUP_REPO/iterm2/PaneCount.py"
  "$APP_SUPPORT/iTerm2/Scripts/AutoTabReorder|$SETUP_REPO/iterm2/AutoTabReorder"
  "$HOME/.orca|$SETUP_REPO/orca"
  "$HOME/.prompt-line|$GHQ/dot-prompt-line"
  "$HOME/.hyper.js|$GHQ/hyper/.hyper.js"
  "$HOME/.config/wezterm/wezterm.lua|$GHQ/hyper/wezterm.lua"
  "$APP_SUPPORT/xbar/plugins/kalloc1024.2m.sh|$SETUP_REPO/xbar/kalloc1024.2m.sh"
  "$APP_SUPPORT/xbar/plugins/claude-sessions.5s.sh|$SETUP_REPO/xbar/claude-sessions.5s.sh"
  "$APP_SUPPORT/xbar/plugins/focus.5s.sh|$SETUP_REPO/xbar/focus.5s.sh"
  "$HOME/Library/LaunchAgents/com.nkmr.claude-stall-monitor.plist|$SETUP_REPO/launchd/com.nkmr.claude-stall-monitor.plist"
  "$HOME/Library/LaunchAgents/com.nkmr.issues-autobackup.plist|$SETUP_REPO/launchd/com.nkmr.issues-autobackup.plist"
  "$HOME/Library/LaunchAgents/io.redis.stack.server.plist|$GHQ/xt/deployments/local/LaunchAgents/io.redis.stack.server.plist"
  "$HOME/bin/check-claude-orphans.sh|$SETUP_REPO/bin/check-claude-orphans.sh"
  "$HOME/bin/claude-stall-monitor.sh|$SETUP_REPO/bin/claude-stall-monitor.sh"
  "$HOME/bin/git-auto-backup.sh|$SETUP_REPO/bin/git-auto-backup.sh"
  "$HOME/bin/claude-terminal-title.sh|$GHQ/ccdash/claude-auto/bin/claude-terminal-title.sh"
  "$HOME/bin/codex-terminal-title.sh|$GHQ/ccdash/codex-auto/bin/codex-terminal-title.sh"
  "$HOME/bin/codex-auto|$GHQ/ccdash/codex-auto/bin/codex-auto.sh"
)

# テスト用: 管理対象を外から差し替える（1 行 1 エントリ。tests/check-config-symlinks.bats）
if [ -n "${CHECK_CONFIG_SYMLINKS_ENTRIES:-}" ]; then
  ENTRIES=()
  while IFS= read -r line; do
    [ -n "$line" ] && ENTRIES+=("$line")
  done <<< "$CHECK_CONFIG_SYMLINKS_ENTRIES"
  # bash 3.2 + set -u では空配列の "${arr[@]}" が unbound variable で落ちる。
  # 「非空だが 1 行も生まない」値を渡されたときに無言でクラッシュしないよう弾く。
  if [ "${#ENTRIES[@]}" -eq 0 ]; then
    echo "CHECK_CONFIG_SYMLINKS_ENTRIES に有効なエントリが 1 件も無い" >&2
    exit 2
  fi
fi

# 定期実行で同じ問題を毎回鳴らすと無視されるようになるので、問題の顔ぶれが前回と
# 変わったときだけ通知する。ただし**顔ぶれが同じでも RENOTIFY_DAYS 経過したら鳴らし直す**
# ——通知を 1 回見逃したら永久に黙る、では 7 週間気づかなかった事故の再来になる。
STATE_FILE="${STATE_DIR:-$HOME/Library/Application Support/check-config-symlinks}/state"
RENOTIFY_DAYS="${RENOTIFY_DAYS:-7}"

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

# 直し方は対象がファイルかディレクトリかで変わる。ディレクトリに `cp`（-R 無し）は失敗し、
# `ln -sfn <repo> <home>` は home が実ディレクトリだと **exit 0 のまま中に入れ子リンクを作る**。
# 助言どおりにやって直らない、が起きないよう種別で出し分ける。
fix_hint() {
  local link="$1" target="$2"
  if [ -d "$link" ]; then
    printf '    diff -r "%s" "%s"\n' "$link" "$target"
    printf '    cp -R "%s/." "%s/"   # ホーム側が現行の場合\n' "$link" "$target"
    printf '    rm -rf "%s" && ln -s "%s" "%s"\n' "$link" "$target" "$link"
  else
    printf '    diff "%s" "%s"\n' "$link" "$target"
    printf '    cp "%s" "%s"   # ホーム側が現行の場合\n' "$link" "$target"
    printf '    ln -sfn "%s" "%s"\n' "$target" "$link"
  fi
}

# --suggest: ホーム配下を走査して「リポジトリを指しているのに ENTRIES に無い symlink」を挙げる。
# 管理対象を手で数える運用だと必ず漏れる（実際 ~/.prompt-line が漏れて事故を検知できなかった）ので、
# 増えたリンクは機械的に見つけられるようにしておく。
if [ "$MODE_SUGGEST" -eq 1 ]; then
  known=""
  for entry in "${ENTRIES[@]}"; do known="$known
${entry%%|*}"; done
  found=0
  # 設定が置かれる場所だけを浅く走査する（ホーム全体を潜ると重い）
  for spec in "$HOME:1" "$HOME/.config:2" "$HOME/.claude:1" "$HOME/.codex:1" \
              "$HOME/Documents:1" "$APP_SUPPORT:3" "$HOME/Library/LaunchAgents:1" "$HOME/bin:1"; do
    dir="${spec%:*}"; depth="${spec##*:}"
    [ -d "$dir" ] || continue
    while IFS= read -r link; do
      target="$(readlink "$link")"
      case "$target" in */ghq/github.com/*) ;; *) continue ;; esac
      case "$known" in *"
$link") ;; *"
$link
"*) ;; *)
        printf '  "%s|%s"\n' "$link" "$target"
        found=$((found + 1)) ;;
      esac
    done <<EOF
$(find "$dir" -maxdepth "$depth" -type l 2>/dev/null)
EOF
  done
  if [ "$found" -eq 0 ]; then
    echo "管理対象に入っていない repo 向け symlink は無い（ENTRIES ${#ENTRIES[@]} 件）"
  else
    echo
    echo "↑ ENTRIES に入っていない。必要なものを bin/check-config-symlinks.sh へ追記する。"
  fi
  exit 0
fi

problems=()
hints=()
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
      hints+=("$(fix_hint "$link" "$target")")
    elif [ ! -e "$link" ]; then
      # symlink はあるが解決できない（リンク切れ）
      rows+=("BROKEN   $link -> $actual")
      problems+=("$link がリンク切れ")
      hints+=("$(fix_hint "$link" "$target")")
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
      hints+=("$(fix_hint "$link" "$target")")
    fi
  elif [ -e "$target" ]; then
    # ホーム側に何も無いのにリポジトリ側には実体がある＝リンクが消されたか、まだ張っていない。
    # どちらにせよ「リポジトリの編集が効かない」状態なので、黙らせない。
    rows+=("NOLINK   $link が無い（リポジトリ側の $target は管理されていない）")
    problems+=("$link のリンクが無い")
    hints+=("    ln -s \"$target\" \"$link\"")
  else
    rows+=("MISSING  $link は未設定（リポジトリ側にも実体が無い）")
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
  printf '%s\n' "${hints[@]}"

  # 状態ファイルは「前回ユーザーに通知した顔ぶれと時刻」を表す。通知していない実行
  # （--no-notify / --list）で書くと、次の定期実行が「前回と同じ＝通知済み」と誤認して黙る。
  if [ "$NOTIFY" -eq 1 ]; then
    current="$(printf '%s\n' "${problems[@]}")"
    previous=""
    last_notified=0
    if [ -f "$STATE_FILE" ]; then
      last_notified="$(head -1 "$STATE_FILE")"
      previous="$(tail -n +2 "$STATE_FILE")"
      case "$last_notified" in ''|*[!0-9]*) last_notified=0 ;; esac
    fi
    now="$(date +%s)"
    stale=$(( now - last_notified > RENOTIFY_DAYS * 86400 ))
    if [ "$current" != "$previous" ] || [ "$stale" -eq 1 ]; then
      notify "設定の symlink が外れている" "${#problems[@]} 件: ${problems[0]}"
      mkdir -p "$(dirname "$STATE_FILE")"
      { echo "$now"; printf '%s\n' "$current"; } > "$STATE_FILE"
    fi
  fi
  exit 1
fi

# 問題が無いときの状態クリアは、通知したかどうかに関係なく常に正しい（次に壊れたら鳴る）。
rm -f "$STATE_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') OK: 管理対象 ${#ENTRIES[@]} 件に外れているリンクは無い"
exit 0
