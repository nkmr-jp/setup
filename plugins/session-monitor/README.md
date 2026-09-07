# session-monitor

A plugin that monitors active Codex / Claude Code sessions through hooks and lists them in the xbar menu bar.

```
⚡2 🔔1 ⏸3   ← Counts of concurrent running / awaiting / idle sessions
```

The dropdown shows each session's cwd, git branch, model, latest prompt excerpt, cumulative tokens, and last update time. Click an entry to open its cwd or transcript.

## How it works

1. Each hook event (`SessionStart` / `UserPromptSubmit` / `PreToolUse` / `PostToolUse` / `Notification` / `PermissionRequest` / `Stop` / `SessionEnd`) invokes `hooks/scripts/update-session.sh`.
2. The script extracts `session_id` / `transcript_path` / `cwd` / `hook_event_name` from JSON on stdin.
3. It scans the transcript JSONL backward with `tail -r` to find `gitBranch`, `model`, the latest user prompt, and `usage`, limiting the scan to the last 400 lines for large sessions.
4. It maps events to statuses as follows and upserts `$CLAUDE_PLUGIN_DATA/sessions.jsonl`:
   - `SessionStart` → `idle`
   - `UserPromptSubmit` / `PreToolUse` / `PostToolUse` → `running`
   - `Notification` / `PermissionRequest` → `awaiting`
   - `Stop` → `idle`
   - `SessionEnd` → Remove the entry
5. The xbar script (`xbar/claude-sessions.5s.sh`) reads sessions.jsonl every five seconds and renders the menu bar.

## Files

```
setup/
├── plugins/session-monitor/
│   ├── .claude-plugin/plugin.json       # Manifest
│   ├── hooks/
│   │   ├── hooks.json                   # Register update-session.sh for all hook events
│   │   └── scripts/update-session.sh    # Hook that upserts sessions.jsonl
│   └── README.md
└── xbar/
    ├── claude-sessions.5s.sh             # xbar plugin (refreshes every five seconds)
    │                                    # Managed in the repository's root xbar folder
    └── click-handler.sh                 # Dispatch menu item clicks
                                         # (focus cmux / activate an app / delete an entry)
```

xbar scripts live in the repository's root `xbar/` directory so future xbar plugins can be managed together.

## Dependencies

- [`jq`](https://jqlang.org/) — `brew install jq`
- [xbar](https://xbarapp.com/) (optional, for the menu bar display) — `brew install --cask xbar`

Without `jq`, the hook exits silently without affecting Claude Code.

## Installation

### 1. Enable as a Codex plugin

```bash
codex plugin marketplace add ~/ghq/github.com/nkmr-jp/setup
codex plugin add session-monitor@setup
```

After installation, start a new thread to load the hooks.

To enable it in Claude Code, use this repository's marketplace:

```bash
/plugin marketplace add nkmr-jp/setup
/plugin install session-monitor
/reload-plugins
```

### 2. Connect xbar

Symlink the repository's `xbar/claude-sessions.5s.sh` into xbar's Plugin Folder (`~/Library/Application Support/xbar/plugins/`):

```bash
ln -sf "$HOME/ghq/github.com/nkmr-jp/setup/xbar/claude-sessions.5s.sh" \
       "$HOME/Library/Application Support/xbar/plugins/claude-sessions.5s.sh"
```

Start or refresh xbar to display `⏸ 0` (zero sessions) in the menu bar. The count increases when Claude Code starts.

### 3. Data location

The hook writes `$CLAUDE_PLUGIN_DATA/sessions.jsonl`. The xbar script resolves the data directory through the anchor file `~/.claude/session-monitor/data-dir`, so Claude Code can manage the actual storage path.

## sessions.jsonl schema

Each line represents one session and contains a snapshot of its latest state.

```jsonc
{
  "session_id": "abc-123",
  "cwd": "/Users/your-user/ghq/github.com/nkmr-jp/setup",
  "git_branch": "master",
  "status": "running",                 // running | awaiting | idle
  "model": "claude-opus-4-7",
  "last_prompt": "Create a plugin to monitor the current session...",
  "updated_at": "2026-05-10T20:11:42Z",
  "last_event": "PostToolUse",
  "transcript_path": "/Users/nkmr/.claude/projects/.../session.jsonl",
  "last_assistant_at": "2026-05-10T20:11:40Z",
  "input_tokens": 1234,
  "output_tokens": 567,
  "cache_read_input_tokens": 89012
}
```

When `status` becomes `ended`, the entry is removed rather than retained.

## Debugging

```bash
# Data directory referenced by the anchor
cat ~/.claude/session-monitor/data-dir

# Current sessions.jsonl
DATA_DIR=$(cat ~/.claude/session-monitor/data-dir)
jq -r '"\(.status)\t\(.cwd)\t\(.last_prompt)"' "$DATA_DIR/sessions.jsonl"

# Inspect xbar script output directly
xbar/claude-sessions.5s.sh
```

Use `claude --debug` to observe hook events and their behavior.

## Design notes

- **Locking**: An atomic `mkdir` mutex prevents concurrent session hooks from corrupting sessions.jsonl, following the cmux pill approach.
- **Fast SessionEnd**: Claude Code imposes a short hook timeout, so `SessionEnd` immediately returns to its parent and completes its work in a child detached with `nohup`.
- **Stale entry cleanup**: Crashes can skip `SessionEnd` and leave idle entries. On each five-second cycle, xbar removes entries whose `updated_at` is more than one day old. To remove one sooner, use the final submenu action, "🗑 Delete from list".
