#!/usr/bin/env zsh
#MISE description="Install tools, applications, and configure this system according to the selected profile.\n\n**Currently selected profile: `{{ env.MISE_ENV | default(value='work') }}`**."
#MISE env={MISE_TASK_RUN_AUTO_INSTALL="false"}
#MISE confirm={message="Apply the `{{ usage.profile }}` system profile?", default="no"}
# The profile flag resolves values in this order: command line, MISE_ENV,
# then default="work". The environment-backed argument and choices validation
# are provided by mise:
# https://mise.jdx.dev/tasks/task-arguments.html#environment-variable-backing
# https://mise.jdx.dev/tasks/task-arguments.html#arguments
#USAGE flag "-p --profile <profile>" env="MISE_ENV" default="work" {
#USAGE   help "Select the profile to apply"
#USAGE   warning """
#USAGE   **Overrides the currently applied / persisted profile.**
#USAGE   Combine with `--dry-run` to preview changes without modifying state.
#USAGE   """
#USAGE   long_help """
#USAGE   Machines are configured differently based on `profile`:
#USAGE
#USAGE   **`work`**: safest, default.
#USAGE   **`personal`**: adds personal resources and configurations.
#USAGE
#USAGE   """
#USAGE   choices {
#USAGE      choice "work" help="Safest profile, default"
#USAGE      choice "personal" help="adds personal resources and configurations"
#USAGE   }
#USAGE }
#USAGE flag "--dry-run" help="Preview the selected `profile` actions without applying them or changing state."

set -euo pipefail

local __root_dir="$MISE_PROJECT_ROOT"
local __mise_config_dir="$__root_dir/home/.config/mise"
local __profile="${usage_profile}"

[[ -d "$__mise_config_dir" ]] ||
    {
        print -u2 -- "error: invalid dotfiles repository root: $__root_dir"
        exit 1
    }

export DOT_PROFILE="$__profile"
export MISE_CONFIG_DIR="$__mise_config_dir"
export MISE_ENV_CONF_D=true
export MISE_ENV="$__profile"
unset MISE_AUTO_ENV

if [[ "${usage_dry_run:-false}" == true ]]; then
    mise -C "$__root_dir" -E "$__profile" bootstrap --dry-run
    exit 0
fi

mise -C "$__root_dir" -E "$__profile" bootstrap --yes
