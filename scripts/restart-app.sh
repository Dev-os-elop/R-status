#!/bin/zsh
set -u

JOB_LABEL="$1"
APP_PATH="$2"
shift 2
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

APP_EXECUTABLE="$APP_PATH/Contents/MacOS/RStudioStatus"
if [[ -x "$APP_EXECUTABLE" ]]; then
    /usr/bin/open -g "$APP_PATH"
fi

# This job is only for the one update restart. Removing it here means a later
# manual quit is not interpreted by launchd as a request to relaunch the app.
/bin/launchctl remove "$JOB_LABEL" 2>/dev/null || true
