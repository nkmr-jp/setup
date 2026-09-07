# cmux notifications and status reference

Notifications are the main way for AI agents to get a user's attention in cmux. They provide sidebar badges, macOS system notifications, and blue rings around surfaces with unread notifications.

## Notification features

- **Sidebar display**: Show notifications with unread badges in the cmux sidebar.
- **macOS notifications**: Optionally send system notifications to Notification Center.
- **Blue ring**: Highlight terminal panes that have unread notifications with a blue border.
- **Workspace targeting**: Associate a notification with a specific workspace using `--workspace`.

## CLI usage

### Send a notification

```bash
# Minimal notification (title only)
cmux notify --title "Build Complete"

# Include a body
cmux notify --title "Claude Code" --body "Waiting for input"

# Include a subtitle and body
cmux notify --title "Claude Code" --subtitle "Permission" --body "Approval needed"

# Target a specific workspace
cmux notify --title "Tests Passed" --body "All 42 tests passed" --workspace workspace:2
```

### List and clear notifications

```bash
# List as text
cmux list-notifications
# [unread] Build Complete - Your build finished
# [read] Tests Passed - All tests passed

# JSON output for programmatic use
cmux list-notifications --json
# {"notifications":[{"id":"...","title":"...","body":"...","is_read":false}]}

# Clear all notifications
cmux clear-notifications
```

## Status

Status displays values such as running, idle, or error in the sidebar. Unlike notifications, it **overwrites** the previous value when the same key is set again.

```bash
# Set status
cmux set-status claude_code Running
cmux set-status copilot_cli Idle

# Remove status
cmux clear-status claude_code
```

> **Note**: While cmux has `automation.claudeCodeIntegration: true`, the daemon manages
> the `claude_code` key. External `cmux set-status claude_code ...` calls return `OK` but
> are **silently ignored** (verified on a real system in setup#3). External updates are
> only possible through cmux's own `cmux hooks claude <event>`, which is affected by
> the upstream turnId drift bug (issue #1027). Do not build a custom write layer on it.

### Key naming conventions

Use `<agent>_cli` or `<agent>` by convention:

- `claude_code`
- `copilot_cli`
- `codex`
- Any custom agent identifier

### Conventional status values

- `Running` — Processing
- `Idle` — Idle
- `Error` — An error occurred
- `Waiting` — Waiting for input

---

## Notifications through the socket API

Use JSON-RPC for operations equivalent to the CLI.

```bash
# Create
echo '{"id":"1","method":"notification.create","params":{"title":"Hello","body":"World"}}' | nc -U /tmp/cmux.sock

# List
echo '{"id":"2","method":"notification.list","params":{}}' | nc -U /tmp/cmux.sock

# Clear
echo '{"id":"3","method":"notification.clear","params":{}}' | nc -U /tmp/cmux.sock
```

For status:

```bash
echo '{"id":"4","method":"status.set","params":{"key":"claude_code","value":"Running"}}' | nc -U /tmp/cmux.sock
echo '{"id":"5","method":"status.clear","params":{"key":"claude_code"}}' | nc -U /tmp/cmux.sock
```

---

## Agent integration patterns

### Pattern 1: Report build results from a shell script

```bash
#!/bin/bash
npm run build
if [ $? -eq 0 ]; then
    cmux notify --title "Build Success" --body "Ready to deploy"
else
    cmux notify --title "Build Failed" --body "Check the logs"
fi
```

### Pattern 2: Integrate hooks in GitHub Copilot CLI or other agents

For agent CLIs with a `hooks` mechanism, configure lifecycle events to call `cmux`. Include a fallback for environments without `cmux` installed.

```json
{
  "hooks": {
    "userPromptSubmitted": [
      {
        "type": "command",
        "bash": "if command -v cmux &>/dev/null; then cmux set-status copilot_cli Running; fi",
        "timeoutSec": 3
      }
    ],
    "agentStop": [
      {
        "type": "command",
        "bash": "if command -v cmux &>/dev/null; then cmux notify --title 'Copilot CLI' --body 'Done'; cmux set-status copilot_cli Idle; else osascript -e 'display notification \"Done\" with title \"Copilot CLI\"'; fi",
        "timeoutSec": 5
      }
    ],
    "errorOccurred": [
      {
        "type": "command",
        "bash": "if command -v cmux &>/dev/null; then cmux notify --title 'Copilot CLI' --subtitle 'Error' --body \"$(cat | jq -r '.errorMessage // \"An error occurred\"' 2>/dev/null | head -c 100)\"; cmux set-status copilot_cli Error; else osascript -e 'display notification \"An error occurred\" with title \"Copilot CLI\"'; fi",
        "timeoutSec": 5
      }
    ],
    "sessionEnd": [
      {
        "type": "command",
        "bash": "if command -v cmux &>/dev/null; then cmux clear-status copilot_cli; fi",
        "timeoutSec": 3
      }
    ]
  }
}
```

### Pattern 3: Call from a Claude Code Stop hook

Example of sending cmux notifications from Claude Code `Stop` / `Notification` hooks (`hooks.json`):

```json
{
  "Stop": [{
    "matcher": "",
    "hooks": [{
      "type": "command",
      "command": "command -v cmux >/dev/null && cmux notify --title 'Claude Code' --body 'Done'",
      "timeout": 5
    }]
  }]
}
```

---

## Troubleshooting

| Symptom | Cause / resolution |
|----|----|
| Notifications do not appear | cmux.app is not running. Check connectivity with `cmux ping`. |
| macOS system notifications do not appear | Allow notifications for cmux.app in System Settings > Notifications. |
| Notifications remain visible | Remove all of them with `cmux clear-notifications`. |
| Status disappears immediately | Another process may overwrite the same key. Use a unique key. |

---

## Related resources

- Detailed CLI options: `cli-commands.md`
- General socket API reference: `socket-api.md`
- Official documentation: https://github.com/manaflow-ai/cmux/blob/main/docs/notifications.md
