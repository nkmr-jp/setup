---
name: cmux
description: Control the manaflow-ai/cmux native macOS terminal via the cmux CLI and JSON-RPC socket API (workspaces, panes, surfaces, notifications, status, browser). Use when asked about cmux or operating cmux from inside a session.
---

# cmux

`cmux` ([manaflow-ai/cmux](https://github.com/manaflow-ai/cmux)) is a native macOS terminal that groups AI coding agent CLIs with vertical tabs, split panes, a notification panel, and embedded browser surfaces, controlled via the `cmux` CLI or UNIX socket API.

## Prerequisites and constraints

- **macOS only**; requires `cmux.app` to be running.
- Target is **manaflow-ai/cmux**, distinct from the Go library `soheilhy/cmux`.
- Socket path: `/tmp/cmux.sock`.
- Use `--surface` / `--pane` in new implementations (`panel` / `--panel` are legacy compatibility aliases).
- Always check `command -v cmux` and provide a fallback (such as `osascript`) in hooks or scripts that may run outside cmux.

## Core concepts and IDs

- Hierarchy: **Window** (`window:N`) > **Workspace** (`workspace:N`, tab group) > **Pane** (`pane:N`, split region) > **Surface** (`surface:N`, terminal or browser tab).
- Prefer prefixed IDs (`--workspace workspace:N`, `--surface surface:N`) over numeric indexes; obtain them with `cmux list-*` or `cmux identify --json`.
- When running inside cmux, call `cmux identify --json` first and pass its returned IDs to subsequent commands.

## Command quick reference

| Purpose | Command |
|----|----|
| Check connectivity / capabilities | `cmux ping` / `cmux capabilities` |
| Identify caller context | `cmux identify --json` |
| List topology | `cmux list-windows` / `list-workspaces [--json]` / `list-panes` / `list-pane-surfaces --pane pane:1` |
| Create / switch workspace | `cmux new-workspace [--cwd <dir>]` / `cmux select-workspace --workspace workspace:2` |
| Split pane / arrange surfaces | `cmux new-split <right\|down\|left\|up> --pane pane:1` / `move-surface --surface surface:7 --pane pane:2 --focus true` / `reorder-surface --surface surface:7 --before surface:3` |
| Flash a surface | `cmux trigger-flash --surface surface:7` |
| Notify / list / clear | `cmux notify --title "..." [--subtitle ...] [--body ...] [--workspace ...]` / `list-notifications [--json]` / `clear-notifications` |
| Set / clear sidebar status | `cmux set-status <key> <value>` / `cmux clear-status <key>` |
| Open / control browser | `cmux --json browser open <url>` / `cmux browser <surface> <subcommand> ...` |

## Setup and troubleshooting

If `cmux` is missing or `cmux ping` fails:

```bash
brew tap manaflow-ai/cmux && brew install --cask cmux
sudo ln -sf "/Applications/cmux.app/Contents/Resources/bin/cmux" /usr/local/bin/cmux
cmux ping
```

If `cmux ping` or socket calls fail, verify `cmux.app` is running and `/tmp/cmux.sock` exists (`ls -l /tmp/cmux.sock`).

## References (read as needed)

- [references/cli-commands.md](references/cli-commands.md) — Read for full subcommand flags, output formats, and exit code conventions.
- [references/notifications.md](references/notifications.md) — Read before configuring notifications, sidebar status keys (including the `claude_code` key caveat when `automation.claudeCodeIntegration` is enabled), or agent hook patterns.
- [references/agent-browser.md](references/agent-browser.md) — Read when automating a web page via `cmux browser` (`open` -> `wait --load-state complete` -> `snapshot --interactive` -> interact with `--snapshot-after`).
- [references/socket-api.md](references/socket-api.md) — Read when issuing bulk/scripted calls directly via the V2 NDJSON socket API (`/tmp/cmux.sock`).

## Official documentation

- Repository: https://github.com/manaflow-ai/cmux
- Notifications: https://github.com/manaflow-ai/cmux/blob/main/docs/notifications.md
- agent-browser specification: https://github.com/manaflow-ai/cmux/blob/main/docs/agent-browser-port-spec.md
- V2 API migration: https://github.com/manaflow-ai/cmux/blob/main/docs/v2-api-migration.md
