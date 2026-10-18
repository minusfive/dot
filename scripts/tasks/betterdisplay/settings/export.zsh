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

    __physical_path() {
        local __path="$1"

        realpath -e "$__path" 2>/dev/null ||
            realpath "$__path" 2>/dev/null
    }

    __validate_physical_file() {
        local __label="$1"
        local __path="$2"

        [[ -f "$__path" ]] || {
            print -u2 -- "$__label is not a regular file: $__path"
            return 1
        }
        if ! __canonical_path="$(__physical_path "$__path")"; then
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

    local __source_path
    if ! __source_path="$(__physical_path "$__tracked_plist")" ||
        [[ "$__source_path" != "$__tracked_plist" ]]; then
        print -u2 -- "Tracked BetterDisplay plist has a symlinked or escaped ancestor: $__tracked_plist"
        exit 1
    fi

    local __source_identity
    if ! __source_identity="$(/usr/bin/stat -f '%d:%i:%z:%m' "$__tracked_plist")" ||
        [[ -z "$__source_identity" ]]; then
        print -u2 -- "Could not identify the tracked BetterDisplay settings."
        exit 1
    fi
    if ! plutil -lint "$__tracked_plist" >/dev/null; then
        print -u2 -- "Tracked BetterDisplay settings are not valid plist data."
        exit 1
    fi

    source "$__helper"

    local __temporary_plist=""
    function __cleanup {
        [[ -n "${__temporary_plist:-}" && -e "$__temporary_plist" ]] &&
            rm -f -- "$__temporary_plist"
    }
    trap __cleanup EXIT
    __abort_export() {
        local __message="$1"
        [[ -n "$__temporary_plist" ]] && rm -f -- "$__temporary_plist"
        print -u2 -- "$__message"
        exit 1
    }

    if ! __temporary_plist="$(mktemp "${__tracked_plist:h}/.config.plist.XXXXXX")"; then
        __abort_export "Could not create temporary BetterDisplay settings."
    fi
    if ! defaults export "$(betterdisplay::bundle_id)" "$__temporary_plist"; then
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

    __validate_physical_file "Tracked BetterDisplay plist" "$__tracked_plist" ||
        __abort_export "Tracked BetterDisplay plist is no longer physical."
    local __current_source_path
    if ! __current_source_path="$(__physical_path "$__tracked_plist")" ||
        [[ "$__source_path" != "$__current_source_path" ]]; then
        __abort_export "Tracked BetterDisplay plist changed during export."
    fi
    local __current_identity
    if ! __current_identity="$(/usr/bin/stat -f '%d:%i:%z:%m' "$__tracked_plist")" ||
        [[ -z "$__current_identity" ]]; then
        __abort_export "Could not revalidate the tracked BetterDisplay settings."
    fi
    if [[ "$__source_identity" != "$__current_identity" ]]; then
        __abort_export "Tracked BetterDisplay plist changed during export."
    fi

    __validate_physical_file "Tracked BetterDisplay plist" "$__tracked_plist" ||
        __abort_export "Tracked BetterDisplay plist is no longer physical."
    if ! __current_source_path="$(__physical_path "$__tracked_plist")" ||
        [[ "$__source_path" != "$__current_source_path" ]] ||
        ! __current_identity="$(/usr/bin/stat -f '%d:%i:%z:%m' "$__tracked_plist")" ||
        [[ -z "$__current_identity" ]] ||
        [[ "$__source_identity" != "$__current_identity" ]]; then
        __abort_export "Tracked BetterDisplay plist changed before replacement."
    fi

    mv -f -- "$__temporary_plist" "$__tracked_plist"
    trap - EXIT
    print -r -- "BetterDisplay settings exported to $__tracked_plist"
}
