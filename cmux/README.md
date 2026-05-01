# cmux

[cmux](https://github.com/manaflow-ai/cmux) のカスタム設定。

## Setup

```sh
mkdir -p ~/.config/cmux
ln -sf ~/ghq/github.com/nkmr-jp/setup/cmux/settings.json ~/.config/cmux/settings.json
```

`~/.config/cmux/settings.json` は Application Support 側の設定ファイルより優先される。
設定を反映するには cmux を再起動するか、`cmd+shift+,` で reload する。

### サイドバーに cwd basename を表示

`showBranchDirectory: false` でフルパス表示を抑止し、代わりに zsh フックから `cmux set-status` でカレントディレクトリの basename を pill として送る。`~/.zshrc` に以下を追加:

```sh
source ~/ghq/github.com/nkmr-jp/setup/cmux/sidebar-cwd.zsh
```

workspace 名は手動設定（`cmd+shift+r` でリネーム）。pill は cd するたびに更新される。

## settings.json

JSON with comments (JSONC) 形式。template として全項目がコメントアウトされた状態で生成されるが、本リポジトリでは `shortcuts` のみ有効化している。

### Keybindings

[Ghostty](https://ghostty.org/) のショートカット (`../ghostty/config`) と整合するよう、ターミナル系の操作を中心にカスタマイズしている。browser/sidebar/workspace 系の操作も cmux 固有の機能としてバインドしている。

主なバインド:

| 操作 | キー |
| --- | --- |
| 新しい surface | `cmd+t` |
| 新しいタブ | `cmd+n` |
| 新しいウィンドウ | `cmd+shift+n` |
| タブを閉じる | `cmd+w` |
| ウィンドウを閉じる | `cmd+ctrl+w` |
| workspace を閉じる | `cmd+shift+w` |
| surface 移動 | `cmd+alt+←/→` |
| surface 番号で選択 | `ctrl+1` 〜 |
| workspace 番号で選択 | `cmd+1` 〜 |
| 右に分割 | `cmd+d` |
| 下に分割 | `cmd+shift+d` |
| 分割間フォーカス移動 | `cmd+↑/↓/←/→` |
| 分割ズーム切替 | `cmd+enter` |
| フルスクリーン切替 | `cmd+ctrl+f` |
| サイドバー切替 | `cmd+b` |
| コマンドパレット | `cmd+shift+p` |
| 検索 | `cmd+f` |
| 設定を開く | `cmd+,` |
| 設定をリロード | `cmd+shift+,` |
| 終了 | `cmd+q` |

ブラウザ系: `cmd+[` / `cmd+]` で戻る/進む、`cmd+r` で reload、`cmd+l` でアドレスバー、`cmd+shift+l` でブラウザを開く、`cmd+opt+i` で DevTools。
