#!/usr/bin/env python3
"""Set user.claudeSessions to icon string showing Claude session states.

Each interactive Claude Code session is shown as 🟡 (active) or 🟢 (idle).
Example: "🟡🟡🟢" means 2 active, 1 idle.
Empty string when no Claude sessions are running.
"""

import asyncio
import subprocess

import iterm2

POLL_INTERVAL = 5  # seconds
CPU_ACTIVE_THRESHOLD = 0.1  # % CPU above this is considered active
ICON_ACTIVE = "🟡"
ICON_IDLE = "🟢"


def get_claude_session_icons():
    """Build icon string from foreground Claude Code CLI processes."""
    result = subprocess.run(
        ["ps", "-eo", "tty,stat,comm,%cpu"],
        capture_output=True,
        text=True,
    )
    active = 0
    idle = 0
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 4 and parts[0].startswith("ttys") and "+" in parts[1] and parts[2] == "claude":
            try:
                if float(parts[3]) > CPU_ACTIVE_THRESHOLD:
                    active += 1
                else:
                    idle += 1
            except ValueError:
                idle += 1
    return ICON_ACTIVE * active + ICON_IDLE * idle


async def main(connection):
    while True:
        icons = get_claude_session_icons()
        app = await iterm2.async_get_app(connection)
        for window in app.terminal_windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    await session.async_set_variable("user.claudeSessions", icons)
        await asyncio.sleep(POLL_INTERVAL)


iterm2.run_forever(main)
