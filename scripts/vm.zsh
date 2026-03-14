#!/usr/bin/env zsh
# VM and Containerization tools setup script

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function with the script's path as its only argument
# used to contain variables and functions in a local scope
function {
    local __context="  VM"
    local __proceed="$__install_vm"

    if [[ "$__proceed" == true ]]; then
        echo "\n"
        _v_log_info $__context "Installing $(_v_fmt_u VM and Containerization) tools..."
        _v_confirm_proceed
    fi

    if [[ "$__proceed" != true ]]; then
        echo "\n"
        _v_log_warn $__context "Skipping $(_v_fmt_u VM and Containerization) tools installation"
        return 0
    fi

    # Create Lima/Podman VM
    if [[ $(command -v lima) == "" ]]; then
        echo "\n"
        _v_log_error $__context "$(_v_fmt_u Lima) not installed"
        exit 1
    else
        echo "\n"
        if limactl list podman >/dev/null 2>&1; then
            _v_log_info $__context "$(_v_fmt_u Lima/Podman) VM already exists, skipping creation"
        else
            _v_log_info $__context "Creating $(_v_fmt_u Lima/Podman) VM"

            if limactl create template:podman >/dev/null 2>&1; then
                _v_log_ok $__context "$(_v_fmt_u Lima/Podman) VM created"
            else
                _v_log_error $__context "Failed to create $(_v_fmt_u Lima/Podman) VM"
                exit 1
            fi
        fi
    fi

    # Wire-up Podman to use Lima VM
    if [[ $(command -v podman) == "" ]]; then
        echo "\n"
        _v_log_error $__context "$(_v_fmt_u Podman) not installed"
    else
        echo "\n"
        _v_log_info $__context "Configuring $(_v_fmt_u Podman) to use $(_v_fmt_u Lima) VM"

        podman system connection add lima-podman "unix://$HOME/.lima/podman/sock/podman.sock"
        podman system connection default lima-podman

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u Podman) configured to use $(_v_fmt_u Lima) VM"
        fi
    fi
}
