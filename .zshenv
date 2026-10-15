# Read by every zsh, including the non-interactive `zsh -c` that Codex and AGY
# use for commands. Keep it minimal: interactive settings belong in .zshrc.
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# Agent shells skip .zshrc, so load the secret-redacting wrappers here.
# The module returns early unless an agent's variable is set.
[[ -o interactive ]] || source "$HOME/ghq/github.com/nkmr-jp/setup/zsh/redact-env.zsh"
