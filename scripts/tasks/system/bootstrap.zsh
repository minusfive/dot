#!/usr/bin/env zsh
#MISE description="Bootstrap this repository with the selected mise profile"
#MISE env={MISE_TASK_RUN_AUTO_INSTALL="false"}
#MISE confirm={message="Apply the selected mise bootstrap profile?", default="no"}
#USAGE flag "-p --profile <profile>" help="Profile to apply" {
#USAGE   choices "work" "personal"
#USAGE }
#USAGE flag "--dry-run" help="Show the selected profile without changing state"

set -euo pipefail

local __root_dir
__root_dir="$(realpath "${MISE_CONFIG_ROOT:-${MISE_PROJECT_ROOT:-$PWD}}")" ||
    {
        print -u2 -- "error: could not resolve the mise project root"
        exit 1
    }

local __mise_config_dir="$__root_dir/home/.config/mise"
local __profile_file="${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile"
local __profile="${usage_profile:-}"

[[ -d "$__root_dir" && -d "$__mise_config_dir" ]] ||
    {
        print -u2 -- "error: invalid dotfiles repository root: $__root_dir"
        exit 1
    }

if [[ -z "$__profile" && -f "$__profile_file" ]]; then
    __profile="$(<"$__profile_file")"
fi
__profile="${__profile:-work}"
if [[ "$__profile" != work && "$__profile" != personal ]]; then
    print -u2 -- "error: profile must be 'work' or 'personal': $__profile"
    exit 2
fi

if [[ "${usage_dry_run:-false}" == true ]]; then
    print -r -- "Would apply the $__profile mise bootstrap profile."
    exit 0
fi

command -v mise >/dev/null 2>&1 ||
    {
        print -u2 -- "error: mise is not available; run scripts/init.zsh to install it"
        exit 1
    }

export DOT_PROFILE="$__profile"
export MISE_CONFIG_DIR="$__mise_config_dir"
export MISE_ENV_CONF_D=true
unset MISE_ENV
unset MISE_AUTO_ENV

mkdir -p "${__profile_file:h}"
print -r -- "$__profile" >| "$__profile_file"

if [[ "${DOT_MISE_INSTALLED_DURING_RUN:-false}" != true ]]; then
    mise -C "$__root_dir" self-update --yes
fi

mise -C "$__root_dir" bootstrap --yes
