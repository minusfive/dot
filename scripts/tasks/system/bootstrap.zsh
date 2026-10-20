#!/usr/bin/env zsh
#MISE description="Install tools, applications, and configure this system according to the selected profile.{% if env.DOT_PROFILE is defined %}\n\n**Currently applied / persisted profile: `{{ env.DOT_PROFILE }}`**.{% endif %}"
#MISE env={MISE_TASK_RUN_AUTO_INSTALL="false"}
#MISE confirm={message="Apply the `{{ usage.profile }}` system profile?", default="no"}
#USAGE flag "-p --profile <profile>" env="DOT_PROFILE" default="work" {
#USAGE   help "Select the profile to apply"
#USAGE   warning """
#USAGE   Use with caution. This flag will override the currently applied / persisted profile. Combine with `--dry-run` to safely preview changes without modifying state.
#USAGE   """
#USAGE   long_help """
#USAGE
#USAGE   Machines are configured differently based on `profile`. Choose the profile you want to apply:
#USAGE
#USAGE   **`work`**: safest, default. Intended for work machines.
#USAGE   **`personal`**: adds personal tools, applications, and configurations. Intended for personal machines.
#USAGE
#USAGE   """
#USAGE   choices "work" "personal"
#USAGE }
#USAGE flag "--dry-run" help="Preview the selected `profile` actions without applying them or changing state."

set -euo pipefail

local __root_dir
__root_dir="$(realpath "${MISE_CONFIG_ROOT:-${MISE_PROJECT_ROOT:-$PWD}}")" ||
    {
        print -u2 -- "error: could not resolve the mise project root"
        exit 1
    }

local __mise_config_dir="$__root_dir/home/.config/mise"
local __profile_file="${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile"
local __profile="${usage_profile}"

[[ -d "$__root_dir" && -d "$__mise_config_dir" ]] ||
    {
        print -u2 -- "error: invalid dotfiles repository root: $__root_dir"
        exit 1
    }

if [[ "${usage_dry_run:-false}" == true ]]; then
    print -r -- "Would apply the $__profile mise bootstrap profile."
    exit 0
fi

command -v mise >/dev/null 2>&1 ||
    {
        print -u2 -- "error: mise is not available; run scripts/install-mise.zsh to install it"
        exit 1
    }

export DOT_PROFILE="$__profile"
export MISE_CONFIG_DIR="$__mise_config_dir"
export MISE_ENV_CONF_D=true
unset MISE_ENV
unset MISE_AUTO_ENV

mkdir -p "${__profile_file:h}"
print -r -- "$__profile" >| "$__profile_file"

mise -C "$__root_dir" self-update --yes

mise -C "$__root_dir" bootstrap --yes
