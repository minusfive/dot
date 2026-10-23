#!/usr/bin/env zsh
#MISE description="Persist the selected profile before package bootstrap"
#MISE quiet=true
#MISE env={MISE_TASK_RUN_AUTO_INSTALL="false"}
#MISE confirm={message="Persist the `{{ usage.profile }}` profile and continue bootstrap?", default="no"}
#USAGE flag "-p --profile <profile>" env="DOT_PROFILE" default="work" {
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

mkdir -p "${__profile_file:h}"
trap 'rm -f -- "$__temporary_profile_file"' EXIT
print -r -- "$__profile" >| "$__temporary_profile_file"
mv -f -- "$__temporary_profile_file" "$__profile_file"
