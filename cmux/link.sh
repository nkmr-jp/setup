#!/bin/sh
# Install/check only the two setup-owned cmux files.
set -eu

usage() {
    echo "usage: link.sh --install|--dry-run|--check"
}
[ "$#" -eq 1 ] || { usage >&2; exit 2; }
case "$1" in
    --install|--dry-run|--check) mode="$1" ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
config_dir="${CMUX_CONFIG_HOME:-$HOME/.config/cmux}"
case "$config_dir" in
    /*) ;;
    *) echo "CMUX_CONFIG_HOME must be an absolute path" >&2; exit 2 ;;
esac
# A directory link back to the repository must not move the source into backup.
if [ -d "$config_dir" ] && [ "$(CDPATH='' cd -- "$config_dir" && pwd -P)" = "$source_dir" ]; then
    echo "CMUX_CONFIG_HOME must not be the source directory" >&2
    exit 2
fi
# Validate both sources before creating any links or backups.
for name in cmux.json sidebar-cwd.zsh; do
    [ -f "$source_dir/$name" ] || { echo "missing source: $source_dir/$name" >&2; exit 2; }
done

result=0
for name in cmux.json sidebar-cwd.zsh; do
    source_file="$source_dir/$name"
    target_file="$config_dir/$name"
    if [ -L "$target_file" ] && [ "$(readlink "$target_file")" = "$source_file" ]; then
        echo "OK $target_file"
        continue
    fi
    if [ "$mode" = --check ]; then
        echo "MISMATCH $target_file (expected: $source_file)" >&2
        result=1
        continue
    fi
    if [ "$mode" = --dry-run ]; then
        echo "LINK $target_file -> $source_file (backup existing target)"
        continue
    fi
    mkdir -p "$config_dir"
    if [ -e "$target_file" ] || [ -L "$target_file" ]; then
        backup_file="$target_file.backup.$(date +%Y%m%d%H%M%S).$$"
        while [ -e "$backup_file" ] || [ -L "$backup_file" ]; do
            backup_file="$backup_file.1"
        done
        mv "$target_file" "$backup_file"
        echo "BACKUP $target_file -> $backup_file"
    fi
    ln -s "$source_file" "$target_file"
    echo "LINK $target_file -> $source_file"
done
exit "$result"
