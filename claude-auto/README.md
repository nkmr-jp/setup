# claude-auto

自動実行用 Claude のサブシステム。ユーザーの本番 Claude 環境（`~/.claude/`）と分離した
`CLAUDE_CONFIG_DIR=~/.claude-auto` で、無人（launchd）の Claude ジョブを回す。

- **機能A**: 自動コミット時のコミットメッセージ生成（分離 Claude / Haiku、失敗時 `auto:<日時>` 降格）
- **機能B**: Claude Code セッションログの日次集計・要約（集計=非LLM、要約=分離 Claude）

設計の根拠は issues の調査・設計レポート（`issues/projects/setup/1-claude-auto-jobs/`）を参照。

## なぜ分離するか

機能B で `~/.claude/projects` を Claude 自身に読ませて要約すると、その分析セッションが
`~/.claude/projects` に新しい `.jsonl` を生み、次回の分析対象に自分のノイズが混入する（自己汚染）。
`CLAUDE_CONFIG_DIR=~/.claude-auto` にすれば、ジョブのログは `~/.claude-auto/` に隔離され、
分析対象の `~/.claude/projects/` は読み取り専用で触るだけ、という綺麗な片方向になる。

## 構成

```
claude-auto/
├── lib/common.sh                 # keychain トークン取得 + 分離 Claude 起動ラッパ（#8473 回避を集約）
├── bin/
│   ├── claude-commit-msg.sh      # 機能A: staged diff → 英語1行メッセージ
│   └── claude-session-summary.sh # 機能B: ~/.claude/projects 集計 → 分離 Claude 要約 → 日次 Markdown
├── launchd/
│   └── com.nkmr.claude-session-summary.plist  # 機能B: 日次 23:30
├── config/claude-auto-skeleton/  # ~/.claude-auto の雛形（実体ではない）
│   └── settings.json             # hooks 空・plugin 無登録（hooks 回避・ログ隔離の担保）
└── install.sh                    # 冪等: symlink 配置 + ~/.claude-auto seed + keychain 確認
```

汎用バックアップ `git-auto-backup.sh` は `setup/bin/`（flat）側に置く。Claude 障害・枠切れが
汎用バックアップを壊さないよう、Claude 固有部だけをこのモジュールに分離している。

## 秘密情報の扱い（重要）

- **トークンはリポジトリにも plist にも置かない**。setup-token のトークンは macOS keychain
  （サービス名 `claude-auto-oauth`）に保管し、スクリプトが実行時に対象プロセスへ **インライン注入** する。
- グローバル env / plist に `CLAUDE_CODE_OAUTH_TOKEN` を置くと、通常の対話 Claude Code が
  それを拾って `/usage` 等が 403 で壊れる（[#8473]）。本モジュールはこれを構造的に回避している。
- `~/.claude-auto/` 実体は `$HOME` 配下＝この repo のワークツリー外なので自動的に Git 管理外。
  リポジトリに入るのは雛形 `config/claude-auto-skeleton/` だけ。

[#8473]: https://github.com/anthropics/claude-code/issues/8473

## セットアップ

### Step 0: トークン発行（ユーザー操作・1回だけ）

```sh
# サブスク長期トークンを発行（対話操作・要 Claude サブスク）
CLAUDE_CONFIG_DIR="$HOME/.claude-auto" claude setup-token

# 発行されたトークンを keychain に登録
security add-generic-password -s claude-auto-oauth -a "$USER" -w '<発行されたトークン>'
```

> 課金: サブスクでの `claude -p` 利用は月次「Agent SDK クレジット」枠（Pro $20 / Max5x $100 /
> Max20x $200）から引かれる。**usage credits を無効にしておけば超過時は停止するだけ＝追加課金ゼロ**。
> Agent SDK クレジットは 2026-06-15 開始。本格運用はそれ以降が無難。

### インストール（冪等）

```sh
~/ghq/github.com/nkmr-jp/setup/claude-auto/install.sh
```

`install.sh` は ① bin スクリプトを `~/bin` へ symlink、② plist を `~/Library/LaunchAgents` へ symlink、
③ `~/.claude-auto` を雛形から seed、④ keychain トークンの有無を確認、までを行う。
**launchd の有効化（bootstrap）は自動実行しない** ので、準備が整ってから表示されたコマンドで手動起動する:

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.nkmr.issues-autobackup.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.nkmr.claude-session-summary.plist
```

## 動作確認 / トラブルシュート

```sh
# 機能A 単体（トークン未登録なら無出力で非ゼロ＝呼び出し側が auto:<日時> に降格）
claude-commit-msg.sh <repo>

# 機能A 経由のバックアップ（push まで）
git-auto-backup.sh <repo> --llm

# 機能B（集計は常時動く。要約はトークン登録後）
CLAUDE_AUTO_DIGEST_DIR=/tmp claude-session-summary.sh

# ログ
tail -f ~/Library/Logs/issues-autobackup.log
tail -f ~/Library/Logs/claude-session-summary.log
```

- **`auto:<日時>` のまま LLM メッセージにならない** → keychain トークン未登録（Step 0）か、
  Agent SDK クレジット枠切れ。`security find-generic-password -s claude-auto-oauth` で確認。
- **launchd から claude が見つからない** → plist の `PATH` に `~/.local/bin` を含めてある。
  `common.sh` も既知の場所をフォールバック探索する。`CLAUDE_BIN` で明示指定も可。

## 環境変数（上書き用）

| 変数 | 既定 | 用途 |
| --- | --- | --- |
| `CLAUDE_AUTO_CONFIG_DIR` | `~/.claude-auto` | 分離 config の実体 |
| `CLAUDE_AUTO_KEYCHAIN_SERVICE` | `claude-auto-oauth` | keychain サービス名 |
| `CLAUDE_BIN` | （自動解決） | claude バイナリの明示指定 |
| `CLAUDE_AUTO_COMMIT_MODEL` | `claude-haiku-4-5-20251001` | 機能A のモデル |
| `CLAUDE_AUTO_COMMIT_MAX_DIFF` | `6000` | 機能A に渡す diff の最大文字数 |
| `CLAUDE_AUTO_SUMMARY_MODEL` | `claude-haiku-4-5-20251001` | 機能B のモデル |
| `CLAUDE_AUTO_PROJECTS_DIR` | `~/.claude/projects` | 機能B の集計対象 |
| `CLAUDE_AUTO_DIGEST_DIR` | `~/ghq/.../issues/reports/digest` | 機能B の出力先 |
