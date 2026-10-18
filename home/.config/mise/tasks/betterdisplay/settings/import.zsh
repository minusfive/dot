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
if ! __source_file="$(betterdisplay_trusted_source_file "$__trusted_root")"; then
    exit 1
fi

betterdisplay_require_installed
betterdisplay_validate_plist "$__source_file"
betterdisplay_acquire_lock
trap betterdisplay_release_lock EXIT

if betterdisplay_is_running; then
    print -u2 -- "error: BetterDisplay is running; quit it before importing settings"
    exit 1
fi

print -n "Import tracked BetterDisplay settings and overwrite live settings? [y/N] "
if ! read -r __reply; then
    print -u2 -- "error: import cancelled"
    exit 1
fi
if [[ "$__reply" != [Yy] ]]; then
    print -r -- "Import cancelled"
    exit 0
fi

if ! __backup_file="$(betterdisplay_backup_current_settings)"; then
    print -u2 -- "error: import stopped because the current settings backup failed"
    exit 1
fi
print -r -- "Backed up current BetterDisplay settings: $__backup_file"

if betterdisplay_is_running; then
    print -u2 -- "error: BetterDisplay relaunched after backup; refusing to import settings"
    exit 1
fi

defaults import "$BETTERDISPLAY_BUNDLE_ID" "$__source_file" || {
    print -u2 -- "error: BetterDisplay settings import failed"
    exit 1
}
print -r -- "Imported BetterDisplay settings. Restart BetterDisplay to apply them."
