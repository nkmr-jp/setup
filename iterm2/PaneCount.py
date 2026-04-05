#!/usr/bin/env python3
"""Set user.paneCount and user.tabDirs for every session in each tab."""

import asyncio

import iterm2


async def update_tab_info(connection):
    """Set paneCount and tabDirs for every session in every tab."""
    app = await iterm2.async_get_app(connection)
    for window in app.terminal_windows:
        for tab in window.tabs:
            # tab.all_sessionsで最大化時の非表示ペイン(minimized_sessions)も含めて取得
            all_sessions = tab.all_sessions
            count = len(all_sessions)
            active_id = tab.active_session_id

            # 各セッションのcurrentDirを取得し、アクティブなペインは[]で囲む
            dirs = []
            for session in all_sessions:
                name = await session.async_get_variable("user.currentDir") or ""
                if session.session_id == active_id:
                    name = f"*{name}"
                dirs.append(name)
            tab_dirs = " ".join(dirs)

            for session in all_sessions:
                await session.async_set_variable("user.paneCount", count)
                await session.async_set_variable("user.tabDirs", tab_dirs)


async def monitor_layout(connection):
    """ペインの追加・削除を監視"""
    async with iterm2.LayoutChangeMonitor(connection) as monitor:
        while True:
            await monitor.async_get()
            await update_tab_info(connection)


async def monitor_focus(connection):
    """ペインのフォーカス変更を監視"""
    async with iterm2.FocusMonitor(connection) as monitor:
        while True:
            update = await monitor.async_get_next_update()
            if update.active_session_changed:
                await update_tab_info(connection)


async def monitor_current_dir(connection):
    """各セッションのuser.currentDir変更を監視"""
    app = await iterm2.async_get_app(connection)
    tasks = []
    for window in app.terminal_windows:
        for tab in window.tabs:
            for session in tab.all_sessions:
                tasks.append(_watch_session_dir(connection, session.session_id))
    await asyncio.gather(*tasks)


async def _watch_session_dir(connection, session_id):
    """単一セッションのcurrentDir変更を監視"""
    async with iterm2.VariableMonitor(
        connection,
        iterm2.VariableScopes.SESSION,
        "user.currentDir",
        session_id,
    ) as monitor:
        while True:
            await monitor.async_get()
            await update_tab_info(connection)


async def main(connection):
    await update_tab_info(connection)
    await asyncio.gather(
        monitor_layout(connection),
        monitor_focus(connection),
        monitor_current_dir(connection),
    )


iterm2.run_forever(main)
