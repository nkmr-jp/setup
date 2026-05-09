# cmux

[manaflow-ai/cmux](https://github.com/manaflow-ai/cmux) のネイティブ macOS ターミナルを Claude Code から操作するためのスキルプラグイン。

cmux は複数の AI コーディングエージェント CLI を縦型タブ・分割ペイン・通知パネル付きで束ねる macOS 専用ターミナルで、`cmux` CLI と UNIX ソケット API（`/tmp/cmux.sock`）で外部から制御できる。本プラグインはその使い方を Claude にオンボーディングする。

## 前提

- macOS
- cmux.app がインストール・起動済みであること（`brew install --cask cmux`）

## インストール

setup リポジトリの marketplace を追加して install する:

```bash
claude plugin marketplace add ~/ghq/github.com/nkmr-jp/setup
claude plugin install cmux@setup
```

## 含まれるスキル

| スキル | 用途 |
|----|----|
| [cmux](skills/cmux/SKILL.md) | `cmux` CLI とソケット API の使い方を提供（ワークスペース・ペイン・サーフェス・通知・ステータス・agent-browser） |

## 含まれる hooks

| イベント | スクリプト | 用途 |
|----|----|----|
| `UserPromptSubmit` | [`hooks/scripts/claude-status-hook.sh running`](hooks/scripts/claude-status-hook.sh) | サイドバー pill を `bolt.fill` (#4C8DFF) に |
| `PreToolUse` | [`hooks/scripts/claude-status-hook.sh running`](hooks/scripts/claude-status-hook.sh) | 通知後にツール実行が再開した場合も pill を `bolt.fill` (#4C8DFF) に戻す |
| `PostToolUse` | [`hooks/scripts/claude-status-hook.sh running`](hooks/scripts/claude-status-hook.sh) | AskUserQuestion 回答や permission 承認後に `awaiting` から `bolt.fill` (#4C8DFF) に戻す |
| `Notification` | [`hooks/scripts/claude-status-hook.sh awaiting`](hooks/scripts/claude-status-hook.sh) | サイドバー pill を `bell.fill` (#FF9500) に |
| `Stop` | [`hooks/scripts/claude-status-hook.sh idle`](hooks/scripts/claude-status-hook.sh) | 応答完了時に pill を `pause.fill` (#8E8E93) に |
| `SessionStart` | [`hooks/scripts/claude-status-hook.sh clear`](hooks/scripts/claude-status-hook.sh) | 前セッションが SessionEnd を逃した場合の stale state を掃除し `folder` アイコンに戻す |
| `SessionEnd` | [`hooks/scripts/claude-status-hook.sh clear`](hooks/scripts/claude-status-hook.sh) | state file を削除し pill を `folder` アイコンに戻す |

`CMUX_PANEL_ID` が無い環境（cmux 外で起動した Claude Code）では即 exit するので無害。zsh 側の pill 描画は `~/ghq/github.com/nkmr-jp/setup/cmux/sidebar-cwd.zsh` で行い、状態は `${TMPDIR}/cmux-pane-state/<panel-id>` を介して同期する。

スキル本体（`SKILL.md`）に概要と頻出ワークフロー、詳細は以下のリファレンスに分割している：

| リファレンス | 内容 |
|----|----|
| [cli-commands.md](skills/cmux/references/cli-commands.md) | 全 CLI サブコマンドのオプションと出力形式 |
| [socket-api.md](skills/cmux/references/socket-api.md) | JSON-RPC ソケット API のメソッド一覧と呼び出し方 |
| [notifications.md](skills/cmux/references/notifications.md) | 通知・ステータス機能と他エージェントとの hooks 連携 |
| [agent-browser.md](skills/cmux/references/agent-browser.md) | `cmux browser` サブコマンド（ナビゲーション、スナップショット、フォーム操作、JS 評価） |

## 想定用途

- **cmux 内で動作する Claude Code が cmux 自身を制御**（ペイン分割、通知発火、ステータス更新）
- **通常の Claude Code セッションから cmux に関する質問に回答**（コマンド使い方、トラブルシューティング）

## トリガー例

以下のような発話でスキルが自動アクティブ化する：

- 「cmux で通知を送りたい」
- 「cmux のワークスペースを新しく作って」
- 「cmux のペインを右に分割」
- 「cmux のサーフェス一覧」
- 「cmux ブラウザで example.com を開く」
- 「Claude Code が終わったら cmux に通知させる hook を書いて」

## 公式リソース

- リポジトリ: https://github.com/manaflow-ai/cmux
- 通知 docs: https://github.com/manaflow-ai/cmux/blob/main/docs/notifications.md
- agent-browser 仕様: https://github.com/manaflow-ai/cmux/blob/main/docs/agent-browser-port-spec.md
