# xbar plugins

[xbar](https://xbarapp.com/) 用のメニューバープラグイン集。
もともと SwiftBar で運用していたが、挙動が不安定だったため xbar に乗り換えた。

## プラグイン一覧

| ファイル | 説明 | 依存 |
| --- | --- | --- |
| `focus.5s.sh` | [Horo.app](https://horo.app) の進行中タスクをメニューバーに表示 | `sqlite3`, Horo.app |
| `claude-sessions.5s.sh` | Claude Code のセッション状態を `⚡running / 🔔awaiting / ⏸idle` で集約表示 | `jq`, Claude Code (session-monitor plugin) |
| `kalloc1024.2m.sh` | Claude Code 起因のカーネルメモリリーク（`data.kalloc.1024`）の閾値到達進捗%・増加ペースを表示 | `zprint` |
| `click-handler.sh` | `claude-sessions.5s.sh` から呼ばれるクリックハンドラ (xbar には登録しない) | cmux (任意) |

`click-handler.sh` は `claude-sessions.5s.sh` 内で `${0:A:h}/click-handler.sh` として呼ばれる。
xbar が実行する symlink は `${0:A}` で実体パスに解決されるため、シンボリックリンクは
`*.5s.sh` だけで十分で、`click-handler.sh` をリンクする必要はない。

## シンボリックリンク作成

```sh
make ln
```

このrepoの3本だけを `~/Library/Application Support/xbar/plugins/` へ個別にリンクする。
同じリンクは維持し、既存実体や異なるリンクはタイムスタンプ付きで退避する。
他のpluginやclick-handlerの配置は変更しない。`./install.sh --dry-run` で事前確認できる。
別の配置先は `XBAR_PLUGIN_DIR=/path/to/plugins make ln` で指定する。

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
