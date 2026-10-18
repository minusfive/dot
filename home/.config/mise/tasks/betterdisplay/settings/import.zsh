#!/usr/bin/env zsh
#MISE description="Import the tracked plist into BetterDisplay"
#MISE quiet=true
#MISE dir="{{cwd}}"

set -euo pipefail

local __source_file __backup_file __reply
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
__source_file="$(betterdisplay_source_file "$__trusted_root")"

betterdisplay_require_installed
betterdisplay_validate_plist "$__source_file"
betterdisplay_acquire_lock
trap betterdisplay_release_lock EXIT

if betterdisplay_is_running; then
    print -u2 -- "error: BetterDisplay is running; quit it before importing settings"
    betterdisplay_release_lock
    exit 1
fi

print -n "Import tracked BetterDisplay settings and overwrite live settings? [y/N] "
if ! read -r __reply; then
    print -u2 -- "error: import cancelled"
    betterdisplay_release_lock
    exit 1
fi
if [[ "$__reply" != [Yy] ]]; then
    print -r -- "Import cancelled"
    betterdisplay_release_lock
    exit 0
fi

if ! __backup_file="$(betterdisplay_backup_current_settings)"; then
    print -u2 -- "error: import stopped because the current settings backup failed"
    betterdisplay_release_lock
    exit 1
fi
print -r -- "Backed up current BetterDisplay settings: $__backup_file"

betterdisplay_import_if_closed() {
    if betterdisplay_is_running; then
        return 2
    fi
    defaults import "$BETTERDISPLAY_BUNDLE_ID" "$__source_file"
}

# Keep the final running-state check adjacent to defaults import. macOS does
# not provide a lock that BetterDisplay itself honors, so verify and roll back
# if it launches during the import.
if betterdisplay_import_if_closed; then
    :
else
    __import_status=$?
    if [[ "$__import_status" == 2 ]]; then
        print -u2 -- "error: BetterDisplay relaunched during import; refusing to overwrite live settings"
    else
        print -u2 -- "error: BetterDisplay settings import failed"
    fi
    betterdisplay_release_lock
    exit 1
fi

if betterdisplay_is_running; then
    print -u2 -- "error: BetterDisplay launched during import; restoring the previous settings"
    if ! defaults import "$BETTERDISPLAY_BUNDLE_ID" "$__backup_file"; then
        print -u2 -- "error: could not roll back BetterDisplay settings; backup retained at $__backup_file"
        betterdisplay_release_lock
        exit 1
    fi
    if betterdisplay_is_running; then
        print -u2 -- "error: BetterDisplay is still running; rollback completed but must be verified after quitting the app"
    else
        print -u2 -- "error: BetterDisplay launched during import; previous settings restored"
    fi
    betterdisplay_release_lock
    exit 1
fi

print -r -- "Imported BetterDisplay settings. Restart BetterDisplay to apply them."
betterdisplay_release_lock
