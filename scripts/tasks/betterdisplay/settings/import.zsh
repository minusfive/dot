#!/usr/bin/env zsh
#MISE description="Import tracked BetterDisplay settings"
#MISE confirm={message="Import tracked BetterDisplay settings and overwrite live settings?", default="no"}

set -euo pipefail

function {
    local __project_root_input="${MISE_PROJECT_ROOT:-}"
    [[ -n "$__project_root_input" ]] || {
        print -u2 -- "MISE_PROJECT_ROOT is required"
        exit 1
    }
    local __project_root
    if ! __project_root="$(
        realpath -e "$__project_root_input" 2>/dev/null ||
            realpath "$__project_root_input" 2>/dev/null
    )"; then
        print -u2 -- "Could not resolve MISE_PROJECT_ROOT: $__project_root_input"
        exit 1
    fi
    [[ "$__project_root" == "$__project_root_input" ]] || {
        print -u2 -- "MISE_PROJECT_ROOT must be a canonical physical directory: $__project_root_input"
        exit 1
    }
    [[ -d "$__project_root" ]] || {
        print -u2 -- "MISE_PROJECT_ROOT is not a directory: $__project_root"
        exit 1
    }

    local __helper="$__project_root/scripts/utils/betterdisplay.zsh"
    local __tracked_plist="$__project_root/home/.config/BetterDisplay/config.plist"
    local __canonical_path

    __validate_physical_file() {
        local __label="$1"
        local __path="$2"

        [[ -f "$__path" ]] || {
            print -u2 -- "$__label is not a regular file: $__path"
            return 1
        }
        if ! __canonical_path="$(
            realpath -e "$__path" 2>/dev/null ||
                realpath "$__path" 2>/dev/null
        )"; then
            print -u2 -- "Could not resolve $__label: $__path"
            return 1
        fi
        [[ "$__canonical_path" == "$__path" ]] || {
            print -u2 -- "$__label has a symlinked or escaped ancestor: $__path"
            return 1
        }
    }

    __validate_physical_file "BetterDisplay helper" "$__helper" || exit 1
    __validate_physical_file "Tracked BetterDisplay plist" "$__tracked_plist" || exit 1

    local __source_identity
    if ! __source_identity="$(stat -f '%d:%i:%z:%m' "$__tracked_plist")" ||
        [[ -z "$__source_identity" ]]; then
        print -u2 -- "Could not identify the tracked BetterDisplay settings."
        exit 1
    fi
    if ! plutil -lint "$__tracked_plist" >/dev/null; then
        print -u2 -- "Tracked BetterDisplay settings are not valid plist data."
        exit 1
    fi

    source "$__helper"

    local __current_identity
    if ! __current_identity="$(betterdisplay::source_identity "$__tracked_plist")" ||
        [[ -z "$__current_identity" ]]; then
        print -u2 -- "Could not revalidate the tracked BetterDisplay settings."
        exit 1
    fi

    local __was_running=false
    local __backup_file=""
    local __wait_timeout_seconds=10
    local __termination_grace_seconds=2
    local __kill_grace_seconds=2
    __run_osascript_with_timeout() {
        local __osascript_pid
        local __deadline
        local __grace_deadline

        osascript \
            -e "with timeout of ${__wait_timeout_seconds} seconds" \
            -e 'tell application "BetterDisplay" to quit' \
            -e 'end timeout' &
        __osascript_pid=$!
        __deadline=$(( SECONDS + __wait_timeout_seconds ))

        while kill -0 "$__osascript_pid" 2>/dev/null; do
            if (( SECONDS >= __deadline )); then
                break
            fi
            sleep 1
        done

        if kill -0 "$__osascript_pid" 2>/dev/null; then
            kill -TERM "$__osascript_pid" 2>/dev/null || true
            __grace_deadline=$(( SECONDS + __termination_grace_seconds ))
            while kill -0 "$__osascript_pid" 2>/dev/null; do
                if (( SECONDS >= __grace_deadline )); then
                    break
                fi
                sleep 1
            done
        fi

        if kill -0 "$__osascript_pid" 2>/dev/null; then
            kill -KILL "$__osascript_pid" 2>/dev/null || true
            __grace_deadline=$(( SECONDS + __kill_grace_seconds ))
            while kill -0 "$__osascript_pid" 2>/dev/null; do
                if (( SECONDS >= __grace_deadline )); then
                    break
                fi
                sleep 1
            done
        fi

        if kill -0 "$__osascript_pid" 2>/dev/null; then
            print -u2 -- "Watchdog could not terminate osascript PID $__osascript_pid."
            return 124
        fi

        wait "$__osascript_pid"
    }

    __abort_after_stop() {
        local __message="$1"
        local __restart_error=""

        if [[ "$__was_running" == true ]] && ! betterdisplay::is_running; then
            if ! open -a "BetterDisplay" >/dev/null 2>&1 ||
                ! betterdisplay::wait_for_state running 10; then
                __restart_error="Could not restore the running BetterDisplay state."
            fi
        fi
        print -u2 -- "$__message"
        if [[ -n "$__restart_error" ]]; then
            print -u2 -- "$__restart_error"
        elif [[ "$__was_running" == true ]]; then
            print -u2 -- "BetterDisplay was restarted."
        fi
        [[ -n "$__backup_file" ]] && print -u2 -- "Backup: $__backup_file"
        exit 1
    }

    if betterdisplay::is_running; then
        __was_running=true
        if ! __run_osascript_with_timeout; then
            __abort_after_stop "Could not stop BetterDisplay before import."
        fi
        if ! betterdisplay::wait_for_state stopped "$__wait_timeout_seconds"; then
            __abort_after_stop "BetterDisplay did not stop before import."
        fi
    fi

    local __backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/BetterDisplay/backups"

    if ! mkdir -p "$__backup_dir"; then
        __abort_after_stop "Could not create the BetterDisplay backup directory."
    fi
    if ! __backup_file="$(mktemp "$__backup_dir/BetterDisplay-live.plist.XXXXXX")"; then
        [[ -n "$__backup_file" && -e "$__backup_file" ]] && rm -f -- "$__backup_file"
        __backup_file=""
        __abort_after_stop "Could not create the live BetterDisplay backup."
    fi

    local __backup_export_status=0
    defaults export "$(betterdisplay::bundle_id)" "$__backup_file" || __backup_export_status=$?
    local __backup_is_valid=false
    if [[ -f "$__backup_file" ]] && plutil -lint "$__backup_file" >/dev/null 2>&1; then
        __backup_is_valid=true
    fi
    if [[ "$__backup_is_valid" != true ]]; then
        rm -f -- "$__backup_file"
        __backup_file=""
        if (( __backup_export_status == 0 )); then
            __abort_after_stop "The live BetterDisplay backup is invalid."
        fi
        __abort_after_stop "Could not save the live BetterDisplay backup."
    fi
    if (( __backup_export_status != 0 )); then
        __abort_after_stop "Could not save the live BetterDisplay backup."
    fi

    if ! __current_identity="$(betterdisplay::source_identity "$__tracked_plist")"; then
        __abort_after_stop "Could not revalidate the tracked BetterDisplay settings."
    fi
    if [[ "$__source_identity" != "$__current_identity" ]]; then
        __abort_after_stop "Tracked BetterDisplay settings changed during import preparation. Backup: $__backup_file"
    fi

    __validate_physical_file "Tracked BetterDisplay plist" "$__tracked_plist" ||
        __abort_after_stop "Tracked BetterDisplay plist path is no longer physical. Backup: $__backup_file"
    if ! defaults import "$(betterdisplay::bundle_id)" "$__tracked_plist"; then
        __abort_after_stop "BetterDisplay import failed. Backup: $__backup_file"
    fi

    if [[ "$__was_running" == true ]]; then
        if ! open -a "BetterDisplay" >/dev/null 2>&1 ||
            ! betterdisplay::wait_for_state running "$__wait_timeout_seconds"; then
            __abort_after_stop "BetterDisplay settings imported, but the app could not be restarted."
        fi
    fi

    print -r -- "BetterDisplay settings imported. Backup: $__backup_file"
}
