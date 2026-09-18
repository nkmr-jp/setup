# cmux

A skill plugin for controlling the [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux) native macOS terminal from Codex / Claude Code / Devin CLI.

cmux is a macOS-only terminal that groups multiple AI coding agent CLIs with vertical tabs, split panes, and a notification panel. It supports external control through the `cmux` CLI and UNIX socket API (`/tmp/cmux.sock`). This plugin teaches Codex / Claude Code / Devin CLI how to use them.

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

## Install in Devin CLI

Install the plugin from the setup repository subfolder:

```bash
devin plugins install nkmr-jp/setup#plugins/cmux
```

For local development against a checkout, use `--local` so edits apply on the
next session:

```bash
devin plugins install --local ~/ghq/github.com/nkmr-jp/setup/plugins/cmux
```

The skill is available as `/cmux:cmux`. Verify the loaded skills and hooks with
`devin plugins info cmux`.

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
| `Notification` | [`hooks/scripts/claude-status-hook.sh awaiting`](hooks/scripts/claude-status-hook.sh) | Set the sidebar pill to `bell.fill` (#FF9500) (Claude Code only) |
| `PermissionRequest` | [`hooks/scripts/claude-status-hook.sh awaiting`](hooks/scripts/claude-status-hook.sh) | Set the pill to `bell.fill` (#FF9500) while the agent awaits approval |
| `Stop` | [`hooks/scripts/claude-status-hook.sh idle`](hooks/scripts/claude-status-hook.sh) | Set the pill to `pause.fill` (#8E8E93) when a response finishes |
| `SessionStart` | [`hooks/scripts/claude-status-hook.sh clear`](hooks/scripts/claude-status-hook.sh) | Clear stale state left by a missed SessionEnd and restore the `folder` icon |
| `SessionEnd` | [`hooks/scripts/claude-status-hook.sh clear`](hooks/scripts/claude-status-hook.sh) | Delete the state file and restore the `folder` icon |

Devin CLI only, the workspace title gets a Claude Code-style status line
appended after a ` ▸ ` marker, because Devin has no native statusLine feature
and sidebar pills truncate long labels.
[`hooks/scripts/devin-statusline-hook.sh`](hooks/scripts/devin-statusline-hook.sh)
renames the workspace to `<base title> ▸ <dir> · <branch> · <session> · <model> · <elapsed> · <ctx tokens> · <diff>`
on `SessionStart` / `UserPromptSubmit` / `PermissionRequest` / `PostCompaction` /
`Stop`, refreshes it on `PostToolUse` at most every 15 seconds, and strips the
marker on `SessionEnd` (leaving the base title). Each refresh strips the existing marker
suffix first, so title rewrites by ccdash's autotitle just fall back to the
base title until the next update. Session data (model, created_at, context
tokens) comes from `~/.local/share/devin/cli/sessions.db`; the workspace
mapping comes from `~/.claude/cmux/hook-sessions.json`, so the status only
appears for Devin sessions running inside cmux.

Each agent reads a different hooks file:

| Agent | File | Notes |
|----|----|----|
| Claude Code | [`hooks/claude.json`](hooks/claude.json) | All events above, referenced through the `hooks` field of `.claude-plugin/plugin.json` |
| Devin CLI | [`hooks/hooks.json`](hooks/hooks.json) | Same events except `Notification`, which Devin does not support. Devin rejects the entire file if it contains an unknown event, so the Claude version lives in a separate file. Devin also reads the root `hooks.json`, which stays in AGY format and simply registers no Devin events |
| AGY / Codex | [`hooks.json`](hooks.json) (plugin root) | `PreInvocation` / `PostInvocation` / `PreToolUse` / `PostToolUse` / `Stop` |

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
