#!/usr/bin/env zsh
# Symlink dotfiles
# GNU Stow documentation: https://www.gnu.org/software/stow/manual/html_node

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

function {
    local __ssh_dir="$HOME/.ssh"
    local __from_dir="$PWD"

    # Ensure $XDG_CONFIG_HOME dir exists to prevent stow from symlinking entire dir
    if [[ -d "$XDG_CONFIG_HOME" ]]; then
        _v::log::ok "Dir $(_v::fmt::u "$XDG_CONFIG_HOME") already exists"
    else
        _v::log::info "Creating $(_v::fmt::u "$XDG_CONFIG_HOME")"
        mkdir "$XDG_CONFIG_HOME"
        _v::log::ok "Dir $(_v::fmt::u "$XDG_CONFIG_HOME") created"
    fi
    echo "\n"


    # Ensure $__ssh_dir dir exists to prevent stow from symlinking entire dir
    if [[ -d "$__ssh_dir" ]]; then
        _v::log::ok "Dir $(_v::fmt::u "$__ssh_dir") already exists"
    else
        _v::log::info "Creating $(_v::fmt::u "$__ssh_dir")"
        mkdir "$__ssh_dir"
        _v::log::ok "Dir $(_v::fmt::u "$__ssh_dir") created"
    fi
    echo "\n"


    if [[ $(command -v stow) != "" ]]; then
        _v::log::info "$(_v::fmt::u GNU Stow) found, symlinking dotfiles"

        # CD to dotfiles dir and then back when done
        if [[ "$__from_dir" != "$__dotfiles_dir" ]]; then
            echo "- Switching to $__dotfiles_dir"
            cd "$__dotfiles_dir"
        fi

        stow -vR .

        if [[ "$PWD" != "$__from_dir" ]]; then
            echo "- Switching back to $__from_dir"
            cd "$__from_dir"
        fi
    else
        _v::log::error "$(_v::fmt::u GNU Stow) not found"
        exit 1
    fi
}

