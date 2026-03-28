---
title: "iTerm2 タブ並べ替え方法の調査"
type: investigation
created: 2026-03-28 19:23 (JST)
updated: 2026-03-28 19:23 (JST)
status: 解決済み
issue: "iTerm2でタブを並べ替える全方法の調査"
---

# iTerm2 タブ並べ替え方法の調査

## 概要

iTerm2 でタブを並べ替える方法を包括的に調査した。ドラッグ&ドロップ、キーボードショートカット、メニューオプション、AppleScript/Python API、設定項目、ウィンドウ間移動の6項目について調査結果をまとめる。

## 1. ドラッグ&ドロップによるタブ並べ替え

タブバー上でタブをドラッグして並べ替えが可能。

- **同一ウィンドウ内**: タブをドラッグして任意の位置にドロップするだけで並び順を変更できる
- **ウィンドウ間移動**: タブを別のウィンドウのタブバーにドラッグ&ドロップすることで移動可能
- **新規ウィンドウ作成**: タブを既存のウィンドウのタブバー外にドロップすると、そのタブが新しいウィンドウとして独立する

## 2. キーボードショートカット

### デフォルトのタブ移動ショートカットは存在しない

「Move tab left」「Move tab right」というアクションは存在するが、デフォルトではキーボードショートカットが割り当てられていない。手動で設定が必要。

### 設定方法

1. **Settings > Keys > Key Bindings** を開く（グローバル設定の場合）
   - または **Settings > Profiles > Keys** を開く（プロファイル別の場合）
2. 「+」ボタンで新しいキーバインドを追加
3. ショートカットキーを入力（例: `Cmd+Shift+Left`）
4. Action で「Move Tab Left」を選択
5. 同様に「Move Tab Right」も設定

### デフォルトで利用可能なタブ関連ショートカット

| ショートカット | 動作 |
|---|---|
| `Cmd+T` | 新しいタブを作成 |
| `Cmd+W` | 現在のタブを閉じる |
| `Cmd+数字` | 指定番号のタブに直接移動 |
| `Cmd+Left` / `Cmd+Right` | 前/次のタブに移動 |
| `Cmd+{` / `Cmd+}` | 前/次のタブに移動（代替） |
| 3本指スワイプ（左/右） | 隣接するタブに移動（トラックパッド） |
| 中クリック | タブを閉じる |

### カスタム設定可能なタブ関連アクション一覧

- **Move Tab Left** - タブを左に移動
- **Move Tab Right** - タブを右に移動
- **Next Tab** - 次のタブに移動
- **Previous Tab** - 前のタブに移動
- **Cycle Tabs Forward** - 最近使用した順でタブを巡回（前方）
- **Cycle Tabs Backward** - 最近使用した順でタブを巡回（後方）
- **New Tab with Profile** - 指定プロファイルで新規タブ作成
- **Duplicate Tab** - 現在のタブを複製

## 3. メニューオプション

タブの並べ替えに関する専用のメニュー項目は存在しない。タブ関連のメニュー操作は以下の通り。

- **Shell > New Tab** (`Cmd+T`) - 新規タブ作成
- **Shell > Close** (`Cmd+W`) - タブを閉じる
- **Window > Select Tab** - タブの選択

## 4. プログラマティックなタブ操作

### Python API（推奨）

iTerm2 の Python API は最も強力なプログラマティック制御を提供する。

#### タブの並べ替え: `Window.async_set_tabs()`

```python
# ウィンドウ内のタブの順序を変更
await window.async_set_tabs([tab3, tab1, tab2])
```

- 任意のウィンドウのタブを受け取り、必要に応じて自動的に移動する
- 指定されたタブは先頭から順番に配置される
- リストに含まれない既存タブはリスト後方に残る
- すべてのタブを失ったウィンドウは自動的に閉じられる

#### タブのウィンドウ間移動

```python
#!/usr/bin/env python3.7
import iterm2

async def main(connection):
    app = await iterm2.async_get_app(connection)

    async def move_current_tab_by_n_windows(delta):
        tab_to_move = app.current_terminal_window.current_tab
        window_with_tab_to_move = app.get_window_for_tab(tab_to_move.tab_id)
        i = app.terminal_windows.index(window_with_tab_to_move)
        n = len(app.terminal_windows)
        j = (i + delta) % n
        if i == j:
            return
        window = app.terminal_windows[j]
        await window.async_set_tabs(window.tabs + [tab_to_move])

    @iterm2.RPC
    async def move_current_tab_to_next_window():
        await move_current_tab_by_n_windows(1)
    await move_current_tab_to_next_window.async_register(connection)

    @iterm2.RPC
    async def move_current_tab_to_previous_window():
        n = len(app.terminal_windows)
        if n > 0:
            await move_current_tab_by_n_windows(n - 1)
    await move_current_tab_to_previous_window.async_register(connection)

iterm2.run_forever(main)
```

