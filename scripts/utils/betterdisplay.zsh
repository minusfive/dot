#!/usr/bin/env zsh

set -euo pipefail

betterdisplay::bundle_id() {
    print -r -- "pro.betterdisplay.BetterDisplay"
}

betterdisplay::is_running() {
    pgrep -x "BetterDisplay" >/dev/null 2>&1
}

betterdisplay::source_identity() {
    stat -f '%d:%i:%z:%m' "$1"
}

betterdisplay::wait_for_state() {
    local __expected_state="$1"
    local __timeout_seconds="${2:-10}"
    local __attempt

    for (( __attempt = 0; __attempt < __timeout_seconds; __attempt++ )); do
        if [[ "$__expected_state" == "running" ]] && betterdisplay::is_running; then
            return 0
        fi
        if [[ "$__expected_state" == "stopped" ]] && ! betterdisplay::is_running; then
            return 0
        fi
        sleep 1
    done

    if [[ "$__expected_state" == "running" ]] && betterdisplay::is_running; then
        return 0
    fi
    if [[ "$__expected_state" == "stopped" ]] && ! betterdisplay::is_running; then
        return 0
    fi
    return 1
}
