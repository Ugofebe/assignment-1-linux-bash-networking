# Linux Diagnostic Toolkit

A small set of Bash scripts for inspecting a Linux system, checking disk usage,
and running basic network diagnostics. Each script runs on its own, writes a
timestamped log under `logs/`, and returns a predictable exit code so it can be
used in other scripts or automation.

## Requirements

- A Linux environment with Bash 4 or newer (the scripts also run on macOS for
  local development, using built-in fallbacks).
- Standard system utilities. The network script works best when `ip`/`ifconfig`,
  `ping`, and `getent` are available, but it degrades gracefully when they are not.

## Setup

Clone the repository and make the scripts executable:

```bash
git clone <repository-url>
cd <repository>
chmod +x *.sh
```

## Usage

### system-info.sh

Prints hostname, current user, date/time, operating system, kernel version,
uptime, CPU, memory, and the current working directory.

```bash
./system-info.sh
```

Exit code: `0` on success.

### disk-check.sh

Reports disk usage for a path and compares it against a threshold percentage.

```bash
./disk-check.sh <threshold> [path]
```

- `<threshold>`: integer from 1 to 100 (required).
- `[path]`: filesystem path to check (optional, defaults to `/`).

Examples:

```bash
./disk-check.sh 90          # check / against a 90% threshold
./disk-check.sh 80 /home    # check /home against an 80% threshold
```

Exit codes:

- `0` — usage is below the threshold.
- `1` — usage is at or above the threshold.
- `2` — invalid input (non-integer threshold, out of 1–100 range, or unreadable path).

### network-check.sh

Resolves a host, checks basic connectivity, lists network interfaces, and
optionally tests a TCP port.

```bash
./network-check.sh <host-or-ip> [port]
```

- `<host-or-ip>`: hostname or IP address (required).
- `[port]`: TCP port from 1 to 65535 (optional).

Examples:

```bash
./network-check.sh localhost         # resolve + connectivity + interfaces
./network-check.sh example.com 443   # also test TCP connectivity to port 443
```

Exit codes:

- `0` — host reachable (and port open, if a port was given).
- `1` — host unreachable or port closed.
- `2` — invalid input (missing host, or port outside 1–65535).

## Logs

Each script appends to a log file under `logs/`:

- `logs/system-info.log`
- `logs/disk-check.log`
- `logs/network-check.log`

Each entry has the form `TIMESTAMP [script] message`, for example:

```
2025-01-15T09:42:07+0000 [disk-check.sh] path=/ usage=41 threshold=90 result=ok
```

The `logs/` directory is tracked in the repository via `logs/.gitkeep`; the
generated `*.log` files are ignored by git.

## Grading

A grading script is included. Make the scripts executable and run it:

```bash
chmod +x grade.sh *.sh
./grade.sh
```

## Running in Docker

The scripts are graded on Linux. To run them (and the grader) in a Linux
container from the project root:

```bash
# run a single script
docker run --rm -v "$PWD":/work -w /work ubuntu:22.04 ./system-info.sh

# run the grader
docker run --rm -v "$PWD":/work -w /work ubuntu:22.04 bash grade.sh
```

The `-v "$PWD":/work` option shares the project folder with the container, and
`-w /work` sets it as the working directory. To exercise the network script with
the optional networking tools installed:

```bash
docker run --rm -v "$PWD":/work -w /work ubuntu:22.04 \
  bash -c "apt-get update && apt-get install -y iputils-ping iproute2 netcat && bash grade.sh"
```

## Assumptions

- The grading target is Linux with Bash 4+. On macOS the scripts fall back to
  equivalent commands (`sysctl`, `ifconfig`) for local development only.
- Disk usage is read with `df -P` for stable, POSIX-formatted output.
- The TCP port check prefers Bash's built-in `/dev/tcp`, so it works without
  `netcat` installed; `nc` is used only as a fallback.
- A missing networking tool results in a clear message rather than a failure, so
  the scripts never crash on a minimal system.
- No secrets or machine-specific values are stored in the repository.
