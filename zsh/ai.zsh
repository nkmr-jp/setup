#!/bin/zsh
# AI coding assistants and tools

# AI agents
alias cl='claude'
alias co='codex'
alias ge='gemini'
alias claw='openclaw'
# https://x.com/oikon48/status/2072599526771421364
alias cl77='CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-5 claude --append-system-prompt "基本的にタスクや作業の実行は、適切な粒度でsubagentsに実行手順が明確な指示を与えて委譲すること。あなたは全体進行の俯瞰と立案を行う。自己判断による例外は認める"'

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

# Text-to-speech
alias ep='edge-playback --rate "+25%" -v ja-JP-NanamiNeural --text'
# alias ep='edge-playback --rate "+25%" -v ja-JP-KeitaNeural --text'
