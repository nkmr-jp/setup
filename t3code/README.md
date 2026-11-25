# T3 Code

Settings for the [T3 Code](https://github.com/pingdotgg/t3code) desktop app.

| File | Target | Contents |
| --- | --- | --- |
| `keybindings.json` | `~/.t3/userdata/keybindings.json` | Keyboard shortcuts (Settings → Keybindings) |
| `settings.json` | `~/.t3/userdata/settings.json` | Server settings: default model, providers, worktree cleanup |

## Setup

```sh
ln -sf ~/ghq/github.com/nkmr-jp/setup/t3code/keybindings.json ~/.t3/userdata/keybindings.json
ln -sf ~/ghq/github.com/nkmr-jp/setup/t3code/settings.json ~/.t3/userdata/settings.json
```

T3 Code resolves symlinks before its atomic writes, so changes made in the app
land in these files and the links survive.

T3 Code watches `~/.t3/userdata/`, not the link target, so editing a file here
is not picked up live. Re-run the `ln -sf` command above (or restart T3 Code)
to reload it.

`client-settings.json` (fonts, appearance, microphone device IDs, window state)
stays local because it holds machine-specific values.
