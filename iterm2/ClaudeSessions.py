#!/usr/bin/env python3
"""Set user.claudeSessions per-session using session name matching.

Shows 🟡 on sessions where Claude is actively working,
🟢 on sessions where Claude is idle (waiting for input),
and empty string on sessions without Claude.
"""

import asyncio
import subprocess

import iterm2

POLL_INTERVAL = 5  # seconds
CPU_ACTIVE_THRESHOLD = 0.1  # % CPU above this is considered active
ICON_ACTIVE = "🟡"
ICON_IDLE = "🟢"
CLAUDE_NAME_MARKER = "Claude Code"


def get_claude_tty_icons():
    """Return dict mapping TTY name to icon based on CPU usage.

    Example: {"ttys003": "🟡", "ttys007": "🟢"}
    """
    result = subprocess.run(
        ["ps", "-eo", "tty,stat,comm,%cpu"],
        capture_output=True,
        text=True,
    )
    icons = {}
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 4 and parts[0].startswith("ttys") and "+" in parts[1] and parts[2] == "claude":
            try:
                icon = ICON_ACTIVE if float(parts[3]) > CPU_ACTIVE_THRESHOLD else ICON_IDLE
            except ValueError:
                icon = ICON_IDLE
            icons[parts[0]] = icon
    return icons


async def main(connection):
    while True:
        icons = get_claude_tty_icons()
        # Default icon when session is detected but TTY doesn't match ps
        default_icon = ICON_ACTIVE if icons else ICON_IDLE
        app = await iterm2.async_get_app(connection)
        for window in app.terminal_windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    name = await session.async_get_variable("name")
                    if name and CLAUDE_NAME_MARKER in name:
                        tty = await session.async_get_variable("tty")
                        tty_short = tty.replace("/dev/", "") if tty else ""
                        icon = icons.get(tty_short, default_icon)
                        await session.async_set_variable("user.claudeSessions", icon)
                    else:
                        await session.async_set_variable("user.claudeSessions", "")
        await asyncio.sleep(POLL_INTERVAL)


iterm2.run_forever(main)
