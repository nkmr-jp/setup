# Read by every zsh, including the non-interactive `zsh -c` that agents use for
# commands. Keep it minimal: interactive settings belong in .zshrc.
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# Non-interactive bash reads $BASH_ENV; non-interactive zsh skips .zshrc.
# Both get the secret-redacting and safe-chain wrappers from shell/env.sh.
export BASH_ENV="$HOME/ghq/github.com/nkmr-jp/setup/shell/env.sh"
[[ -o interactive ]] || source "$BASH_ENV"
