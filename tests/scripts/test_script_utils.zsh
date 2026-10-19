#!/usr/bin/env zsh

set -euo pipefail

local __fixture_dir="$(mktemp -d)"
__fixture_dir="$(realpath "$__fixture_dir")"
trap 'rm -rf -- "$__fixture_dir"' EXIT

source scripts/utils/filesystem.zsh
source scripts/utils/application.zsh

local __file="$__fixture_dir/file"
print -r -- content >| "$__file"
filesystem::is_physical_file "$__file" ||
    { print -u2 -- "physical file was not accepted"; exit 1; }
[[ -n "$(filesystem::physical_path "$__file")" ]] ||
    { print -u2 -- "physical file path was not resolved"; exit 1; }
[[ -n "$(filesystem::identity "$__file")" ]] ||
    { print -u2 -- "physical file identity was not returned"; exit 1; }
local __file_identity="$(filesystem::identity "$__file")"
filesystem::identity_matches "$__file" "$__file" "$__file_identity" ||
    { print -u2 -- "matching physical file identity was not accepted"; exit 1; }

ln -s "$__file" "$__fixture_dir/link"
if filesystem::is_physical_file "$__fixture_dir/link"; then
    print -u2 -- "symlinked file was accepted as physical"
    exit 1
fi
if filesystem::identity_matches \
    "$__fixture_dir/link" "$__file" "$__file_identity"; then
    print -u2 -- "symlinked file identity was accepted"
    exit 1
fi

local __temporary_file="$__fixture_dir/known-temp"
print -r -- temporary >| "$__temporary_file"
filesystem::cleanup_known_temp "$__temporary_file" ||
    { print -u2 -- "known temporary file cleanup failed"; exit 1; }
[[ ! -e "$__temporary_file" ]] ||
    { print -u2 -- "known temporary file remained"; exit 1; }

local __application_state=stopped
pgrep() {
    [[ "$__application_state" == running ]]
}
open() {
    __application_state=running
}
sleep() {
    :
}

application::wait_for_state ExampleApp stopped 1 ||
    { print -u2 -- "stopped application state was not detected"; exit 1; }
__application_state=running
application::wait_for_state ExampleApp running 1 ||
    { print -u2 -- "running application state was not detected"; exit 1; }
application::restart ExampleApp ExampleApp 1 ||
    { print -u2 -- "application restart did not complete"; exit 1; }

echo "Script utility tests passed."
