# setup

Manage OS settings, general shell configuration, tool settings, and helper scripts.
Agent-specific user settings live in agent-settings; cmux, xbar, and plugin implementations remain here.

- The canonical cmux settings live in `cmux/`. `cmux/link.sh` links the two configuration files individually and backs up existing targets.
- Do not duplicate tool implementations or settings in the agent settings repository.
- Follow KISS, YAGNI, and DRY. Update README.md and this file when the structure changes.
- Validate cmux with `bats tests/cmux-link.bats`, `shellcheck cmux/link.sh`, and `sh -n cmux/link.sh`.
- Tests must use temporary HOME / CMUX_CONFIG_HOME directories and must not modify the real home or services.

## Public Repository Boundaries

- Shell settings were restored at the user's request. Defer shell portability and personal-setting separation; preserve initialization, PATH, and aliases.
- Put machine-specific shell overrides in `~/.zshrc.local`, outside this public repository.
- Preserve existing automatic make login, GUI PATH propagation, and PromptLine updates. Do not source real settings or invoke external integrations during validation.
- Do not commit credentials or local settings. Do not expose authentication values in logs or reports.
- Validate shell scripts with `zsh -n` and compare them with the pre-change backup. `tests/startup.bats` loads real user startup settings and must not run automatically.
- Use `~/ghq/github.com/nkmr-jp/setup` for this repository's path in documentation and comments. Write documentation and comments in English.

`iterm-run <command>` remains defined in `zsh/init.zsh`.

Git settings were restored to the original `gitconfig` at the user's request. Separation through a local Git include is deferred.
