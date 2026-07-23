# xbar plugins ディレクトリへシンボリックリンクを張る。
# - `*.5s.sh` / `*.2m.sh` (xbar の `name.interval.extension` 形式) だけをリンク対象にする。
# - click-handler.sh は claude-sessions.5s.sh から `${0:A:h}` 経由で
#   リポジトリ内の相対パスとして呼ばれるのでリンク不要。

.PHONY: ln

ln:
	rm -rf /Users/nkmr/Library/Application\ Support/xbar/plugins/*
	chmod +x ~/ghq/github.com/nkmr-jp/setup/xbar/*.sh
	ln -sf ~/ghq/github.com/nkmr-jp/setup/xbar/*.5s.sh ~/ghq/github.com/nkmr-jp/setup/xbar/*.2m.sh /Users/nkmr/Library/Application\ Support/xbar/plugins
	ls /Users/nkmr/Library/Application\ Support/xbar/plugins
