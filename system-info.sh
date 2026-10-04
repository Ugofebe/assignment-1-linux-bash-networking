#!/usr/bin/env bash
#
# system-info.sh - report key details about the host system.
# All values are read from the system at runtime.

set -u

LOG_DIR="logs"
LOG_FILE="$LOG_DIR/system-info.log"
SCRIPT_NAME="system-info.sh"

log() {
    local msg="$1"
    local ts
    ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
    mkdir -p "$LOG_DIR"
    printf '%s [%s] %s\n' "$ts" "$SCRIPT_NAME" "$msg" >> "$LOG_FILE"
}

# Hostname
host="$(hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null || uname -n)"

# Current user
user="$(whoami 2>/dev/null || id -un 2>/dev/null || printf '%s' "${USER:-unknown}")"

# Date and time
now="$(date)"

# Operating system
os="$( . /etc/os-release 2>/dev/null && printf '%s' "$PRETTY_NAME" || uname -s )"

# Kernel version
kernel="$(uname -s -r)"

# Uptime
if uptime >/dev/null 2>&1; then
    up="$(uptime)"
elif [[ -r /proc/uptime ]]; then
    secs="$(cut -d. -f1 /proc/uptime)"
    up="$(( secs / 86400 ))d $(( (secs % 86400) / 3600 ))h $(( (secs % 3600) / 60 ))m"
else
    up="unavailable"
fi

# CPU information
if [[ -r /proc/cpuinfo ]]; then
    cpu_model="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
    cpu_count="$(grep -c '^processor' /proc/cpuinfo)"
    cpu="${cpu_model:-unknown} (${cpu_count} cores)"
elif command -v sysctl >/dev/null 2>&1; then
    cpu="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown) ($(sysctl -n hw.ncpu 2>/dev/null || echo '?') cores)"
else
    cpu="$(command -v nproc >/dev/null 2>&1 && echo "$(nproc) cores" || echo unavailable)"
fi

# Memory information
if command -v free >/dev/null 2>&1; then
    mem="$(free -h | awk 'NR==2 {print $3 " used / " $2 " total"}')"
elif [[ -r /proc/meminfo ]]; then
    mem="$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {printf "%.1f GiB available / %.1f GiB total", a/1048576, t/1048576}' /proc/meminfo)"
elif command -v sysctl >/dev/null 2>&1; then
    mem="$(awk -v b="$(sysctl -n hw.memsize 2>/dev/null || echo 0)" 'BEGIN {printf "%.1f GiB total", b/1073741824}')"
else
    mem="unavailable"
fi

# Current working directory
cwd="$(pwd)"

printf 'Hostname: %s\n' "$host"
printf 'Current User: %s\n' "$user"
printf 'Date/Time: %s\n' "$now"
printf 'Operating System: %s\n' "$os"
printf 'Kernel Version: %s\n' "$kernel"
printf 'Uptime: %s\n' "$up"
printf 'CPU: %s\n' "$cpu"
printf 'Memory: %s\n' "$mem"
printf 'Working Directory: %s\n' "$cwd"

log "reported system information"
exit 0
