#!/usr/bin/env zsh
# Complete mise bootstrap lifecycle and maintenance
# See: https://mise.jdx.dev

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

function _v_mise_is_valid {
    local __mise_path="$1"
    local __mise_version

    [[ -f "$__mise_path" && -x "$__mise_path" ]] || return 1
    __mise_version="$("$__mise_path" --version 2>/dev/null)" || return 1
    [[ "$__mise_version" =~ '^(mise[[:space:]]+)?[0-9]+\.[0-9]+\.[0-9]+([[:space:]].*)?$' ]]
}

function _v_mise_ensure_stable_path {
    local __mise_path="${1:-}"
    local __stable_path="$HOME/.local/bin/mise"
    local __physical_path

    if [[ -e "$__stable_path" || -L "$__stable_path" ]]; then
        if _v_mise_is_valid "$__stable_path"; then
            export PATH="$HOME/.local/bin:$PATH"
            hash -r
            return 0
        fi
        if [[ ! -L "$__stable_path" ]]; then
            _v_log_error "MISE" "Cannot create stable mise path: $__stable_path is not a valid mise executable"
            return 1
        fi
        if [[ -e "$__stable_path" ]]; then
            _v_log_error "MISE" "Cannot create stable mise path: $__stable_path is not a valid mise executable"
            return 1
        fi
        command rm "$__stable_path"
    fi

    hash -r
    __mise_path="${__mise_path:-$(command -v mise || true)}"
    __physical_path="$(realpath "$__mise_path" 2>/dev/null || true)"
    if [[ -z "$__physical_path" || "$__physical_path" == "$__stable_path" ]] ||
        ! _v_mise_is_valid "$__physical_path"; then
        if [[ "$__physical_path" == "$__stable_path" ]]; then
            _v_log_error "MISE" "Cannot create stable mise path recursively: $__stable_path"
        else
            _v_log_error "MISE" "Cannot create stable mise path: no valid mise executable was found"
        fi
        return 1
    fi
    __mise_path="$__physical_path"

    command mkdir -p "$HOME/.local/bin"
    command ln -s "$__mise_path" "$__stable_path"
    export PATH="$HOME/.local/bin:$PATH"
    hash -r

    _v_mise_is_valid "$__stable_path" || {
        _v_log_error "MISE" "Stable mise path was not created: $__stable_path"
        return 1
    }
}

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
    unset MISE_AUTO_ENV

    local __mise_path="$(command -v mise || true)"
    if [[ -z "$__mise_path" ]]; then
        echo "\n"
        _v_log_info $__context "$(_v_fmt_u mise) not found. Attempting install..."
        curl -fsSL https://mise.run | sh
        __mise_installed_during_run=true

        # Official installer installs mise to ~/.local/bin.
        if [[ -x "$HOME/.local/bin/mise" ]]; then
            export PATH="$HOME/.local/bin:$PATH"
            hash -r
        fi

        __mise_path="$(command -v mise || true)"
        if [[ -z "$__mise_path" ]]; then
            _v_log_error $__context "$(_v_fmt_u mise) install succeeded, but it's still not in PATH"
            exit 1
        fi

        _v_log_ok $__context "$(_v_fmt_u mise) installed at $__mise_path"
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

    _v_mise_ensure_stable_path "$__mise_path"

    if [[ "$__mise_installed_during_run" != true ]]; then
        mise -C "$__dotfiles_dir" self-update --yes
        _v_log_ok $__context "Mise self-update complete"
    fi

    hash -r

    if (command -v gh >/dev/null 2>&1 && gh auth status --hostname github.com >/dev/null 2>&1) ||
        mise exec gh@latest -- gh auth status --hostname github.com >/dev/null 2>&1; then
        _v_log_ok $__context "$(_v_fmt_u GitHub CLI) is already authenticated"
    else
        _v_log_info $__context "Authenticating $(_v_fmt_u GitHub CLI)..."
        mise exec gh@latest -- gh auth login --hostname github.com --git-protocol https --web
        mise exec gh@latest -- gh auth setup-git --hostname github.com
        _v_log_ok $__context "$(_v_fmt_u GitHub CLI) authenticated"
    fi

    mise -C "$__dotfiles_dir" bootstrap --yes
    _v_log_ok $__context "Mise bootstrap and maintenance complete"

}
