# cmux

cmux のユーザー設定・sidebar 連携は setup のこのディレクトリで管理する。
エージェント自身の設定は agent-settings で管理する。

リポジトリのルートで実行する:

```sh
./cmux/link.sh --dry-run
./cmux/link.sh --install
./cmux/link.sh --check
```

`cmux.json` と `sidebar-cwd.zsh` をそれぞれ `~/.config/cmux/` へリンクする。
設定ディレクトリ全体はリンクしない。既存の実体や異なるリンクは同じディレクトリに
`<filename>.backup.<日時>.<pid>` として退避し、正しいリンクは変更しない。
`--dry-run` と `--check` はファイル・ディレクトリを作成しない。
検証用の配置先は `CMUX_CONFIG_HOME`（絶対パス）で変更できる。

agent-settings から戻す場合も上記 `--install` を使う。変更した旧正本がある場合は先に差分を確認して取り込む。
戻す必要があれば対象の新リンクだけを外し、該当 backup を元のファイル名へ戻す。

zsh はインストール済みの `~/.config/cmux/sidebar-cwd.zsh` を source する。
`cmux.json` は JSONC 形式。反映は `cmux reload-config` または新しい cmux セッションで行う。
この installer はアプリ操作やサービス起動を行わない。

プラグイン本体と hooks は [plugins/cmux](../plugins/cmux/README.md) で管理する。
回帰テスト: `bats tests/cmux-link.bats`。
