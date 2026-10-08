#!/usr/bin/env zsh
# mise package and dev tools installation
# See: https://mise.jdx.dev

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function with the script's path as its only argument
# used to contain variables and functions in a local scope
function {
    local __context="MISE"
    local __run_steps="$__install_mise_dev_tools"
    local __profile="${DOT_PROFILE:-work}"

    if [[ "$__run_steps" != true ]]; then
        echo "\n"
        _v_log_warn $__context "Skipping mise update, package bootstrap, dev tools installation, bootstrap repos, and dotfiles"
        return 0
    fi

    if ! _v_profile_is_valid "$__profile"; then
        _v_log_warn $__context "Invalid DOT_PROFILE '$__profile'; falling back to 'work'"
        __profile="work"
    fi
    export MISE_ENV="$__profile"

    if [[ $(command -v mise) == "" ]]; then
        echo "\n"
        _v_log_info $__context "$(_v_fmt_u mise) not found. Attempting install..."
        curl -fsSL https://mise.run | sh

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
    _v_log_info $__context "$(_v_color_fg green MISE_ENV)=$(_v_color_fg yellow "'$MISE_ENV'")"
    _v_log_info $__context "Updating mise..."
    _v_confirm_proceed
    if [[ "$__proceed" == true ]]; then
        mise self-update --yes

        _v_log_ok $__context "Mise updated"
    else
        _v_log_warn $__context "Skipping mise update"
    fi

    __proceed=true
    _v_log_info $__context "Applying package bootstrap..."
    _v_confirm_proceed
    if [[ "$__proceed" == true ]]; then
        mise bootstrap packages apply --yes
        mise bootstrap packages upgrade --yes
        mise bootstrap packages prune --yes

        _v_log_ok $__context "Package bootstrap applied"
    else
        _v_log_warn $__context "Skipping package bootstrap"
    fi

    __proceed=true
    _v_log_info $__context "Applying workspace mise configuration..."
    _v_confirm_proceed
    if [[ "$__proceed" == true ]]; then
        mise bootstrap files apply --yes
        mise trust --yes "$HOME/dev/personal/mise.toml"
        mise trust --yes "$HOME/dev/work/mise.toml"

        _v_log_ok $__context "Workspace mise configuration applied"
    else
        _v_log_warn $__context "Skipping workspace mise configuration"
    fi

    __proceed=true
    _v_log_info $__context "Installing, updating and pruning dev tools..."
    _v_confirm_proceed
    if [[ "$__proceed" == true ]]; then
        mise prune
        mise install
        mise upgrade
        mise reshim -f

        _v_log_ok $__context "Dev tools installed, updated and pruned"
    else
        _v_log_warn $__context "Skipping dev tools installation"
    fi

    __proceed=true
    _v_log_info $__context "Bootstrapping repos..."
    _v_confirm_proceed
    if [[ "$__proceed" == true ]]; then
        mise bootstrap repos apply --yes

        _v_log_ok $__context "Bootstrap repos applied"
    else
        _v_log_warn $__context "Skipping bootstrap repos"
    fi

    __proceed=true
    _v_log_info $__context "Applying mise dotfiles..."
    _v_confirm_proceed
    if [[ "$__proceed" == true ]]; then
        mise bootstrap dotfiles apply --yes

        _v_log_ok $__context "Mise dotfiles applied"
    else
        _v_log_warn $__context "Skipping mise dotfiles"
    fi
}
