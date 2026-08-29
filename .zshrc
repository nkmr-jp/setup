# Source modular Zsh configurations
SETUP_DIR="$HOME/ghq/github.com/nkmr-jp/setup"

# Initialize Zsh (loads all other configurations)
source "$SETUP_DIR/zsh/init.zsh"

# ここには何も足さない。設定は zsh/ 配下のモジュールへ入れる
# (PATH は zsh/env.zsh、alias は zsh/aliases.zsh、補完は zsh/init.zsh の
#  compinit より前)。インストーラがここへ追記してきたら、同じ要領で移すこと。
# 経緯: symlink が外れている間にインストーラの追記が溜まり、compinit の
# 二重呼び出しで起動が遅くなっていた (setup#20)。
