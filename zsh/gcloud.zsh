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

# Show the active gcloud account/project and the ADC account
gcp-whoami() {
    echo "gcloud account: $(gcloud config get-value account 2>/dev/null)"
    echo "gcloud project: $(gcloud config get-value project 2>/dev/null)"

    local adc_file="${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}/application_default_credentials.json"
    if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
        adc_file="${GOOGLE_APPLICATION_CREDENTIALS}"
    fi
    if [[ ! -f "${adc_file}" ]]; then
        echo "ADC account:    (not configured)"
        return
    fi

    local adc_account
    if [[ "$(jq -r '.type' "${adc_file}")" == "service_account" ]]; then
        adc_account=$(jq -r '.client_email' "${adc_file}")
    else
        local token
        token=$(gcloud auth application-default print-access-token 2>/dev/null)
        if [[ -n "${token}" ]]; then
            adc_account=$(curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=${token}" | jq -r '.email // empty')
        fi
        adc_account=${adc_account:-"(token unavailable; run gcp-login)"}
    fi
    echo "ADC account:    ${adc_account}"
    echo "ADC quota:      $(jq -r '.quota_project_id // "-"' "${adc_file}")"
}

# Log in to gcloud and update ADC in a single browser flow
gcp-login() {
    gcloud auth login --update-adc "$@" || return

    # Record new login time after successful authentication
    date +%s > "${GCP_LOGIN_TIME_FILE}"
}

# Function to revoke current credentials and re-authenticate gcloud (user + ADC)
gcp_token_update() {
    gcloud auth revoke --all --quiet 2>/dev/null
    gcloud auth application-default revoke --quiet 2>/dev/null
    gcp-login
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
