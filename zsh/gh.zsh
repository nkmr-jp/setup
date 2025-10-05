# GitHub CLI (gh) configuration

# File to store last login time
GH_LOGIN_TIME_FILE="${HOME}/.gh_last_login"

# Function to display last login time
gh_last_login() {
    if [[ -f "${GH_LOGIN_TIME_FILE}" ]]; then
        last_login=$(cat "${GH_LOGIN_TIME_FILE}")
        last_login_date=$(date -r "${last_login}" "+%Y-%m-%d %H:%M:%S")
        current_time=$(date +%s)
        elapsed_hours=$(( (current_time - last_login) / 3600 ))
        elapsed_minutes=$(( ((current_time - last_login) % 3600) / 60 ))

        echo "Last GitHub CLI login: ${last_login_date}"
        echo "Elapsed time: ${elapsed_hours}h ${elapsed_minutes}m"
    else
        echo "No login time recorded"
    fi
}

# Check if gh is installed and user is logged in
if command -v gh &> /dev/null; then
    if ! gh auth status &> /dev/null; then
        echo "GitHub CLI is not authenticated. Please log in:"
        gh auth login -p ssh --web --skip-ssh-key

        # Record login time after successful authentication
        if gh auth status &> /dev/null; then
            date +%s > "${GH_LOGIN_TIME_FILE}"
        fi
    else
        # Check if login time file exists and validate token age
        if [[ -f "${GH_LOGIN_TIME_FILE}" ]]; then
            last_login=$(cat "${GH_LOGIN_TIME_FILE}")
            current_time=$(date +%s)
            elapsed_hours=$(( (current_time - last_login) / 3600 ))
        else
            # If file doesn't exist, treat as expired (elapsed_hours >= 8)
            elapsed_hours=8
        fi

        if [[ ${elapsed_hours} -ge 8 ]]; then
            echo "⚠️  WARNING: GitHub CLI token is ${elapsed_hours} hours old (>= 8 hours)"
            echo ""
            echo "Opening GitHub applications settings..."
            echo "https://github.com/settings/applications"
            echo ""
            echo "Please follow these steps:"
            echo "  1. Find 'GitHub CLI' in the 'Authorized OAuth Apps' tab"
            echo "  2. Click the '...' menu button on the right"
            echo "  3. Click 'Revoke' button"
            echo ""
            open https://github.com/settings/applications
            echo "After revoking, press Enter to re-authenticate..."
            read
            gh auth login -p ssh --web --skip-ssh-key

            # Record new login time after successful authentication
            if gh auth status &> /dev/null; then
                date +%s > "${GH_LOGIN_TIME_FILE}"
            fi
        fi
    fi
fi
