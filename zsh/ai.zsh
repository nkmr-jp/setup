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
# See: https://github.com/anthropics/claude-code/issues/24292
alias claude="unset CLAUDE_CODE_OAUTH_TOKEN; unset ANTHROPIC_API_KEY; claude --teammate-mode=tmux"
alias cctop='/Users/nkmr/ghq/github.com/nkmr-jp/claude/scripts/session-top.sh'
alias ccstatus='/Users/nkmr/ghq/github.com/nkmr-jp/claude/scripts/session-status.sh'
alias h='claude --setting-sources "" --model haiku -p'
alias ccusage='bunx ccusage'

# Text-to-speech
alias ep='edge-playback --rate "+25%" -v ja-JP-NanamiNeural --text'
# alias ep='edge-playback --rate "+25%" -v ja-JP-KeitaNeural --text'
