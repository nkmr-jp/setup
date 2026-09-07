# Ghostty

Custom configuration for [Ghostty](https://ghostty.org/).

## Setup

```sh
mkdir -p ~/.config/ghostty
ln -sf ~/ghq/github.com/nkmr-jp/setup/ghostty/config ~/.config/ghostty/config
```

Restart Ghostty or press `cmd+shift+,` to reload the configuration.

## config

### Keybindings

Bindings align with [cmux](https://github.com/manaflow-ai/cmux) shortcuts
(`../cmux/cmux.json`). Only terminal operations are mapped;
browser/sidebar/workspace operations are excluded.

Main bindings:

| Operation | Keys |
| --- | --- |
| New tab | `cmd+t` / `cmd+n` |
| Close tab/pane | `cmd+w` |
| Switch tabs | `cmd+alt+←/→` |
| Select tab by number | `ctrl+1` through `ctrl+9` |
| New window | `cmd+shift+n` |
| Close window | `cmd+ctrl+w` |
| Toggle fullscreen | `cmd+ctrl+f` |
| Quit | `cmd+q` |
| Split right | `cmd+d` |
| Split down | `cmd+shift+d` |
| Move focus between splits | `cmd+↑/↓/←/→` |
| Toggle split zoom | `cmd+enter` |
| Open configuration | `cmd+,` |
| Reload configuration | `cmd+shift+,` |

### Behavior

- `confirm-close-surface = false`: disable confirmation when closing a tab or pane.
