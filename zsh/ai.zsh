#!/bin/zsh
# AI coding assistants and tools

# AI agents
alias cl='claude'
alias co='codex'
alias ge='gemini'
alias claw='openclaw'

# Claude Code
# See: https://spiess.dev/blog/how-i-use-claude-code
# See: https://github.com/anthropics/claude-code/issues/8473
#alias claude="unset CLAUDE_CODE_OAUTH_TOKEN; unset ANTHROPIC_API_KEY; claude"
# cmux 内では claude を直接、cmux 外では cmux claude-teams を起動
yolo() {
  if [[ -n "$CMUX_SHELL_INTEGRATION" ]]; then
    claude --dangerously-skip-permissions "$@"
  else
    cmux claude-teams --dangerously-skip-permissions "$@"
  fi
}
alias cctop='/Users/nkmr/ghq/github.com/nkmr-jp/claude/scripts/session-top.sh'
alias ccstatus='/Users/nkmr/ghq/github.com/nkmr-jp/claude/scripts/session-status.sh'
alias h='claude --setting-sources "" --model haiku -p'
alias ccusage='bunx ccusage'

# claude を tmux セッション（ccdash-<sid8>）内で起動し、ccdash のターミナルパネルや
# 他のターミナルから `tmux attach -t ccdash-<sid8>` で同じ対話セッションに合流できる
# ようにする（同一セッションの二重 resume による会話の枝分かれ防止）。
# - セッション ID をこちらで採番して --session-id で渡す（tmux 名 = ccdash-<sid8> が契約。
#   ccdash 側は同名で `tmux new-session -A` するため検出なしで合流できる）
# - `--resume <sid>` はその sid を tmux 名に使う。既に ccdash-<sid8> が生きていれば
#   新規起動せずそこへ合流する（-A）
# - 素通し: tmux 内 / tmux 無し / CC_NO_TMUX=1 / 非対話・ヘルプ系フラグ /
#   sid を特定できない resume ピッカー・--continue
claude() {
  if [[ -n "$TMUX" || -n "$CC_NO_TMUX" ]] || ! command -v tmux >/dev/null 2>&1; then
    command claude "$@"
    return
  fi
  local arg
  for arg in "$@"; do
    case "$arg" in
      -p|--print|-h|--help|-v|--version|-c|--continue|--session-id)
        command claude "$@"
        return
        ;;
    esac
  done
  # --resume/-r の直後の引数が UUID ならそれを tmux 名に採用する。
  # 値なし（対話ピッカー）は起動してみるまで sid が分からないため素通しする。
  local sid="" i
  local -a args
  args=("$@")
  for (( i = 1; i <= $#args; i++ )); do
    if [[ "${args[i]}" == "--resume" || "${args[i]}" == "-r" ]]; then
      if [[ "${args[i+1]}" == [0-9a-fA-F]*-*-*-*-* ]]; then
        sid="${args[i+1]}"
      else
        command claude "$@"
        return
      fi
    fi
  done
  if [[ -z "$sid" ]]; then
    sid="$(uuidgen | tr '[:upper:]' '[:lower:]')"
    args+=(--session-id "$sid")
  fi
  # 引数を 1 つずつクォートして tmux の shell-command 文字列に畳む
  local cmd="command claude"
  for arg in "${args[@]}"; do
    cmd+=" ${(q)arg}"
  done
  tmux new-session -A -s "ccdash-${sid:0:8}" -c "$PWD" "$cmd"
}

# Text-to-speech
alias ep='edge-playback --rate "+25%" -v ja-JP-NanamiNeural --text'
# alias ep='edge-playback --rate "+25%" -v ja-JP-KeitaNeural --text'
