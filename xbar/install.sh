#!/bin/bash
# Link this repository's three plugins; never delete unrelated xbar content.
set -eu
SOURCE="${BASH_SOURCE[0]}"
while [[ -h "$SOURCE" ]]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
ROOT="$(cd -P "$(dirname "$SOURCE")" && pwd)"
PLUGIN_DIR="${XBAR_PLUGIN_DIR:-$HOME/Library/Application Support/xbar/plugins}"
case "${1:-}" in
  --dry-run) dry_run=true ;;
  "") dry_run=false ;;
  *) echo "usage: $0 [--dry-run]" >&2; exit 2 ;;
esac
[[ $# -le 1 && -n "$PLUGIN_DIR" ]] || exit 2
# Resolve directory aliases before any write: a source directory cannot be a target.
if [[ -d "$PLUGIN_DIR" && "$(cd -P "$PLUGIN_DIR" && pwd)" == "$ROOT" ]]; then
  echo "XBAR_PLUGIN_DIR must not be the source directory" >&2
  exit 2
fi
plugin_names=(claude-sessions.5s.sh focus.5s.sh kalloc1024.2m.sh)
# Preflight every source before making directories, links or backups.
for name in "${plugin_names[@]}"; do
  [[ -f "$ROOT/$name" && -x "$ROOT/$name" ]] || {
    echo "missing executable: $ROOT/$name" >&2; exit 1;
  }
done
$dry_run || mkdir -p "$PLUGIN_DIR"
for name in "${plugin_names[@]}"; do
  source="$ROOT/$name"; target="$PLUGIN_DIR/$name"
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    echo "OK: $target"; continue
  fi
  if $dry_run; then echo "would link with backup if needed: $target -> $source"; continue; fi
  if [[ -e "$target" || -L "$target" ]]; then
    backup="$target.backup-$(date +%Y%m%d%H%M%S)"
    suffix=0
    while [[ -e "$backup" || -L "$backup" ]]; do
      suffix=$((suffix + 1)); backup="$target.backup-$(date +%Y%m%d%H%M%S)-$suffix"
    done
    mv "$target" "$backup"
    echo "backup: $backup"
  fi
  ln -s "$source" "$target"
  echo "linked: $target -> $source"
done
