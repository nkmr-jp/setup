# PromptLine 用のキャッシュ更新
#
# ~/.prompt-line/*.txt は PromptLine アプリが読むだけで、シェル自身は使わない。
# それを起動時に同期実行していたため、毎回のシェル起動で約 175ms 払っていた
# (実測: mdfind 135ms + ghq list 30ms + zoxide query 9ms)。
# 内容は「直近 7 日」「ghq のリポジトリ一覧」なので秒単位の鮮度は要らない。
# 1 時間より古いときだけバックグラウンドで更新する。

_prompt_line_refresh() {
    local dir="$HOME/.prompt-line"
    mkdir -p "$dir" || return
    zoxide query -l > "$dir/z.txt" 2>/dev/null
    mdfind -onlyin ~ 'kMDItemLastUsedDate >= $time.today(-7)' 2>/dev/null \
        | head -100 > "$dir/mdfind.txt"
    ghq list > "$dir/ghq.txt" 2>/dev/null
}

# 起動のたびに走らせないためのゲート。
# glob qualifier は素の形で書く ((#q...) は EXTENDED_GLOB が要る)。
# N=無ければ空 / .=通常ファイル / mh-1=1時間以内に更新
_prompt_line_start_refresh() {
    local dir="$HOME/.prompt-line"
    local -a fresh=("$dir"/ghq.txt(N.mh-1))
    (( $#fresh )) && return 0

    # 先にタイムスタンプを進めてから起動する。端末を一度に何枚も開いたときに
    # mdfind が同時に何本も走るのを防ぐ (更新に失敗しても次の 1 時間後に再挑戦する)。
    mkdir -p "$dir" || return
    touch "$dir/ghq.txt"
    _prompt_line_refresh &!
}
