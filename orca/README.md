# Orca

Keybindings for [Orca](https://github.com/stablyai/orca) (`com.stablyai.orca`).
Ported from `shortcuts.bindings` in [`../cmux/cmux.json`](../cmux/cmux.json)
to use the same keys as cmux. **Some bindings intentionally differ at the user's
request**, as explained in the rationale column below.

## Setup

Use this directory as **`~/.orca` itself**: symlink the entire directory rather
than individual files, for the reasons below.

**Prerequisite: `~/ghq/github.com/nkmr-jp/setup/orca/` must already exist**
(after this change has landed on main). Otherwise, `cp` creates `orca/` itself,
and `git checkout` fails, leaving `~/.orca` pointing to a directory without
the managed `keybindings.json`.

```sh
REPO=~/ghq/github.com/nkmr-jp/setup/orca
test -f "$REPO/keybindings.json" || echo "Pull main first"

# 1. Quit Orca: running agent sessions reference agent-hooks/.
osascript -e 'quit app "Orca"'

# 2. Copy existing ~/.orca contents, including Orca-generated agent-hooks/, into this repository.
#    Use the trailing /. to include dotfiles; ~/.orca/* would miss them.
#    This overwrites the repository's keybindings.json with the existing local one.
#    Always restore the managed version after copying (the checkout below).
#    Chain with && to stop on any failure. Separate commands could let rm -rf run
#    after a failed copy and delete agent-hooks/ along with ~/.orca.
test -f "$REPO/keybindings.json" \
  && cp -R ~/.orca/. "$REPO"/ \
  && git -C ~/ghq/github.com/nkmr-jp/setup checkout -- orca/keybindings.json \
  && rm -rf ~/.orca \
  && ln -s "$REPO" ~/.orca

# 3. Confirm the link exists and keybindings.json is visible.
ls -ld ~/.orca
ls -l ~/.orca/keybindings.json
```

If `~/.orca` does not exist yet, skip step 2 and run only `ln -s "$REPO" ~/.orca`.
**Do not run `ln -s` alone when `~/.orca` already exists**: instead of failing,
`ln` creates a nested `~/.orca/orca` link. The existing directory must be removed first.

Apply changes in **Orca Settings → Shortcuts → "Reload from Disk"**.
**There is no file watcher, so editing alone does not apply changes.** Orca has
no CLI subcommand equivalent to `cmux reload-config`.

### Why link the directory instead of the file?

Orca writes `keybindings.json` atomically by writing `<path>.tmp` and renaming it.
The rename replaces the symlink itself with a regular file. A symlink at
`~/.orca/keybindings.json` would therefore be silently replaced when:

- Changing or resetting shortcuts in the Settings UI.
- Automatically creating a missing file.
- Migrating old bindings or running a one-time startup migration; future migrations may do the same.

No error appears, and the repository file is left stale. This is the same failure
as the `~/.claude/settings.json` symlink being replaced by `claude doctor` / `/config`,
which went unnoticed for seven weeks.

With a directory symlink, both temporary-file creation and rename happen inside
this repository. Settings UI edits and future migrations therefore appear in `git diff`.

Orca also stores runtime state such as `agent-hooks/` in `~/.orca`, so `.gitignore`
uses an allowlist: ignore `*`, then allow `keybindings.json` and the other managed files.
Two caveats:

- Git does not descend into ignored directories, so `!` exceptions only restore
  top-level files here. If Orca starts storing configuration in subdirectories,
  add appropriate directory exceptions to `.gitignore`.
- **Do not run `git clean -fdx` in this directory.** Ignored files such as
  `agent-hooks/` are live Orca state; deleting them as cleanup breaks the app.

## Writing keybindings.json

- Path: `~/.orca/keybindings.json`. The format is undocumented; it was determined
  from `src/main/keybindings/` and `src/shared/keybindings.ts` in
  [stablyai/orca](https://github.com/stablyai/orca).
- The four root keys are `$schema`, `version`, `keybindings`, and `platforms`.
  `platforms.<current OS>` overrides the shared `keybindings`. Settings UI edits
  also go into `platforms.darwin`, so handwritten overrides are kept there.
- **Strict JSON** (`JSON.parse`): unlike cmux.json, neither `//` comments nor trailing
  commas are allowed. They cause `Could not read keybindings file`. Document intent here.
- Values can be strings or arrays of strings, allowing several keys per action.
  **Use `null` to disable an action.**
- Keys use forms such as `Mod+Shift+P`. On macOS, `Mod` means Cmd. Modifiers are
  `Mod` / `Cmd` / `Ctrl` / `Alt` / `Shift`. Case-insensitive aliases include
  `[` → `BracketLeft`, `.` → `Period`, and `Up` → `ArrowUp`.
- **Do not write a literal comma as the key.** Orca first splits values on `,`
  as a multiple-binding separator. `Mod+Shift+,` therefore fails parsing and
  discards the entire override. Always write `Mod+Shift+Comma`.
- **Bare and Shift-only keys are mostly unsupported.** Exceptions are the three
  `allowBareKeybindings` actions (`editor.previousChange`, `editor.nextChange`,
  `fileExplorer.delete`), the one `allowShiftOnlyKeybindings` action
  (`terminal.switchInputSource`), and `Shift+Insert`. Assigning `Enter` or `F7`
  elsewhere discards the entire override.
- **`tab.selectByIndex` / `workspace.selectByIndex` accept only digits `1` through `9`**,
  for example `Mod+1`. Other keys discard the whole override.
- **On JIS keyboards, do not omit Shift for symbols that require it.** JIS has no
  standalone `=` key: it is entered with `Shift+-`. A binding of `Mod+Alt+Equal`
  receives `Mod+Alt+Shift+Minus` and never matches, because `keybindingMatchesInput`
  requires exact modifiers (`modifierStateMatches && keyMatches`). Symbols requiring
  Shift on JIS include `=` `+` `_` `|` `~` `"` `&` `(` `)` `*` `<` `>` `?`.
  Symbols available without Shift include `-` `^` `¥` `@` `[` `]` `;` `:` `,` `.` `/`.
  Letters and digits do not depend on the layout, so prefer them when unsure.
  `check-keybindings.py` cannot detect this: it checks what Orca accepts, not whether
  your keyboard can produce it. For example, `terminal.equalizePaneSizes` assigned
  to `Mod+Alt+Equal` passed validation but did nothing even after Reload from Disk.
- `$schema` is an accepted root key, but no public schema exists; its value is ignored.

### Conflicting overrides are silently discarded

Conflicts are checked in `conflictGroup ?? scope` buckets. Overrides involved in
a collision are silently dropped (`removeConflictingOverrides`); only Settings
shows a diagnostic. Dropped overrides revert to the action's default key instead
of disabling it. The requested key does nothing while the default still works.

Actions set to `null` (an empty list) have no active bindings, so they do not
participate in conflict checks and are never dropped. Disabling always works.

Unsupported key specifications also discard the entire override and restore
the default. Always validate after editing:

```sh
./check-keybindings.py          # Defaults to keybindings.json in this directory
```

The script extracts action definitions from the installed `Orca.app` `app.asar`.
Run it after updating Orca to detect conflicts caused by upstream default changes.
It checks unknown action IDs, invalid key specifications (the restrictions above),
and conflicts involving overrides. Its checks mirror `normalizeKeyToken`,
`isSafeBareKey`, `canonicalizeDigitIndexBinding`, and
`findKeybindingConflictsForDefinitions` in Orca.

The same key in different scopes is not itself a conflict. Orca defaults reuse
`Mod+F` in browser/editor/terminal/settings and `Mod+L` in global/browser;
focus determines which UI handles them. The validator accepts these too.

However, absence of a detected conflict does not guarantee that overlap is useful.
All cross-scope overlaps in Orca defaults involve a focus-specific scope such as
browser/editor/terminal/fileExplorer/settings. None combines two always-active
scopes such as `global` and `tabs`. This configuration explicitly disables
`worktree.history.forward` with `null` because it shares the key used by
`tab.nextSameType`, even though the validator does not flag that overlap.

## Mapping to cmux

### Matching defaults (no override needed)

`cmd+,` settings / `cmd+b` sidebar / `cmd+t` new terminal / `cmd+w` close /
`cmd+r` rename/reload / `cmd+shift+t` reopen closed tab / `cmd+d` `cmd+shift+d` split /
`cmd+f` search / `cmd+[` `cmd+]` browser back/forward / `cmd+l` address bar /
`cmd+=` `cmd+-` `cmd+0` zoom / `cmd+1` select workspace / `ctrl+1` select tab.

`cmd+n` and `cmd+shift+n` match as keys but have different meanings: both invoke
`workspace.create` (create a worktree) in Orca, unlike cmux's separate
`newTab` and `newWindow` operations.

### Overrides in keybindings.json

| cmux | Keys | Orca action | Orca default | Rationale |
| --- | --- | --- | --- | --- |
| `goToWorkspace` | `cmd+p` | `worktree.palette` | `Mod+J` | Match cmux workspace navigation. |
| `commandPalette` | `cmd+shift+p` | `worktree.quickOpen` | `Mod+P` | Move off the key above. Orca has no command palette, so use file search. |
| `renameWorkspace` | `cmd+shift+r` | `workspace.rename` | `Mod+Alt+R` | — |
| `reloadConfiguration` | `cmd+shift+,` | `app.forceReload` | `Mod+Shift+R` | Free `Mod+Shift+R` for the row above and match cmux configuration reload. |
| `prevSidebarTab` / `nextSidebarTab` | `alt+↑` / `↓` | `worktree.navigateUp` / `navigateDown` | `Mod+Shift+Arrow` | Intentionally different from cmux, at the user's request: workspace navigation uses one modifier. |
| `prevSurface` / `nextSurface` | `cmd+alt+←` / `→` (also retain default `cmd+shift+[` / `]`) | `tab.previousAllTypes` / `nextAllTypes` | `Mod+Shift+Bracket*` | cmux surface cycling crosses types, so use AllTypes. SameType cannot move from a terminal to an editor tab. Retain the defaults explicitly to avoid startup migration diffs, as in the SameType row below. |
| `focusHistoryBack` / `Forward` (disabled in cmux) | — | `worktree.history.back` / `forward` | `Mod+Alt+ArrowLeft/Right` | `null`: shares the keys above, and was also disabled in cmux. Different scopes (`global` and `tabs`) evade conflict detection, but both are always active. |
| `focusLeft` / `focusRight` / `focusUp` / `focusDown` | `cmd+←` `→` / `cmd+↑` `↓` | `terminal.focusPreviousPane` / `focusNextPane` | `Mod+Bracket*` | Orca has no directional pane focus, only previous/next. Assign both axes to those two actions. With stacked panes this approximates up/down; with side-by-side panes, `cmd+↑` and `cmd+←` do the same thing. |
| `toggleSplitZoom` | `cmd+enter` | `terminal.expandPane` | `Mod+Shift+Enter` | — |
| No cmux equivalent | `cmd+alt+e` | `terminal.equalizePaneSizes` | None | Restore equal widths after repeated splits. The action has no default binding. The initial `cmd+alt+=` could not be entered on JIS, so use a letter instead. |
| `openBrowser` | `cmd+shift+l` | `tab.newBrowser` | `Mod+Shift+B` | — |
| No cmux equivalent | `cmd+alt+[` / `]` | `tab.previousSameType` / `nextSameType` | `Mod+Alt+Bracket*` | Explicitly retain the defaults after assigning arrows to AllTypes. Orca may append Mod+Alt+Bracket* during a one-time startup migration; declaring them prevents unexplained diffs. |
| `focusRightSidebar` (disabled in cmux) | — | `sidebar.right.toggle` | `Mod+L` | `null`, matching cmux and removing overlap with browser.focusAddressBar. Assign an unused key such as Mod+Alt+L if needed. |

### cmux keys without Orca equivalents

`closeOtherTabsInPane` / `editWorkspaceDescription` / `findNext` / `findPrevious` / `hideFind` /
`jumpToUnread` / `openFolder` / `sendFeedback` / `showBrowserJavaScriptConsole` / `showNotifications` /
`splitBrowserDown` / `splitBrowserRight` / `toggleBrowserDeveloperTools` / `toggleTerminalCopyMode` /
`triggerFlash` / `useSelectionForFind`.
Orca handles `closeWindow` / `quit` / `toggleFullScreen` through native menus.

### Intentionally unmatched operations

- **Same-type tab cycling (`tab.previousSameType` / `nextSameType`)** has no cmux
  equivalent. Keep default `cmd+alt+[` / `]` for cycling terminals only, for example.
- **`closeWorkspace` (`cmd+shift+w`)**: Orca's `workspace.delete` deletes rather than
  closes. Keep default `Mod+Shift+Backspace` to avoid accidental deletion when trying to close.
- **`toggleReactGrab` (`cmd+shift+g`)**: the closest action is `browser.grabElement`
  (default `Mod+C`), but cmux's feature is internal to cmux, so it is not matched.
  Orca uses `Mod+Shift+G` for `sidebar.sourceControl.toggle`.

## Shortcuts inside terminals

Orca defaults `terminalShortcutPolicy` to `orca-first`: app shortcuts take priority
even with a terminal pane focused. `terminal-first` limits this to `scope: terminal`
actions and a few marked `allowInTerminal`. The cmux #6007 limitation where Option
alone goes to the terminal and never triggers shortcuts does not apply by default.

Consequently, Orca consumes the workspace-navigation keys `alt+↑` / `↓` even in
terminal panes. Shell bindings using those keys, such as zsh history-substring-search,
will not work inside Orca.

## Background

For the investigation (how the format was established, management approaches,
and all 88 actions), see the setup#13 report in the issues repository:
`13-orca-keybindings-same-as-cmux/reports/2608291717-orca-keybindings-config.md`.
