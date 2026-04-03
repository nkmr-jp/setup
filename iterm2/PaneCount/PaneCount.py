#!/usr/bin/env python3
"""Set user-defined variables for tab status display.

Variables:
  user.paneCount          - number of panes in the current tab
  user.claudeSessionCount - number of active Claude Code interactive sessions
"""

import asyncio
import subprocess

import iterm2

CLAUDE_POLL_INTERVAL = 5  # seconds


def get_claude_session_count():
    """Count foreground Claude Code CLI processes attached to a TTY."""
    result = subprocess.run(
        ["ps", "-eo", "tty,stat,comm"],
        capture_output=True,
        text=True,
    )
    count = 0
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[0].startswith("ttys") and "+" in parts[1] and parts[2] == "claude":
            count += 1
    return count


async def update_pane_counts(connection):
    """Set paneCount for every session in every tab."""
    app = await iterm2.async_get_app(connection)
    for window in app.terminal_windows:
        for tab in window.tabs:
            count = len(tab.sessions)
            for session in tab.sessions:
                await session.async_set_variable("user.paneCount", count)


async def update_claude_session_count(connection):
    """Set claudeSessionCount for every session."""
    count = get_claude_session_count()
    app = await iterm2.async_get_app(connection)
    for window in app.terminal_windows:
        for tab in window.tabs:
            for session in tab.sessions:
                await session.async_set_variable("user.claudeSessionCount", count)


async def poll_claude_sessions(connection):
    """Periodically update Claude session count."""
    while True:
        await update_claude_session_count(connection)
        await asyncio.sleep(CLAUDE_POLL_INTERVAL)


async def watch_layout_changes(connection):
    """Update pane counts on layout changes."""
    async with iterm2.LayoutChangeMonitor(connection) as monitor:
        while True:
            await monitor.async_get()
            await update_pane_counts(connection)


async def main(connection):
    await update_pane_counts(connection)
    await update_claude_session_count(connection)

    await asyncio.gather(
        watch_layout_changes(connection),
        poll_claude_sessions(connection),
    )


iterm2.run_forever(main)
