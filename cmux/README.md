# cmux

This setup directory manages cmux user settings and sidebar integration.
Agent settings are managed in agent-settings.

Run from the repository root:

```sh
./cmux/link.sh --dry-run
./cmux/link.sh --install
./cmux/link.sh --check
```

Link `cmux.json` and `sidebar-cwd.zsh` individually into `~/.config/cmux/`.
The configuration directory itself is not linked. Existing files and different
links are backed up beside the destination as `<filename>.backup.<timestamp>.<pid>`;
correct links are left unchanged. `--dry-run` and `--check` create no files or
directories. Override the destination for testing with `CMUX_CONFIG_HOME` (an absolute path).

Use the same `--install` command when moving back from agent-settings. Review and
incorporate any changes to the old source files first. To roll back, remove only
the new links concerned and restore the corresponding backups to their original names.

zsh sources the installed `~/.config/cmux/sidebar-cwd.zsh`.
`cmux.json` uses JSONC. Apply changes with `cmux reload-config` or a new cmux session.
The installer does not control apps or start services.

The plugin and hooks live in [plugins/cmux](../plugins/cmux/README.md).
Regression tests: `bats tests/cmux-link.bats`.
