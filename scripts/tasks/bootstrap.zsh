#!/usr/bin/env zsh
#MISE description="Bootstrap the machine with the selected profile"
#MISE quiet=true
#USAGE flag "--profile <work|personal>" help="Select and persist the bootstrap profile"
#USAGE flag "--dry-run" help="Show the bootstrap plan without changing resources or profile state"

set -euo pipefail

typeset -r __task_file="${0:A}"

main() {
    local __task_dir="${__task_file:h}"
    local __scripts_dir="${__task_dir:h}"
    local __project_root="${MISE_PROJECT_ROOT:-${MISE_ORIGINAL_CWD:-${PWD}}}"
    local __profile_helper="$__scripts_dir/utils/profile.zsh"
    local __mise_helper="$__scripts_dir/utils/mise.zsh"

    if [[ ! -f "$__profile_helper" || ! -f "$__mise_helper" ]]; then
        print -u2 -- "error: bootstrap helpers are missing"
        exit 1
    fi

    source "$__profile_helper"
    source "$__mise_helper"

    local __requested_profile="${usage_profile:-}"
    local __dry_run="${usage_dry_run:-false}"

    if [[ -n "$__requested_profile" ]] && ! _v_profile_is_valid "$__requested_profile"; then
        print -u2 -- "error: profile must be 'work' or 'personal': $__requested_profile"
        exit 2
    fi

    local __profile="${__requested_profile:-$(_v_profile_read)}"
    export DOT_PROFILE="$__profile"
    export MISE_CONFIG_DIR="$__project_root/home/.config/mise"
    export MISE_ENV_CONF_D=true
    unset MISE_ENV
    unset MISE_AUTO_ENV

    if [[ "$__dry_run" == true ]]; then
        mise -C "$__project_root" bootstrap --dry-run
        return $?
    fi

    local __mise_path="$(command -v mise || true)"
    local __mise_installed_during_run=false
    if [[ -z "$__mise_path" ]]; then
        print -r -- "mise was not found. Installing mise..."
        curl -fsSL https://mise.run | sh
        __mise_installed_during_run=true
        export PATH="$HOME/.local/bin:$PATH"
        hash -r
        __mise_path="$(command -v mise || true)"
        [[ -n "$__mise_path" ]] || {
            print -u2 -- "error: mise installation succeeded, but mise is not in PATH"
            exit 1
        }
    fi

    print -r -- "Profile: $__profile"
    print -r -- "Apply the full mise bootstrap lifecycle and maintenance?"
    local __reply
    if [[ ! -t 0 ]]; then
        __reply="${MISE_BOOTSTRAP_CONFIRM:-}"
    else
        vared -p "Proceed? [y/N/q] " -c __reply
    fi
    if [[ "$__reply" != [Yy]* ]]; then
        print -r -- "Skipping mise bootstrap"
        return 0
    fi

    if [[ -n "$__requested_profile" ]]; then
        _v_profile_write "$__requested_profile" || {
            print -u2 -- "error: failed to persist profile '$__requested_profile'"
            exit 1
        }
    fi

    _v_mise_ensure_stable_path "$__mise_path"

    if [[ "$__mise_installed_during_run" != true ]]; then
        mise -C "$__project_root" self-update --yes
    fi

    if (command -v gh >/dev/null 2>&1 && gh auth status --hostname github.com >/dev/null 2>&1) ||
        mise exec gh@latest -- gh auth status --hostname github.com >/dev/null 2>&1; then
        print -r -- "GitHub CLI is already authenticated"
    else
        print -r -- "Authenticating GitHub CLI..."
        mise exec gh@latest -- gh auth login --hostname github.com --git-protocol https --web
        mise exec gh@latest -- gh auth setup-git --hostname github.com
    fi

    mise -C "$__project_root" bootstrap --yes --skip task
    print -r -- "Mise bootstrap and maintenance complete"
}

main "$@"
