#!/usr/bin/env python3
"""Set user.paneCount to the number of panes in the current tab."""

import iterm2


async def update_pane_counts(connection):
    """Set paneCount for every session in every tab."""
    app = await iterm2.async_get_app(connection)
    for window in app.terminal_windows:
        for tab in window.tabs:
            # tab.sessionsは最大化時に表示中のセッションのみ返すため、
            # tab.root.sessionsで非表示ペインも含めた全セッションを取得する
            all_sessions = tab.root.sessions
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
