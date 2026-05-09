# cmux agent-browser リファレンス

cmux のサーフェスはターミナルだけでなく**ブラウザ**にもなる。`cmux browser` サブコマンド群は Playwright ライクな CLI を提供し、AI エージェントが Web UI を制御する用途に最適化されている。

## 構文

```bash
# 主形式
cmux browser --surface <surface-id> <subcommand> [args...]

# 短縮形
cmux browser <surface-id> <subcommand> [args...]
```

`--surface` 省略時は短縮形と解釈される。

## 起動と疎通

### 新規ブラウザサーフェスを作成

```bash
cmux --json browser open https://example.com
# => {"surface":"surface:7"}
```

返ってきた `surface:7` を以降の操作で使う。

### コンテキスト確認

```bash
cmux identify --json
cmux capabilities
cmux browser identify --surface surface:7
```

---

## ナビゲーションと待機

| サブコマンド | 用途 |
|----|----|
| `get url` | 現在 URL を取得 |
| `wait --load-state complete --timeout-ms <ms>` | ロード完了まで待機 |
| `wait --selector <css> --timeout-ms <ms>` | 要素出現まで待機 |
| `goto <url>` | URL 遷移 |
| `back` / `forward` / `reload` | 履歴操作 |

```bash
cmux browser surface:7 get url
cmux browser surface:7 wait --load-state complete --timeout-ms 15000
```

---

## スナップショットと参照（`e1`, `e2`, ... ref）

`snapshot --interactive` を撮ると、操作可能な要素に短い参照（`e1`, `e2`, ...）が割り当てられる。後続の操作はこの ref または CSS セレクタで対象を指定する。

```bash
cmux browser surface:7 snapshot --interactive
# 出力例:
# @e1: link "More information..."
# @e2: input "email"
# @e3: button "Submit"
```

### スナップショットオプション

```bash
cmux browser <surface> snapshot [--interactive] [--compact] [--max-depth N]
```

- `--interactive` — 操作可能な要素のみ抽出して ref を付与
- `--compact` — 簡潔な出力
- `--max-depth N` — DOM 走査の最大深度

---

## 要素操作

| サブコマンド | 用途 |
|----|----|
| `click <ref-or-selector>` | クリック |
| `dblclick <ref-or-selector>` | ダブルクリック |
| `hover <ref-or-selector>` | ホバー |
| `focus <ref-or-selector>` | フォーカス |
| `fill <ref-or-selector> <text>` | 入力欄に値をセット（クリア後） |
| `type <ref-or-selector> <text>` | 文字を 1 文字ずつ入力 |
| `press <key>` | キー入力（例: `Enter`, `Tab`） |
| `keydown <key>` / `keyup <key>` | 個別キーイベント |
| `select <ref-or-selector> <value>` | `<select>` の値を選択 |
| `check <ref-or-selector>` / `uncheck <ref-or-selector>` | チェックボックス |
| `scroll [--selector <css>] [--dx N] [--dy N]` | スクロール |

```bash
cmux browser surface:7 fill e1 "hello"
cmux --json browser surface:7 click e2 --snapshot-after
cmux browser surface:7 press Enter
```

`--snapshot-after` を付けるとアクション直後に再スナップショットを返し、続く操作で新しい ref を使える。

---

## 取得（getter）

| サブコマンド | 用途 |
|----|----|
| `get text body` / `get text <selector-or-ref>` | テキスト取得 |
| `get html body` | HTML 取得 |
| `get value <selector-or-ref>` | フォーム値 |
| `get attr <selector-or-ref> --attr <name>` | 属性値 |
| `get count <selector-or-ref>` | マッチ要素数 |
| `get box <selector-or-ref>` | bounding box |
| `get styles <selector-or-ref> --property <css-prop>` | 計算済みスタイル |

```bash
cmux browser surface:1 get text "#email"
cmux browser surface:1 get attr "#email" --attr placeholder
cmux browser surface:1 get count "li.todo"
```

---

## JavaScript 評価

```bash
cmux browser surface:7 eval 'document.title'
cmux browser surface:7 eval 'Array.from(document.querySelectorAll("a")).map(a => a.href)'
```

---

## 推奨ワークフロー（安定エージェントループ）

スナップショット → アクション → 再スナップショットの 3 段で進めるのが最も安定する。

```bash
# 1. URL 確認（必要なら goto）
cmux browser surface:7 get url

# 2. ロード完了待ち
cmux browser surface:7 wait --load-state complete --timeout-ms 15000

# 3. スナップショットで ref を取得
cmux browser surface:7 snapshot --interactive

# 4. アクション実行 + 直後スナップショット
cmux --json browser surface:7 click e5 --snapshot-after

# 5. 必要なら再度スナップショット
cmux browser surface:7 snapshot --interactive
```

### なぜこの順序か

- DOM が変わった直後に古い ref を使うと壊れる
- `--snapshot-after` で「アクション直後」の DOM スナップを得れば次のアクションが安全
- `wait --load-state complete` を間に入れることで動的読み込みのレースを抑える

---

## エンドツーエンド例：フォーム送信

```bash
# 1. 新規ブラウザを開く
cmux --json browser open https://example.com/login
# {"surface":"surface:7"}

# 2. ロード待ち + スナップショット
cmux browser surface:7 wait --load-state complete --timeout-ms 15000
cmux browser surface:7 snapshot --interactive
# @e1: input "email"
# @e2: input "password"
# @e3: button "Sign in"

# 3. 入力 → 送信
cmux browser surface:7 fill e1 "user@example.com"
cmux browser surface:7 fill e2 "secret"
cmux --json browser surface:7 click e3 --snapshot-after

# 4. 結果確認
cmux browser surface:7 get url
cmux browser surface:7 get text body
```

---

## トラブルシューティング

| 症状 | 対処 |
|----|----|
| ref が無効と言われる | DOM が更新されている。`snapshot --interactive` を再実行 |
| ロードが完了しない | `--timeout-ms` を伸ばす。動的 SPA なら特定セレクタの `wait` を使う |
| クリックしても反応がない | 要素が overlay に隠れている可能性。`get box` で位置を確認 |
| `fill` で値が入らない | input でなく contenteditable の場合あり。`type` を試す |

---

## 関連

- 全 CLI: `cli-commands.md`
- ソケット API（`browser.*` メソッド）: `socket-api.md`
- 公式仕様: https://github.com/manaflow-ai/cmux/blob/main/docs/agent-browser-port-spec.md
