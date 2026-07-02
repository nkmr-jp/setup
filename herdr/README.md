# herdr

[herdr](https://herdr.dev)（terminal workspace manager for AI coding agents）のカスタム設定。

## Setup

```sh
brew install herdr
ln -sf ~/ghq/github.com/nkmr-jp/setup/herdr/config.toml ~/.config/herdr/config.toml
herdr server reload-config   # サーバー起動中に設定を反映
```

スキーマ全体は `herdr --default-config` で確認できる。

## キーバインド

デフォルトの `ctrl+b` プレフィックス操作は維持しつつ、`ctrl+alt` の直接チョードを併記して
プレフィックスなしで操作できるようにしている（issues#4）。

### Pane

| 操作 | 直接 | prefix 版 |
| --- | --- | --- |
| フォーカス移動（左/下/上/右） | `ctrl+alt+h/j/k/l` | `prefix+h/j/k/l` |
| 縦分割 | `ctrl+alt+v` | `prefix+v` |
| 横分割 | `ctrl+alt+s` | `prefix+-` |
| ペインを閉じる | `ctrl+alt+x` | `prefix+x` |
| ズーム | `ctrl+alt+z` | `prefix+z` |
| リサイズモード | `ctrl+alt+r` | `prefix+r` |

### Tab

| 操作 | 直接 | prefix 版 |
| --- | --- | --- |
| 新規タブ | `ctrl+alt+t` | `prefix+c` |
| 前/次のタブ | `ctrl+alt+←/→` | `prefix+p/n` |
| タブ番号切替 | `ctrl+alt+1..9` | `prefix+1..9` |

### Workspace

| 操作 | 直接 | prefix 版 |
| --- | --- | --- |
| ワークスペース一覧 | `ctrl+alt+w` | `prefix+w` |
| 前/次のワークスペース | `ctrl+alt+↑/↓` | （デフォルト未設定） |

### Misc

| 操作 | 直接 | prefix 版 |
| --- | --- | --- |
| goto（navigate mode） | `ctrl+alt+g` | `prefix+g` |
| スクロールバック編集 | `ctrl+alt+e` | `prefix+e` |
| サイドバー表示切替 | `ctrl+alt+b` | `prefix+b` |

## モディファイア選定の理由

- `cmd` 系は ghostty がターミナル層で消費して herdr に届かない
- 素の `ctrl+英字` は zsh ウィジェット（`ctrl+g/f/]`）や readline 操作と衝突する
- herdr 公式も「explicit modified chords」を信頼できる直接バインドとして推奨
- herdr は cmux 内では使わない想定のため、cmux のショートカットとの衝突は考慮しない

## ターミナル互換性の注意

- `ctrl+alt+英字` は **CSI-u（kitty keyboard protocol）対応ターミナルが必要**。
  legacy な ESC プレフィックスエンコーディングでは herdr に `ctrl+alt` として届かない
  （隔離セッション + PTY での実測により確認）。
- `ctrl+alt+矢印` は xterm 標準の modified arrow エンコーディング（`CSI 1;7A` 等）なので
  legacy ターミナルでも動く。
- **iTerm2（普段使いの環境）**: プロファイルの Option キーがデフォルト（Normal）だと
  option が alt として送信されず、`ctrl+alt` チョードが herdr に届かない。
  Settings → Profiles → 対象プロファイル → Keys → General →
  **Left Option key を「Esc+」に変更**する。
  ※ JIS キーボードで `option+¥` によるバックスラッシュ入力を使っている場合、
  Esc+ にした側の option では打てなくなるので、片側（Left）だけ Esc+ にして
  もう片側は Normal のまま残すとよい。
- **ghostty**: kitty keyboard protocol 対応。`ctrl+alt+英字` が効かない場合は
  config に `macos-option-as-alt = true` を追加する。

## 運用メモ

- herdr の設定画面（`prefix+s`）は config.toml を直接書き換える。symlink が実ファイルに
  置き換わってしまった場合は、差分をリポジトリ側に取り込んでから上記 `ln -sf` を張り直す。
- キーバインドが無効値だと herdr はそのバインドだけ無効化してログに
  `disabling binding` を出す（フェイルセーフ）。反映確認は
  `~/.config/herdr/herdr-server.log` を見る。
