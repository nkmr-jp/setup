# GitHub CLI (gh) configuration

# Check if gh is installed and user is logged in
if command -v gh &> /dev/null; then
    if ! gh auth status &> /dev/null; then
        echo "GitHub CLI is not authenticated. Please log in:"
        gh auth login -p ssh --web --skip-ssh-key
    fi
fi
