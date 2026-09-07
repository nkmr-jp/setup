# Complete cmux CLI reference

This reference lists the `cmux` binary's subcommands and options. Use `cmux <command> --help` for command-specific help. Many commands accept the common `--json` flag for machine-readable output.

---

## 1. Basic commands and inspection

### `cmux ping`

Check connectivity with cmux.app. Returns a short "ok" on success.

```bash
cmux ping
```

### `cmux identify [--json]`

Return the caller's context: its window, workspace, pane, and surface. This lets AI agents identify their location.

```bash
cmux identify --json
# => {"window":"window:1","workspace":"workspace:2","pane":"pane:3","surface":"surface:7"}
```

### `cmux capabilities`

Return the features and API version supported by cmux.app for compatibility checks.

```bash
cmux capabilities
```

---

## 2. List the topology

### `cmux list-windows [--json]`

List all cmux windows.

### `cmux list-workspaces [--json]`

List all workspaces across windows.

```bash
cmux list-workspaces --json
```

### `cmux list-panes [--workspace <id>] [--json]`

List panes, optionally filtered by `--workspace`.

### `cmux list-pane-surfaces --pane <pane-id> [--json]`

List the surfaces in a specific pane.

```bash
cmux list-pane-surfaces --pane pane:1 --json
```

---

## 3. Workspace management

### `cmux new-workspace [--cwd <dir>] [--window <id>] [--json]`

Create a workspace. `--cwd` sets the initial working directory; `--window` selects the destination window.

```bash
cmux new-workspace --cwd ~/Projects/frontend
```

### `cmux select-workspace --workspace <id>`

Focus the specified workspace.

```bash
cmux select-workspace --workspace workspace:2
```

### `cmux close-workspace --workspace <id>`

Close the workspace.

---

## 4. Layout operations (panes and surfaces)

### `cmux new-split <direction> --pane <id> [--cwd <dir>]`

Split a pane in one of four directions: `right`, `down`, `left`, or `up`.

```bash
cmux new-split right --pane pane:1
cmux new-split down --pane pane:2 --cwd ~/Projects
```

### `cmux move-surface --surface <id> --pane <id> [--focus true|false] [--index N]`

Move a surface to another pane.

```bash
cmux move-surface --surface surface:7 --pane pane:2 --focus true
```

### `cmux reorder-surface --surface <id> [--before <id>] [--after <id>] [--index N]`

Change the order within a pane.

```bash
cmux reorder-surface --surface surface:7 --before surface:3
```

### `cmux trigger-flash [--workspace <id>] [--surface <id>]`

Flash a surface or workspace to draw attention.

---

## 5. Notifications

### `cmux notify --title <text> [--subtitle <text>] [--body <text>] [--workspace <id>] [--tab <id|index>] [--panel <id|index>]`

Send a notification. `--workspace` associates it with a specific workspace in the sidebar. `--tab` and `--panel` are legacy compatibility names.

```bash
cmux notify --title "Build Complete"
cmux notify --title "Tests" --subtitle "Pass" --body "All 42 passed" --workspace workspace:2
```

### `cmux list-notifications [--json]`

Get the list of notifications.

```bash
cmux list-notifications --json
# => {"notifications":[{"id":"...","title":"...","body":"...","is_read":false}]}
```

### `cmux clear-notifications`

Clear all notifications.

---

## 6. Status

Display an icon and label, such as Running, Idle, or Error, in the sidebar.

### `cmux set-status <key> <value>`

`<key>` is an arbitrary agent identifier, such as `copilot_cli` or `claude_code`; `<value>` is the status label to display.

```bash
cmux set-status claude_code Running
```

### `cmux clear-status <key>`

Remove the status for the specified key.

---

## 7. Agent browser

Create a browser surface and control it with a Playwright-like CLI. See `agent-browser.md` for details.

```bash
cmux --json browser open <url>                  # Create a browser surface
cmux browser <surface> <subcommand> ...         # Control an existing surface
```

Common `<subcommand>` values: `get url`, `wait`, `snapshot`, `click`, `fill`, `type`, `press`, `select`, `check`, `scroll`, `eval`, and `get text|html|value|attr|count|box|styles`.

---

## 8. Common flags

| Flag | Meaning |
|----|----|
| `--json` | Produce machine-readable JSON output |
| `--surface <id>` | Select the target surface |
| `--pane <id>` | Select the target pane |
| `--workspace <id>` | Select the target workspace |
| `--window <id>` | Select the target window |
| `--panel <id>` | Legacy name; migrate to `--surface` / `--pane` |

---

## 9. Exit codes and output conventions

- Success: exit code `0`, with text or JSON on stdout.
- Failure: a nonzero exit code, with an error message on stderr.
- With `--json`, failures may also return an error object (`{"error":{...}}`).
