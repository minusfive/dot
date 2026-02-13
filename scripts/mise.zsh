#!/usr/bin/env zsh
# mise dev tools installation
# See: https://mise.jdx.dev

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function with the script's path as its only argument
# used to contain variables and functions in a local scope
function {
    local __context="MISE"
    local __proceed="$__install_mise_dev_tools"

    if [[ "$__proceed" == true ]]; then
        echo "\n"
        _v_log_info $__context "Installing, updating and pruning $(_v_fmt_u mise) dev tools..."
        _v_confirm_proceed
    fi

    if [[ "$__proceed" != true ]]; then
        echo "\n"
        _v_log_warn $__context "Skipping, updating and pruning $(_v_fmt_u mise) dev tools installation"
        return 0
    fi

    if [[ $(command -v mise) != "" ]]; then
        echo "\n"
        mise prune
        mise install
        mise upgrade
        mise reshim -f

        if [[ $? = 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u mise) dev tools installed, updated and pruned"
        fi
    else
        echo "\n"
        _v_log_error $__context "$(_v_fmt_u mise) not found"
        exit 1
    fi
}

