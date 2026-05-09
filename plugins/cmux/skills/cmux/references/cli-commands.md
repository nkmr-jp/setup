# cmux CLI 完全リファレンス

`cmux` バイナリの全サブコマンドとオプションを記載する。`cmux <command> --help` で個別ヘルプも参照可能。共通フラグとして多くのコマンドが `--json` を受け付ける（機械可読出力）。

---

## 1. 基本／確認系

### `cmux ping`

cmux.app との疎通確認。成功時は短い "ok" を返す。

```bash
cmux ping
```

### `cmux identify [--json]`

呼び出し元のコンテキスト（自分がどのウィンドウ・ワークスペース・ペイン・サーフェスにいるか）を返す。AI エージェントが自分の所在を知るのに必須。

```bash
cmux identify --json
# => {"window":"window:1","workspace":"workspace:2","pane":"pane:3","surface":"surface:7"}
```

### `cmux capabilities`

cmux アプリが提供する機能・API バージョンを返す。互換性チェック用途。

```bash
cmux capabilities
```

---

## 2. トポロジ列挙

### `cmux list-windows [--json]`

すべての cmux ウィンドウを列挙。

### `cmux list-workspaces [--json]`

すべてのワークスペース（ウィンドウ横断）を列挙。

```bash
cmux list-workspaces --json
```

### `cmux list-panes [--workspace <id>] [--json]`

ペイン一覧。`--workspace` で絞り込み可能。

### `cmux list-pane-surfaces --pane <pane-id> [--json]`

特定ペイン内のサーフェス一覧。

```bash
cmux list-pane-surfaces --pane pane:1 --json
```

---

## 3. ワークスペース管理

### `cmux new-workspace [--cwd <dir>] [--window <id>] [--json]`

新規ワークスペースを作成。`--cwd` で初期作業ディレクトリ、`--window` で配置先ウィンドウを指定。

```bash
cmux new-workspace --cwd ~/Projects/frontend
```

### `cmux select-workspace --workspace <id>`

指定ワークスペースをフォーカス。

```bash
cmux select-workspace --workspace workspace:2
```

### `cmux close-workspace --workspace <id>`

ワークスペースを閉じる。

---

## 4. レイアウト操作（ペイン／サーフェス）

### `cmux new-split <direction> --pane <id> [--cwd <dir>]`

ペインを `right`/`down`/`left`/`up` のいずれかに分割。

```bash
cmux new-split right --pane pane:1
cmux new-split down --pane pane:2 --cwd ~/Projects
```

### `cmux move-surface --surface <id> --pane <id> [--focus true|false] [--index N]`

サーフェスを別ペインへ移動。

```bash
cmux move-surface --surface surface:7 --pane pane:2 --focus true
```

### `cmux reorder-surface --surface <id> [--before <id>] [--after <id>] [--index N]`

ペイン内の並びを変更。

```bash
cmux reorder-surface --surface surface:7 --before surface:3
```

### `cmux trigger-flash [--workspace <id>] [--surface <id>]`

サーフェス／ワークスペースを視覚的に点滅させる注意喚起。

---

## 5. 通知

### `cmux notify --title <text> [--subtitle <text>] [--body <text>] [--workspace <id>] [--tab <id|index>] [--panel <id|index>]`

通知を送信。`--workspace` を指定すると特定ワークスペースのサイドバーに紐付く。`--tab` / `--panel` は旧称（互換）。

```bash
cmux notify --title "Build Complete"
cmux notify --title "Tests" --subtitle "Pass" --body "All 42 passed" --workspace workspace:2
```

### `cmux list-notifications [--json]`

通知一覧を取得。

```bash
cmux list-notifications --json
# => {"notifications":[{"id":"...","title":"...","body":"...","is_read":false}]}
```

### `cmux clear-notifications`

すべての通知を消去。

---

## 6. ステータス

サイドバーにアイコンとラベル（例: Running / Idle / Error）を表示する仕組み。

### `cmux set-status <key> <value>`

`<key>` はエージェント識別子（`copilot_cli`, `claude_code` など任意）、`<value>` は表示する状態名。

```bash
cmux set-status claude_code Running
```

### `cmux clear-status <key>`

指定キーのステータスを削除。

---

## 7. エージェントブラウザ

サーフェスをブラウザにし、Playwright 風 CLI で操作。詳細は `agent-browser.md` を参照。

```bash
cmux --json browser open <url>                  # 新規ブラウザサーフェスを作成
cmux browser <surface> <subcommand> ...         # 既存サーフェスを操作
```

主な `<subcommand>`: `get url`, `wait`, `snapshot`, `click`, `fill`, `type`, `press`, `select`, `check`, `scroll`, `eval`, `get text|html|value|attr|count|box|styles`。

---

## 8. 共通フラグ

| フラグ | 意味 |
|----|----|
| `--json` | 出力を JSON 化（機械処理向け） |
| `--surface <id>` | 対象サーフェスの指定 |
| `--pane <id>` | 対象ペインの指定 |
| `--workspace <id>` | 対象ワークスペースの指定 |
| `--window <id>` | 対象ウィンドウの指定 |
| `--panel <id>` | 旧称。`--surface` / `--pane` への移行を推奨 |

---

## 9. 終了コードと出力規約

- 成功: 終了コード `0`、stdout に結果（テキストまたは JSON）
- 失敗: 非ゼロ終了コード、stderr にエラーメッセージ
- `--json` 指定時は失敗もエラーオブジェクト（`{"error":{...}}`）として返る場合あり
