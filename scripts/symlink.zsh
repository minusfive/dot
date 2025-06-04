#!/usr/bin/env zsh
# Symlink dotfiles
# GNU Stow documentation: https://www.gnu.org/software/stow/manual/html_node

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

function {
    echo "\n"
    local __context="LINK"
    local __proceed="$__symlink_dotfiles"

    if [[ "$__proceed" == true ]]; then
        _v_log_info $__context "Symlinking $(_v_fmt_u dotfiles)..."
        _v_confirm_proceed
    fi

    if [[ "$__proceed" == false ]]; then
        _v_log_warn $__context "Skipping $(_v_fmt_u dotfiles) symlinking"
        return 0
    fi

    local __ssh_dir="$HOME/.ssh"
    local __from_dir="$PWD"

    # Ensure $XDG_CONFIG_HOME dir exists to prevent stow from symlinking entire dir
    if [[ -d "$XDG_CONFIG_HOME" ]]; then
        _v_log_ok $__context "Dir $(_v_fmt_u "$XDG_CONFIG_HOME") already exists"
    else
        _v_log_info $__context "Creating $(_v_fmt_u "$XDG_CONFIG_HOME")"
        mkdir "$XDG_CONFIG_HOME"
        _v_log_ok $__context "Dir $(_v_fmt_u "$XDG_CONFIG_HOME") created"
    fi
    echo "\n"


    # Ensure $__ssh_dir dir exists to prevent stow from symlinking entire dir
    if [[ -d "$__ssh_dir" ]]; then
        _v_log_ok $__context "Dir $(_v_fmt_u "$__ssh_dir") already exists"
    else
        _v_log_info $__context "Creating $(_v_fmt_u "$__ssh_dir")"
        mkdir "$__ssh_dir"
        _v_log_ok $__context "Dir $(_v_fmt_u "$__ssh_dir") created"
    fi
    echo "\n"


    if [[ $(command -v stow) != "" ]]; then
        _v_log_info $__context "$(_v_fmt_u GNU Stow) found, proceeding..."

        # CD to dotfiles dir and then back when done
        if [[ "$__from_dir" != "$__dotfiles_dir" ]]; then
            _v_log_info $__context "Switching to $__dotfiles_dir"
            cd "$__dotfiles_dir"
        fi

        stow -vR .

        if [[ "$PWD" != "$__from_dir" ]]; then
            echo "- Switching back to $__from_dir"
            cd "$__from_dir"
        fi
    else
        _v_log_error $__context "$(_v_fmt_u GNU Stow) not found"
        exit 1
    fi
}

