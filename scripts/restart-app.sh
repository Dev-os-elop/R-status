#!/bin/zsh
set -u

APP_PATH="$1"
shift
RUNNING_PIDS=("$@")

# The launchd job is independent of both the app and the installer.
sleep 0.5
for running_pid in "${RUNNING_PIDS[@]}"; do
    kill -TERM "$running_pid" 2>/dev/null || true
done
for _ in {1..20}; do
    remaining=0
    for running_pid in "${RUNNING_PIDS[@]}"; do
        if kill -0 "$running_pid" 2>/dev/null; then
            remaining=1
        fi
    done
    if (( remaining == 0 )); then
        break
    fi
    sleep 0.1
done
for running_pid in "${RUNNING_PIDS[@]}"; do
    if kill -0 "$running_pid" 2>/dev/null; then
        kill -KILL "$running_pid" 2>/dev/null || true
    fi
done

if [[ -d "$APP_PATH" ]]; then
    /usr/bin/open -g "$APP_PATH"
fi
