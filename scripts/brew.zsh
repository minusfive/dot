#!/usr/bin/env zsh
# Homebrew and Homebrew packages installation

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

function {
    export HOMEBREW_BUNDLE_FILE_GLOBAL="$__dotfiles_scripts_dir/Brewfile"

    # Install Homebrew
    if [[ $(command -v brew) == "" ]]; then
        _v::log::info "$(_v::fmt::u Homebrew) not installed. Attempting install..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        if [[ $? == 0 ]]; then
            _v::log::ok "$(_v::fmt::u Homebrew) installed, adding to path..."
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        _v::log::ok "$(_v::fmt::u Homebrew) installed at $(which brew)"
    fi
    echo "\n"


    # Install Homebrew packages and apps
    if [[ $(command -v brew) != "" ]]; then
        if [[ ! -f $HOMEBREW_BUNDLE_FILE_GLOBAL ]]; then
            _v::log::error "$(_v::fmt::u Brewfile) not found"
            exit 1
        fi

        _v::log::info "Installing $(_v::fmt::u Homebrew bundle)"
        brew bundle -v --global --cleanup --zap

        if [[ $? == 0 ]]; then
            _v::log::ok "$(_v::fmt::u Homebrew bundle) installed"
        fi

        _v::log::info "Upgrading $(_v::fmt::u Homebrew bundle)"
        brew cu -fi

        if [[ $? == 0 ]]; then
            _v::log::ok "$(_v::fmt::u Homebrew bundle) upgraded"
        fi
    fi
}

