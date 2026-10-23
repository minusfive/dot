#!/usr/bin/env zsh
#MISE description="Persist the selected profile before package bootstrap"
#MISE quiet=true
#MISE env={MISE_TASK_RUN_AUTO_INSTALL="false"}
#MISE confirm={message="Persist the `{{ usage.profile }}` profile and continue bootstrap?", default="no"}
#USAGE flag "-p --profile <profile>" env="MISE_ENV" default="work" {
#USAGE   help "Select the profile to persist"
#USAGE   choices {
#USAGE      choice "work" help="Safest profile, default"
#USAGE      choice "personal" help="adds personal resources and configurations"
#USAGE   }
#USAGE }

set -euo pipefail

local __profile="${usage_profile}"
local __profile_file="${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile"
local __temporary_profile_file="${__profile_file}.tmp.$$"
local __previous_profile_file="${__profile_file}.previous.$$"
local __selector_file="$HOME/.config/mise/miserc.local.toml"
local __previous_selector_file="${__selector_file}.previous.$$"
local __had_previous_profile=false
local __had_previous_selector=false

mkdir -p "${__profile_file:h}"
if [[ -f "$__profile_file" ]]; then
    cp -p -- "$__profile_file" "$__previous_profile_file"
    __had_previous_profile=true
fi
if [[ -f "$__selector_file" ]]; then
    cp -p -- "$__selector_file" "$__previous_selector_file"
    __had_previous_selector=true
fi
trap 'rm -f -- "$__temporary_profile_file" "$__previous_profile_file" "$__previous_selector_file"' EXIT
print -r -- "$__profile" >| "$__temporary_profile_file"
mv -f -- "$__temporary_profile_file" "$__profile_file"

local __project_root="${MISE_PROJECT_ROOT:-}"
if {
    if [[ -n "$__project_root" && -d "$__project_root/home/.config/mise" ]]; then
        MISE_CONFIG_DIR="$__project_root/home/.config/mise" \
            mise --no-hooks dot apply --yes "~/.config/mise/miserc.local.toml"
    else
        mise --no-hooks dot apply --yes "~/.config/mise/miserc.local.toml"
    fi
}; then
    exit 0
fi

if [[ "$__had_previous_profile" == true ]]; then
    mv -f -- "$__previous_profile_file" "$__profile_file"
else
    rm -f -- "$__profile_file"
fi
if [[ "$__had_previous_selector" == true ]]; then
    mv -f -- "$__previous_selector_file" "$__selector_file"
else
    rm -f -- "$__selector_file"
fi
print -u2 -- "error: could not refresh the persisted mise profile selector; restored the previous profile state"
exit 1
