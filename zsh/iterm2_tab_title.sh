# ============================================================
# iTerm2 タブタイトル カスタマイズ（Shell Integration 不要）
# ============================================================
#
# タイトル:    Name(Job+Args) - PWD
# サブタイトル: 現在のディレクトリ名（basename）
#
# セットアップ:
#   1. このスニペットを ~/.zshrc に追加（source でも可）
#   2. Settings > Profiles > General > Title → "Session Name" を選択
#   3. Settings > Profiles > General > Subtitle → \(user.currentDir) を入力
#   4. Settings > Profiles > Terminal > Allow session to set title ✅
#
# ============================================================

if [[ -n "$ITERM_SESSION_ID" ]]; then

  # ── エスケープシーケンス ヘルパー ──
  _iterm2_set_tab_title() {
    printf '\e]1;%s\a' "$1"
  }

  _iterm2_set_user_var() {
    printf '\e]1337;SetUserVar=%s=%s\a' "$1" "$(printf '%s' "$2" | base64)"
  }

  # ── precmd: プロンプト表示直前 ──
  _iterm2_precmd_title() {
    _iterm2_set_tab_title "${ITERM_PROFILE}(zsh) - ${PWD}"
    _iterm2_set_user_var currentDir "${PWD##*/}"
  }

  # ── preexec: コマンド実行直前 ──
  _iterm2_preexec_title() {
    _iterm2_set_tab_title "${ITERM_PROFILE}($1) - ${PWD}"
  }

  # ── フック登録 ──
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd  _iterm2_precmd_title
  add-zsh-hook preexec _iterm2_preexec_title

fi
