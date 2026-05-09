# session-monitor

Claude Code の進行中セッションを hooks で監視し、SwiftBar のメニューバーから一覧表示するプラグイン。

```
⚡2 🔔1 ⏸3   ← 並走中の running / awaiting / idle セッション数
```

ドロップダウンには各セッションの cwd、git branch、モデル、直近プロンプトの抜粋、累計トークン、最終更新時刻が並び、クリックで cwd や transcript を開ける。

## 動作概要

1. 各 hook イベント (`SessionStart` / `UserPromptSubmit` / `PreToolUse` / `PostToolUse` / `Notification` / `Stop` / `SessionEnd`) で `hooks/scripts/update-session.sh` が起動。
2. stdin の JSON から `session_id` / `transcript_path` / `cwd` / `hook_event_name` を抽出。
3. transcript jsonl の末尾を `tail -r` で逆順スキャンし、`gitBranch` / `model` / 直近 user プロンプト / `usage` を取得（巨大セッション対策に末尾 400 行に制限）。
4. ステータスを以下に写像し、`$CLAUDE_PLUGIN_DATA/sessions.jsonl` を upsert:
   - `SessionStart` → `idle`
   - `UserPromptSubmit` / `PreToolUse` / `PostToolUse` → `running`
   - `Notification` → `awaiting`
   - `Stop` → `idle`
   - `SessionEnd` → 削除
5. SwiftBar スクリプト (`swiftbar/claude-sessions.5s.sh`) が 5 秒間隔で sessions.jsonl を読み、メニューバーを描画。

## ファイル一覧

```
setup/
├── plugins/session-monitor/
│   ├── .claude-plugin/plugin.json       # マニフェスト
│   ├── hooks/
│   │   ├── hooks.json                   # 7 イベントすべてに update-session.sh を登録
│   │   └── scripts/update-session.sh    # sessions.jsonl を upsert する hook 本体
│   └── README.md
└── swiftbar/
    └── claude-sessions.5s.sh            # SwiftBar プラグイン (5 秒更新)。リポジトリ
                                         # ルート直下の SwiftBar 集約フォルダで管理する
```

SwiftBar スクリプトをリポジトリのルート `swiftbar/` 配下に置くのは、将来的に他の SwiftBar プラグインも同じフォルダで一括管理するため。

## 必要な依存

- [`jq`](https://jqlang.org/) — `brew install jq`
- [SwiftBar](https://github.com/swiftbar/SwiftBar) (オプショナル: メニューバー表示用) — `brew install --cask swiftbar`

`jq` が無い環境では hook が無音で抜けるだけで Claude Code 本体には影響しない。

## インストール

### 1. Claude Code プラグインとして有効化

このリポジトリの marketplace から:

```bash
/plugin marketplace add nkmr-jp/setup
/plugin install session-monitor
/reload-plugins
```

### 2. SwiftBar に連携

`swiftbar/claude-sessions.5s.sh` はこのリポジトリのルート `swiftbar/` フォルダで管理しているので、SwiftBar 側の Plugin Folder をリポジトリの `swiftbar/` に向けるだけで読み込まれる（symlink もコピーも使わない）。

SwiftBar の設定で:

```
Preferences → General → Plugin Folder → /Users/nkmr/ghq/github.com/nkmr-jp/setup/swiftbar
```

を指定する。すでに別の Plugin Folder を使っている場合は、その配下に `swiftbar/claude-sessions.5s.sh` を直接置くか、Plugin Folder をこのリポジトリの `swiftbar/` に移すかのどちらか。

SwiftBar を起動／リフレッシュすると、メニューバーに `⏸ 0` (= 0 セッション) が現れる。Claude Code を起動するとカウントが増える。

### 3. データ保存先

hook は `$CLAUDE_PLUGIN_DATA/sessions.jsonl` を書く。SwiftBar スクリプトはその実パスを `~/.claude/session-monitor/data-dir` という anchor ファイルから解決するため、配置パスは Claude Code の管理に任せて構わない。

## sessions.jsonl のスキーマ

1 行 1 セッション。各行はそのセッションの最新状態のスナップショット。

```jsonc
{
  "session_id": "abc-123",
  "cwd": "/Users/nkmr/ghq/github.com/nkmr-jp/setup",
  "git_branch": "master",
  "status": "running",                 // running | awaiting | idle
  "model": "claude-opus-4-7",
  "last_prompt": "今のセッションをモニタリングするプラグインを作成…",
  "updated_at": "2026-05-10T20:11:42Z",
  "last_event": "PostToolUse",
  "transcript_path": "/Users/nkmr/.claude/projects/.../session.jsonl",
  "last_assistant_at": "2026-05-10T20:11:40Z",
  "input_tokens": 1234,
  "output_tokens": 567,
  "cache_read_input_tokens": 89012
}
```

`status` が `ended` になると行は削除される（保持しない）。

## デバッグ

```bash
# anchor が指すデータディレクトリ
cat ~/.claude/session-monitor/data-dir

# 現在の sessions.jsonl
DATA_DIR=$(cat ~/.claude/session-monitor/data-dir)
jq -r '"\(.status)\t\(.cwd)\t\(.last_prompt)"' "$DATA_DIR/sessions.jsonl"

# SwiftBar スクリプトの出力を直接確認
plugins/session-monitor/swiftbar/claude-sessions.5s.sh
```

hook の挙動は `claude --debug` で各イベント発火を観察できる。

## 設計上の注意

- **lock**: 複数セッションが同時に hook を発火し sessions.jsonl を破壊しないよう、`mkdir` を atomic mutex として使う（cmux pill と同じ流儀）。
- **SessionEnd の高速化**: Claude Code 側の hook タイムアウトが厳しいため、`SessionEnd` だけは即座に親へ復帰し、実処理は `nohup` で detach した子プロセスで完結させる。
- **stale 行のクリーンアップ**: 現状はクラッシュ等で `SessionEnd` を逃すと idle 行が残る。気になる場合は手動で `sessions.jsonl` を削除するか、cron 等で「N 時間以上更新が無い行を捨てる」掃除ジョブを足す。
