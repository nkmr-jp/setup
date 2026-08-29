# anyenv init のキャッシュ生成
#
# `anyenv init -` は env ごとに別プロセスを起こすため 550ms かかるが、出力は env の
# 顔ぶれとバージョンが変わらない限り不変。init.zsh がこの関数の出力をキャッシュする。
#
# 出力から落としているもの:
#   jenv refresh-plugins — プラグインの symlink を張り直す保守コマンドで、実際に働くのは
#     jenv 本体を更新したときだけ (jenv.version と現在の版を比べている)。なのに毎回の
#     シェル起動で 70ms 使う。キャッシュを作り直すのは jenv を更新したとき (依存に
#     $ANYENV_ROOT/envs/*/libexec を入れてある) なので、そのタイミングでここで 1 回だけ
#     実行し、起動のたびに走る分は落とす。
#     jenv を更新したのにプラグインの link が古いと感じたら `jenv refresh-plugins --force`。
_zsh_gen_anyenv_init() {
    local jenv="${ANYENV_ROOT:-$HOME/.anyenv}/envs/jenv/bin/jenv"
    [[ -x $jenv ]] && "$jenv" refresh-plugins >/dev/null 2>&1
    anyenv init - --no-rehash zsh | grep -v '^jenv refresh-plugins$'
}
