#!/usr/bin/env zsh
#MISE description="Export live BetterDisplay settings or import tracked settings"
#MISE quiet=true
#MISE confirm={message="{% if usage.import == true or usage.import == \"true\" %}Import tracked BetterDisplay settings and overwrite live settings?{% else %}Export live BetterDisplay settings to the tracked plist?{% endif %}", default="no"}
#USAGE flag "-i --import" help="Import tracked settings instead of exporting live settings" default=#false

set -euo pipefail

typeset -gr PLIST_EXPORT_SUCCESS=0
typeset -gr PLIST_EXPORT_COMMAND_FAILED=10
typeset -gr PLIST_EXPORT_INVALID_OUTPUT=11
typeset -gr PLIST_EXPORT_COMMAND_FAILED_INVALID_OUTPUT=12

filesystem::physical_path() {
    realpath -e "$1" 2>/dev/null
}

filesystem::is_physical_file() {
    local __path="$1"
    local __physical_path

    [[ -f "$__path" && ! -L "$__path" ]] || return 1
    __physical_path="$(filesystem::physical_path "$__path")" || return 1
    [[ "$__physical_path" == "$__path" ]]
}

filesystem::validate_physical_file() {
    local __label="$1"
    local __path="$2"

    filesystem::is_physical_file "$__path" && return 0
    print -u2 -- "$__label is not a regular physical file: $__path"
    return 1
}

filesystem::identity() {
    /usr/bin/stat -f '%d:%i:%z:%m' "$1"
}

filesystem::identity_matches() {
    local __path="$1"
    local __expected_path="$2"
    local __expected_identity="$3"
    local __current_path
    local __current_identity

    filesystem::is_physical_file "$__path" || return 1
    __current_path="$(filesystem::physical_path "$__path")" || return 1
    [[ "$__current_path" == "$__expected_path" ]] || return 1
    __current_identity="$(filesystem::identity "$__path")" || return 1
    [[ -n "$__current_identity" && "$__current_identity" == "$__expected_identity" ]]
}

filesystem::cleanup_file() {
    local __path="${1:-}"

    [[ -n "$__path" && -e "$__path" ]] || return 0
    rm -f -- "$__path"
}

plist::export_and_validate() {
    local __bundle_id="$1"
    local __destination="$2"
    local __export_status=0
    local __validation_status=0
    local __resolved_destination

    defaults export "$__bundle_id" "$__destination" >/dev/null 2>&1 ||
        __export_status=$?

    if ! filesystem::is_physical_file "$__destination" ||
        ! __resolved_destination="$(filesystem::physical_path "$__destination")" ||
        [[ "$__resolved_destination" != "$__destination" ]] ||
        ! plutil -lint "$__destination" >/dev/null 2>&1; then
        __validation_status=1
    fi

    if (( __export_status != 0 )); then
        (( __validation_status != 0 )) &&
            return "$PLIST_EXPORT_COMMAND_FAILED_INVALID_OUTPUT"
        return "$PLIST_EXPORT_COMMAND_FAILED"
    fi

    (( __validation_status != 0 )) &&
        return "$PLIST_EXPORT_INVALID_OUTPUT"

    return "$PLIST_EXPORT_SUCCESS"
}

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

betterdisplay::validate_source() {
    local __tracked_plist="$1"

    filesystem::validate_physical_file \
        "Tracked BetterDisplay plist" "$__tracked_plist" || return 1
    plutil -lint "$__tracked_plist" >/dev/null ||
        {
            print -u2 -- "Tracked BetterDisplay settings are not valid plist data."
            return 1
        }
}

betterdisplay::export_settings() {
    local __tracked_plist="$1"
    local __source_identity="$2"
    local __temporary_plist=""
    local __export_status=0
    local __comparison_status=0

    betterdisplay::export_failure() {
        local __message="$1"

        filesystem::cleanup_file "$__temporary_plist"
        print -u2 -- "$__message"
        return 1
    }

    if ! __temporary_plist="$(mktemp "${__tracked_plist:h}/.config.plist.XXXXXX")"; then
        betterdisplay::export_failure \
            "Could not create temporary BetterDisplay settings."
        return $?
    fi

    plist::export_and_validate \
        "pro.betterdisplay.BetterDisplay" "$__temporary_plist" ||
        __export_status=$?
    case "$__export_status" in
        "$PLIST_EXPORT_SUCCESS")
            ;;
        "$PLIST_EXPORT_COMMAND_FAILED"|"$PLIST_EXPORT_COMMAND_FAILED_INVALID_OUTPUT")
            betterdisplay::export_failure \
                "Could not export BetterDisplay settings."
            return 1
            ;;
        "$PLIST_EXPORT_INVALID_OUTPUT")
            betterdisplay::export_failure \
                "Exported BetterDisplay settings are not valid plist data."
            return 1
            ;;
        *)
            betterdisplay::export_failure \
                "Could not export BetterDisplay settings."
            return 1
            ;;
    esac

    cmp -s "$__temporary_plist" "$__tracked_plist" ||
        __comparison_status=$?
    case "$__comparison_status" in
        0)
            filesystem::cleanup_file "$__temporary_plist"
            __temporary_plist=""
            print -r -- "BetterDisplay settings are unchanged."
            return 0
            ;;
        1)
            ;;
        *)
            betterdisplay::export_failure \
                "Could not compare exported BetterDisplay settings."
            return 1
            ;;
    esac

    if ! filesystem::identity_matches \
        "$__tracked_plist" "$__tracked_plist" "$__source_identity"; then
        betterdisplay::export_failure \
            "Tracked BetterDisplay plist changed during export."
        return 1
    fi

    if ! mv -f -- "$__temporary_plist" "$__tracked_plist"; then
        betterdisplay::export_failure \
            "Could not replace tracked BetterDisplay settings."
        return 1
    fi
    __temporary_plist=""
    print -r -- "BetterDisplay settings exported to $__tracked_plist"
}

