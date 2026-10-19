#!/usr/bin/env zsh
#MISE description="Import tracked BetterDisplay settings"
#MISE confirm={message="Import tracked BetterDisplay settings and overwrite live settings?", default="no"}

set -euo pipefail

function {
    local __project_root
    if ! __project_root="$(realpath -e "$MISE_PROJECT_ROOT" 2>/dev/null)"; then
        print -u2 -- "Could not resolve the mise project root."
        exit 1
    fi
    local __filesystem_utility="$__project_root/scripts/utils/filesystem.zsh"
    local __resolved_filesystem_utility
    if [[ ! -f "$__filesystem_utility" ]] ||
        ! __resolved_filesystem_utility="$(
        realpath -e "$__filesystem_utility" 2>/dev/null
    )" || [[ "$__resolved_filesystem_utility" != "$__filesystem_utility" ]]; then
        print -u2 -- "Filesystem utility is not a regular physical file: $__filesystem_utility"
        exit 1
    fi
    builtin source "$__filesystem_utility"
    local __application_utility="$__project_root/scripts/utils/application.zsh"
    local __tracked_plist="$__project_root/home/.config/BetterDisplay/config.plist"
    local __application_name="BetterDisplay"
    local __bundle_id="pro.betterdisplay.BetterDisplay"

    filesystem::validate_physical_file \
        "Tracked BetterDisplay plist" "$__tracked_plist" || exit 1
    local __source_identity
    if ! __source_identity="$(filesystem::identity "$__tracked_plist")" ||
        [[ -z "$__source_identity" ]]; then
        print -u2 -- "Could not identify the tracked BetterDisplay settings."
        exit 1
    fi
    if ! plutil -lint "$__tracked_plist" >/dev/null; then
        print -u2 -- "Tracked BetterDisplay settings are not valid plist data."
        exit 1
    fi

    filesystem::validate_physical_file \
        "Application utility" "$__application_utility" || exit 1
    builtin source "$__application_utility"

    local __was_running=false
    local __backup_file=""
    local __wait_timeout_seconds=10
    __abort_after_stop() {
        local __message="$1"
        local __restart_error=""
        local __restart_status=0

        if [[ "$__was_running" == true ]] &&
            ! application::is_running "$__application_name"; then
            application::restart \
                "$__application_name" "$__application_name" "$__wait_timeout_seconds" ||
                __restart_status=$?
            if (( __restart_status != 0 )); then
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
        exit 1
    }

    if application::is_running "$__application_name"; then
        __was_running=true
        if ! application::quit \
            "$__application_name" "$__wait_timeout_seconds"; then
            __abort_after_stop "Could not stop ${__application_name} before import."
        fi
        if ! application::wait_for_state \
            "$__application_name" stopped "$__wait_timeout_seconds"; then
            __abort_after_stop "${__application_name} did not stop before import."
        fi
    fi

    local __backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/BetterDisplay/backups"

    if ! mkdir -p "$__backup_dir"; then
        __abort_after_stop "Could not create the BetterDisplay backup directory."
    fi
    if ! __backup_file="$(mktemp "$__backup_dir/BetterDisplay-live.plist.XXXXXX")"; then
        filesystem::cleanup_known_temp "$__backup_file"
        __backup_file=""
        __abort_after_stop "Could not create the live BetterDisplay backup."
    fi

    local __backup_export_status=0
    defaults export "$__bundle_id" "$__backup_file" || __backup_export_status=$?
    local __backup_is_valid=false
    if filesystem::is_physical_file "$__backup_file" &&
        plutil -lint "$__backup_file" >/dev/null 2>&1; then
        __backup_is_valid=true
    fi
    if [[ "$__backup_is_valid" != true ]]; then
        filesystem::cleanup_known_temp "$__backup_file"
        __backup_file=""
        if (( __backup_export_status == 0 )); then
            __abort_after_stop "The live BetterDisplay backup is invalid."
        fi
        __abort_after_stop "Could not save the live BetterDisplay backup."
    fi
    if (( __backup_export_status != 0 )); then
        __abort_after_stop "Could not save the live BetterDisplay backup."
    fi

    if ! filesystem::identity_matches \
        "$__tracked_plist" "$__tracked_plist" "$__source_identity"; then
        __abort_after_stop "Tracked BetterDisplay settings changed during import preparation."
    fi

    if ! defaults import "$__bundle_id" "$__tracked_plist"; then
        __abort_after_stop "BetterDisplay import failed."
    fi

    if [[ "$__was_running" == true ]]; then
        local __restart_status=0
        application::restart \
            "$__application_name" "$__application_name" "$__wait_timeout_seconds" ||
            __restart_status=$?
        case "$__restart_status" in
            125)
                __abort_after_stop \
                    "BetterDisplay settings imported, but the app could not be started."
                ;;
            124)
                print -u2 -- \
                    "BetterDisplay settings imported, but the app restart could not be confirmed within ${__wait_timeout_seconds} seconds."
                print -u2 -- "Backup: $__backup_file"
                exit 1
                ;;
            0)
                ;;
            *)
                __abort_after_stop "BetterDisplay settings imported, but the app could not be restarted."
                ;;
        esac
    fi

    print -r -- "BetterDisplay settings imported. Backup: $__backup_file"
}
