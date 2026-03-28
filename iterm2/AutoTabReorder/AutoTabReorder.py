#!/usr/bin/env python3
"""iTerm2 タブ自動並べ替えスクリプト

セッションの更新が新しい順にタブを自動で並べ替える。
zsh の precmd フックで設定される user.lastActivity 変数を監視し、
アクティブになったセッションのタブをウィンドウの先頭（左端）に移動する。

デプロイ:
  ln -s ~/ghq/github.com/nkmr-jp/setup/iterm2/AutoTabReorder \\
    ~/Library/Application\\ Support/iTerm2/Scripts/AutoTabReorder
"""

import iterm2


async def main(connection):
    async def reorder_tab_to_front(session_id):
        app = await iterm2.async_get_app(connection)
        for window in app.terminal_windows:
            for tab in window.tabs:
                if any(s.session_id == session_id for s in tab.sessions):
                    if window.tabs[0] == tab:
                        return
                    new_order = [tab] + [t for t in window.tabs if t != tab]
                    await window.async_set_tabs(new_order)
                    return

    last_session = None
    async with iterm2.VariableMonitor(
        connection,
        iterm2.VariableScopes.SESSION,
        "user.lastActivity",
        None,
    ) as mon:
        while True:
            change = await mon.async_get()
            if change.session != last_session:
                await reorder_tab_to_front(change.session)
                last_session = change.session


iterm2.run_forever(main)
