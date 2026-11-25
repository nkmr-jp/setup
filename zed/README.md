# Zed

Settings for the [Zed](https://zed.dev) editor.

| File | Target | Contents |
| --- | --- | --- |
| `keymap.json` | `~/.config/zed/keymap.json` | Keyboard shortcuts |
| `settings.json` | `~/.config/zed/settings.json` | Editor settings: panels, agent, fonts, theme |

## Setup

```sh
mkdir -p ~/.config/zed
ln -sf ~/ghq/github.com/nkmr-jp/setup/zed/keymap.json ~/.config/zed/keymap.json
ln -sf ~/ghq/github.com/nkmr-jp/setup/zed/settings.json ~/.config/zed/settings.json
```

Zed resolves symlinks before writing these files (settings UI, keymap editor,
and migrations), so changes made in the app land here and the links survive.

Other entries in `~/.config/zed` (prompts, conversations, themes) stay local.
