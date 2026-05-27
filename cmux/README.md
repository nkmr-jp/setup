# cmux

[cmux](https://github.com/manaflow-ai/cmux) のカスタム設定。

## Setup

```sh
mkdir -p ~/.config/cmux
ln -sf ~/ghq/github.com/nkmr-jp/setup/cmux/settings.json ~/.config/cmux/settings.json
```

`~/.config/cmux/settings.json` は Application Support 側の設定ファイルより優先される。
設定を反映するには cmux を再起動するか、`cmd+shift+,` で reload する。

### サイドバーに pane 別ステータスを表示

`showBranchDirectory: false` でフルパス表示を抑止し、代わりに pane 別の pill をサイドバーに並べる。`~/.zshrc` に以下を追加:

```sh
source ~/ghq/github.com/nkmr-jp/setup/cmux/sidebar-cwd.zsh
```

Claude Code 側のフック (`UserPromptSubmit` / `Notification`) は [`agent-plugins/plugins/cmux`](https://github.com/nkmr-jp/agent-plugins/tree/master/plugins/cmux) プラグインで管理する。`cmux@agent-plugins` を有効化すると `claude-status-hook.sh` が自動登録される。

単一 pill `cwd_<panel-id>`（値=ディレクトリ basename）のアイコンを Claude Code 状態で切り替える設計:

| Claude 状態 | アイコン | 色 | トリガ |
| --- | --- | --- | --- |
| Running | `bolt.fill` | `#4C8DFF` | `UserPromptSubmit` |
| Awaiting | `bell.fill` | `#FF9500` | `Notification` |
| デフォルト | `folder` | — | state file 不在時 (shell 起動直後など) |

状態は `${TMPDIR}/cmux-pane-state/<panel-id>` に永続化され、Claude hook と zsh 側の precmd/chpwd の両方が読み取ってアイコンを揃える。cmux 標準の workspace 単位の `claude_code` pill は複数 pane で 1 つにまとまるため、こちらの pane 別 pill で代替する。標準 pill は `automation.claudeCodeIntegration: false` で抑止する。

workspace 名は手動設定（`cmd+shift+r` でリネーム）。強制クローズで残った pill は独立 sweeper が数秒おきに回収する。

### Pane 起動/削除時に分割サイズを均等化

`sidebar-cwd.zsh` は以下のタイミングで `workspace.equalize_splits` RPC を打つ:

- **起動時**: interactive shell init で同期的に 1 回
- **削除時**: `zshexit` から disowned 子プロセスを spawn し、`0.1` 秒 → `0.4` 秒の 2 回リトライで RPC を打つ (`equalize_splits` は冪等)

新しい pane を作る／既存 pane を閉じるたびに、その workspace 内の分割が自動で均等化される。既に均等／分割が無い場合は no-op。

| env var | デフォルト | 意味 |
| --- | --- | --- |
| `CMUX_EQUALIZE_SPLITS` | `1` | `0` で全無効化 |
| `CMUX_EQUALIZE_AFTER_CLOSE_DELAYS` | `"0.1 0.4"` | 削除後 equalize までのリトライ間隔 (スペース区切りの秒数列) |

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
