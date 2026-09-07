---
name: cmux
description: Use this skill when the user asks about cmux, sending cmux notifications, managing workspaces, splitting panes, inspecting surfaces, updating status, or controlling the cmux browser; also use it when Codex / Claude Code running inside cmux needs to control cmux itself. It explains how to operate the manaflow-ai/cmux native macOS terminal through the cmux CLI and JSON-RPC socket API.
---

# cmux

`cmux` ([manaflow-ai/cmux](https://github.com/manaflow-ai/cmux)) is a native macOS terminal that groups multiple AI coding agent CLIs with vertical tabs, split panes, and a notification panel. This skill covers its bundled `cmux` CLI and UNIX socket control API.

## Important prerequisites

- Supported OS: **macOS only**.
- Target application: **manaflow-ai/cmux**, distinct from the Go library `soheilhy/cmux`.
- CLI socket path: `/tmp/cmux.sock`.
- The legacy `--panel` name remains a CLI compatibility alias; use `--surface` / `--pane` in new implementations.

## Installation and connectivity

If cmux is not installed, provide these steps:

```bash
brew tap manaflow-ai/cmux
brew install --cask cmux

# Symlink the CLI into /usr/local/bin
sudo ln -sf "/Applications/cmux.app/Contents/Resources/bin/cmux" /usr/local/bin/cmux

# Check connectivity (cmux.app must be running)
cmux ping
```

If `cmux ping` fails, launch cmux.app and try again.

## Core concepts for automation

| Term | Meaning |
|----|----|
| **Window** | A top-level macOS cmux window |
| **Workspace** | A group equivalent to a tab within a window |
| **Pane** | A split region within a workspace |
| **Surface** | A tab within a pane, hosting a terminal or browser |

IDs use `window:N`, `workspace:N`, `pane:N`, and `surface:N`. Many CLI arguments accept either an ID or an index.

> Older APIs use the term `panel`; newer APIs consistently use `surface`.

## Command quick reference

| Purpose | Command |
|----|----|
| Identify the caller's context | `cmux identify --json` |
| Get supported capabilities | `cmux capabilities` |
| Check connectivity | `cmux ping` |
| List windows | `cmux list-windows` |
| List workspaces | `cmux list-workspaces [--json]` |
| List panes | `cmux list-panes` |
| List surfaces | `cmux list-pane-surfaces --pane pane:1` |
| Create a workspace | `cmux new-workspace [--cwd <dir>]` |
| Switch workspaces | `cmux select-workspace --workspace workspace:2` |
| Split a pane | `cmux new-split <right\|down\|left\|up> --pane pane:1` |
| Move a surface | `cmux move-surface --surface surface:7 --pane pane:2 --focus true` |
| Reorder surfaces | `cmux reorder-surface --surface surface:7 --before surface:3` |
| Trigger a visual flash | `cmux trigger-flash --surface surface:7` |
| Send a notification | `cmux notify --title "..." [--body ...] [--workspace ...]` |
| List notifications | `cmux list-notifications [--json]` |
| Clear notifications | `cmux clear-notifications` |
| Set status | `cmux set-status <key> <value>` |
| Remove status | `cmux clear-status <key>` |
| Open a browser | `cmux --json browser open <url>` |
| Control a browser | `cmux browser <surface> <subcommand> ...` |

See `references/cli-commands.md` for detailed command options.

## Common workflows

### 1. Identify the current context

Codex / Claude Code running inside cmux should first call `identify` to locate itself.

```bash
cmux identify --json
# => {"window": "...", "workspace": "...", "pane": "...", "surface": "..."}
```

Pass the returned IDs to subsequent `--workspace` / `--surface` arguments.

### 2. Create and select a workspace

```bash
cmux new-workspace --cwd ~/Projects/frontend
cmux select-workspace --workspace workspace:2
```

### 3. Split a pane and arrange surfaces

```bash
cmux new-split right --pane pane:1
cmux move-surface --surface surface:7 --pane pane:2 --focus true
```

### 4. Get the user's attention with a notification

Use notifications to signal events such as build completion or pending approval from an AI agent to a user.

```bash
cmux notify --title "Claude Code" --subtitle "Permission" --body "Approval needed"
```

Add `--workspace workspace:2` to target a specific workspace. See `references/notifications.md` for details.

### 5. Represent idle / running state with status

```bash
cmux set-status copilot_cli Running
# Once processing finishes
cmux clear-status copilot_cli
```

The sidebar displays an icon and label.

### 6. Open and control a browser

cmux can host a browser in a surface, allowing AI agents to control web interfaces.

```bash
cmux --json browser open https://example.com
# => {"surface": "surface:7"}

cmux browser surface:7 wait --load-state complete --timeout-ms 15000
cmux browser surface:7 snapshot --interactive
cmux browser surface:7 click e1 --snapshot-after
```

See `references/agent-browser.md` for detailed browser operations and form input.

## AI agent integration patterns

cmux is designed to be called by other CLI coding agents, including Claude Code, Codex, and Copilot CLI. A typical integration using `hooks`:

```bash
# Notify when the agent stops
if command -v cmux &>/dev/null; then
  cmux notify --title 'Claude Code' --body 'Done'
  cmux clear-status claude_code
else
  osascript -e 'display notification "Done" with title "Claude Code"'
fi
```

Provide a fallback when `cmux` is unavailable by checking `command -v cmux`.

## Socket API for automation

Operations equivalent to the CLI are available through JSON-RPC over a UNIX socket. Use this for issuing many commands quickly from a script or controlling cmux from a language without a CLI wrapper.

```bash
echo '{"id":"1","method":"workspace.list","params":{}}' | nc -U /tmp/cmux.sock
echo '{"id":"2","method":"notification.create","params":{"title":"Hi","body":"Hello"}}' | nc -U /tmp/cmux.sock
```

See `references/socket-api.md` for methods and request / response formats.

## Troubleshooting

| Symptom | Resolution |
|----|----|
| `cmux ping` fails | cmux.app is not running. Launch it through Spotlight or another method. |
| `cmux: command not found` | The symlink is missing. Run `ln -sf ...` from the installation steps. |
| Existing scripts using `--panel` produce warnings | The compatibility alias still works, but replace it with `--surface` / `--pane`. |
| IDs and indexes are confused | Use `cmux list-*` to obtain exact IDs, then pass a prefix such as `--workspace workspace:N`. |
| Socket connection is refused | Check that cmux.app is running and use `ls -l` to check `/tmp/cmux.sock`. |

## Additional resources

- **`references/cli-commands.md`** — Complete CLI subcommand options and output formats
- **`references/socket-api.md`** — JSON-RPC socket methods, request / response formats, and error codes
- **`references/notifications.md`** — Notification and status details, with agent integration patterns
- **`references/agent-browser.md`** — `cmux browser` subcommands for navigation, snapshots, forms, and JavaScript evaluation

## Official documentation

- Repository: https://github.com/manaflow-ai/cmux
- Notification documentation: https://github.com/manaflow-ai/cmux/blob/main/docs/notifications.md
- agent-browser specification: https://github.com/manaflow-ai/cmux/blob/main/docs/agent-browser-port-spec.md
- V2 API migration: https://github.com/manaflow-ai/cmux/blob/main/docs/v2-api-migration.md
