---
name: cmux
description: このスキルは、ユーザーが「cmux」「cmux で通知を送る」「cmux のワークスペースを操作」「cmux のペインを分割」「cmux のサーフェス」「cmux のステータスを更新」「cmux ブラウザを操作」と依頼したとき、または cmux 内で動作している Claude Code が cmux 自身を制御したいときに使用すべきです。manaflow-ai/cmux のネイティブ macOS ターミナルを CLI（`cmux` コマンド）と JSON-RPC ソケット API で操作する方法を提供します。
version: 0.1.0
---

# cmux

`cmux`（[manaflow-ai/cmux](https://github.com/manaflow-ai/cmux)）は、複数の AI コーディングエージェント CLI を縦型タブ・分割ペイン・通知パネル付きで束ねるネイティブ macOS ターミナルである。本スキルは付属の `cmux` CLI コマンドと UNIX ソケット制御 API の使い方を提供する。

## 重要な前提

- 対象 OS は **macOS のみ**
- 対象アプリは **manaflow-ai/cmux**（Go 製の `soheilhy/cmux` ライブラリとは別物）
- CLI のソケットパスは `/tmp/cmux.sock`
- 旧称 `--panel` は CLI 互換エイリアスとして残るが、新規実装では `--surface` / `--pane` を使う

## インストールと疎通確認

未インストールなら以下の手順を案内する。

```bash
brew tap manaflow-ai/cmux
brew install --cask cmux

# /usr/local/bin に CLI を symlink
sudo ln -sf "/Applications/cmux.app/Contents/Resources/bin/cmux" /usr/local/bin/cmux

# 疎通確認（cmux アプリが起動している必要あり）
cmux ping
```

`cmux ping` がエラーを返す場合は、cmux.app を起動してから再試行する。

## コア概念（自動化用語）

| 用語 | 意味 |
|----|----|
| **Window** | macOS の cmux ウィンドウ（最上位） |
| **Workspace** | ウィンドウ内の「タブ」相当のグループ |
| **Pane** | ワークスペース内の分割領域 |
| **Surface** | ペイン内のタブ。ターミナルまたはブラウザ |

ID 形式は `window:N` / `workspace:N` / `pane:N` / `surface:N`。CLI 引数の多くで ID または index を受け付ける。

> 旧 API では `panel` という語が使われるが、新 API では `surface` に統一されている。

## 主要コマンド早見表

| 目的 | コマンド |
|----|----|
| 自分のコンテキスト把握 | `cmux identify --json` |
| 機能ケイパビリティ取得 | `cmux capabilities` |
| 疎通確認 | `cmux ping` |
| ウィンドウ一覧 | `cmux list-windows` |
| ワークスペース一覧 | `cmux list-workspaces [--json]` |
| ペイン一覧 | `cmux list-panes` |
| サーフェス一覧 | `cmux list-pane-surfaces --pane pane:1` |
| 新規ワークスペース | `cmux new-workspace [--cwd <dir>]` |
| ワークスペース切替 | `cmux select-workspace --workspace workspace:2` |
| ペイン分割 | `cmux new-split <right\|down\|left\|up> --pane pane:1` |
| サーフェス移動 | `cmux move-surface --surface surface:7 --pane pane:2 --focus true` |
| サーフェス並べ替え | `cmux reorder-surface --surface surface:7 --before surface:3` |
| 視覚的なフラッシュ | `cmux trigger-flash --surface surface:7` |
| 通知送信 | `cmux notify --title "..." [--body ...] [--workspace ...]` |
| 通知一覧 | `cmux list-notifications [--json]` |
| 通知クリア | `cmux clear-notifications` |
| ステータス設定 | `cmux set-status <key> <value>` |
| ステータス削除 | `cmux clear-status <key>` |
| ブラウザ起動 | `cmux --json browser open <url>` |
| ブラウザ操作 | `cmux browser <surface> <subcommand> ...` |

各コマンドの詳細オプションは `references/cli-commands.md` を参照。

## 典型ワークフロー

### 1. 現在の文脈を把握する

cmux 内で動く Claude Code から自分の所在を知るには、まず `identify` を呼ぶ。

```bash
cmux identify --json
# => {"window": "...", "workspace": "...", "pane": "...", "surface": "..."}
```

得られた ID を後続の `--workspace` / `--surface` 引数に渡す。

### 2. ワークスペースを新規作成して開く

```bash
cmux new-workspace --cwd ~/Projects/frontend
cmux select-workspace --workspace workspace:2
```

### 3. ペインを分割してサーフェスを配置

```bash
cmux new-split right --pane pane:1
cmux move-surface --surface surface:7 --pane pane:2 --focus true
```

### 4. 通知でユーザーの注意を引く

ビルド完了・承認待ちなど、AI エージェントから人間に合図を送る用途。

```bash
cmux notify --title "Claude Code" --subtitle "Permission" --body "Approval needed"
```

`--workspace workspace:2` を付ければ特定のワークスペースを対象にできる。詳細は `references/notifications.md` を参照。

### 5. ステータスでアイドル/実行中を表現

```bash
cmux set-status copilot_cli Running
# 処理が終わったら
cmux clear-status copilot_cli
```

サイドバーにアイコンとラベルが表示される。

### 6. ブラウザを開いて操作する

cmux はサーフェスをブラウザにできる。AI エージェントが Web UI を制御する用途で使う。

```bash
cmux --json browser open https://example.com
# => {"surface": "surface:7"}

cmux browser surface:7 wait --load-state complete --timeout-ms 15000
cmux browser surface:7 snapshot --interactive
cmux browser surface:7 click e1 --snapshot-after
```

詳細なブラウザ操作とフォーム入力は `references/agent-browser.md` を参照。

## AI エージェントとの統合パターン

cmux は他の CLI コーディングエージェント（Claude Code, Codex, Copilot CLI など）から呼ばれることを想定している。`hooks` を使った典型的な連携：

```bash
# エージェント停止時に通知
if command -v cmux &>/dev/null; then
  cmux notify --title 'Claude Code' --body 'Done'
  cmux clear-status claude_code
else
  osascript -e 'display notification "Done" with title "Claude Code"'
fi
```

`cmux` 未インストール環境にもフォールバックさせる（`command -v cmux`）のがベストプラクティス。

## ソケット API（自動化向け）

CLI と等価な操作を JSON-RPC over UNIX socket で呼べる。スクリプトから多数のコマンドを高速に発行したい場合や、CLI が存在しない言語から制御したい場合に使う。

```bash
echo '{"id":"1","method":"workspace.list","params":{}}' | nc -U /tmp/cmux.sock
echo '{"id":"2","method":"notification.create","params":{"title":"Hi","body":"Hello"}}' | nc -U /tmp/cmux.sock
```

メソッド一覧とリクエスト/レスポンスの形式は `references/socket-api.md` を参照。

## トラブルシューティング

| 症状 | 対処 |
|----|----|
| `cmux ping` が失敗 | cmux.app が未起動。Spotlight 等で起動する |
| `cmux: command not found` | symlink 未作成。インストール手順の `ln -sf ...` を実施 |
| `--panel` を使った既存スクリプトの警告 | 互換のため当面動作するが、`--surface` / `--pane` に置換する |
| ID と index が取り違えられる | `cmux list-*` でまず正確な ID を取得し、`--workspace workspace:N` のように prefix 付きで渡す |
| ソケット接続が拒否される | cmux.app が起動しているか確認。`/tmp/cmux.sock` の存在を `ls -l` で確認 |

## その他のリソース

- **`references/cli-commands.md`** — 全 CLI サブコマンドのオプションと出力形式の完全リファレンス
- **`references/socket-api.md`** — JSON-RPC ソケット API のメソッド一覧、リクエスト/レスポンス形式、エラーコード
- **`references/notifications.md`** — 通知・ステータス機能の詳細、エージェント連携パターン
- **`references/agent-browser.md`** — `cmux browser` サブコマンド群（ナビゲーション、スナップショット、フォーム操作、JS 評価）

## 公式ドキュメント

- リポジトリ: https://github.com/manaflow-ai/cmux
- 通知 docs: https://github.com/manaflow-ai/cmux/blob/main/docs/notifications.md
- agent-browser 仕様: https://github.com/manaflow-ai/cmux/blob/main/docs/agent-browser-port-spec.md
- v2 API マイグレーション: https://github.com/manaflow-ai/cmux/blob/main/docs/v2-api-migration.md
