# cmux ソケット API リファレンス

cmux.app は UNIX ドメインソケット `/tmp/cmux.sock` で JSON-RPC を待ち受ける。CLI コマンドはこのソケット呼び出しの薄いラッパであり、スクリプトから直接叩くことも可能。

## トランスポート仕様（V2 プロトコル）

- パス: `/tmp/cmux.sock`
- フォーマット: **改行区切り JSON（NDJSON）**
- 1 リクエスト 1 行、1 レスポンス 1 行

### リクエスト形式

```json
{"id":"<string>","method":"<namespace>.<action>","params":{...}}
```

| フィールド | 型 | 説明 |
|----|----|----|
| `id` | string | 呼び出し側で付与する任意の ID。レスポンスに同じ値が返る |
| `method` | string | `<namespace>.<action>` 形式（例: `workspace.list`） |
| `params` | object | メソッド固有パラメータ。空でも `{}` を渡す |

### レスポンス形式

成功:

```json
{"id":"1","ok":true,"result":{...}}
```

失敗:

```json
{"id":"1","ok":false,"error":{"code":"not_found","message":"workspace not found"}}
```

---

## 呼び出し例

### netcat（最小構成）

```bash
echo '{"id":"1","method":"workspace.list","params":{}}' | nc -U /tmp/cmux.sock
```

### Python

```python
import json, socket

def call(method, params=None, req_id="1"):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect("/tmp/cmux.sock")
    payload = json.dumps({"id": req_id, "method": method, "params": params or {}})
    s.sendall((payload + "\n").encode())
    data = s.recv(65536)
    s.close()
    return json.loads(data.decode().strip())

print(call("workspace.list"))
print(call("notification.create", {"title": "Hi", "body": "Hello"}))
```

### Bash + jq

```bash
nc -U /tmp/cmux.sock <<EOF | jq
{"id":"1","method":"workspace.list","params":{}}
EOF
```

---

## 主要メソッド一覧

### window.*

| メソッド | params | 説明 |
|----|----|----|
| `window.list` | `{}` | ウィンドウ列挙 |
| `window.create` | `{}` | 新規ウィンドウ作成 |

### workspace.*

| メソッド | params | 説明 |
|----|----|----|
| `workspace.list` | `{ "window_id"?: string }` | ワークスペース列挙 |
| `workspace.create` | `{ "cwd"?: string, "window_id"?: string }` | 新規作成 |
| `workspace.select` | `{ "workspace_id": string }` | フォーカス切替 |
| `workspace.current` | `{}` | 現在フォーカスを返す |
| `workspace.close` | `{ "workspace_id": string }` | クローズ |
| `workspace.move_to_window` | `{ "workspace_id": string, "window_id": string }` | 別ウィンドウへ移動 |

### pane.* / surface.*

| メソッド | params | 説明 |
|----|----|----|
| `pane.list` | `{ "workspace_id"?: string }` | ペイン列挙 |
| `pane.split` | `{ "pane_id": string, "direction": "right\|down\|left\|up" }` | 分割 |
| `surface.list` | `{ "pane_id": string }` | サーフェス列挙 |
| `surface.move` | `{ "surface_id": string, "pane_id": string, "focus"?: bool }` | 移動 |
| `surface.reorder` | `{ "surface_id": string, "before"?: string, "after"?: string }` | 並べ替え |
| `surface.trigger_flash` | `{ "surface_id"?: string, "workspace_id"?: string }` | 視覚的注意喚起 |

### notification.*

| メソッド | params | 説明 |
|----|----|----|
| `notification.create` | `{ "title": string, "subtitle"?: string, "body"?: string, "workspace_id"?: string }` | 通知作成 |
| `notification.list` | `{}` | 通知一覧 |
| `notification.clear` | `{}` | 全通知クリア |

### status.*

| メソッド | params | 説明 |
|----|----|----|
| `status.set` | `{ "key": string, "value": string }` | ステータス設定 |
| `status.clear` | `{ "key": string }` | ステータス削除 |

### identify / capabilities

| メソッド | params | 説明 |
|----|----|----|
| `identify` | `{}` | 呼び出し元の所在を返す |
| `capabilities` | `{}` | サポート機能一覧を返す |

### browser.*

`agent-browser.md` を参照。`browser.open`, `browser.click`, `browser.fill`, `browser.snapshot` などが該当する。

---

## エラーコード

| code | 意味 |
|----|----|
| `not_found` | 指定 ID のリソースが存在しない |
| `invalid_params` | パラメータ不足／型不一致 |
| `unsupported` | 旧バージョンで未サポート |
| `internal` | 内部エラー |

---

## ベストプラクティスと注意

- **ID は文字列で送る**。数値だけの ID（`"1"`）も string で渡す
- **タイムアウト**を呼び出し側で設けること（cmux.app 終了時にソケットがハングする可能性）
- **複数呼び出し**はコネクションを使い回せる場合があるが、確実性のためコマンドごとに接続するのが安全
- **CLI と API は等価**。CLI で動作確認 → スクリプト化のときに API へ移行、という流れが扱いやすい
