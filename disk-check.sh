#!/usr/bin/env bash
#
# disk-check.sh - report disk usage for a path and compare it to a threshold.
# Usage: ./disk-check.sh <threshold> [path]
#   threshold : integer 1-100 (percent)
#   path      : filesystem path to check (default: /)
# Exit: 0 usage below threshold, 1 usage at/above threshold, 2 invalid input.

set -u

LOG_DIR="logs"
LOG_FILE="$LOG_DIR/disk-check.log"
SCRIPT_NAME="disk-check.sh"

log() {
    local msg="$1"
    local ts
    ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
    mkdir -p "$LOG_DIR"
    printf '%s [%s] %s\n' "$ts" "$SCRIPT_NAME" "$msg" >> "$LOG_FILE"
}

threshold="${1:-}"
path="${2:-/}"

# Validate threshold: must be a plain integer within 1-100.
if [[ ! "$threshold" =~ ^[0-9]+$ ]]; then
    echo "Error: threshold must be an integer between 1 and 100" >&2
    echo "Usage: $SCRIPT_NAME <threshold> [path]" >&2
    log "invalid threshold: '$threshold'"
    exit 2
fi
if (( threshold < 1 || threshold > 100 )); then
    echo "Error: threshold must be between 1 and 100 (got $threshold)" >&2
    log "threshold out of range: $threshold"
    exit 2
fi

# Read the usage percentage for the path (POSIX output keeps columns stable).
usage="$(df -P "$path" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')"

# If df failed or produced no numeric value, treat the path as unreadable.
if [[ ! "$usage" =~ ^[0-9]+$ ]]; then
    echo "Error: could not read disk usage for '$path'" >&2
    log "df failed for path: '$path'"
    exit 2
fi

printf 'Disk usage for %s: %s%% (threshold %s%%)\n' "$path" "$usage" "$threshold"

if (( usage < threshold )); then
    log "path=$path usage=$usage threshold=$threshold result=ok"
    exit 0
else
    echo "Warning: disk usage ${usage}% is at or above threshold ${threshold}%" >&2
    log "path=$path usage=$usage threshold=$threshold result=exceeded"
    exit 1
fi
