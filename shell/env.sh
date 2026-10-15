# Wrappers for non-interactive shells (bash via BASH_ENV, zsh via .zshenv).
# Coding agents (Claude Code, Codex, AGY, Devin) and scripts never read .zshrc,
# so the wrappers that interactive shells get from zsh/init.zsh are loaded here.
. "$HOME/ghq/github.com/nkmr-jp/setup/shell/redact-env.sh"

# Aikido safe-chain: npm, npx, yarn, pnpm, bun, ... scan packages before install.
# See: https://github.com/AikidoSec/safe-chain
if [ -f "$HOME/.safe-chain/scripts/init-posix.sh" ]; then
  . "$HOME/.safe-chain/scripts/init-posix.sh"
fi
