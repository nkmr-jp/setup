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

現在のタブのペイン数をユーザー定義変数 `user.paneCount` に設定するスクリプト。
`LayoutChangeMonitor` でペインの追加・削除をリアルタイム監視し、自動更新する。

### 表示設定

Preferences → Profiles → General → Title で以下のように設定する:

1. Title ドロップダウンで適用したい項目にチェックを入れる
2. 「Session Name」等のチェックボックスの下にあるテキストフィールドにカスタム文字列を入力

例:
```
\(user.paneCount) panes
```

これでタブタイトルにペイン数が表示される。

### 変数の利用

`user.paneCount` は iTerm2 のユーザー定義変数として各セッションに設定されるため、
タブタイトル以外にも Status Bar やトリガーなど `\(user.paneCount)` 記法が使える場所で利用できる。
