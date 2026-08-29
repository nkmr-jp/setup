# Orca

[Orca](https://github.com/stablyai/orca)（`com.stablyai.orca`）のキーバインド設定。
**cmux と同じキー操作になるように** [`../cmux/cmux.json`](../cmux/cmux.json) の
`shortcuts.bindings` を移植したもの。

## Setup

このディレクトリは **`~/.orca` そのもの**として使う（ファイル単体ではなく**ディレクトリごと**
symlink する。理由は後述）。

```sh
# 1. Orca を終了する（agent-hooks/ を動作中のエージェントセッションが参照しているため）
osascript -e 'quit app "Orca"'

# 2. 既存の ~/.orca（Orca が生成した agent-hooks/ などが入っている）の中身をこのリポジトリへ移す
#    ※ `~/.orca/*` はドットファイルを取りこぼすので、末尾 `/.` で中身ごとコピーする
cp -R ~/.orca/. ~/ghq/github.com/nkmr-jp/setup/orca/
rm -rf ~/.orca
ln -s ~/ghq/github.com/nkmr-jp/setup/orca ~/.orca

# 3. 確認（リンクになっていること・keybindings.json が見えること）
ls -ld ~/.orca
ls -l ~/.orca/keybindings.json
```

`~/.orca` がまだ無い場合は 2 の `cp` / `rm -rf` を飛ばして `ln -s` だけでよい。

設定を反映するには **Orca の Settings → Shortcuts → Reload**（`keybindings.json` の再読込）。
**ファイル監視は無いので、編集しただけでは反映されない**。cmux の `cmux reload-config` に相当する
CLI サブコマンドは Orca には無い。

### なぜファイル単体でなくディレクトリを symlink するのか

Orca は `keybindings.json` を **`<path>.tmp` に書いて `rename`** する（atomic write）。
rename は**シンボリックリンクそのものを通常ファイルで置き換える**ので、
`~/.orca/keybindings.json` をファイル単体の symlink にすると、次のタイミングで**無言で外れる**:

- Settings UI でショートカットを変更・リセットしたとき
- ファイルが存在しないときの自動生成
- 旧設定からのキーバインド移行、起動時の一回限りのマイグレーション（今後も同型のものが入りうる）

外れてもエラーは出ず、リポジトリ側のファイルが古いまま取り残される。
`~/.claude/settings.json` の symlink が `claude doctor` / `/config` に置き換えられて
**7 週間気づかなかった**のと同じ壊れ方（`~/ghq/github.com/nkmr-jp/claude/docs/agent-knowledge.md`）。

ディレクトリごと symlink すれば、tmp ファイルの作成も rename も**このリポジトリの中で完結する**ため、
Settings UI から変更しても将来のマイグレーションが走っても、結果がそのまま `git diff` に出る。

`~/.orca` はキーバインド専用ディレクトリではなく Orca が状態物（`agent-hooks/` など）も置くので、
`.gitignore` は**ホワイトリスト方式**（`*` を無視して `keybindings.json` などだけ通す）にしてある。

## keybindings.json の書き方

- パスは `~/.orca/keybindings.json`。**ドキュメント化されていない**（仕様は
  [stablyai/orca](https://github.com/stablyai/orca) の `src/main/keybindings/` と
  `src/shared/keybindings.ts` から確定した）。
- ルートキーは `$schema` / `version` / `keybindings` / `platforms` の 4 つ。
  `keybindings`（全 OS 共通）を `platforms.<現在の OS>` が上書きする。
  Settings UI から変更した値も `platforms.darwin` に書かれるので、手書きもそちらに寄せている。
- **厳格な JSON**（`JSON.parse`）。cmux.json と違い **`//` コメントも末尾カンマも書けない**
  （書くと `Could not read keybindings file` になる）。意図はこの README 側に書く。
- 値は文字列または文字列配列（1 アクションに複数割当可）。**`null` で無効化**。
- キーは `Mod+Shift+P` 形式。`Mod` は macOS では Cmd。修飾子は `Mod` / `Cmd` / `Ctrl` / `Alt` / `Shift`。
  修飾子なしは原則エラー。キー名は `[`→`BracketLeft`、`,`→`Comma`、`Up`→`ArrowUp` のように
  エイリアスが効く（大文字小文字は不問）。
- `$schema` はルートキーとして許容されるだけで**公開スキーマは存在しない**（書いても無視される）。

### 競合すると両方消える

競合は `conflictGroup ?? scope` のバケット単位で判定され、**override が絡む競合は衝突した両方が
無言で捨てられる**（Settings に diagnostic が出るだけ）。「片方だけ書いたら両方効かなくなった」
という壊れ方をするので、編集したら必ず検証する:

```sh
./check-keybindings.py          # 引数省略で同ディレクトリの keybindings.json を見る
```

アクション定義は導入済みの `Orca.app` の `app.asar` から抽出するので、**Orca を更新したあとに
流し直すと、上流の既定キー変更で新しく競合が生まれていないか分かる**。
検出するのは「未知のアクション ID」「不正なキー指定」「override が絡む競合」の 3 つ。

なお **scope が違うだけの同キーは競合ではない**（Orca の既定自体が `Mod+F` を browser / editor /
terminal / settings に、`Mod+L` を global / browser に重ねている）。フォーカス中の UI で解決される
設計なので、検証スクリプトもこれは通す。

## cmux との対応

### 既定のまま一致している（override 不要）

`cmd+,` 設定 / `cmd+b` サイドバー / `cmd+t` 新規ターミナル / `cmd+w` 閉じる / `cmd+r` リネーム・リロード /
`cmd+shift+t` 閉じたタブを復元 / `cmd+d` `cmd+shift+d` 分割 / `cmd+f` 検索 / `cmd+[` `cmd+]` ブラウザ戻る進む /
`cmd+l` アドレスバー / `cmd+=` `cmd+-` `cmd+0` ズーム / `cmd+1` ワークスペース選択 / `ctrl+1` タブ選択 /
`cmd+n` `cmd+shift+n` 新規作成。

### override して合わせたもの（`keybindings.json` の中身）

| cmux | キー | Orca アクション | Orca 既定 | 理由 |
| --- | --- | --- | --- | --- |
| `goToWorkspace` | `cmd+p` | `worktree.palette` | `Mod+J` | cmux の「ワークスペース移動」に合わせる |
| `commandPalette` | `cmd+shift+p` | `worktree.quickOpen` | `Mod+P` | 上の玉突き。Orca にコマンドパレットは無いのでファイル検索を置く |
| `renameWorkspace` | `cmd+shift+r` | `workspace.rename` | `Mod+Alt+R` | — |
| `reloadConfiguration` | `cmd+shift+,` | `app.forceReload` | `Mod+Shift+R` | 上の玉突き（`Mod+Shift+R` を空ける）。cmux の設定リロードと同じ位置 |
| `prevSidebarTab` / `nextSidebarTab` | `cmd+alt+↑` / `↓` | `worktree.navigateUp` / `navigateDown` | `Mod+Shift+Arrow` | — |
| `prevSurface` / `nextSurface` | `cmd+alt+←` / `→` | `tab.previousSameType` / `nextSameType` | `Mod+Alt+Bracket*` | 上下（ワークスペース移動）と対にする |
| `focusHistoryBack` / `Forward` (cmux で無効化) | — | `worktree.history.back` / `forward` | `Mod+Alt+ArrowLeft/Right` | `null`。上の行と同じキーなので**無効化が必須** |
| `focusLeft` / `focusRight` | `cmd+←` / `→` | `terminal.focusPreviousPane` / `focusNextPane` | `Mod+Bracket*` | Orca には**方向フォーカスが無い**ので前/次ペインで代用（上下は非対応） |
| `toggleSplitZoom` | `cmd+enter` | `terminal.expandPane` | `Mod+Shift+Enter` | — |
| `openBrowser` | `cmd+shift+l` | `tab.newBrowser` | `Mod+Shift+B` | — |
| `focusRightSidebar` (cmux で無効化) | — | `sidebar.right.toggle` | `Mod+L` | `null`。cmux と同じく無効化。既定が `browser.focusAddressBar` と同キーなのも解消する。使いたければ空いている `Mod+Alt+L` などに振る |

### Orca に対応するものが無い cmux のキー

`closeOtherTabsInPane` / `editWorkspaceDescription` / `findNext` / `findPrevious` / `hideFind` /
`jumpToUnread` / `openFolder` / `sendFeedback` / `showBrowserJavaScriptConsole` / `showNotifications` /
`splitBrowserDown` / `splitBrowserRight` / `toggleBrowserDeveloperTools` / `toggleTerminalCopyMode` /
`triggerFlash` / `useSelectionForFind`。
`closeWindow` / `quit` / `toggleFullScreen` は Orca ではネイティブメニュー側。

### 意図的に合わせていないもの

- **`focusUp` / `focusDown`（`cmd+↑` `cmd+↓`）**: Orca に上下方向のペインフォーカス移動が無い。
  左右のみ `terminal.focusPreviousPane` / `focusNextPane` で代用している。
- **`closeWorkspace`（`cmd+shift+w`）**: Orca の `workspace.delete` は「閉じる」ではなく**削除**。
  同じキーに振ると閉じるつもりで消す事故になるため、既定の `Mod+Shift+Backspace` のままにしてある。

## ターミナル内でのショートカット

Orca の `terminalShortcutPolicy` は既定 `orca-first` で、**ターミナルペインにフォーカスがあっても
アプリのショートカットが優先して発火する**。`terminal-first` にすると `scope: terminal` のアクションと
`allowInTerminal` が付いた一部だけになる。cmux で踏んだ「Option 単体が端末優先になって
ショートカットが発火しない」（cmux #6007）に相当する制約は、既定では起きない。

## 経緯

調査の詳細（仕様をどう確定したか・管理方式の比較・全 88 アクションの一覧）は
issues リポジトリの setup#13 のレポート
`13-orca-keybindings-same-as-cmux/reports/2608291717-orca-keybindings-config.md` を参照。
