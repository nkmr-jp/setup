#!/usr/bin/env python3
"""Set user-defined variables for tab status display.

Variables:
  user.paneCount          - number of panes in the current tab
  user.claudeSessionCount - number of active Claude Code interactive sessions
  user.claudeActiveCount  - number of actively working Claude sessions (CPU > 0%)
  user.claudeIdleCount    - number of idle Claude sessions (waiting for input)
"""

import asyncio
import subprocess

import iterm2

CLAUDE_POLL_INTERVAL = 5  # seconds
CPU_ACTIVE_THRESHOLD = 0.1  # % CPU above this is considered active


def get_claude_session_stats():
    """Count foreground Claude Code CLI processes by state.

    Returns (total, active, idle) counts.
    """
    result = subprocess.run(
        ["ps", "-eo", "tty,stat,comm,%cpu"],
        capture_output=True,
        text=True,
    )
    total = 0
    active = 0
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 4 and parts[0].startswith("ttys") and "+" in parts[1] and parts[2] == "claude":
            total += 1
            try:
                if float(parts[3]) > CPU_ACTIVE_THRESHOLD:
                    active += 1
            except ValueError:
                pass
    return total, active, total - active


async def update_pane_counts(connection):
    """Set paneCount for every session in every tab."""
    app = await iterm2.async_get_app(connection)
    for window in app.terminal_windows:
        for tab in window.tabs:
            count = len(tab.sessions)
            for session in tab.sessions:
                await session.async_set_variable("user.paneCount", count)


async def update_claude_session_stats(connection):
    """Set Claude session variables for every session."""
    total, active, idle = get_claude_session_stats()
    app = await iterm2.async_get_app(connection)
    for window in app.terminal_windows:
        for tab in window.tabs:
            for session in tab.sessions:
                await session.async_set_variable("user.claudeSessionCount", total)
                await session.async_set_variable("user.claudeActiveCount", active)
                await session.async_set_variable("user.claudeIdleCount", idle)


async def poll_claude_sessions(connection):
    """Periodically update Claude session stats."""
    while True:
        await update_claude_session_stats(connection)
        await asyncio.sleep(CLAUDE_POLL_INTERVAL)


async def watch_layout_changes(connection):
    """Update pane counts on layout changes."""
    async with iterm2.LayoutChangeMonitor(connection) as monitor:
        while True:
            await monitor.async_get()
            await update_pane_counts(connection)


async def main(connection):
    await update_pane_counts(connection)
    await update_claude_session_stats(connection)

    await asyncio.gather(
        watch_layout_changes(connection),
        poll_claude_sessions(connection),
    )


iterm2.run_forever(main)
