# Wrappers for non-interactive shells (bash via BASH_ENV, zsh via .zshenv).
# Coding agents (Claude Code, Codex, AGY, Devin) and scripts never read .zshrc,
# so the wrappers that interactive shells get from zsh/init.zsh are loaded here.
. "$HOME/ghq/github.com/nkmr-jp/setup/shell/redact-env.sh"

# Aikido safe-chain: npm, npx, yarn, pnpm, bun, ... scan packages before install.
# See: https://github.com/AikidoSec/safe-chain
# Skipped inside Codex's sandbox (CODEX_SANDBOX): safe-chain starts a local
# registry proxy, the sandbox denies listen(), and every wrapped command
# (python3 included) would fail. The sandbox has no network to install with
# anyway; commands Codex reruns outside it get safe-chain again.
if [ -z "${CODEX_SANDBOX:-}" ] && [ -f "$HOME/.safe-chain/scripts/init-posix.sh" ]; then
  . "$HOME/.safe-chain/scripts/init-posix.sh"
  # python / python3 only guard `python -m pip`, but every call would start
  # safe-chain (node, about +0.23s), and scripts call python3 often. pip, pip3,
  # uv, and pipx stay wrapped; interactive shells keep all wrappers.
  unset -f python python3 2>/dev/null
fi
