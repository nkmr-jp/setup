#!/usr/bin/env python3
"""Set user-defined variable 'paneCount' to the number of panes in the current tab."""

import iterm2


async def update_all_pane_counts(connection):
    """Set paneCount for every session in every tab."""
    app = await iterm2.async_get_app(connection)
    for window in app.terminal_windows:
        for tab in window.tabs:
            count = len(tab.sessions)
            for session in tab.sessions:
                await session.async_set_variable("user.paneCount", count)


async def main(connection):
    await update_all_pane_counts(connection)

    async with iterm2.LayoutChangeMonitor(connection) as monitor:
        while True:
            await monitor.async_get()
            await update_all_pane_counts(connection)


iterm2.run_forever(main)
