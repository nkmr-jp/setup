#!/usr/bin/env python3
"""Validate keybindings.json against the action definitions in Orca.

Orca silently drops unsupported or conflicting overrides (only Settings shows
a diagnostic). Dropped overrides revert to the action's default key rather than
disabling it: the requested key does nothing while the default still works.
This script detects that otherwise easy-to-miss failure.

Extract action definitions from the installed Orca.app app.asar so validation
tracks changes to upstream defaults. Run again after updating Orca to check
whether new defaults introduce conflicts.

    ./check-keybindings.py [keybindings.json]

Without an argument, use keybindings.json in this directory.
Print any problems and exit 1.
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

# Mirror Orca's parseModifierToken / normalizeKeyToken / isSafeBareKey in app.asar.
# Keep these in sync with Orca: drift can hide that a configured key equals a
# default and allow conflicts to escape detection.
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
# Keys allowed without modifiers, but only for actions with allowBareKeybindings.
# This candidate list is permissive; Orca remains the authority for strict validation.
BARE_OK = {
    "Backspace", "Delete", "Enter", "Escape", "Tab",
    "ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "PageUp", "PageDown",
}


def load_registry(asar_path):
    """Extract {actionId: {"buckets":..., "darwin":[...]}} from app.asar."""
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
            # The final entry has no next definition. A fixed small window can miss
            # defaultBindings after long searchKeywords and hide conflicts. Stop at
            # the next `{id:"`, or use a sufficiently large window if none exists.
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
            # Conflicts are checked in conflictGroup ?? scope buckets.
            # Also check the scope bucket when conflictGroup exists, as Orca does.
            "buckets": {group.group(1) if group else (scope.group(1) if scope else "?")}
            | ({scope.group(1)} if group and scope else set()),
            "darwin": [x.strip().strip('"') for x in raw.split(",") if x.strip()],
            # Bare/Shift-only permissions vary by action (observed: 3 bare, 1 Shift-only).
            # Extract from the same segment rather than accepting all actions loosely.
            "allow_bare": "allowBareKeybindings:!0" in seg,
            "allow_shift_only": "allowShiftOnlyKeybindings:!0" in seg,
            "digit_index": head.group(1) in DIGIT_INDEX_ACTIONS,
        }
    return registry


def normalize_key(token):
    """Mirror Orca normalizeKeyToken; return None for unknown keys, which Orca rejects."""
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
    """Canonicalize for darwin (Mod equals Cmd); return None if Orca rejects the binding.

    Pass `definition` (one load_registry entry) to check action-specific bare-key
    and digit-index restrictions. Omitting it weakens validation, so always pass
    it when the action is known to avoid missed errors.
    """
    # Orca splits both string values and array items on commas before parsing
    # (normalizeKeybindingListWithOptions). A literal comma in Mod+Shift+, splits
    # the binding, fails parsing, and causes the whole override to be discarded.
    # The Comma key name works; reject literal commas consistently as a lint rule.
    if "," in binding:
        return None
    parts = [p.strip() for p in binding.split("+") if p.strip()]
    if not parts:
        return None
    if any(p.lower() == "doubletap" for p in parts):
        # Orca parseDoubleTapKeybinding accepts exactly one modifier.
        tokens = [MODIFIER_ALIASES.get(p.upper()) for p in parts if p.lower() != "doubletap"]
        if len(tokens) != 1 or tokens[0] is None:
            return None
        # Mod equals Cmd on darwin; treating them separately would miss double-tap conflicts.
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
    if not (mods - {"Shift"}):  # Shift is the only modifier, or there are no modifiers
        # Mirror Orca normalizeKeybindingWithOptions + isSafeBareKey.
        # Only the 3 allowBareKeybindings actions accept bare keys, and only
        # the 1 allowShiftOnlyKeybindings action accepts Shift alone.
        # Previously, accepting these independently of the action incorrectly
        # approved {"tab.close": ["Enter"]}, which Orca discards entirely.
        is_function = bool(FUNCTION_KEY.match(key))
        if "Shift" in mods:
            safe_bare = allow_bare and is_function
            allowed = (key == "Insert") or safe_bare or allow_shift_only
        else:
            allowed = allow_bare and (is_function or key in BARE_OK)
        if not allowed:
            return None

    if definition and definition["digit_index"]:
        # tab.selectByIndex / workspace.selectByIndex accept only 1 through 9;
        # other keys discard the whole override (canonicalizeDigitIndexBinding).
        if not re.fullmatch(r"[1-9]", key):
            return None
        key = "1"  # Orca itself canonicalizes to 1

    # Mod equals Cmd on darwin. Fix modifier order to compare binding identities.
    meta = "Mod" in mods or "Cmd" in mods
    order = (["Cmd"] if meta else []) + [m for m in ("Ctrl", "Alt", "Shift") if m in mods]
    return "+".join(order + [key])


def as_bindings(value):
    """Mirror Orca normalizeBindingValue: accept strings, string arrays, null, or false."""
    if value is None or value is False:
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, list) and all(isinstance(item, str) for item in value):
        return list(value)
    return None


def identities(action_id, binding, definition):
    """Expand selectByIndex actions to 1 through 9, as Orca does."""
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
    # Extraction uses regexes over a minified blob. After an Orca update, a broken
    # pattern could extract only some definitions yet report success and miss conflicts.
    # We observed 88 actions; treat a much smaller count as an extraction failure.
    if len(registry) < 50:
        print(f"NG: アクション定義の抽出に失敗した（{len(registry)} 件）。")
        print("  - Orca の更新で app.asar の形が変わった可能性がある。load_registry の正規表現を見直す。")
        return 1
    try:
        with open(path) as f:
            document = json.load(f)
    except (OSError, ValueError) as e:
        # Orca fails similarly ("Could not read keybindings file"); report NG
        # instead of showing a traceback.
        print(f"NG: {path}\n  - 読み込めない: {e}")
        return 1
    if not isinstance(document, dict):
        print(f"NG: {path}\n  - ルートがオブジェクトでない")
        return 1
    errors = []

    for key in document:
        if key not in ROOT_KEYS:
            # Without a keybindings key, Orca reads bindings from the root
            # (parseBindingSection skipRootKeys path); it does not ignore them.
            errors.append(f"未知のルートキー: {key}（$schema/version/keybindings/platforms のみ）")

    # Merge common keybindings first, then platforms.darwin
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
        # Only conflicts involving overrides are dropped; overlapping defaults are intentional.
        # Dropped overrides revert to the action's default key rather than disabling it.
        # An action set to null (= empty list) has no active bindings, so it never
        # participates in conflicts or gets dropped: disabling always works.
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
