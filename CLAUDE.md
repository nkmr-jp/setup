# setup

OS・汎用シェル・ツール設定と補助スクリプトを管理する。
エージェント自身のユーザー設定は agent-settings に置き、cmux・xbar・plugin 本体は setup に残す。

- cmux の正本は `cmux/`。`cmux/link.sh` が設定2ファイルを個別に退避付きでリンクする。
- エージェント設定のリポジトリへツールの実装や設定を複製しない。
- KISS/YAGNI/DRY。構成変更時は README.md とこのファイルを更新する。
- cmux の検証は `bats tests/cmux-link.bats`、`shellcheck cmux/link.sh`、`sh -n cmux/link.sh`。
- テストでは一時 HOME / CMUX_CONFIG_HOME を使い、実ホームや実サービスを変更しない。

## 公開リポジトリの境界

- シェル設定はユーザー指示により作業前の挙動へ戻した。シェルのパス汎用化と個人設定分離は保留し、初期化・PATH・aliasを変更しない。
- マシン固有のシェル上書き設定は `~/.zshrc.local` に置き、公開リポジトリへ追加しない。
- シェルのmake login・GUI PATH反映・PromptLine更新は従来の動作を維持する。検証時は実環境へsourceせず、外部コマンドを実行しない。
- credentials・local設定をコミットしない。認証値をテストログやレポートへ出さない。
- シェルの検証は `zsh -n` と作業前のバックアップ比較で行う。実ユーザーの起動設定を読む `tests/startup.bats` は実機用なので自動実行しない。

`iterm-run <command>` は従来どおり `zsh/init.zsh` で定義する。

Git設定はユーザー指示により作業前の `gitconfig` へ復元済み。ローカルGit設定のinclude分離は保留する。
