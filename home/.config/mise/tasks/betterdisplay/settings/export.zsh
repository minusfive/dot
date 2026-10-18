#!/usr/bin/env zsh
#MISE description="Export BetterDisplay settings to the tracked plist"
#MISE quiet=true
#MISE dir="{{cwd}}"

set -euo pipefail

local __repo_root __source_file __baseline_file __export_file __expected_file __conflict_file __repo_hint
if [[ -n "${MISE_PROJECT_ROOT:-}" && -d "$MISE_PROJECT_ROOT/home/.config/BetterDisplay" ]]; then
    __repo_root="$(cd "$MISE_PROJECT_ROOT" && pwd -P)"
else
    __repo_hint="${MISE_ORIGINAL_CWD:-$PWD}"
    __repo_root="$(git -C "$__repo_hint" rev-parse --show-toplevel 2>/dev/null)" ||
        { print -u2 -- "error: could not find the dotfiles repository"; exit 1; }
fi
source "$__repo_root/scripts/utils/betterdisplay.zsh"
__source_file="$(betterdisplay_source_file "$__repo_root")"

betterdisplay_require_installed
betterdisplay_validate_plist "$__source_file"
betterdisplay_acquire_lock
cleanup() {
    betterdisplay_release_lock
    [[ -n "${__baseline_file:-}" ]] && rm -f "$__baseline_file"
    [[ -n "${__export_file:-}" ]] && rm -f "$__export_file"
    [[ -n "${__expected_file:-}" ]] && rm -f "$__expected_file"
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

if ! cmp -s "$__export_file" "$__baseline_file"; then
    __conflict_file="$(betterdisplay_make_temp_file "$(betterdisplay_runtime_dir)/conflicts")"
    cp "$__export_file" "$__conflict_file"
    if ! betterdisplay_atomic_swap "$__source_file" "$__export_file" >/dev/null 2>&1; then
        __export_file=""
        print -u2 -- "error: could not roll back the concurrent BetterDisplay settings replacement"
        print -u2 -- "error: previous tracked content preserved at $__conflict_file"
        cleanup
        exit 1
    fi
    print -u2 -- "error: tracked BetterDisplay plist changed during replacement; refusing replacement"
    print -u2 -- "error: concurrent content preserved at $__conflict_file"
    cleanup
    exit 1
fi
if ! cmp -s "$__source_file" "$__expected_file"; then
    __conflict_file="$(betterdisplay_make_temp_file "$(betterdisplay_runtime_dir)/conflicts")"
    cp "$__source_file" "$__conflict_file"
    if ! betterdisplay_atomic_swap "$__source_file" "$__export_file" >/dev/null 2>&1; then
        __export_file=""
        print -u2 -- "error: could not roll back the concurrent BetterDisplay settings replacement"
        print -u2 -- "error: concurrent content preserved at $__conflict_file"
        cleanup
        exit 1
    fi
    print -u2 -- "error: tracked BetterDisplay plist changed after replacement; refusing replacement"
    print -u2 -- "error: concurrent content preserved at $__conflict_file"
    cleanup
    exit 1
fi

rm -f "$__export_file"
__export_file=""
rm -f "$__baseline_file" "$__expected_file"
__baseline_file=""
__expected_file=""
print -r -- "Updated tracked BetterDisplay settings: $__source_file"
