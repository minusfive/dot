#!/usr/bin/env zsh
#MISE description="Export BetterDisplay settings to the tracked plist"
#MISE quiet=true
#MISE dir="{{cwd}}"

set -euo pipefail

local __source_file __baseline_file __export_file __recovery_file
local __task_file="${0:A}" __trusted_root
__trusted_root="$(cd "${__task_file:h}/../../../../../../" 2>/dev/null && pwd -P)" || {
    print -u2 -- "error: could not determine the trusted dotfiles repository"
    exit 1
}
source "$__trusted_root/scripts/utils/betterdisplay.zsh"
betterdisplay_repo_root_is_valid "$__trusted_root" || {
    print -u2 -- "error: refusing untrusted dotfiles repository: $__trusted_root"
    exit 1
}
if ! __source_file="$(betterdisplay_trusted_source_file "$__trusted_root")"; then
    exit 1
fi

betterdisplay_require_installed
betterdisplay_validate_plist "$__source_file"
betterdisplay_acquire_lock
cleanup() {
    betterdisplay_release_lock
    [[ -n "${__baseline_file:-}" ]] && rm -f "$__baseline_file"
    [[ -n "${__export_file:-}" ]] && rm -f "$__export_file"
    [[ -n "${__recovery_file:-}" ]] &&
        print -u2 -- "error: recovery copy retained at $__recovery_file"
    return 0
}
trap cleanup EXIT

__baseline_file="$(betterdisplay_make_temp_file "$(dirname "$__source_file")")"
cp "$__source_file" "$__baseline_file"
__export_file="$(betterdisplay_make_temp_file "$(dirname "$__source_file")")"

if ! defaults export "$BETTERDISPLAY_BUNDLE_ID" "$__export_file" >/dev/null; then
    print -u2 -- "error: BetterDisplay settings export failed"
    exit 1
fi
if ! betterdisplay_validate_plist "$__export_file"; then
    exit 1
fi
if ! cmp -s "$__source_file" "$__baseline_file"; then
    __recovery_file="$(betterdisplay_preserve_recovery_file "$__export_file")" || true
    __export_file=""
    print -u2 -- "error: tracked BetterDisplay plist changed during export; refusing replacement"
    exit 1
fi

if cmp -s "$__source_file" "$__export_file"; then
    print -r -- "BetterDisplay settings unchanged"
    exit 0
fi

if ! cmp -s "$__source_file" "$__baseline_file"; then
    __recovery_file="$(betterdisplay_preserve_recovery_file "$__export_file")" || true
    __export_file=""
    print -u2 -- "error: tracked BetterDisplay plist changed before replacement; refusing replacement"
    exit 1
fi

if ! mv "$__export_file" "$__source_file"; then
    __recovery_file="$(betterdisplay_preserve_recovery_file "$__export_file")" || true
    __export_file=""
    print -u2 -- "error: could not replace tracked BetterDisplay settings"
    exit 1
fi
__export_file=""
rm -f "$__baseline_file"
__baseline_file=""
print -r -- "Updated tracked BetterDisplay settings: $__source_file"
