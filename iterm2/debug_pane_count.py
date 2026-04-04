#!/usr/bin/env python3
"""Debug script to inspect tab/pane structure in iTerm2."""

import iterm2


def inspect_node(node, depth=0):
    """Recursively inspect a split pane tree node."""
    indent = "  " * depth
    node_type = type(node).__name__
    lines = []

    if isinstance(node, iterm2.Session):
        lines.append(f"{indent}Session: id={node.session_id}, name={node.name}")
    elif isinstance(node, iterm2.SplitPane):
        lines.append(f"{indent}SplitPane: vertical={node.vertical}")
        for child in node.children:
            lines.extend(inspect_node(child, depth + 1))
    else:
        lines.append(f"{indent}{node_type}: {node}")
        if hasattr(node, "children"):
            for child in node.children:
                lines.extend(inspect_node(child, depth + 1))
        if hasattr(node, "sessions"):
            lines.append(f"{indent}  .sessions = {node.sessions}")
            lines.append(f"{indent}  len(.sessions) = {len(node.sessions)}")

    return lines


async def main(connection):
    app = await iterm2.async_get_app(connection)

    for window in app.terminal_windows:
        print(f"=== Window: {window.window_id} ===")
        for tab in window.tabs:
            print(f"\n--- Tab: {tab.tab_id} ---")

            # tab.sessions (visible sessions only)
            tab_sessions = tab.sessions
            print(f"tab.sessions (len={len(tab_sessions)}):")
            for s in tab_sessions:
                print(f"  Session: id={s.session_id}, name={s.name}")

            # tab.root
            root = tab.root
            print(f"\ntab.root type: {type(root).__name__}")
            print(f"tab.root: {root}")

            # tab.root.sessions
            root_sessions = root.sessions
            print(f"\ntab.root.sessions (len={len(root_sessions)}):")
            for s in root_sessions:
                print(f"  Session: id={s.session_id}, name={s.name}")

            # Tree structure
            print(f"\nTree structure:")
            for line in inspect_node(root):
                print(line)

            # Check active session
            active = tab.active_session
            print(f"\nActive session: id={active.session_id}, name={active.name}")

            # Check maximized state
            # tab.tmux_window_id might give hints, but let's check all attributes
            print(f"\nTab attributes:")
            for attr in dir(tab):
                if not attr.startswith("_") and not callable(getattr(tab, attr, None)):
                    try:
                        val = getattr(tab, attr)
                        print(f"  {attr} = {val}")
                    except Exception as e:
                        print(f"  {attr} = ERROR: {e}")

            # Check current paneCount variable
            print(f"\nCurrent user.paneCount per session:")
            for s in root_sessions:
                try:
                    count = await s.async_get_variable("user.paneCount")
                    print(f"  {s.session_id}: paneCount={count}")
                except Exception as e:
                    print(f"  {s.session_id}: ERROR: {e}")

    print("\n=== Done ===")


iterm2.run_until_complete(main)
