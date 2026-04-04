#!/usr/bin/env python3
"""Set user.paneCount to the number of panes in the current tab."""

import iterm2


async def update_pane_counts(connection):
    """Set paneCount for every session in every tab."""
    app = await iterm2.async_get_app(connection)
    for window in app.terminal_windows:
        for tab in window.tabs:
            # tab.all_sessionsで最大化時の非表示ペイン(minimized_sessions)も含めて取得
            all_sessions = tab.all_sessions
            count = len(all_sessions)
            for session in all_sessions:
                await session.async_set_variable("user.paneCount", count)


async def main(connection):
    await update_pane_counts(connection)

    async with iterm2.LayoutChangeMonitor(connection) as monitor:
        while True:
            await monitor.async_get()
            await update_pane_counts(connection)


iterm2.run_forever(main)
