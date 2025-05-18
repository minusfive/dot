#!/usr/bin/env zsh
# Homebrew and Homebrew packages installation

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

function {
    export HOMEBREW_BUNDLE_FILE_GLOBAL="$__dotfiles_scripts_dir/Brewfile"

    function _v::pq() { print -P "  $1? ($(_v::color::fg red p)ersonal / $(_v::color::fg blue W)ork) $(_v::color::fg green %B⟩%b) " }

    # Ask to choose which $HOMEBREW_PROFILE to use: "personal" or "work"
    if [[ -z ${HOMEBREW_PROFILE:-} ]]; then
        vared -p "$(_v::pq "Which $(_v::fmt::u HOMEBREW_PROFILE) would you like to use")" -c REPLY
        if [[ $REPLY =~ ^[Pp]$ ]]; then
            export HOMEBREW_PROFILE="personal"
            _v::log::info "\$HOMEBREW_PROFILE set to \"$(_v::color::fg red personal)\""
        elif [[ $REPLY == "" || $REPLY =~ ^[Ww]$ ]]; then
            export HOMEBREW_PROFILE="work"
            _v::log::info "\$HOMEBREW_PROFILE set to \"$(_v::color::fg blue work)\""
        else
            _v::log::error "Invalid input"
            exit 1
        fi
        unset REPLY
        echo "\n"
    fi


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
        brew cu

        if [[ $? == 0 ]]; then
            _v::log::ok "$(_v::fmt::u Homebrew bundle) upgraded"
        fi
    fi
}

