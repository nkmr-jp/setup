#!/usr/bin/env python3
"""Set user.claudeSessions per-session based on TTY matching.

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


def get_claude_tty_states():
    """Return dict mapping TTY device name to icon.

    Example: {"/dev/ttys003": "🟡", "/dev/ttys007": "🟢"}
    """
    result = subprocess.run(
        ["ps", "-eo", "tty,stat,comm,%cpu"],
        capture_output=True,
        text=True,
    )
    states = {}
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 4 and parts[0].startswith("ttys") and "+" in parts[1] and parts[2] == "claude":
            tty = f"/dev/{parts[0]}"
            try:
                icon = ICON_ACTIVE if float(parts[3]) > CPU_ACTIVE_THRESHOLD else ICON_IDLE
            except ValueError:
                icon = ICON_IDLE
            states[tty] = icon
    return states


async def main(connection):
    while True:
        states = get_claude_tty_states()
        app = await iterm2.async_get_app(connection)
        for window in app.terminal_windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    tty = await session.async_get_variable("tty")
                    icon = states.get(tty, "")
                    await session.async_set_variable("user.claudeSessions", icon)
        await asyncio.sleep(POLL_INTERVAL)


iterm2.run_forever(main)
