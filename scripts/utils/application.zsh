#!/usr/bin/env zsh

set -euo pipefail

application::is_running() {
    pgrep -x "$1" >/dev/null 2>&1
}

application::wait_for_state() {
    local __process_name="$1"
    local __expected_state="$2"
    local __timeout_seconds="${3:-10}"
    local __attempt

    [[ "$__expected_state" == running || "$__expected_state" == stopped ]] ||
        return 2

    for (( __attempt = 0; __attempt < __timeout_seconds; __attempt++ )); do
        if [[ "$__expected_state" == running ]] &&
            application::is_running "$__process_name"; then
            return 0
        fi
        if [[ "$__expected_state" == stopped ]] &&
            ! application::is_running "$__process_name"; then
            return 0
        fi
        sleep 1
    done

    if [[ "$__expected_state" == running ]] &&
        application::is_running "$__process_name"; then
        return 0
    fi
    if [[ "$__expected_state" == stopped ]] &&
        ! application::is_running "$__process_name"; then
        return 0
    fi
    return 1
}

application::wait_for_pid_exit() {
    local __pid="$1"
    local __timeout_seconds="${2:-10}"
    local __deadline=$(( SECONDS + __timeout_seconds ))

    while kill -0 "$__pid" 2>/dev/null; do
        (( SECONDS >= __deadline )) && return 1
        sleep 1
    done
}

application::quit() {
    local __application_name="$1"
    local __timeout_seconds="${2:-10}"
    local __termination_grace_seconds="${3:-2}"
    local __kill_grace_seconds="${4:-2}"
    local __osascript_pid

    osascript \
        -e "with timeout of ${__timeout_seconds} seconds" \
        -e "tell application \"${__application_name}\" to quit" \
        -e 'end timeout' &
    __osascript_pid=$!

    if ! application::wait_for_pid_exit "$__osascript_pid" "$__timeout_seconds"; then
        kill -TERM "$__osascript_pid" 2>/dev/null || true
        application::wait_for_pid_exit \
            "$__osascript_pid" "$__termination_grace_seconds" || true
    fi

    if kill -0 "$__osascript_pid" 2>/dev/null; then
        kill -KILL "$__osascript_pid" 2>/dev/null || true
        application::wait_for_pid_exit \
            "$__osascript_pid" "$__kill_grace_seconds" || true
    fi

    if kill -0 "$__osascript_pid" 2>/dev/null; then
        return 124
    fi

    wait "$__osascript_pid"
}

application::restart() {
    local __application_name="$1"
    local __process_name="$2"
    local __timeout_seconds="${3:-10}"

    open -a "$__application_name" >/dev/null 2>&1 || return 125
    application::wait_for_state \
        "$__process_name" running "$__timeout_seconds" || return 124
}
