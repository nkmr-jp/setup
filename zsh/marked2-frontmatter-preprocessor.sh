#!/bin/zsh
#
# Marked 2 Custom Preprocessor: Frontmatter Display (shell version).
#
# Use this script as a Marked 2 preprocessor.
# Detect YAML frontmatter and display it in a GitHub-style table.
#
# Setup:
# 1. Open Marked 2 settings (Cmd+,).
# 2. Select the "Advanced" tab.
# 3. Uncheck "Strip MMD3 Metadata headers".
# 4. Set "YAML Frontmatter" to "Ignore".
# 5. Click the "Preprocessor" tab.
# 6. Check "Enable Custom Preprocessor".
# 7. Set "Path" to this script's path.
# 8. Optionally check "Automatically enable for new windows".
#
# Path:
# ~/ghq/github.com/nkmr-jp/setup/zsh/marked2-frontmatter-preprocessor.sh

# Detect frontmatter and output it as a YAML code block.
awk '
BEGIN {
    in_frontmatter = 0
    first_line = 1
    line_count = 0
}
{
    # Check whether the first line starts with ---.
    if (first_line == 1) {
        first_line = 0
        if (/^---[[:space:]]*$/) {
            in_frontmatter = 1
            next
        }
    }

    # Detect the closing --- inside frontmatter.
    if (in_frontmatter == 1 && /^---[[:space:]]*$/) {
        in_frontmatter = 0

        # Output a collapsible YAML code block.
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

    # Save lines inside frontmatter.
    if (in_frontmatter == 1) {
        line_count++
        lines[line_count] = $0
        next
    }

    # Output lines outside frontmatter unchanged.
    print
}
'
