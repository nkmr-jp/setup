# cmux

A skill plugin for controlling the [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux) native macOS terminal from Codex / Claude Code.

cmux is a macOS-only terminal that groups multiple AI coding agent CLIs with vertical tabs, split panes, and a notification panel. It supports external control through the `cmux` CLI and UNIX socket API (`/tmp/cmux.sock`). This plugin teaches Codex / Claude Code how to use them.

## Prerequisites

- macOS
- cmux.app must be installed and running (`brew install --cask cmux`).

## Install in Codex

Add the setup repository's marketplace and install the plugin:

```bash
codex plugin marketplace add ~/ghq/github.com/nkmr-jp/setup
codex plugin add cmux@setup
```

After installation, start a new thread to load the skill and hooks.

## Install in Claude Code

Add the setup repository's marketplace and install the plugin:

```bash
claude plugin marketplace add ~/ghq/github.com/nkmr-jp/setup
claude plugin install cmux@setup
```

## Included skills

| Skill | Purpose |
|----|----|
| [cmux](skills/cmux/SKILL.md) | Use the `cmux` CLI and socket API for workspaces, panes, surfaces, notifications, status, and agent-browser |

## Included hooks

| Event | Script | Purpose |
|----|----|----|
| `UserPromptSubmit` | [`hooks/scripts/claude-status-hook.sh running`](hooks/scripts/claude-status-hook.sh) | Set the sidebar pill to `bolt.fill` (#4C8DFF) |
| `PreToolUse` | [`hooks/scripts/claude-status-hook.sh running`](hooks/scripts/claude-status-hook.sh) | Restore `bolt.fill` (#4C8DFF) when tool execution resumes after a notification |
| `PostToolUse` | [`hooks/scripts/claude-status-hook.sh running`](hooks/scripts/claude-status-hook.sh) | Switch from `awaiting` to `bolt.fill` (#4C8DFF) after an AskUserQuestion answer or permission approval |
| `Notification` | [`hooks/scripts/claude-status-hook.sh awaiting`](hooks/scripts/claude-status-hook.sh) | Set the sidebar pill to `bell.fill` (#FF9500) |
| `PermissionRequest` | [`hooks/scripts/claude-status-hook.sh awaiting`](hooks/scripts/claude-status-hook.sh) | Set the pill to `bell.fill` (#FF9500) while Codex awaits approval |
| `Stop` | [`hooks/scripts/claude-status-hook.sh idle`](hooks/scripts/claude-status-hook.sh) | Set the pill to `pause.fill` (#8E8E93) when a response finishes |
| `SessionStart` | [`hooks/scripts/claude-status-hook.sh clear`](hooks/scripts/claude-status-hook.sh) | Clear stale state left by a missed SessionEnd and restore the `folder` icon |
| `SessionEnd` | [`hooks/scripts/claude-status-hook.sh clear`](hooks/scripts/claude-status-hook.sh) | Delete the state file and restore the `folder` icon |

Without `CMUX_PANEL_ID` (for Claude Code started outside cmux), the hook exits immediately without effects. zsh renders the pill through `~/.config/cmux/sidebar-cwd.zsh`, sharing state through `${TMPDIR}/cmux-pane-state/<panel-id>`.

The skill (`SKILL.md`) covers the overview and common workflows. Detailed references are split into these files:

| Reference | Contents |
|----|----|
| [cli-commands.md](skills/cmux/references/cli-commands.md) | CLI subcommand options and output formats |
| [socket-api.md](skills/cmux/references/socket-api.md) | JSON-RPC socket methods and invocation examples |
| [notifications.md](skills/cmux/references/notifications.md) | Notifications, status, and hook integration with other agents |
| [agent-browser.md](skills/cmux/references/agent-browser.md) | `cmux browser` subcommands for navigation, snapshots, forms, and JavaScript evaluation |

## Intended uses

- **Let Claude Code running inside cmux control cmux itself**: split panes, send notifications, and update status.
- **Answer cmux questions from a regular Claude Code session**: command usage and troubleshooting.

## Example triggers

The skill activates automatically for requests such as:

- "Send a notification in cmux."
- "Create a cmux workspace."
- "Split the cmux pane to the right."
- "List cmux surfaces."
- "Open example.com in the cmux browser."
- "Write a hook that notifies cmux when Claude Code finishes."

## Official resources

- Repository: https://github.com/manaflow-ai/cmux
- Notification documentation: https://github.com/manaflow-ai/cmux/blob/main/docs/notifications.md
- agent-browser specification: https://github.com/manaflow-ai/cmux/blob/main/docs/agent-browser-port-spec.md
