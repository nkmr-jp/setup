# Ghostty

[Ghostty](https://ghostty.org/) のカスタム設定。

## Setup

```sh
mkdir -p ~/.config/ghostty
ln -sf ~/ghq/github.com/nkmr-jp/setup/ghostty/config ~/.config/ghostty/config
```

設定を反映するには Ghostty を再起動するか、`cmd+shift+,` で reload する。

## config

### Keybindings

[cmux](https://github.com/manaflow-ai/cmux) のショートカット (`../cmux/settings.json`) と整合するキーバインドを設定している。
ターミナルに対応する操作のみマッピングしており、browser/sidebar/workspace 系の操作は対象外。

主なバインド:

| 操作 | キー |
| --- | --- |
| 新しいタブ | `cmd+t` / `cmd+n` |
| タブ/ペインを閉じる | `cmd+w` |
| タブ移動 | `cmd+alt+←/→` |
| タブ番号で選択 | `ctrl+1` 〜 `ctrl+9` |
| 新しいウィンドウ | `cmd+shift+n` |
| ウィンドウを閉じる | `cmd+ctrl+w` |
| フルスクリーン切替 | `cmd+ctrl+f` |
| 終了 | `cmd+q` |
| 右に分割 | `cmd+d` |
| 下に分割 | `cmd+shift+d` |
| 分割間フォーカス移動 | `cmd+↑/↓/←/→` |
| 分割ズーム切替 | `cmd+enter` |
| 設定を開く | `cmd+,` |
| 設定をリロード | `cmd+shift+,` |
| 現在ディレクトリで VS Code を開く | `cmd+ctrl+e` |

### Behavior

- `confirm-close-surface = false`: タブ/ペインを閉じる際の確認ポップアップを無効化。
