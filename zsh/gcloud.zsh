#!/bin/zsh
# Google Cloud Platform aliases

# Open GCP console pages
alias ops='open https://console.cloud.google.com/storage/browser'
alias opf='open https://console.cloud.google.com/functions/list'
alias opb='open https://console.cloud.google.com/bigquery'
alias opr='open https://console.cloud.google.com/run'
alias ope='open https://console.cloud.google.com/eventarc/triggers'

# File to store last login time
GCP_LOGIN_TIME_FILE="${HOME}/.gcp_last_login"

# Token expiration threshold in hours (2 days = 48 hours)
GCP_TOKEN_EXPIRATION_HOURS=48

# Function to display last login time
gcp_last_login() {
    if [[ -f "${GCP_LOGIN_TIME_FILE}" ]]; then
        local last_login=$(cat "${GCP_LOGIN_TIME_FILE}")
        local elapsed=$(( $(date +%s) - last_login ))
        echo "Last gcloud login: $(date -r "${last_login}" "+%Y-%m-%d %H:%M:%S")"
        echo "Elapsed time: $(( elapsed / 3600 ))h $(( (elapsed % 3600) / 60 ))m"
    else
        echo "No login time recorded"
    fi
}

# Function to revoke current credentials and re-authenticate gcloud (user + ADC)
gcp_token_update() {
    gcloud auth revoke --all --quiet 2>/dev/null
    gcloud auth application-default revoke --quiet 2>/dev/null
    gcloud auth login || return
    gcloud auth application-default login || return

    # Record new login time after successful authentication
    date +%s > "${GCP_LOGIN_TIME_FILE}"
}

# Warn on shell startup if the token is expired (does not block startup)
if command -v gcloud &> /dev/null; then
    if [[ -f "${GCP_LOGIN_TIME_FILE}" ]]; then
        gcp_elapsed_hours=$(( ($(date +%s) - $(cat "${GCP_LOGIN_TIME_FILE}")) / 3600 ))
    else
        # If file doesn't exist, treat as expired
        gcp_elapsed_hours=${GCP_TOKEN_EXPIRATION_HOURS}
    fi

    if [[ ${gcp_elapsed_hours} -ge ${GCP_TOKEN_EXPIRATION_HOURS} ]]; then
        echo "⚠️  WARNING: gcloud credentials are ${gcp_elapsed_hours} hours old (>= ${GCP_TOKEN_EXPIRATION_HOURS} hours)"
        echo "    Run 'gcp_token_update' to revoke and re-authenticate."
    fi
    unset gcp_elapsed_hours
fi
