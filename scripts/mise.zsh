#!/usr/bin/env zsh
# mise dev tools installation
# See: https://mise.jdx.dev

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function with the script's path as its only argument
# used to contain variables and functions in a local scope
function {
    local __context="MISE"
    local __run_steps="$__install_mise_dev_tools"

    if [[ "$__run_steps" != true ]]; then
        echo "\n"
        _v_log_warn $__context "Skipping dev tools installation"
        _v_log_warn $__context "Skipping bootstrap repos"
        return 0
    fi

    if [[ $(command -v mise) == "" ]]; then
        echo "\n"
        _v_log_error $__context "$(_v_fmt_u mise) not found"
        exit 1
    fi

    echo "\n"
    local __proceed=true
    _v_log_info $__context "Installing, updating and pruning dev tools..."
    _v_confirm_proceed
    if [[ "$__proceed" == true ]]; then
        _v_log_info $__context "Installing, updating and pruning dev tools..."
        mise prune
        mise install
        mise upgrade
        mise reshim -f

        if [[ $? = 0 ]]; then
            _v_log_ok $__context "Dev tools installed, updated and pruned"
        fi
    else
        _v_log_warn $__context "Skipping dev tools installation"
    fi

    __proceed=true
    _v_log_info $__context "Bootstrapping repos..."
    _v_confirm_proceed
    if [[ "$__proceed" == true ]]; then
        _v_log_info $__context "Bootstrapping repos..."
        mise bootstrap repos apply --yes

        if [[ $? = 0 ]]; then
            _v_log_ok $__context "Bootstrap repos applied"
        fi
    else
        _v_log_warn $__context "Skipping bootstrap repos"
    fi
}
