#!/usr/bin/env python3
"""keybindings.json を Orca 本体のアクション定義と突き合わせて検証する。

Orca は受け付けられない override や競合する override を **無言で捨てる**（Settings に
diagnostic が出るだけ）。捨てられた override は無効になるのではなく**そのアクションの
既定キーに戻る**ので、「書いたキーが効かず、代わりに既定のキーが動いている」という
気づきにくい壊れ方をする。それを検知するのがこのスクリプト。

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
DIGIT_INDEX_ACTIONS = {"tab.selectByIndex", "workspace.selectByIndex"}
FUNCTION_KEY = re.compile(r"^F([1-9]|1[0-9]|2[0-4])$")

# 以下は Orca 本体（app.asar の parseModifierToken / normalizeKeyToken /
# isSafeBareKey）の写し。ここがずれると「書いたキーが既定と同じだと気づけない」
# ＝競合検知をすり抜けるので、Orca 側が変わったら合わせる。
MODIFIER_ALIASES = {
    "MOD": "Mod", "CMDORCTRL": "Mod", "COMMANDORCONTROL": "Mod",
    "CMD": "Cmd", "COMMAND": "Cmd", "META": "Cmd", "⌘": "Cmd",
    "CTRL": "Ctrl", "CONTROL": "Ctrl", "⌃": "Ctrl",
    "ALT": "Alt", "OPTION": "Alt", "OPT": "Alt", "⌥": "Alt",
    "SHIFT": "Shift", "⇧": "Shift",
}
KEY_ALIASES = {
    "[": "BracketLeft", "]": "BracketRight", "{": "BracketLeft", "}": "BracketRight",
    "-": "Minus", "_": "Underscore", "=": "Equal", "+": "Plus",
    ",": "Comma", ".": "Period", "/": "Slash", "\\": "Backslash",
    ";": "Semicolon", "'": "Quote", "`": "Backquote",
    "RETURN": "Enter", "ESC": "Escape", "SPACEBAR": "Space",
    "PGUP": "PageUp", "PGDN": "PageDown",
    "PLUS": "Plus", "MINUS": "Minus", "EQUAL": "Equal", "UNDERSCORE": "Underscore",
    "ARROWLEFT": "ArrowLeft", "LEFT": "ArrowLeft",
    "ARROWRIGHT": "ArrowRight", "RIGHT": "ArrowRight",
    "ARROWUP": "ArrowUp", "UP": "ArrowUp",
    "ARROWDOWN": "ArrowDown", "DOWN": "ArrowDown",
    "PAGEUP": "PageUp", "PAGEDOWN": "PageDown",
    "BACKSPACE": "Backspace", "DELETE": "Delete", "DEL": "Delete",
    "INSERT": "Insert", "INS": "Insert",
    "ENTER": "Enter", "TAB": "Tab", "ESCAPE": "Escape", "SPACE": "Space",
    "BRACKETLEFT": "BracketLeft", "BRACKETRIGHT": "BracketRight",
    "NUMPADADD": "NumpadAdd", "NUMPADSUBTRACT": "NumpadSubtract",
    "ADD": "NumpadAdd", "SUBTRACT": "NumpadSubtract",
    "COMMA": "Comma", "PERIOD": "Period", "SLASH": "Slash",
    "BACKSLASH": "Backslash", "SEMICOLON": "Semicolon",
    "QUOTE": "Quote", "BACKQUOTE": "Backquote",
}
# 修飾子なしで許されるキー（実際に許されるのは allowBareKeybindings が付いた
# アクションだけ。ここでは緩めに通し、厳密な判定は Orca 本体に任せる）
BARE_OK = {
    "Backspace", "Delete", "Enter", "Escape", "Tab",
    "ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "PageUp", "PageDown",
}


def load_registry(asar_path):
    """app.asar から {actionId: {"buckets":..., "darwin":[...]}} を抽出する。"""
    with open(asar_path, "rb") as f:
        data = f.read().decode("utf-8", "ignore")
    heads = list(
        re.finditer(r'\{id:"([a-zA-Z]+(?:\.[a-zA-Z0-9]+)+)",title:"[^"]*",group:"[^"]*"', data)
    )
    registry = {}
    for i, head in enumerate(heads):
        if i + 1 < len(heads):
            end = heads[i + 1].start()
        else:
            # 最後の 1 件は「次の定義」が無い。固定長で切ると searchKeywords が長い
            # 定義の defaultBindings を取りこぼして競合を見逃すので、次の `{id:"` まで、
            # 無ければ十分に広い窓を取る。
            nxt = data.find('{id:"', head.start() + 1)
            end = nxt if nxt != -1 else head.start() + 8000
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
            # 修飾子なし／Shift 単独を許すかはアクションごとに違う（実測で前者 3 件・後者 1 件）。
            # 同じセグメントから取れるので、アクションを見ない緩い判定にしない。
            "allow_bare": "allowBareKeybindings:!0" in seg,
            "allow_shift_only": "allowShiftOnlyKeybindings:!0" in seg,
            "digit_index": head.group(1) in DIGIT_INDEX_ACTIONS,
        }
    return registry


def normalize_key(token):
    """Orca の normalizeKeyToken 相当。未知のキー名は None（Orca も拒否する）。"""
    if token == " ":
        return "Space"
    trimmed = token.strip()
    if not trimmed:
        return None
    upper = trimmed.upper()
    if len(upper) == 1 and upper.isascii() and upper.isalnum():
        return upper
    if FUNCTION_KEY.match(upper):
        return upper
    return KEY_ALIASES.get(upper)


def canonical(binding, definition=None):
    """darwin 向けに正規化する（Mod は Cmd と同一視）。Orca が受け付けないものは None。

    `definition`（load_registry の 1 エントリ）を渡すと、そのアクションに許された
    修飾子なしキー・digit index の制約まで見る。渡さないと**緩く通してしまう**ので、
    アクションが分かる場所では必ず渡すこと（渡し忘れが見逃しになる）。
    """
    # Orca は文字列値も配列要素も、まず `,` で split してから 1 つずつパースする
    # （normalizeKeybindingListWithOptions）。`Mod+Shift+,` のようにキー名として
    # カンマを書くと分割されてパースに失敗し、**override 全体が捨てられる**。
    # `Comma` と書けば通るので、ここでは lint として一律拒否する。
    if "," in binding:
        return None
    parts = [p.strip() for p in binding.split("+") if p.strip()]
    if not parts:
        return None
    if any(p.lower() == "doubletap" for p in parts):
        # Orca の parseDoubleTapKeybinding は修飾子ちょうど 1 つだけを受ける。
        tokens = [MODIFIER_ALIASES.get(p.upper()) for p in parts if p.lower() != "doubletap"]
        if len(tokens) != 1 or tokens[0] is None:
            return None
        # darwin では Mod = Cmd。ここを分けると同じ二度押しの競合を見逃す。
        token = "Cmd" if tokens[0] == "Mod" else tokens[0]
        return f"DoubleTap+{token}"
    mods, key = set(), None
    for part in parts:
        modifier = MODIFIER_ALIASES.get(part.upper())
        if modifier:
            mods.add(modifier)
            continue
        if key is not None:
            return None
        key = normalize_key(part)
        if key is None:
            return None
    if key is None:
        return None
    if "Mod" in mods and ("Cmd" in mods or "Ctrl" in mods):
        return None  # Orca: "Use either Mod or a platform-specific modifier, not both."

    allow_bare = bool(definition and definition["allow_bare"])
    allow_shift_only = bool(definition and definition["allow_shift_only"])
    if not (mods - {"Shift"}):  # 修飾子が Shift だけ／全く無い
        # Orca の normalizeKeybindingWithOptions + isSafeBareKey と同じ判定。
        # 修飾子なしを許すのは allowBareKeybindings が付いた 3 アクションだけ、
        # Shift 単独は allowShiftOnlyKeybindings が付いた 1 アクションだけ。
        # ここをアクションに関係なく通していたため、`{"tab.close": ["Enter"]}` のような
        # 「Orca が override ごと捨てる」設定を OK と報告していた。
        is_function = bool(FUNCTION_KEY.match(key))
        if "Shift" in mods:
            safe_bare = allow_bare and is_function
            allowed = (key == "Insert") or safe_bare or allow_shift_only
        else:
            allowed = allow_bare and (is_function or key in BARE_OK)
        if not allowed:
            return None

    if definition and definition["digit_index"]:
        # tab.selectByIndex / workspace.selectByIndex は 1〜9 のみ受け付け、
        # それ以外だと override が丸ごと捨てられる（canonicalizeDigitIndexBinding）。
        if not re.fullmatch(r"[1-9]", key):
            return None
        key = "1"  # Orca 自身が 1 に正規化する

    # darwin では Mod = Cmd。修飾子の並び順を固定して同一性の判定に使う。
    meta = "Mod" in mods or "Cmd" in mods
    order = (["Cmd"] if meta else []) + [m for m in ("Ctrl", "Alt", "Shift") if m in mods]
    return "+".join(order + [key])


def as_bindings(value):
    """Orca の normalizeBindingValue 相当。文字列 / 文字列配列 / null / false を受ける。"""
    if value is None or value is False:
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, list) and all(isinstance(item, str) for item in value):
        return list(value)
    return None


def identities(action_id, binding, definition):
    """selectByIndex 系は 1〜9 に展開される（Orca 本体と同じ）。"""
    canon = canonical(binding, definition)
    if canon is None:
        return []
    if action_id in DIGIT_INDEX_ACTIONS and re.fullmatch(r"[1-9]", canon.split("+")[-1]):
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
    # 抽出は minify 済みの blob への正規表現なので、Orca の更新でパターンが壊れると
    # 「一部しか取れていないのに OK」になりうる（競合を見逃す＝このスクリプトの存在意義が
    # 消える）。実測 88 件なので、大きく下回ったら抽出失敗とみなして落とす。
    if len(registry) < 50:
        print(f"NG: アクション定義の抽出に失敗した（{len(registry)} 件）。")
        print("  - Orca の更新で app.asar の形が変わった可能性がある。load_registry の正規表現を見直す。")
        return 1
    try:
        with open(path) as f:
            document = json.load(f)
    except (OSError, ValueError) as e:
        # Orca 側も同じ壊れ方をする（"Could not read keybindings file"）ので、
        # トレースバックではなく NG として報告する。
        print(f"NG: {path}\n  - 読み込めない: {e}")
        return 1
    if not isinstance(document, dict):
        print(f"NG: {path}\n  - ルートがオブジェクトでない")
        return 1
    errors = []

    for key in document:
        if key not in ROOT_KEYS:
            # `keybindings` キーが無いと、Orca はルート直下をバインドセクションとして
            # 読みにいく（parseBindingSection の skipRootKeys 経路）。「無視される」ではない。
            errors.append(f"未知のルートキー: {key}（$schema/version/keybindings/platforms のみ）")

    # keybindings（共通）→ platforms.darwin の順にマージされる
    overrides = dict(document.get("keybindings") or {})
    overrides.update(document.get("platforms", {}).get("darwin") or {})

    normalized = {}
    for action_id, value in overrides.items():
        bindings = as_bindings(value)
        if bindings is None:
            errors.append(
                f"値が不正: {action_id} = {value!r}（文字列 / 文字列配列 / null / false）"
            )
            continue
        normalized[action_id] = bindings
        if action_id not in registry:
            errors.append(f"未知のアクション: {action_id}")
            continue
        for binding in bindings:
            if canonical(binding, registry[action_id]) is None:
                errors.append(
                    f"キー指定が不正（Orca はこの override を丸ごと捨てて既定に戻す）: "
                    f"{action_id} = {binding}"
                )

    owners = {}
    for action_id, definition in registry.items():
        effective = normalized.get(action_id, definition["darwin"])
        for binding in effective:
            for identity in identities(action_id, binding, definition):
                for bucket in definition["buckets"]:
                    owners.setdefault((bucket, identity), set()).add(action_id)

    for (bucket, identity), action_ids in sorted(owners.items()):
        # override が絡む競合だけが捨てられる。既定同士は Orca が意図して重ねている。
        # 捨てられた override は「無効」になるのではなく**そのアクションの既定キーに戻る**。
        # なお `null`（= 空リスト）にしたアクションは有効なバインドを 1 つも持たないので
        # 競合判定に参加せず、捨てられることは無い（＝無効化は常に効く）。
        if len(action_ids) > 1 and action_ids & set(normalized):
            errors.append(
                f"競合（override が捨てられ既定に戻る）: {bucket} / {identity} -> "
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
    print(f"OK: {path}（{len(normalized)} 件の override / {len(registry)} アクション）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