betterdisplay::import_settings() {
    local __tracked_plist="$1"
    local __source_identity="$2"
    local __application_name="BetterDisplay"
    local __bundle_id="pro.betterdisplay.BetterDisplay"
    local __wait_timeout_seconds=10
    local __was_running=false
    local __backup_file=""
    local __backup_export_status=0
    local __restart_status=0

    betterdisplay::recover_after_stop() {
        local __message="$1"
        local __restart_error=""
        local __recovery_restart_status=0

        if [[ "$__was_running" == true ]] &&
            ! application::is_running "$__application_name"; then
            application::restart \
                "$__application_name" "$__application_name" "$__wait_timeout_seconds" ||
                __recovery_restart_status=$?
            if (( __recovery_restart_status != 0 )); then
                __restart_error="Could not restore the running ${__application_name} state."
            else
                print -u2 -- "${__application_name} was restarted."
            fi
        fi
        print -u2 -- "$__message"
        [[ -n "$__restart_error" ]] &&
            print -u2 -- "$__restart_error"
        [[ -n "$__backup_file" ]] &&
            print -u2 -- "Backup: $__backup_file"
        return 1
    }

    if application::is_running "$__application_name"; then
        __was_running=true
        if ! application::quit \
            "$__application_name" "$__wait_timeout_seconds" ||
            ! application::wait_for_state \
            "$__application_name" stopped "$__wait_timeout_seconds"; then
            betterdisplay::recover_after_stop \
                "Could not stop ${__application_name} before import."
            return $?
        fi
    fi

    local __backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/BetterDisplay/backups"
    if ! mkdir -p "$__backup_dir"; then
        betterdisplay::recover_after_stop \
            "Could not create the BetterDisplay backup directory."
        return $?
    fi
    if ! __backup_file="$(mktemp "$__backup_dir/BetterDisplay-live.plist.XXXXXX")"; then
        filesystem::cleanup_file "$__backup_file"
        __backup_file=""
        betterdisplay::recover_after_stop \
            "Could not create the live BetterDisplay backup."
        return $?
    fi

    plist::export_and_validate "$__bundle_id" "$__backup_file" ||
        __backup_export_status=$?
    case "$__backup_export_status" in
        "$PLIST_EXPORT_SUCCESS")
            ;;
        "$PLIST_EXPORT_COMMAND_FAILED")
            betterdisplay::recover_after_stop \
                "Could not save the live BetterDisplay backup."
            return $?
            ;;
        "$PLIST_EXPORT_COMMAND_FAILED_INVALID_OUTPUT")
            filesystem::cleanup_file "$__backup_file"
            __backup_file=""
            betterdisplay::recover_after_stop \
                "The live BetterDisplay backup is invalid."
            return $?
            ;;
        "$PLIST_EXPORT_INVALID_OUTPUT")
            filesystem::cleanup_file "$__backup_file"
            __backup_file=""
            betterdisplay::recover_after_stop \
                "The live BetterDisplay backup is invalid."
            return $?
            ;;
        *)
            filesystem::cleanup_file "$__backup_file"
            __backup_file=""
            betterdisplay::recover_after_stop \
                "Could not save the live BetterDisplay backup."
            return $?
            ;;
    esac

    if ! betterdisplay::validate_source "$__tracked_plist" ||
        ! filesystem::identity_matches \
        "$__tracked_plist" "$__tracked_plist" "$__source_identity"; then
        betterdisplay::recover_after_stop \
            "Tracked BetterDisplay settings changed during import preparation."
        return $?
    fi

    if ! defaults import "$__bundle_id" "$__tracked_plist"; then
        betterdisplay::recover_after_stop "BetterDisplay import failed."
        return $?
    fi

    if [[ "$__was_running" == true ]]; then
        __restart_status=0
        application::restart \
            "$__application_name" "$__application_name" "$__wait_timeout_seconds" ||
            __restart_status=$?
        case "$__restart_status" in
            125)
                betterdisplay::recover_after_stop \
                    "BetterDisplay settings imported, but the app could not be started."
                return $?
                ;;
            124)
                print -u2 -- \
                    "BetterDisplay settings imported, but the app restart could not be confirmed within ${__wait_timeout_seconds} seconds."
                print -u2 -- \
                    "BetterDisplay was left in its current state. The task did not retry or restore the backup."
                print -u2 -- "Backup: $__backup_file"
                return 1
                ;;
            0)
                ;;
            *)
                betterdisplay::recover_after_stop \
                    "BetterDisplay settings imported, but the app could not be restarted."
                return $?
                ;;
        esac
    fi

    print -r -- "BetterDisplay settings imported. Backup: $__backup_file"
}

main() {
    local __project_root
    local __tracked_plist
    local __source_identity

    if ! __project_root="$(realpath -e "$MISE_PROJECT_ROOT" 2>/dev/null)"; then
        print -u2 -- "Could not resolve the mise project root."
        return 1
    fi
    __tracked_plist="$__project_root/home/.config/BetterDisplay/config.plist"

    betterdisplay::validate_source "$__tracked_plist" || return 1
    if ! __source_identity="$(filesystem::identity "$__tracked_plist")" ||
        [[ -z "$__source_identity" ]]; then
        print -u2 -- "Could not identify the tracked BetterDisplay settings."
        return 1
    fi

    if [[ "${usage_import:-false}" == true || "${usage_import:-false}" == 1 ]]; then
        betterdisplay::import_settings "$__tracked_plist" "$__source_identity"
    else
        betterdisplay::export_settings "$__tracked_plist" "$__source_identity"
    fi
}

main "$@"
