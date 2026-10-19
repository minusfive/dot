#!/usr/bin/env zsh
#MISE description="Export tracked BetterDisplay settings"

set -euo pipefail

function {
    local __project_root="$MISE_PROJECT_ROOT"
    local __filesystem_utility="$__project_root/scripts/utils/filesystem.zsh"

    [[ -f "$__filesystem_utility" &&
        "$__filesystem_utility" == "${__filesystem_utility:A}" ]] ||
        {
            print -u2 -- "Filesystem utility is not a regular physical file: $__filesystem_utility"
            exit 1
        }
    builtin source "$__filesystem_utility"
    local __tracked_plist="$__project_root/home/.config/BetterDisplay/config.plist"

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

    local __temporary_plist=""
    function __cleanup {
        filesystem::cleanup_known_temp "${__temporary_plist:-}"
    }
    trap __cleanup EXIT
    __abort_export() {
        local __message="$1"
        filesystem::cleanup_known_temp "$__temporary_plist"
        print -u2 -- "$__message"
        exit 1
    }

    if ! __temporary_plist="$(mktemp "${__tracked_plist:h}/.config.plist.XXXXXX")"; then
        __abort_export "Could not create temporary BetterDisplay settings."
    fi
    if ! defaults export "pro.betterdisplay.BetterDisplay" "$__temporary_plist"; then
        __abort_export "Could not export BetterDisplay settings."
    fi
    if ! plutil -lint "$__temporary_plist" >/dev/null; then
        __abort_export "Exported BetterDisplay settings are not valid plist data."
    fi

    local __comparison_status=0
    cmp -s "$__temporary_plist" "$__tracked_plist" || __comparison_status=$?
    case "$__comparison_status" in
        0)
            print -r -- "BetterDisplay settings are unchanged."
            exit 0
            ;;
        1)
            ;;
        *)
            __abort_export "Could not compare exported BetterDisplay settings."
            ;;
    esac

    if ! filesystem::identity_matches \
        "$__tracked_plist" "$__tracked_plist" "$__source_identity"; then
        __abort_export "Tracked BetterDisplay plist changed during export."
    fi

    mv -f -- "$__temporary_plist" "$__tracked_plist"
    trap - EXIT
    print -r -- "BetterDisplay settings exported to $__tracked_plist"
}
