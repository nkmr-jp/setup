# xbar plugins

[xbar](https://xbarapp.com/) 用のメニューバープラグイン集。
もともと SwiftBar で運用していたが、挙動が不安定だったため xbar に乗り換えた。

## プラグイン一覧

| ファイル | 説明 | 依存 |
| --- | --- | --- |
| `focus.5s.sh` | [Horo.app](https://horo.app) の進行中タスクをメニューバーに表示 | `sqlite3`, Horo.app |
| `claude-sessions.5s.sh` | Claude Code のセッション状態を `⚡running / 🔔awaiting / ⏸idle` で集約表示 | `jq`, Claude Code (session-monitor plugin) |
| `click-handler.sh` | `claude-sessions.5s.sh` から呼ばれるクリックハンドラ (xbar には登録しない) | cmux (任意) |

`click-handler.sh` は `claude-sessions.5s.sh` 内で `${0:A:h}/click-handler.sh` として呼ばれる。
xbar が実行する symlink は `${0:A}` で実体パスに解決されるため、シンボリックリンクは
`*.5s.sh` だけで十分で、`click-handler.sh` をリンクする必要はない。

## cmux ステータス連携 (claude-sessions.5s.sh)

`claude-sessions.5s.sh` はメニューバー描画だけでなく、cmux サイドバーの
workspace 単位 `claude_code` pill (Running/Awaiting) も更新する
(`sync_cmux_pills` 関数)。`sessions.jsonl` を `cmux_workspace_id` ごとに
集約し、running > awaiting > idle-only(=clear) の優先度で
`cmux set-status`/`clear-status` を叩く。cmux 未インストール環境では
`command -v cmux` チェックで自動的に何もしない。

session-monitor 側の hook (`plugins/session-monitor/hooks/scripts/update-session.sh`)
はセッション状態が変わるたびに `xbar://refreshPlugin` を叩いてこのスクリプトを
即時再実行させるため、5s の定期実行を待たずに cmux 側もほぼリアルタイムに追従する。
`plugins/cmux/hooks/scripts/claude-status-hook.sh` 側にも独立した自己修復ロジック
(`sync_claude_code_pill`) があるが、そちらは cmux hook が発火した pane のみが対象。
ここは `cmux_workspace_id` が付与された全セッション (cmux 外の hook 取りこぼしを
含む) を横断できるため、保険として両方が同じ `claude_code` キーへ書き込む。

## シンボリックリンク作成

```sh
make ln
```

これは以下を実行する。

1. `~/Library/Application Support/xbar/plugins/` 配下を **すべて削除** する
2. `setup/xbar/*.sh` に実行権限を付与
3. `setup/xbar/*.5s.sh` を `~/Library/Application Support/xbar/plugins/` にシンボリックリンク
4. リンク結果を `ls` で確認

> [!WARNING]
> `make ln` は `~/Library/Application Support/xbar/plugins/` の中身を `rm -rf` で消す。
> 他リポジトリ (例: `~/ghq/github.com/nkmr-jp/xbar`) からリンクされた既存プラグインも
> 一緒に削除されるので注意。

リンク作成後、xbar のメニューバーから **xbar → Refresh all** を実行すれば反映される。

## xbar 自体のインストール

```sh
brew install --cask xbar
```

## SwiftBar からの移行メモ

- メタデータの prefix を `<bitbar.*>` / `<swiftbar.*>` から `<xbar.*>` に統一
- SwiftBar 専用の `<swiftbar.hideAbout>` / `<swiftbar.hideRunInTerminal>` は削除
- `shell=` パラメータは xbar 標準の `bash=` に置き換え
- `${0:A:h}` (zsh の symlink 解決) が xbar でも問題なく動くことに依存している
