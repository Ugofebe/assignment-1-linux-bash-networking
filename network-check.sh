#!/usr/bin/env bash
#
# network-check.sh - resolve a host, check connectivity, show interfaces,
# and optionally test a TCP port.
# Usage: ./network-check.sh <host-or-ip> [port]
#   host : hostname or IP address (required)
#   port : TCP port 1-65535 (optional)
# Exit: 0 reachable / port open, 1 unreachable / port closed, 2 invalid input.

set -u

LOG_DIR="logs"
LOG_FILE="$LOG_DIR/network-check.log"
SCRIPT_NAME="network-check.sh"

log() {
    local msg="$1"
    local ts
    ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
    mkdir -p "$LOG_DIR"
    printf '%s [%s] %s\n' "$ts" "$SCRIPT_NAME" "$msg" >> "$LOG_FILE"
}

host="${1:-}"
port="${2:-}"

# A host argument is required.
if [[ -z "$host" ]]; then
    echo "Error: a host or IP address is required" >&2
    echo "Usage: $SCRIPT_NAME <host-or-ip> [port]" >&2
    log "missing host argument"
    exit 2
fi

# If a port was supplied, validate it before doing any network work.
if [[ -n "$port" ]]; then
    if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        echo "Error: port must be an integer between 1 and 65535 (got '$port')" >&2
        log "invalid port: '$port'"
        exit 2
    fi
fi

# Resolve the host to an address. Try several tools so this works whether or
# not any single resolver utility is installed.
addr="$(getent hosts "$host" 2>/dev/null | awk '{print $1; exit}')"
if [[ -z "$addr" ]]; then
    addr="$(host "$host" 2>/dev/null | awk '/has address/{print $NF; exit}')"
fi
if [[ -z "$addr" ]]; then
    addr="$(python3 -c 'import socket,sys; print(socket.gethostbyname(sys.argv[1]))' "$host" 2>/dev/null)"
fi
if [[ -z "$addr" ]]; then
    addr="$(ping -c 1 "$host" 2>/dev/null | sed -n 's/.*(\([0-9.]*\)).*/\1/p' | head -n1)"
fi
printf 'Host: %s\n' "$host"
printf 'Resolved address: %s\n' "${addr:-unresolved}"

# Basic connectivity check. Guarded so a missing/odd ping never aborts us.
reachable=1
if ping -c 1 -W 1 "$host" >/dev/null 2>&1; then
    reachable=0
fi
printf 'Connectivity: %s\n' "$([[ $reachable -eq 0 ]] && echo reachable || echo unreachable)"

# Network interface information: ip first, then ifconfig, else a notice.
echo "Network interfaces:"
if command -v ip >/dev/null 2>&1; then
    ip addr
elif command -v ifconfig >/dev/null 2>&1; then
    ifconfig
else
    echo "  (interface information unavailable: no 'ip' or 'ifconfig')"
fi

# Optional TCP port check using bash's built-in /dev/tcp (no extra package),
# falling back to nc only if the built-in attempt fails.
if [[ -n "$port" ]]; then
    if timeout 2 bash -c ">/dev/tcp/$host/$port" 2>/dev/null; then
        printf 'TCP %s:%s -> open\n' "$host" "$port"
        reachable=0
    elif command -v nc >/dev/null 2>&1 && nc -z -w 2 "$host" "$port" >/dev/null 2>&1; then
        printf 'TCP %s:%s -> open\n' "$host" "$port"
        reachable=0
    else
        printf 'TCP %s:%s -> closed\n' "$host" "$port"
        reachable=1
    fi
fi

log "host=$host addr=${addr:-unresolved} port=${port:-none} reachable=$reachable"
exit "$reachable"
