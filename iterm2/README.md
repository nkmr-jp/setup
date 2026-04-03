# iTerm2 Scripts

iTerm2 Python API を使った AutoLaunch スクリプト集。

## Setup

```sh
mkdir -p ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch
ln -s ~/ghq/github.com/nkmr-jp/setup/iterm2/PaneCount.py ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch/PaneCount.py
ln -s ~/ghq/github.com/nkmr-jp/setup/iterm2/ClaudeSessions.py ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch/ClaudeSessions.py
```

iTerm2 を再起動するとスクリプトが自動実行される。

## スクリプト一覧

### PaneCount.py

現在のタブのペイン数をユーザー定義変数 `user.paneCount` に設定する。
`LayoutChangeMonitor` でペインの追加・削除をリアルタイム監視し、自動更新する。

### ClaudeSessions.py

起動中の Claude Code インタラクティブセッションの状態をユーザー定義変数 `user.claudeSessions` に設定する。
5秒ごとのポーリングでセッション状態を更新する。

| アイコン | 状態 | 判定基準 |
|---|---|---|
| 🟡 | アクティブ（作業中） | CPU > 0.1% |
| 🟢 | アイドル（入力待ち） | CPU ≈ 0% |

セッション数分のアイコンが並ぶ。例: `🟡🟡🟢`（アクティブ2、アイドル1）

TTY にアタッチされたフォアグラウンドの `claude` プロセス（`ps` の STAT が `S+`）をカウントする。
JetBrains ACP 等のバックグラウンドプロセスは除外される。

## 表示設定

Preferences → Profiles → General → Title で以下のように設定する:

1. Title ドロップダウンで適用したい項目にチェックを入れる
2. 「Session Name」等のチェックボックスの下にあるテキストフィールドにカスタム文字列を入力

例:
```
\(user.paneCount) panes \(user.claudeSessions)
```

これらの変数は iTerm2 のユーザー定義変数として各セッションに設定されるため、
タブタイトル以外にも Status Bar やトリガーなど `\(user.変数名)` 記法が使える場所で利用できる。
