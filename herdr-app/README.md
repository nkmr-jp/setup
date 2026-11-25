# Herdr app

Keybindings for the Herdr desktop app (`herdr-app`). This is separate from the
herdr TUI configured in [`../herdr`](../herdr); the app does not read `config.toml`.
`keys.json` uses the same keys as `shortcuts.bindings` in [`../cmux/cmux.json`](../cmux/cmux.json)
(and therefore [`../orca`](../orca)).

## Setup

```sh
cd ~/.config/herdr-app
cp -p keys.json "keys.json.bak-$(date +%Y%m%d_%H%M%S)"
ln -sf ~/ghq/github.com/nkmr-jp/setup/herdr-app/keys.json keys.json
herdr-app status   # "errors" must be empty
```

The app watches `~/.config/herdr-app`, not this repository, so editing
`keys.json` here is not picked up by itself. After editing, run
`touch -h ~/.config/herdr-app/keys.json` to reload it, then check
`herdr-app status` (an invalid file is skipped and reported there).

Only `keys.json`, `layouts/main-custom.json` and `mods/pane-equalize` are managed. The rest of `~/.config/herdr-app` is app state
or files Herdr rewrites on every start.

## Equal pane sizes

Herdr's split halves the split pane and has no equalize command.
`mods/pane-equalize` sets every split child of a tab to weight 1
(`layout.resize`) whenever that tab gains or loses a pane, and on `cmd+alt+e`.
Dragged dividers stay until the next split or close. The split tree is read from
herdr-core's `herdr-app` document (`children.py`, `hc connect` + `doc.get`)
because `panes()` has no geometry. Remote spaces are skipped.

The mod runs from a hidden block in `layouts/main-custom.json`, a clone of
the shipped `main` layout (`layout.clone`; shipped layouts are read-only and
the app never auto-docked the new mod). The clone does not get later changes
to `main`; re-clone and re-add the block if `main` changes.

```sh
R=~/ghq/github.com/nkmr-jp/setup/herdr-app
H=~/.config/herdr-app
# The app ignores a symlinked mod folder, so link the files into a real one.
mkdir -p $H/mods/pane-equalize
for f in main.js mod.json children.py; do ln -s $R/mods/pane-equalize/$f $H/mods/pane-equalize/$f; done
ln -s $R/layouts/main-custom.json $H/layouts/main-custom.json
herdr-app check $H/mods/pane-equalize
herdr-app do layout.switch --name main-custom
```

After editing, `touch -h` the edited link under `~/.config/herdr-app/mods/pane-equalize` to reload it.

## Mapping to cmux

The app starts from Herdr's default `keys.json`; only these rows differ from it.
Herdr space = cmux workspace, Herdr tab = cmux surface.

| cmux | Keys | Herdr command | Herdr default |
| --- | --- | --- | --- |
| `selectWorkspaceByNumber` | `cmd+1..9` | `space.select` | `ctrl-1..9` |
| `selectSurfaceByNumber` | `ctrl+1..9` | `tab.select` | `cmd-1..9` |
| `nextSidebarTab` / `prevSidebarTab` | `cmd+alt+↓` / `↑` | `space.next` / `space.prev` | `cmd-alt-]` / `[` |
| `nextSurface` / `prevSurface` | `cmd+alt+→` / `←` | `tab.next` / `tab.prev` | `cmd-shift-]` / `[` (kept) |
| `focusLeft` / `Right` / `Up` / `Down` | `cmd+←` `→` `↑` `↓` | `pane.go` | `cmd-alt-arrows` |
| `toggleSplitZoom` | `cmd+enter` | `pane.zoom` | `cmd-shift-enter` |
| `closeWorkspace` | `cmd+shift+w` | `space.close` (asks first) | `pane.close` |
| `closeTab` | `cmd+w` | `pane.close` | `tab.close` |
| No cmux equivalent | `cmd+alt+w` | `tab.close` | none |
| `renameTab` | `cmd+r` | `tab.rename` | `f2` (kept) |
| `renameWorkspace` | `cmd+shift+r` | `space.rename` | `shift-f2` (kept) |

- `cmd+←` / `cmd+→` no longer send line start/end (`^A` / `^E`) to the
  terminal, because cmux uses them for pane focus. Use `ctrl+a` / `ctrl+e`.
- `cmd+w` closes the focused pane, like cmux closing the focused surface.
  Herdr's `tab.close` ends every pane in the tab, and closing a space's last
  tab closes the space, so it moved to `cmd+alt+w`.
- Option-only chords never reach `keys.json` on macOS: `alt+↑/↓` bound to
  `agent.next/prev` (global or terminal section) did nothing, while `cmd+alt+…`
  and `ctrl+↓` worked. Don't bind bare `alt-` keys. Agents move with
  `cmd+shift+↑/↓` (no cmux equivalent) as well as `cmd+[` / `]`.
  `herdr.kmmacros` (Keyboard Maestro group `herdr`, Herdr only) turns
  `alt+↑/↓` into `cmd+shift+↑/↓`, the same way the `orca` and `cmux` groups
  remap `alt+↑/↓`. Import it by opening the file, then enable the group
  (imports start disabled).
- Already the same as cmux: `cmd+t` `cmd+n` `cmd+d` `cmd+shift+d`
  `cmd+p` (go to a space or tab) `cmd+shift+p` `cmd+,` `cmd+b` `cmd+f`
  `cmd+=` `cmd+-` `cmd+0` `cmd+q`.
- Kept as Herdr defaults: `cmd+[` / `]` (previous/next agent; browser back/forward
  in cmux, which Herdr has no browser for), `cmd+shift+l` (switch layout; open
  browser in cmux) and `cmd+alt+shift+arrows` (swap panes).
- cmux keys with no Herdr command: `reloadConfiguration` (the app reloads by
  itself), browser, notification and find-next keys.
