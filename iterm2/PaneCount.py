#!/usr/bin/env python3
"""Set user.paneCount and user.tabDirs for every session in each tab."""

import asyncio
import traceback

import iterm2

REFRESH_INTERVAL = 2.0
RETRY_INTERVAL = 1.0

# session_id -> (paneCount, tabDirs): iTerm2への冗長な書き込みとUI再描画を避ける
_last_set: dict = {}


async def update_tab_info(connection):
    app = await iterm2.async_get_app(connection)
    live_ids = set()
    for window in app.terminal_windows:
        for tab in window.tabs:
            # all_sessionsは最大化時の非表示ペイン(minimized_sessions)も含む
            all_sessions = tab.all_sessions
            count = len(all_sessions)
            active_id = tab.active_session_id

            dirs = []
            for session in all_sessions:
                name = await session.async_get_variable("user.currentDir") or ""
                if session.session_id == active_id:
                    name = f"*{name}"
                dirs.append(name)
            tab_dirs = " ".join(dirs)

            for session in all_sessions:
                sid = session.session_id
                live_ids.add(sid)
                new_val = (count, tab_dirs)
                if _last_set.get(sid) == new_val:
                    continue
                await session.async_set_variable("user.paneCount", count)
                await session.async_set_variable("user.tabDirs", tab_dirs)
                _last_set[sid] = new_val

    for sid in _last_set.keys() - live_ids:
        del _last_set[sid]


async def _retry_loop(coro_factory):
    while True:
        try:
            await coro_factory()
        except asyncio.CancelledError:
            raise
        except Exception:
            traceback.print_exc()
            await asyncio.sleep(RETRY_INTERVAL)


async def monitor_layout(connection):
    async def run():
        async with iterm2.LayoutChangeMonitor(connection) as monitor:
            while True:
                await monitor.async_get()
                await update_tab_info(connection)
    await _retry_loop(run)


async def monitor_focus(connection):
    async def run():
        async with iterm2.FocusMonitor(connection) as monitor:
            while True:
                update = await monitor.async_get_next_update()
                if update.active_session_changed:
                    await update_tab_info(connection)
    await _retry_loop(run)


async def periodic_refresh(connection):
    async def run():
        while True:
            await asyncio.sleep(REFRESH_INTERVAL)
            await update_tab_info(connection)
    await _retry_loop(run)


async def main(connection):
    await update_tab_info(connection)
    await asyncio.gather(
        monitor_layout(connection),
        monitor_focus(connection),
        periodic_refresh(connection),
    )


iterm2.run_forever(main)
