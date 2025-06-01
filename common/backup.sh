#!/bin/bash
# Backup utilities for setup scripts

# Create backup with timestamp
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup_dir="$HOME/.dotfile_backups"
        mkdir -p "$backup_dir"
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        local backup_path="$backup_dir/$(basename "$file").backup.$timestamp"
        cp "$file" "$backup_path"
        log_info "Backed up $file to $backup_path"
        return 0
    else
        log_info "File $file does not exist, no backup needed"
        return 1
    fi
}

# Safely write to file with backup
safe_write() {
    local target_file="$1"
    local content="$2"
    
    # Backup existing file if it exists
    backup_file "$target_file"
    
    # Write new content
    echo "$content" > "$target_file"
    log_info "Created $target_file"
}

# Safely append to file with backup
safe_append() {
    local target_file="$1"
    local content="$2"
    
    # Backup existing file if it exists
    backup_file "$target_file"
    
    # Append new content
    echo "$content" >> "$target_file"
    log_info "Appended to $target_file"
}