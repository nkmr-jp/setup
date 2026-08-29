#!/usr/bin/env python3
"""keybindings.json を Orca 本体のアクション定義と突き合わせて検証する。

Orca は競合する override を **無言で捨てる**（Settings に diagnostic が出るだけで、
アプリの挙動としては「両方のショートカットが効かない」になる）ので、書いたつもりの
キーが黙って死ぬ。それを検知するのがこのスクリプト。

アクション定義は導入済みの Orca.app の app.asar から抽出するので、Orca を更新して
既定キーが変わった場合もそのまま追随する（更新後に流し直すと、上流の既定変更で
新しく競合が生まれていないか分かる）。

    ./check-keybindings.py [keybindings.json]

引数を省略すると同じディレクトリの keybindings.json を見る。
問題があれば内容を出力して exit 1。
"""

import json
import os
import re
import sys

ASAR = os.environ.get(
    "ORCA_ASAR", "/Applications/Orca.app/Contents/Resources/app.asar"
)
ROOT_KEYS = {"$schema", "version", "keybindings", "platforms"}
PLATFORMS = ("darwin", "linux", "win32")
MODIFIERS = {"MOD", "CMD", "CTRL", "ALT", "SHIFT"}
# 修飾子なしで許されるキー（allowBareKeybindings が付いたアクションのみ。
# ここでは緩めに通し、厳密な判定は Orca 本体に任せる）
BARE_OK = {
    "BACKSPACE", "DELETE", "ENTER", "ESCAPE", "TAB",
    "ARROWLEFT", "ARROWRIGHT", "ARROWUP", "ARROWDOWN", "PAGEUP", "PAGEDOWN",
}


def load_registry(asar_path):
    """app.asar から {actionId: {"bucket":..., "darwin":[...]}} を抽出する。"""
    with open(asar_path, "rb") as f:
        data = f.read().decode("utf-8", "ignore")
    heads = list(
        re.finditer(r'\{id:"([a-zA-Z]+(?:\.[a-zA-Z0-9]+)+)",title:"[^"]*",group:"[^"]*"', data)
    )
    registry = {}
    for i, head in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else head.start() + 800
        seg = data[head.start():end]
        m = re.search(r'defaultBindings:\{darwin:\[([^\]]*)\]', seg) or re.search(
            r'defaultBindings:\w+\(\[([^\]]*)\]', seg
        )
        raw = m.group(1) if m else ""
        scope = re.search(r'scope:"([^"]+)"', seg)
        group = re.search(r'conflictGroup:"([^"]+)"', seg)
        registry[head.group(1)] = {
            # 競合は conflictGroup ?? scope のバケット単位で判定される。
            # conflictGroup がある場合は scope 側のバケットでも見る（Orca 本体と同じ）。
            "buckets": {group.group(1) if group else (scope.group(1) if scope else "?")}
            | ({scope.group(1)} if group and scope else set()),
            "darwin": [x.strip().strip('"') for x in raw.split(",") if x.strip()],
        }
    return registry


def canonical(binding):
    """darwin 向けに正規化する（Mod は Cmd と同一視）。不正なら None。"""
    alias = {
        "UP": "ArrowUp", "DOWN": "ArrowDown", "LEFT": "ArrowLeft", "RIGHT": "ArrowRight",
        "[": "BracketLeft", "]": "BracketRight", ",": "Comma", ".": "Period",
        "-": "Minus", "=": "Equal", "/": "Slash", "\\": "Backslash", ";": "Semicolon",
        "RETURN": "Enter", "ESC": "Escape", "PGUP": "PageUp", "PGDN": "PageDown",
    }
    mods, key = [], None
    for part in [p.strip() for p in binding.split("+") if p.strip()]:
        upper = part.upper()
        if upper in MODIFIERS:
            mods.append("Cmd" if upper in ("MOD", "CMD") else upper.capitalize())
            continue
        if key is not None:
            return None
        key = alias.get(upper, alias.get(part, part if len(part) > 1 else part.upper()))
    if key is None:
        return None
    if not mods and key.upper() not in BARE_OK:
        return None
    order = [m for m in ("Cmd", "Ctrl", "Alt", "Shift") if m in mods]
    return "+".join(order + [key])


def identities(action_id, binding):
    """selectByIndex 系は 1〜9 に展開される（Orca 本体と同じ）。"""
    canon = canonical(binding)
    if canon is None:
        return []
    if action_id.endswith(".selectByIndex") and re.fullmatch(r"\d", canon.split("+")[-1]):
        base = "+".join(canon.split("+")[:-1])
        return [f"{base}+{n}" for n in range(1, 10)]
    return [canon]


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "keybindings.json"
    )
    if not os.path.exists(ASAR):
        print(f"skip: Orca が見つからない ({ASAR})")
        return 0
    registry = load_registry(ASAR)
    document = json.load(open(path))
    errors = []

    for key in document:
        if key not in ROOT_KEYS:
            errors.append(f"未知のルートキー: {key}（Orca は無視する）")

    # keybindings（共通）→ platforms.darwin の順にマージされる
    overrides = dict(document.get("keybindings") or {})
    overrides.update(document.get("platforms", {}).get("darwin") or {})

    for action_id, value in overrides.items():
        if action_id not in registry:
            errors.append(f"未知のアクション: {action_id}")
            continue
        for binding in value or []:
            if canonical(binding) is None:
                errors.append(f"キー指定が不正: {action_id} = {binding}")

    owners = {}
    for action_id, definition in registry.items():
        effective = definition["darwin"]
        if action_id in overrides:
            effective = overrides[action_id] or []
        for binding in effective:
            if canonical(binding) is None:
                continue
            for identity in identities(action_id, binding):
                for bucket in definition["buckets"]:
                    owners.setdefault((bucket, identity), set()).add(action_id)

    for (bucket, identity), action_ids in sorted(owners.items()):
        # override が絡む競合だけが「捨てられる」。既定同士は Orca が意図して重ねている。
        if len(action_ids) > 1 and action_ids & set(overrides):
            errors.append(
                f"競合（両方とも無効化される）: {bucket} / {identity} -> "
                + ", ".join(sorted(action_ids))
            )

    for platform in PLATFORMS:
        if platform not in document.get("platforms", {}):
            errors.append(f"platforms.{platform} が無い（Orca は書き戻し時に補うが明示しておく）")

    if errors:
        print(f"NG: {path}")
        for error in errors:
            print(f"  - {error}")
        return 1
    print(f"OK: {path}（{len(overrides)} 件の override / {len(registry)} アクション）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
