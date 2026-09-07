# xbar plugins

Menu-bar plugins for [xbar](https://xbarapp.com/).
Originally run with SwiftBar; migrated to xbar because SwiftBar behavior was unstable.

## Plugins

| File | Description | Dependencies |
| --- | --- | --- |
| `focus.5s.sh` | Show the current [Horo.app](https://horo.app) task in the menu bar | `sqlite3`, Horo.app |
| `claude-sessions.5s.sh` | Summarize Claude Code sessions as `⚡running / 🔔awaiting / ⏸idle` | `jq`, Claude Code (session-monitor plugin) |
| `kalloc1024.2m.sh` | Show threshold progress and growth rate for the Claude Code kernel memory leak (`data.kalloc.1024`) | `zprint` |
| `click-handler.sh` | Click handler called by `claude-sessions.5s.sh` (not registered with xbar) | cmux (optional) |

`claude-sessions.5s.sh` calls `click-handler.sh` as `${0:A:h}/click-handler.sh`.
`${0:A}` resolves the symlink executed by xbar to its real path, so the session
plugin link is sufficient; `click-handler.sh` does not need its own link.

## Create symlinks

Run in this directory:

```sh
make ln
```

Link only the three plugins from this repository into
`~/Library/Application Support/xbar/plugins/`. Keep correct links and back up
existing files or different links with a timestamp. Other plugins and the
click-handler installation are left unchanged. Preview with `./install.sh --dry-run`.
Use `XBAR_PLUGIN_DIR=/path/to/plugins make ln` for a different destination.

After linking, choose **xbar → Refresh all** from the menu bar to apply the changes.

## Install xbar

```sh
brew install --cask xbar
```

## Migration notes from SwiftBar

- Standardize metadata prefixes from `<bitbar.*>` / `<swiftbar.*>` to `<xbar.*>`.
- Remove SwiftBar-only `<swiftbar.hideAbout>` / `<swiftbar.hideRunInTerminal>`.
- Replace `shell=` with xbar's standard `bash=` parameter.
- Rely on `${0:A:h}` (zsh symlink resolution) working correctly under xbar as well.
