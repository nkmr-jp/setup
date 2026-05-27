# session-monitor

Claude Code の進行中セッションを hooks で監視し、xbar のメニューバーから一覧表示するプラグイン。

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
5. xbar スクリプト (`xbar/claude-sessions.5s.sh`) が 5 秒間隔で sessions.jsonl を読み、メニューバーを描画。

## ファイル一覧

```
setup/
├── plugins/session-monitor/
│   ├── .claude-plugin/plugin.json       # マニフェスト
│   ├── hooks/
│   │   ├── hooks.json                   # 7 イベントすべてに update-session.sh を登録
│   │   └── scripts/update-session.sh    # sessions.jsonl を upsert する hook 本体
│   └── README.md
└── xbar/
    ├── claude-sessions.5s.sh            # xbar プラグイン (5 秒更新)。リポジトリ
    │                                    # ルート直下の xbar 集約フォルダで管理する
    └── click-handler.sh                 # メニュー項目クリック時の振り分け
                                         # (cmux focus / アプリ activate / 削除)
```

xbar スクリプトをリポジトリのルート `xbar/` 配下に置くのは、将来的に他の xbar プラグインも同じフォルダで一括管理するため。

## 必要な依存

- [`jq`](https://jqlang.org/) — `brew install jq`
- [xbar](https://xbarapp.com/) (オプショナル: メニューバー表示用) — `brew install --cask xbar`

`jq` が無い環境では hook が無音で抜けるだけで Claude Code 本体には影響しない。

## インストール

### 1. Claude Code プラグインとして有効化

このリポジトリの marketplace から:

```bash
/plugin marketplace add nkmr-jp/setup
/plugin install session-monitor
/reload-plugins
```

### 2. xbar に連携

xbar の Plugin Folder (`~/Library/Application Support/xbar/plugins/`) にリポジトリの `xbar/claude-sessions.5s.sh` を symlink で配置する:

```bash
ln -sf "$(pwd)/xbar/claude-sessions.5s.sh" \
       "$HOME/Library/Application Support/xbar/plugins/claude-sessions.5s.sh"
```

xbar を起動／リフレッシュすると、メニューバーに `⏸ 0` (= 0 セッション) が現れる。Claude Code を起動するとカウントが増える。

### 3. データ保存先

hook は `$CLAUDE_PLUGIN_DATA/sessions.jsonl` を書く。xbar スクリプトはその実パスを `~/.claude/session-monitor/data-dir` という anchor ファイルから解決するため、配置パスは Claude Code の管理に任せて構わない。

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

# xbar スクリプトの出力を直接確認
xbar/claude-sessions.5s.sh
```

hook の挙動は `claude --debug` で各イベント発火を観察できる。

## 設計上の注意

- **lock**: 複数セッションが同時に hook を発火し sessions.jsonl を破壊しないよう、`mkdir` を atomic mutex として使う（cmux pill と同じ流儀）。
- **SessionEnd の高速化**: Claude Code 側の hook タイムアウトが厳しいため、`SessionEnd` だけは即座に親へ復帰し、実処理は `nohup` で detach した子プロセスで完結させる。
- **stale 行のクリーンアップ**: クラッシュ等で `SessionEnd` を逃すと idle 行が残るが、xbar 側スクリプトが 5s ループ毎に「`updated_at` が 1 日以上前の行」を GC する。それより早く消したい場合はメニュー項目のサブメニュー末尾「🗑 Delete from list」で個別削除できる。
