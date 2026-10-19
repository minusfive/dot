#!/usr/bin/env zsh
#MISE description="Export tracked BetterDisplay settings"

set -euo pipefail

function {
    local __project_root_input="${MISE_PROJECT_ROOT:-}"
    local __project_root
    local __filesystem_utility
    local __filesystem_utility_parent
    local __physical_utility_parent

    [[ -n "$__project_root_input" && "$__project_root_input" == /* ]] || {
        print -u2 -- "MISE_PROJECT_ROOT must be a non-empty canonical physical directory."
        exit 1
    }
    if ! __project_root="$(
        builtin cd -P -- "$__project_root_input" 2>/dev/null &&
            builtin pwd -P
    )"; then
        print -u2 -- "Could not resolve MISE_PROJECT_ROOT: $__project_root_input"
        exit 1
    fi
    [[ "$__project_root" == "$__project_root_input" && -d "$__project_root" ]] || {
        print -u2 -- "MISE_PROJECT_ROOT must be a canonical physical directory: $__project_root_input"
        exit 1
    }
    __filesystem_utility_parent="$__project_root/scripts/utils"
    if ! __physical_utility_parent="$(
        builtin cd -P -- "$__filesystem_utility_parent" 2>/dev/null &&
            builtin pwd -P
    )"; then
        print -u2 -- "Could not resolve the filesystem utility directory: $__filesystem_utility_parent"
        exit 1
    fi
    [[ "$__physical_utility_parent" == "$__filesystem_utility_parent" ]] || {
        print -u2 -- "Filesystem utility directory must be canonical and physical: $__filesystem_utility_parent"
        exit 1
    }
    __filesystem_utility="$__filesystem_utility_parent/filesystem.zsh"
    [[ -f "$__filesystem_utility" && ! -L "$__filesystem_utility" ]] || {
        print -u2 -- "Filesystem utility must be a regular physical file: $__filesystem_utility"
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
