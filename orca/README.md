# Orca

[Orca](https://github.com/stablyai/orca)（`com.stablyai.orca`）のキーバインド設定。
**cmux と同じキー操作になるように** [`../cmux/cmux.json`](../cmux/cmux.json) の
`shortcuts.bindings` を移植したもの（**一部はユーザー指定で意図的に違えている**——
下の対応表の「理由」欄に明記してある）。

## Setup

このディレクトリは **`~/.orca` そのもの**として使う（ファイル単体ではなく**ディレクトリごと**
symlink する。理由は後述）。

**前提: この手順は `setup/orca/` が存在する状態で実行する**（＝この変更が main に入ったあと）。
まだ無い状態で流すと、`cp` が `orca/` を勝手に作ってしまい、`git checkout` だけが静かに失敗して、
**管理下の `keybindings.json` が入っていないディレクトリ**を `~/.orca` が指すことになる。

```sh
REPO=~/ghq/github.com/nkmr-jp/setup/orca
test -f "$REPO/keybindings.json" || echo "先に main を pull すること"

# 1. Orca を終了する（agent-hooks/ を動作中のエージェントセッションが参照しているため）
osascript -e 'quit app "Orca"'

# 2. 既存の ~/.orca（Orca が生成した agent-hooks/ などが入っている）の中身をこのリポジトリへ移す
#    ※ `~/.orca/*` はドットファイルを取りこぼすので、末尾 `/.` で中身ごとコピーする
#    ※ この cp は既存の ~/.orca/keybindings.json でリポジトリ側の keybindings.json を
#      上書きする。管理している設定が消えるので、コピー後に必ず戻す（下の checkout）
#    ※ 1 行でも失敗したら止まるよう `&&` で繋ぐ。改行で並べると cp が失敗しても
#      `rm -rf ~/.orca` が走って agent-hooks/ ごと消える
test -f "$REPO/keybindings.json" \
  && cp -R ~/.orca/. "$REPO"/ \
  && git -C ~/ghq/github.com/nkmr-jp/setup checkout -- orca/keybindings.json \
  && rm -rf ~/.orca \
  && ln -s "$REPO" ~/.orca

# 3. 確認（リンクになっていること・keybindings.json が見えること）
ls -ld ~/.orca
ls -l ~/.orca/keybindings.json
```

`~/.orca` がまだ無い場合は 2 を飛ばして `ln -s "$REPO" ~/.orca` だけでよい。
逆に **`~/.orca` が既にある状態で `ln -s` だけを実行してはいけない**——`ln` は失敗せず
`~/.orca/orca` という入れ子のリンクを作る（`rm -rf ~/.orca` が先に必要）。

設定を反映するには **Orca の Settings → Shortcuts → "Reload from Disk"**。
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
注意点が 2 つ:

- `*` でディレクトリごと無視すると git はその中に降りないため、**`!` による復活はトップレベルの
  ファイルにしか効かない**。Orca が将来サブディレクトリ配下に設定を置いたら、`.gitignore` を
  そのディレクトリ用に書き足す必要がある。
- **このディレクトリで `git clean -fdx` を使わない**。無視されている `agent-hooks/` などは
  Orca のライブ状態なので、掃除のつもりで消すとアプリ側が壊れる。

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
  キー名は `[`→`BracketLeft`、`.`→`Period`、`Up`→`ArrowUp` のようにエイリアスが効く
  （大文字小文字は不問）。
- **カンマだけは記号のまま書けない**。Orca は値をまず `,` で分割してから 1 つずつ解釈するので
  （複数割当の区切りに使う）、`Mod+Shift+,` は分割されて解釈に失敗し **override ごと捨てられる**。
  必ず `Mod+Shift+Comma` と書く。
- **修飾子なし・Shift 単独のキーはほぼ使えない**。許されるのは
  `allowBareKeybindings` が付いた 3 アクション（`editor.previousChange` / `editor.nextChange` /
  `fileExplorer.delete`）と `allowShiftOnlyKeybindings` が付いた 1 アクション
  （`terminal.switchInputSource`）、あとは `Shift+Insert` だけ。それ以外に `Enter` や `F7` を
  振っても override ごと捨てられる。
- **`tab.selectByIndex` / `workspace.selectByIndex` は `1`〜`9` のキーしか受け付けない**
  （`Mod+1` のように書く。それ以外だと override ごと捨てられる）。
- `$schema` はルートキーとして許容されるだけで**公開スキーマは存在しない**（書いても無視される）。

### 競合すると override が無言で捨てられる

競合は `conflictGroup ?? scope` のバケット単位で判定され、**衝突に関わった override が
無言で捨てられる**（Settings に diagnostic が出るだけ / `removeConflictingOverrides`）。
捨てられた側は**無効になるのではなく、そのアクションの既定キーに戻る**。つまり
「書いたキーが効かず、代わりに既定のキーが動いている」という気づきにくい壊れ方をする。

`null`（＝空リスト）にしたアクションは**有効なバインドを 1 つも持たないので競合判定に
参加せず、捨てられることが無い**——無効化は常に効く。

競合以外に、**Orca が受け付けないキー指定でも override は丸ごと捨てられる**（同じく既定に戻る）。
編集したら必ず検証する:

```sh
./check-keybindings.py          # 引数省略で同ディレクトリの keybindings.json を見る
```

アクション定義は導入済みの `Orca.app` の `app.asar` から抽出するので、**Orca を更新したあとに
流し直すと、上流の既定キー変更で新しく競合が生まれていないか分かる**。
検出するのは「未知のアクション ID」「不正なキー指定（上の制約に反するもの）」
「override が絡む競合」の 3 つ。判定は本体の
`normalizeKeyToken` / `isSafeBareKey` / `canonicalizeDigitIndexBinding` /
`findKeybindingConflictsForDefinitions` を写している。

なお **scope が違うだけの同キーは競合ではない**（Orca の既定自体が `Mod+F` を browser / editor /
terminal / settings に、`Mod+L` を global / browser に重ねている）。フォーカス中の UI で解決される
設計なので、検証スクリプトもこれは通す。

ただし**検出されないからといって重ねてよいとは限らない**。Orca の既定に含まれる scope 跨ぎの重複は
すべて「フォーカスで区別できる scope 同士」（browser / editor / terminal / fileExplorer / settings が
片側にいる）で、`global` と `tabs` のような**どちらも常時有効な組み合わせは 1 つも無い**。
この設定でも、`tab.nextSameType` と同じキーになる `worktree.history.forward` は
検出対象外だが `null` で明示的に外してある。

## cmux との対応

### 既定のまま一致している（override 不要）

`cmd+,` 設定 / `cmd+b` サイドバー / `cmd+t` 新規ターミナル / `cmd+w` 閉じる / `cmd+r` リネーム・リロード /
`cmd+shift+t` 閉じたタブを復元 / `cmd+d` `cmd+shift+d` 分割 / `cmd+f` 検索 / `cmd+[` `cmd+]` ブラウザ戻る進む /
`cmd+l` アドレスバー / `cmd+=` `cmd+-` `cmd+0` ズーム / `cmd+1` ワークスペース選択 / `ctrl+1` タブ選択。

`cmd+n` / `cmd+shift+n` はキーとしては一致するが意味が違う。Orca では**どちらも
`workspace.create`（worktree を作る）**で、cmux の `newTab` / `newWindow` のような別動作ではない。

### override して合わせたもの（`keybindings.json` の中身）

| cmux | キー | Orca アクション | Orca 既定 | 理由 |
| --- | --- | --- | --- | --- |
| `goToWorkspace` | `cmd+p` | `worktree.palette` | `Mod+J` | cmux の「ワークスペース移動」に合わせる |
| `commandPalette` | `cmd+shift+p` | `worktree.quickOpen` | `Mod+P` | 上の玉突き。Orca にコマンドパレットは無いのでファイル検索を置く |
| `renameWorkspace` | `cmd+shift+r` | `workspace.rename` | `Mod+Alt+R` | — |
| `reloadConfiguration` | `cmd+shift+,` | `app.forceReload` | `Mod+Shift+R` | 上の玉突き（`Mod+Shift+R` を空ける）。cmux の設定リロードと同じ位置 |
| `prevSidebarTab` / `nextSidebarTab` | `alt+↑` / `↓` | `worktree.navigateUp` / `navigateDown` | `Mod+Shift+Arrow` | **cmux と意図的に違える**（ユーザー指定）。ワークスペース移動は修飾子 1 つで打てるようにする |
| `prevSurface` / `nextSurface` | `cmd+alt+←` / `→`（既定の `cmd+shift+[` / `]` も残す） | `tab.previousAllTypes` / `nextAllTypes` | `Mod+Shift+Bracket*` | cmux の surface 巡回は**種類をまたぐ**ので `AllTypes` に合わせる。`SameType` だとターミナルタブからエディタタブへ移動できない。既定キーも併記して残してあるのは、下の `SameType` 行と同じ起動時マイグレーション対策 |
| `focusHistoryBack` / `Forward` (cmux で無効化) | — | `worktree.history.back` / `forward` | `Mod+Alt+ArrowLeft/Right` | `null`。上の行と同じキーになるため（cmux でも無効化していた）。scope が `global` と `tabs` で違うので競合検出には掛からないが、どちらも常時有効なので重ねない |
| `focusLeft` / `focusRight` / `focusUp` / `focusDown` | `cmd+←` `→` / `cmd+↑` `↓` | `terminal.focusPreviousPane` / `focusNextPane` | `Mod+Bracket*` | Orca には**方向フォーカスが無い**（pane 系は前/次のみ）ので、両方を同じ 2 アクションに割り当てて代用。上下分割なら実質上下移動になるが、**左右分割では `cmd+↑` と `cmd+←` が同じ動作**になる |
| `toggleSplitZoom` | `cmd+enter` | `terminal.expandPane` | `Mod+Shift+Enter` | — |
| （cmux に対応なし） | `cmd+alt+=` | `terminal.equalizePaneSizes` | **なし** | ペインを分割するたびに幅が半分になっていくのを均等に戻す。アクションは存在するが**既定キーが空**なので、割り当てないと呼べない |
| `openBrowser` | `cmd+shift+l` | `tab.newBrowser` | `Mod+Shift+B` | — |
| （cmux に対応なし） | `cmd+alt+[` / `]` | `tab.previousSameType` / `nextSameType` | `Mod+Alt+Bracket*` | **既定値をそのまま明示**。矢印キーを `AllTypes` に渡したので既定に戻すが、Orca が起動時の一回限りの移行で `Mod+Alt+Bracket*` を勝手に書き足すことがあり、説明のつかない diff になるため先に固定しておく |
| `focusRightSidebar` (cmux で無効化) | — | `sidebar.right.toggle` | `Mod+L` | `null`。cmux と同じく無効化。既定が `browser.focusAddressBar` と同キーなのも解消する。使いたければ空いている `Mod+Alt+L` などに振る |

### Orca に対応するものが無い cmux のキー

`closeOtherTabsInPane` / `editWorkspaceDescription` / `findNext` / `findPrevious` / `hideFind` /
`jumpToUnread` / `openFolder` / `sendFeedback` / `showBrowserJavaScriptConsole` / `showNotifications` /
`splitBrowserDown` / `splitBrowserRight` / `toggleBrowserDeveloperTools` / `toggleTerminalCopyMode` /
`triggerFlash` / `useSelectionForFind`。
`closeWindow` / `quit` / `toggleFullScreen` は Orca ではネイティブメニュー側。

### 意図的に合わせていないもの

- **同種タブだけの巡回（`tab.previousSameType` / `nextSameType`）**: cmux に対応する概念が無い。
  既定の `cmd+alt+[` / `]` のままにしてあるので、ターミナルだけを回りたいときはこちらを使う。
- **`closeWorkspace`（`cmd+shift+w`）**: Orca の `workspace.delete` は「閉じる」ではなく**削除**。
  同じキーに振ると閉じるつもりで消す事故になるため、既定の `Mod+Shift+Backspace` のままにしてある。
- **`toggleReactGrab`（`cmd+shift+g`）**: 近いのは `browser.grabElement`（既定 `Mod+C`）だが、
  cmux 側が cmux 内部向けの機能なので合わせていない。なお Orca の `Mod+Shift+G` は
  `sidebar.sourceControl.toggle`。

## ターミナル内でのショートカット

Orca の `terminalShortcutPolicy` は既定 `orca-first` で、**ターミナルペインにフォーカスがあっても
アプリのショートカットが優先して発火する**。`terminal-first` にすると `scope: terminal` のアクションと
`allowInTerminal` が付いた一部だけになる。cmux で踏んだ「Option 単体が端末優先になって
ショートカットが発火しない」（cmux #6007）に相当する制約は、既定では起きない。

裏返しの副作用として、**ワークスペース移動に振った `alt+↑` / `↓` はターミナルペインでも Orca が
先に奪う**。同じキーをシェル側（zsh の history-substring-search など）に割り当てていると、
Orca の中では効かなくなる。

## 経緯

調査の詳細（仕様をどう確定したか・管理方式の比較・全 88 アクションの一覧）は
issues リポジトリの setup#13 のレポート
`13-orca-keybindings-same-as-cmux/reports/2608291717-orca-keybindings-config.md` を参照。
