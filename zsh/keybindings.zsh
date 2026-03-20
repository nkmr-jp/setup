# Zsh key bindings
#
# NOTE: fzfのインタラクティブ操作はiTerm2のプロセスCWD追跡を混乱させる。
# そのため、fzfはウィジェット内で「選択のみ」行い、cdはzle-line-init経由の
# 遅延実行で行う（gwt.zshの_GWT_DEFERRED_CMD機構を共用）。

# ========================================
# ghqリポジトリ検索と移動 (Ctrl+G)
# ========================================
_ghq_finder_widget() {
    local selected_dir=$(find ~/ghq -mindepth 3 -maxdepth 3 -type d | sed "s|$HOME/ghq/||" | fzf --reverse --height 40%)
    if [[ -n "$selected_dir" ]]; then
        local full_path="$HOME/ghq/$selected_dir"
        # fzfの影響外でcdするため遅延実行（gwt.zshの_GWT_DEFERRED_CMD機構を使用）
        _GWT_DEFERRED_CMD="cd '${full_path}'"
        _GWT_DEFERRED_RETURN=""
        BUFFER=""
        zle accept-line
    else
        zle reset-prompt
    fi
}
zle -N _ghq_finder_widget
bindkey '^G' _ghq_finder_widget

# ========================================
# fzfと組み合わせたディレクトリ移動 (Ctrl+])
# ========================================
_fzf_cd_widget() {
    local dir
    dir=$(
        (
            zoxide query -l 2>/dev/null | sed 's/^[0-9.]* *//'
            echo ".."
            echo "../.."
            echo "../../.."
            echo "../../../.."
            echo "../../../../.."
            find . -type d -not -path '*/\.*' 2>/dev/null | head -100
        ) | awk '!seen[$0]++' | fzf --height 50% --reverse --preview 'tree -C {} 2>/dev/null | head -200'
    )
    if [[ -n "$dir" ]]; then
        _GWT_DEFERRED_CMD="cd '${dir}'"
        _GWT_DEFERRED_RETURN=""
        BUFFER=""
        zle accept-line
    else
        zle reset-prompt
    fi
}
zle -N _fzf_cd_widget
bindkey '^]' _fzf_cd_widget

# ========================================
# Git Worktree switch (Ctrl+F)
# ========================================
_gwt_switch_widget() {
    if ! command -v fzf > /dev/null 2>&1; then
        echo "Error: fzfがインストールされていません"
        zle reset-prompt
        return 1
    fi
    local worktree=$(git worktree list 2>/dev/null | fzf \
        --height=40% \
        --reverse \
        --header="Select worktree to switch")
    if [[ -n "$worktree" ]]; then
        local wt_path=$(echo "$worktree" | awk '{print $1}')
        _GWT_DEFERRED_CMD="cd '${wt_path}' && echo -e '\\033[32m→ 切り替えました: ${wt_path}\\033[0m'"
        _GWT_DEFERRED_RETURN=""
        BUFFER=""
        zle accept-line
    else
        zle reset-prompt
    fi
}
zle -N _gwt_switch_widget
bindkey '^F' _gwt_switch_widget
