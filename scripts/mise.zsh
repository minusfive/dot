#!/usr/bin/env zsh
# Complete mise bootstrap lifecycle and maintenance
# See: https://mise.jdx.dev

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function with the script's path as its only argument
# used to contain variables and functions in a local scope
function {
    local __context="MISE"
    local __run_steps="$__install_mise_dev_tools"
    local __profile="${DOT_PROFILE:-work}"
    local __mise_config_dir="$__dotfiles_dir/home/.config/mise"
    local __mise_installed_during_run=false

    if [[ "$__run_steps" != true ]]; then
        echo "\n"
        _v_log_warn $__context "Skipping full mise bootstrap lifecycle and maintenance"
        return 0
    fi

    if ! _v_profile_is_valid "$__profile"; then
        _v_log_warn $__context "Invalid DOT_PROFILE '$__profile'; falling back to 'work'"
        __profile="work"
    fi

    export MISE_CONFIG_DIR="$__mise_config_dir"
    export MISE_ENV_CONF_D=true
    unset MISE_ENV

    if [[ $(command -v mise) == "" ]]; then
        echo "\n"
        _v_log_info $__context "$(_v_fmt_u mise) not found. Attempting install..."
        curl -fsSL https://mise.run | sh
        __mise_installed_during_run=true

        # Official installer installs mise to ~/.local/bin.
        if [[ -x "$HOME/.local/bin/mise" ]]; then
            export PATH="$HOME/.local/bin:$PATH"
            hash -r
        fi

        if [[ $(command -v mise) == "" ]]; then
            _v_log_error $__context "$(_v_fmt_u mise) install succeeded, but it's still not in PATH"
            exit 1
        fi

        _v_log_ok $__context "$(_v_fmt_u mise) installed at $(which mise)"
    fi

    echo "\n"
    local __proceed=true
    _v_log_info $__context "$(_v_color_fg green DOT_PROFILE)=$(_v_color_fg yellow "'$__profile'")"
    _v_log_info $__context "Apply the full mise bootstrap lifecycle and maintenance (including an existing-mise self-update, all declared resources, workspace trust, package and tool maintenance, and reshim)?"
    _v_confirm_proceed
    if [[ "$__proceed" != true ]]; then
        _v_log_warn $__context "Skipping full mise bootstrap lifecycle and maintenance"
        return 0
    fi

    if [[ "$__mise_installed_during_run" != true ]]; then
        mise -C "$__dotfiles_dir" self-update --yes
        _v_log_ok $__context "Mise updated"
    fi

    hash -r

    mise -C "$__dotfiles_dir" bootstrap --yes
    _v_log_ok $__context "Full mise bootstrap lifecycle applied"

    _v_log_ok $__context "Mise maintenance complete"

}
