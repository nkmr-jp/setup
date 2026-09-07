# herdr

Custom configuration for [herdr](https://herdr.dev), a terminal workspace manager for AI coding agents.

## Setup

```sh
brew install herdr
ln -sf ~/ghq/github.com/nkmr-jp/setup/herdr/config.toml ~/.config/herdr/config.toml
herdr server reload-config   # Apply configuration while the server is running
```

Inspect the complete schema with `herdr --default-config`.

## Keybindings

Keep the default `ctrl+b` prefix bindings and add direct `ctrl+alt` chords
for operation without a prefix (issues#4).

### Pane

| Operation | Direct | With prefix |
| --- | --- | --- |
| Move focus (left/down/up/right) | `ctrl+alt+h/j/k/l` | `prefix+h/j/k/l` |
| Vertical split | `ctrl+alt+v` | `prefix+v` |
| Horizontal split | `ctrl+alt+s` | `prefix+-` |
| Close pane | `ctrl+alt+x` | `prefix+x` |
| Zoom | `ctrl+alt+z` | `prefix+z` |
| Resize mode | `ctrl+alt+r` | `prefix+r` |

### Tab

| Operation | Direct | With prefix |
| --- | --- | --- |
| New tab | `ctrl+alt+t` | `prefix+c` |
| Previous/next tab | `ctrl+alt+←/→` | `prefix+p/n` |
| Select tab by number | `ctrl+alt+1..9` | `prefix+1..9` |

### Workspace

| Operation | Direct | With prefix |
| --- | --- | --- |
| List workspaces | `ctrl+alt+w` | `prefix+w` |
| Previous/next workspace | `ctrl+alt+↑/↓` | Unassigned by default |

### Misc

| Operation | Direct | With prefix |
| --- | --- | --- |
| goto (navigate mode) | `ctrl+alt+g` | `prefix+g` |
| Edit scrollback | `ctrl+alt+e` | `prefix+e` |
| Toggle sidebar | `ctrl+alt+b` | `prefix+b` |

## Modifier rationale

- Ghostty consumes `cmd` chords at the terminal layer before they reach herdr.
- Bare `ctrl+letter` conflicts with zsh widgets (`ctrl+g/f/]`, etc.) and readline.
- herdr also recommends explicit modified chords for reliable direct bindings.
- herdr is not intended to run inside cmux, so cmux shortcut conflicts are not considered.

## Terminal compatibility

- `ctrl+alt+letter` requires a terminal supporting **CSI-u (kitty keyboard protocol)**.
  Legacy ESC-prefix encoding does not reach herdr as `ctrl+alt`, as confirmed in
  an isolated session with a PTY.
- `ctrl+alt+arrow` uses standard xterm modified-arrow encoding (`CSI 1;7A`, etc.),
  so it also works in legacy terminals.
- **iTerm2 (the usual environment)**: with the default Option setting (Normal),
  Option is not sent as Alt and `ctrl+alt` chords do not reach herdr.
  In Settings → Profiles → your profile → Keys → General,
  **set Left Option key to "Esc+"**.
  If you enter backslashes using `option+¥` on a JIS keyboard, this stops working
  on the Esc+ side. Set only Left to Esc+ and leave the other side Normal.
- **Ghostty** supports the kitty keyboard protocol. If `ctrl+alt+letter` does not
  work, add `macos-option-as-alt = true` to the configuration.

## Operational notes

- herdr's settings screen (`prefix+s`) rewrites config.toml directly. If it replaces
  the symlink with a regular file, incorporate the diff into the repository before
  restoring the link with the `ln -sf` command above.
- Invalid bindings are disabled individually, with `disabling binding` logged
  as a fail-safe. Check `~/.config/herdr/herdr-server.log` after applying changes.