このスクリプトを登録した後、**Settings > Keys** で「Invoke Script Function」アクションを選択し、`move_current_tab_to_next_window()` または `move_current_tab_to_previous_window()` を呼び出すキーバインドを設定する。

#### タブを新しいウィンドウに移動

```python
# Tab クラスのメソッド
new_window = await tab.async_move_to_window()
```

#### 主要な Tab クラスのプロパティ

| プロパティ | 型 | 説明 |
|---|---|---|
| `tab_id` | str | グローバル一意なタブID |
| `window` | Optional[Window] | 親ウィンドウの参照 |
| `current_session` | Session | アクティブなセッション |
| `sessions` | List[Session] | すべてのセッション（分割ペイン） |
| `index` | int | タブの位置（0始まり） |

#### 主要な Window クラスのメソッド

| メソッド | 説明 |
|---|---|
| `async_set_tabs(tabs)` | タブの順序を変更・移動 |
| `async_create_tab(profile, command, index)` | 新しいタブを作成（indexで位置指定可能） |
| `tabs` | ウィンドウ内のすべてのタブを取得 |
| `current_tab` | 現在アクティブなタブを取得 |

### AppleScript（制限あり）

AppleScript でのタブ操作はタブの作成・選択・閉じるに限定される。タブの並べ替えやウィンドウ間移動のコマンドは提供されていない。

```applescript
-- タブ作成のみ可能
tell application "iTerm2"
    tell current window
        create tab with default profile
    end tell
end tell
```

利用可能な AppleScript のタブ操作:

- `create tab with default profile` - デフォルトプロファイルでタブ作成
- `create tab with profile "名前"` - 指定プロファイルでタブ作成
- `current tab` - 現在のタブを参照
- `close` - タブを閉じる
- `select` - タブをアクティブにする
- `index` - タブの位置を取得（読み取り専用）

**タブの並べ替えには AppleScript は使えない。Python API を使用する必要がある。**

## 5. 関連する設定項目

### Settings > Appearance > Tabs

- タブバーの表示位置（上/下/左）
- タブの表示スタイル
- タブのアクティビティインジケーター（青い点、アクティビティアイコン等）

### Settings > Keys > Navigation Shortcuts

- **Shortcut to activate a tab**: タブ切替に使用する修飾キーの変更（デフォルト: `Cmd+数字`）

### Settings > General

- タブバーの表示/非表示に関する一般設定

## 6. ウィンドウ間のタブ移動

タブはウィンドウ間で自由に移動可能。以下の方法がある。

| 方法 | 操作 |
|---|---|
| ドラッグ&ドロップ | タブを別ウィンドウのタブバーにドラッグ |
| 新規ウィンドウ化 | タブをウィンドウ外にドロップ |
| Python API | `window.async_set_tabs()` で別ウィンドウのタブを指定 |
| Python API | `tab.async_move_to_window()` で新規ウィンドウに分離 |

## まとめ

| 方法 | タブ並べ替え | ウィンドウ間移動 | 備考 |
|---|---|---|---|
| ドラッグ&ドロップ | 可能 | 可能 | 最も簡単 |
| キーボードショートカット | 要設定 | 不可（デフォルト） | Move Tab Left/Right を手動設定 |
| メニュー | 不可 | 不可 | 並べ替え用メニューなし |
| Python API | 可能 | 可能 | 最も柔軟、自動化向き |
| AppleScript | 不可 | 不可 | 作成・選択・閉じるのみ |

## 参考資料

- [iTerm2 General Usage Documentation](https://iterm2.com/documentation-general-usage.html)
- [iTerm2 Keys Profiles Preferences](https://iterm2.com/documentation-preferences-profiles-keys.html)
- [iTerm2 Keys Preferences](https://iterm2.com/documentation-preferences-keys.html)
- [iTerm2 Python API - Tab Class](https://iterm2.com/python-api/tab.html)
- [iTerm2 Python API - Window Class](https://iterm2.com/python-api/window.html)
- [iTerm2 Python API - Move Tab Example](https://iterm2.com/python-api/examples/movetab.html)
- [iTerm2 Scripting Documentation](https://iterm2.com/documentation-scripting.html)
- [iTerm2 Cheatsheet (GitHub Gist)](https://gist.github.com/squarism/ae3613daf5c01a98ba3a)
