# GitHub CLI (gh) configuration

# File to store last login time
GH_LOGIN_TIME_FILE="${HOME}/.gh_last_login"

# Token expiration threshold in hours (2 days = 48 hours)
GH_TOKEN_EXPIRATION_HOURS=48

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

# Function to revoke the current token and re-authenticate GitHub CLI
gh_token_update() {
    local revoke_url="https://github.com/settings/connections/applications/178c6fc778ccc68e1d6a"

    echo "Opening GitHub CLI application settings..."
    echo "${revoke_url}"
    echo ""
    echo "Please follow these steps:"
    echo "  1. Click 'Revoke access' button in the top right"
    echo "  2. Confirm the revocation"
    echo ""
    open "${revoke_url}"
    echo "After revoking, press Enter to re-authenticate..."
    read
    gh auth login -p ssh --web --skip-ssh-key || return

    # Record new login time after successful authentication
    date +%s > "${GH_LOGIN_TIME_FILE}"
}

# Warn on shell startup if the token is expired (does not block startup)
if command -v gh &> /dev/null; then
    if [[ -f "${GH_LOGIN_TIME_FILE}" ]]; then
        last_login=$(cat "${GH_LOGIN_TIME_FILE}")
        current_time=$(date +%s)
        elapsed_hours=$(( (current_time - last_login) / 3600 ))
    else
        # If file doesn't exist, treat as expired
        elapsed_hours=${GH_TOKEN_EXPIRATION_HOURS}
    fi

    if [[ ${elapsed_hours} -ge ${GH_TOKEN_EXPIRATION_HOURS} ]]; then
        echo "⚠️  WARNING: GitHub CLI token is ${elapsed_hours} hours old (>= ${GH_TOKEN_EXPIRATION_HOURS} hours)"
        echo "    Run 'gh_token_update' to revoke and re-authenticate."
    fi
fi
