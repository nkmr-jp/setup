#!/bin/zsh
#
# Marked 2 Custom Preprocessor: Frontmatter Display (Shell版)
#
# このスクリプトはMarked 2のPreprocessorとして使用します。
# YAML frontmatterを検出し、GitHubのようなテーブル形式で表示します。
#
# 設定手順:
# 1. Marked 2の設定を開く (Cmd+,)
# 2. "Advanced" タブを選択
# 3. "Strip MMD3 Metadata headers" のチェックを外す
# 4. "YAML Frontmatter" を "Ignore" にする
# 5. "Preprocessor" タブをクリック
# 6. "Enable Custom Preprocessor" にチェック
# 7. "Path" にこのスクリプトのパスを設定
# 8. "Automatically enable for new windows" にチェック（任意）
#
# パス:
# /Users/nkmr/ghq/github.com/nkmr-jp/setup/marked2-frontmatter-preprocessor.sh

# frontmatterを検出してYAMLコードブロックとして出力。
awk '
BEGIN {
    in_frontmatter = 0
    first_line = 1
    line_count = 0
}
{
    # 最初の行が---で始まるかチェック
    if (first_line == 1) {
        first_line = 0
        if (/^---[[:space:]]*$/) {
            in_frontmatter = 1
            next
        }
    }

    # frontmatter内で終了の---を検出
    if (in_frontmatter == 1 && /^---[[:space:]]*$/) {
        in_frontmatter = 0

        # 折りたたみ可能なYAMLコードブロックとして出力
        if (line_count > 0) {
            print "<details>"
            print "<summary>Frontmatter</summary>"
            print ""
            print "```yaml"
            for (i = 1; i <= line_count; i++) {
                print lines[i]
            }
            print "```"
            print ""
            print "</details>"
            print ""
        }
        next
    }

    # frontmatter内の行を保存
    if (in_frontmatter == 1) {
        line_count++
        lines[line_count] = $0
        next
    }

    # frontmatter外の行はそのまま出力
    print
}
'
