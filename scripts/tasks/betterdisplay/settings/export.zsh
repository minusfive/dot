#!/usr/bin/env zsh
#MISE description="Export tracked BetterDisplay settings"

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

    local __temporary_plist
    __temporary_plist="$(mktemp "${__tracked_plist:h}/.config.plist.XXXXXX")"
    function __cleanup {
        [[ -n "${__temporary_plist:-}" && -e "$__temporary_plist" ]] && rm -f -- "$__temporary_plist"
    }
    trap __cleanup EXIT

    defaults export "$(betterdisplay::bundle_id)" "$__temporary_plist"
    plutil -lint "$__temporary_plist" >/dev/null

    if cmp -s "$__temporary_plist" "$__tracked_plist"; then
        print -r -- "BetterDisplay settings are unchanged."
        exit 0
    fi

    __validate_physical_file "Tracked BetterDisplay plist" "$__tracked_plist" || exit 1
    mv -f -- "$__temporary_plist" "$__tracked_plist"
    trap - EXIT
    print -r -- "BetterDisplay settings exported to $__tracked_plist"
}
