#!/bin/bash
# guard-agent-rm: エージェントが実行しようとする rm が、ホームの実データを
# ゴミ箱を経由せずに消そうとしていないか検査する PreToolUse hook。
#
# なぜ要るか:
#   `alias rm='trash'`（zsh/aliases.zsh）は **対話 zsh にしか効かない**。alias は
#   子プロセスに継承されず、非対話シェルもスクリプトも .zshrc を読まないため、
#   エージェントが scratchpad に書いた .sh を `bash` で実行する経路では素の /bin/rm になる。
#   長いコマンドは Bash ツールに弾かれるのでスクリプト化はむしろ推奨経路であり、
#   安全網が主要な実行経路をカバーしていない状態だった。
#
#   実害（2026-08-29）: 検証スクリプトが `mv ~/.prompt-line ~/.prompt-line.verifybak` の
#   あと `rm -rf ~/.prompt-line.verifybak` して退避ごと消した。ゴミ箱にも残らなかった。
#
# 何を見るか:
#   Bash ツールのコマンド文字列そのものに加え、`bash <script>` のように**呼び出される
#   スクリプトの中身も読む**。上記の事故はコマンド文字列が `bash verify-edge.sh` だけで、
#   危険がそこに現れなかった。
#
# 判定（best effort。変数越しのパスまでは追わない）:
#   `rm` を含む行が $HOME / ~/ / /Users/<user>/ を指しており、かつ許可リスト
#   （/tmp・$TMPDIR・/private/tmp・ghq 配下のリポジトリ）に該当しないならブロックする。
#   `mv` は正当な退避と区別できず誤検知が多いので対象外。
#
# 出力: 問題なければ黙って exit 0。ブロックするときは stderr に理由を書いて exit 2。

set -u

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
[ "$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)" = "Bash" ] || exit 0

command_text="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -n "$command_text" ] || exit 0

# 走査対象: コマンド本体 ＋ そこから呼ばれるスクリプトの中身
scan_text="$command_text"
while IFS= read -r script; do
  [ -f "$script" ] || continue
  scan_text="$scan_text
$(cat "$script" 2>/dev/null)"
done <<EOF
$(printf '%s' "$command_text" | grep -oE '(^|[;&|] *)(bash|sh|zsh|source|\.) +[^ ;&|)]+' \
   | awk '{print $NF}' | sort -u)
EOF

# 以下 2 つは正規表現リテラル。`$HOME` や `$TMPDIR` は**展開したい変数ではなく、
# 検査対象の文字列に含まれる文字列そのもの**なのでシングルクォートが正しい。
# shellcheck disable=SC2016
# 許可する場所（消えても取り返しがつく、または git で戻せる）
allowed='(/tmp/|/tmp"|/private/tmp|\$TMPDIR|\{TMPDIR|/ghq/github\.com/|BATS_TEST_TMPDIR|/\.Trash)'
# shellcheck disable=SC2016
# ホームの実データを指している兆候
home_ref='(\$HOME|\$\{HOME\}|~/|/Users/[a-zA-Z0-9._-]+/)'

offenders=""
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  printf '%s' "$line" | grep -qE '(^|[;&|(]| )rm( +-[a-zA-Z]+)* ' || continue
  printf '%s' "$line" | grep -qE "$home_ref" || continue
  printf '%s' "$line" | grep -qE "$allowed" && continue
  offenders="$offenders
  $line"
done <<EOF
$scan_text
EOF

[ -n "$offenders" ] || exit 0

cat >&2 <<MSG
ホームの実データを rm で消そうとしています。ゴミ箱を経由しないため取り消せません。
$offenders

対処:
  - 消さずに済むなら消さない（検証で実データを退避したなら「戻す」。退避を消さない）
  - どうしても消すなら trash を使う: trash <path>
  - 使い捨ての作業領域なら /tmp か scratchpad 配下に置く（そこは検査対象外）

補足: alias rm='trash' は対話 zsh にしか効かず、bash/zsh スクリプトの中では
素の /bin/rm になります。ホームの実データを検証で触るときは
~/.prompt-line-isolated/ のような隔離環境を使ってください。（setup#19）
MSG
exit 2
