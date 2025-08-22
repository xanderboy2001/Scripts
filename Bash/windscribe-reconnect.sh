#!/usr/bin/env bash
set -euo pipefail

function get_connection_status() {
    windscribe-cli status | grep 'Connect state:' | awk -F':' '{print $2}' | tr -d '[:space:]'
}

function wait_for_status() {
    while [ "$(get_connection_status)" != "$1" ]; do
        sleep 1
    done
}

if [ "$(get_connection_status)" = 'Connected' ]; then
    windscribe-cli disconnect
    wait_for_status 'Disconnected'
fi
windscribe-cli connect best
wait_for_status 'Connected'
