# cmux 通知・ステータス機能リファレンス

cmux の通知機能は AI エージェントから人間に注意を引くための主要な手段である。サイドバーへのバッジ表示、macOS システム通知の発火、未読サーフェスへの青リング表示などを行う。

## 通知の特徴

- **サイドバー表示**: cmux アプリのサイドバーに未読バッジ付きで表示
- **macOS 通知**: オプションでシステム通知を発火（OS の通知センターに表示）
- **青リング**: 未読通知を持つターミナルペインに青い枠が出る
- **ワークスペース指定**: `--workspace` で特定ワークスペースに紐付け可能

## CLI 使用方法

### 基本送信

```bash
# 最小（タイトルのみ）
cmux notify --title "Build Complete"

# 本文付き
cmux notify --title "Claude Code" --body "Waiting for input"

# サブタイトル + 本文
cmux notify --title "Claude Code" --subtitle "Permission" --body "Approval needed"

# 特定ワークスペース指定
cmux notify --title "Tests Passed" --body "All 42 tests passed" --workspace workspace:2
```

### 一覧と消去

```bash
# テキスト形式で一覧
cmux list-notifications
# [unread] Build Complete - Your build finished
# [read] Tests Passed - All tests passed

# JSON 形式（プログラム処理向け）
cmux list-notifications --json
# {"notifications":[{"id":"...","title":"...","body":"...","is_read":false}]}

# 全消去
cmux clear-notifications
```

## ステータス機能

ステータスはサイドバー上に「実行中／待機中／エラー」などの状態を表示する。通知と異なり**上書き型**であり、同じキーを set すると前の値を置き換える。

```bash
# 設定
cmux set-status claude_code Running
cmux set-status copilot_cli Idle

# 削除
cmux clear-status claude_code
```

> **注意**: `claude_code` キーは cmux の `automation.claudeCodeIntegration: true` の間は
> daemon が管理しており、外部からの `cmux set-status claude_code ...` は `OK` を返しつつ
> **黙って無視される**（setup#3 で実機検証済み）。外部から書けるのは cmux 自身の
> `cmux hooks claude <event>` 経由のみだが、これは upstream の turnId ドリフトバグ
> (issue #1027) の影響を受けるため、自前の書き込みレイヤーを構築してはならない。

### キーの命名規約

慣例として `<agent>_cli` や `<agent>` 形式を使う：

- `claude_code`
- `copilot_cli`
- `codex`
- 任意のエージェント識別子

### 状態値の慣例

- `Running` — 処理実行中
- `Idle` — 待機中
- `Error` — エラー発生
- `Waiting` — 入力待ち

---

## ソケット API での通知

CLI と等価な操作を JSON-RPC で行える。

```bash
# 作成
echo '{"id":"1","method":"notification.create","params":{"title":"Hello","body":"World"}}' | nc -U /tmp/cmux.sock

# 一覧
echo '{"id":"2","method":"notification.list","params":{}}' | nc -U /tmp/cmux.sock

# クリア
echo '{"id":"3","method":"notification.clear","params":{}}' | nc -U /tmp/cmux.sock
```

ステータス用：

```bash
echo '{"id":"4","method":"status.set","params":{"key":"claude_code","value":"Running"}}' | nc -U /tmp/cmux.sock
echo '{"id":"5","method":"status.clear","params":{"key":"claude_code"}}' | nc -U /tmp/cmux.sock
```

---

## エージェント統合パターン

### パターン 1: シェルスクリプトでビルド結果を通知

```bash
#!/bin/bash
npm run build
if [ $? -eq 0 ]; then
    cmux notify --title "Build Success" --body "Ready to deploy"
else
    cmux notify --title "Build Failed" --body "Check the logs"
fi
```

### パターン 2: GitHub Copilot CLI / 他エージェントの hooks 連携

`hooks` 機構を持つエージェント CLI なら、ライフサイクルイベントごとに `cmux` を呼ぶよう設定する。`cmux` 未インストール環境にもフォールバックさせるのが堅牢。

```json
{
  "hooks": {
    "userPromptSubmitted": [
      {
        "type": "command",
        "bash": "if command -v cmux &>/dev/null; then cmux set-status copilot_cli Running; fi",
        "timeoutSec": 3
      }
    ],
    "agentStop": [
      {
        "type": "command",
        "bash": "if command -v cmux &>/dev/null; then cmux notify --title 'Copilot CLI' --body 'Done'; cmux set-status copilot_cli Idle; else osascript -e 'display notification \"Done\" with title \"Copilot CLI\"'; fi",
        "timeoutSec": 5
      }
    ],
    "errorOccurred": [
      {
        "type": "command",
        "bash": "if command -v cmux &>/dev/null; then cmux notify --title 'Copilot CLI' --subtitle 'Error' --body \"$(cat | jq -r '.errorMessage // \"An error occurred\"' 2>/dev/null | head -c 100)\"; cmux set-status copilot_cli Error; else osascript -e 'display notification \"An error occurred\" with title \"Copilot CLI\"'; fi",
        "timeoutSec": 5
      }
    ],
    "sessionEnd": [
      {
        "type": "command",
        "bash": "if command -v cmux &>/dev/null; then cmux clear-status copilot_cli; fi",
        "timeoutSec": 3
      }
    ]
  }
}
```

### パターン 3: Claude Code の Stop フックから呼ぶ

Claude Code の `Stop` / `Notification` フックから cmux 通知を発火する例（`hooks.json`）：

```json
{
  "Stop": [{
    "matcher": "",
    "hooks": [{
      "type": "command",
      "command": "command -v cmux >/dev/null && cmux notify --title 'Claude Code' --body 'Done'",
      "timeout": 5
    }]
  }]
}
```

---

## トラブルシューティング

| 症状 | 原因 / 対処 |
|----|----|
| 通知が表示されない | cmux.app が未起動。`cmux ping` で疎通確認 |
| macOS のシステム通知が出ない | システム設定 > 通知 で cmux.app の通知を許可 |
| 通知が消えない | `cmux clear-notifications` で一括削除 |
| ステータスがすぐ消える | 同じキーを別プロセスが上書きしている可能性。キー名を一意にする |

---

## 関連

- CLI の詳細オプション: `cli-commands.md`
- ソケット API 一般: `socket-api.md`
- 公式 docs: https://github.com/manaflow-ai/cmux/blob/main/docs/notifications.md
