#!/usr/bin/env zsh
#MISE description="Export BetterDisplay settings to the tracked plist"
#MISE quiet=true
#MISE dir="{{cwd}}"

set -euo pipefail

local __source_file __baseline_file __export_file __expected_file __recovery_file
local __task_file="${0:A}" __trusted_root
local __preserve_displaced=false
local -a __recovery_files=()
__trusted_root="$(cd "${__task_file:h}/../../../../../../" 2>/dev/null && pwd -P)" || {
    print -u2 -- "error: could not determine the trusted dotfiles repository"
    exit 1
}
source "$__trusted_root/scripts/utils/betterdisplay.zsh"
betterdisplay_repo_root_is_valid "$__trusted_root" || {
    print -u2 -- "error: refusing untrusted dotfiles repository: $__trusted_root"
    exit 1
}
__source_file="$(betterdisplay_source_file "$__trusted_root")"

betterdisplay_require_installed
betterdisplay_validate_plist "$__source_file"
betterdisplay_acquire_lock
cleanup() {
    betterdisplay_release_lock
    [[ -n "${__baseline_file:-}" ]] && rm -f "$__baseline_file"
    if [[ "$__preserve_displaced" != true && -n "${__export_file:-}" ]]; then
        rm -f "$__export_file"
    fi
    [[ -n "${__expected_file:-}" ]] && rm -f "$__expected_file"
    if [[ "$__preserve_displaced" == true ]]; then
        print -u2 -- "error: displaced tracked content retained at $__export_file"
    fi
    for __recovery_file in "${__recovery_files[@]}"; do
        print -u2 -- "error: recovery copy retained at $__recovery_file"
    done
}
trap cleanup EXIT

__baseline_file="$(betterdisplay_make_temp_file "$(dirname "$__source_file")")"
cp "$__source_file" "$__baseline_file"
__export_file="$(betterdisplay_make_temp_file "$(dirname "$__source_file")")"

if ! defaults export "$BETTERDISPLAY_BUNDLE_ID" "$__export_file" >/dev/null; then
    print -u2 -- "error: BetterDisplay settings export failed"
    cleanup
    exit 1
fi
if ! betterdisplay_validate_plist "$__export_file"; then
    cleanup
    exit 1
fi
__expected_file="$(betterdisplay_make_temp_file "$(dirname "$__source_file")")"
cp "$__export_file" "$__expected_file"

if ! cmp -s "$__source_file" "$__baseline_file"; then
    print -u2 -- "error: tracked BetterDisplay plist changed during export; refusing replacement"
    cleanup
    exit 1
fi

if cmp -s "$__source_file" "$__export_file"; then
    print -r -- "BetterDisplay settings unchanged"
    cleanup
    exit 0
fi

if ! betterdisplay_atomic_swap "$__source_file" "$__export_file"; then
    print -u2 -- "error: could not replace tracked BetterDisplay settings"
    cleanup
    exit 1
fi

__preserve_recovery_copy() {
    local __source="$1" __recovery_file

    if ! __recovery_file="$(betterdisplay_make_temp_file "$(betterdisplay_runtime_dir)/conflicts")" ||
        ! cp "$__source" "$__recovery_file"; then
        rm -f "${__recovery_file:-}"
        __preserve_displaced=true
        return 1
    fi
    __recovery_files+=("$__recovery_file")
    print -u2 -- "error: concurrent content preserved at $__recovery_file"
}

__rollback_swap() {
    local __before_file

    if ! __before_file="$(betterdisplay_make_temp_file "$(betterdisplay_runtime_dir)/conflicts")" ||
        ! cp "$__source_file" "$__before_file"; then
        rm -f "${__before_file:-}"
        __preserve_displaced=true
        print -u2 -- "error: could not preserve content before BetterDisplay settings rollback"
        return 1
    fi
    __recovery_files+=("$__before_file")

    if ! betterdisplay_atomic_swap "$__source_file" "$__export_file" >/dev/null 2>&1; then
        __preserve_displaced=true
        print -u2 -- "error: could not roll back the concurrent BetterDisplay settings replacement"
        return 1
    fi

    if ! cmp -s "$__export_file" "$__before_file"; then
        if ! __preserve_recovery_copy "$__export_file"; then
            print -u2 -- "error: could not preserve content displaced by BetterDisplay settings rollback"
            return 1
        fi
    fi
}

if ! cmp -s "$__export_file" "$__baseline_file"; then
    if ! __preserve_recovery_copy "$__export_file"; then
        __preserve_displaced=true
        print -u2 -- "error: could not preserve concurrent BetterDisplay settings"
        exit 1
    fi
    if ! __rollback_swap; then
        exit 1
    fi
    print -u2 -- "error: tracked BetterDisplay plist changed during replacement; refusing replacement"
    cleanup
    exit 1
fi
if ! cmp -s "$__source_file" "$__expected_file"; then
    if ! __preserve_recovery_copy "$__source_file"; then
        __preserve_displaced=true
        print -u2 -- "error: could not preserve concurrent BetterDisplay settings"
        exit 1
    fi
    if ! __rollback_swap; then
        exit 1
    fi
    print -u2 -- "error: tracked BetterDisplay plist changed after replacement; refusing replacement"
    cleanup
    exit 1
fi

rm -f "$__export_file"
__export_file=""
rm -f "$__baseline_file" "$__expected_file"
__baseline_file=""
__expected_file=""
print -r -- "Updated tracked BetterDisplay settings: $__source_file"
