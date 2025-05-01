#!/usr/bin/env zsh

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function with the script's path as its only argument
# used to contain variables and functions in a local scope
function {
    local __dotfiles_scripts_dir="$(realpath "$(dirname "$ZSH_ARGZERO")")"
    local __dotfiles_dir="$(dirname "$__dotfiles_scripts_dir")"

    function _v::fmt::u() { print -P "%U$@%u" }
    function _v::color::fg() { print -P "%F{$1}${@:2}%f" }
    function _v::log::error() { print -P "$(_v::color::fg red 󰡅  " $1")" }
    function _v::log::info() { print -P "$(_v::color::fg blue 󰬐  " $1")" }
    function _v::log::ok() { print -P "$(_v::color::fg green 󰄲  " $1")" }
    function _v::log::warn() { print -P "$(_v::color::fg yellow 󰀩  " $1")" }
    function _v::q() { print -P "  $1? ($(_v::color::fg green y)/$(_v::color::fg red N)) $(_v::color::fg green %B⟩%b) " }

    # Load important environment variables
    source "$__dotfiles_dir/.zshenv"

    # From https://github.com/ohmyzsh/ohmyzsh/blob/d82669199b5d900b50fd06dd3518c277f0def869/lib/cli.zsh#L668-L676
    function _v::reload {
        _v::log::warn "Reloading Zsh..."
        # Delete current completion cache
        (command rm -f $_comp_dumpfile $ZSH_COMPDUMP) 2> /dev/null

        # Old zsh versions don't have ZSH_ARGZERO
        local zsh="${ZSH_ARGZERO:-${functrace[-1]%:*}}"

        # Check whether to run a login shell
        [[ "$zsh" = -* || -o login ]] && exec -l "${zsh#-}" || exec "$zsh"
    }


    # Homebrew and Homebrew packages installation
    vared -p "$(_v::q "Install $(_v::fmt::u Homebrew and Homebrew apps)")" -c REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        _v::log::info "Installing $(_v::fmt::u "Homebrew and Homebrew apps")"
        source "$__dotfiles_scripts_dir/brew.zsh"
    elif [[ $REPLY == "" || $REPLY =~ ^[Nn]$ ]]; then
        _v::log::warn "Skipping $(_v::fmt::u "Homebrew and Homebrew apps") installation"
    else
        _v::log::error "Invalid input"
        exit 1
    fi
    unset REPLY
    echo "\n"


    # Symlink dotfiles
    vared -p "$(_v::q "Symlink $(_v::fmt::u dotfiles)")" -c REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        _v::log::info "Symlinking $(_v::fmt::u dotfiles)"
        # Symlink dotfiles
        source "$__dotfiles_scripts_dir/symlink.zsh"
    elif [[ $REPLY == "" || $REPLY =~ ^[Nn]$ ]]; then
        _v::log::warn "Skipping $(_v::fmt::u dotfiles) symlinking"
    else
        _v::log::error "Invalid input"
        exit 1
    fi
    unset REPLY
    echo "\n"


    # Install Zsh theme + plugins
    vared -p "$(_v::q "Install $(_v::fmt::u Zsh theme + plugins)")" -c REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        _v::log::info "Installing $(_v::fmt::u Zsh theme + plugins)"
        source "$__dotfiles_scripts_dir/zsh.zsh"
    elif [[ $REPLY == "" || $REPLY =~ ^[Nn]$ ]]; then
        _v::log::warn "Skipping $(_v::fmt::u Zsh theme + plugins) installation"
    else
        _v::log::error "Invalid input"
        exit 1
    fi
    unset REPLY
    echo "\n"


    # Install mise dev tools
    vared -p "$(_v::q "Install $(_v::fmt::u mise dev tools)")" -c REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        _v::log::info "Installing $(_v::fmt::u mise dev tools)"
        source "$__dotfiles_scripts_dir/mise.zsh"
    elif [[ $REPLY == "" || $REPLY =~ ^[Nn]$ ]]; then
        _v::log::warn "Skipping $(_v::fmt::u mise dev tools) installation"
    else
        _v::log::error "Invalid input"
        exit 1
    fi
    unset REPLY
    echo "\n"


    # Configure OS settings
    vared -p "$(_v::q "Configure $(_v::fmt::u OS settings)")" -c REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        _v::log::info "Configuring $(_v::fmt::u OS settings)"
        source "$__dotfiles_scripts_dir/os.zsh"
    elif [[ $REPLY == "" || $REPLY =~ ^[Nn]$ ]]; then
        _v::log::warn "Skipping $(_v::fmt::u OS settings) configuration"
    else
        _v::log::error "Invalid input"
        exit 1
    fi
    unset REPLY
    echo "\n"


    # Update bat theme
    if [[ $(command -v bat) != "" ]]; then
        vared -p "$(_v::q "Update $(_v::fmt::u bat) theme")" -c REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            _v::log::info "Updating $(_v::fmt::u bat) theme"
            wget -O "$(bat --config-dir)/themes/Catppuccin Mocha.tmTheme" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme

            if [[ $? == 0 ]]; then
                _v::log::ok "$(_v::fmt::u bat) theme updated"
            fi
        elif [[ $REPLY == "" || $REPLY =~ ^[Nn]$ ]]; then
            _v::log::warn "Skipping $(_v::fmt::u bat) theme update"
        else
            _v::log::error "Invalid input"
            exit 1
        fi
        unset REPLY
        echo "\n"

        _v::log::info "Refreshing $(_v::fmt::u Bat) cache"
        bat cache --build

        if [[ $? == 0 ]]; then
            _v::log::ok "$(_v::fmt::u Bat) cache refreshed"
        fi
        echo "\n"
    fi

    _v::log::ok "Bootstrap complete"
    _v::reload
}

