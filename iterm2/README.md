# iTerm2 Scripts

iTerm2 Python API を使った AutoLaunch スクリプト集。

## Setup

```sh
# AutoLaunch ディレクトリにシンボリックリンクを作成
mkdir -p ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch
ln -s ~/ghq/github.com/nkmr-jp/setup/iterm2/PaneCount ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch/PaneCount
```

iTerm2 を再起動するとスクリプトが自動実行される。

## PaneCount

以下のユーザー定義変数を各セッションに設定するスクリプト。

| 変数 | 説明 | 更新タイミング |
|---|---|---|
| `user.paneCount` | 現在のタブのペイン数 | レイアウト変更時（リアルタイム） |
| `user.claudeSessionCount` | 起動中の Claude Code インタラクティブセッション数 | 5秒ごとのポーリング |
| `user.claudeActiveCount` | アクティブ（作業中）の Claude セッション数 | 5秒ごとのポーリング |
| `user.claudeIdleCount` | アイドル（入力待ち）の Claude セッション数 | 5秒ごとのポーリング |

### 表示設定

Preferences → Profiles → General → Title で以下のように設定する:

1. Title ドロップダウンで適用したい項目にチェックを入れる
2. 「Session Name」等のチェックボックスの下にあるテキストフィールドにカスタム文字列を入力

例:
```
\(user.paneCount) panes | Claude: \(user.claudeActiveCount)active \(user.claudeIdleCount)idle
```

### 変数の利用

これらの変数は iTerm2 のユーザー定義変数として各セッションに設定されるため、
タブタイトル以外にも Status Bar やトリガーなど `\(user.変数名)` 記法が使える場所で利用できる。

### Claude セッションの検出方法

TTY にアタッチされたフォアグラウンドの `claude` プロセス（`ps` の STAT が `S+`）をカウントする。
JetBrains ACP 等のバックグラウンドプロセスは除外される。

CPU 使用率で状態を判定する:
- **Active**: CPU > 0.1%（API通信中、ツール実行中など）
- **Idle**: CPU ≈ 0%（ユーザー入力待ち）
