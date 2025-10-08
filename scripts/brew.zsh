#!/usr/bin/env zsh
# Homebrew and Homebrew packages installation

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function with the script's path as its only argument
# used to contain variables and functions in a local scope
function {
    local __context="BREW"
    local __proceed="$__brew"

    export HOMEBREW_PROFILE="$__profile"
    export HOMEBREW_BUNDLE_FILE_GLOBAL="$__dotfiles_dir/.config/brew/Brewfile"

    if [[ "$__proceed" == true ]]; then
        echo "\n"
        _v_log_info $__context "Installing $(_v_fmt_u Homebrew) and managed software..."
        _v_log_info $__context "$(_v_color_fg green HOMEBREW_PROFILE)=$(_v_color_fg yellow "'$HOMEBREW_PROFILE'")"
        _v_log_info $__context "$(_v_color_fg green HOMEBREW_BUNDLE_FILE_GLOBAL)=$(_v_color_fg yellow "'$HOMEBREW_BUNDLE_FILE_GLOBAL'")"

        _v_confirm_proceed
    fi

    if [[ "$__proceed" != true ]]; then
        echo "\n"
        _v_log_warn $__context "Skipping $(_v_fmt_u Homebrew) and managed software installation"
        return 0
    fi

    # Install Homebrew
    if [[ $(command -v brew) == "" ]]; then
        echo "\n"
        _v_log_info $__context "$(_v_fmt_u Homebrew) not installed. Attempting install..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u Homebrew) installed, adding to path..."
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        echo "\n"
        _v_log_ok $__context "$(_v_fmt_u Homebrew) installed at $(which brew)"
    fi

    # Install Homebrew packages and apps
    if [[ $(command -v brew) != "" ]]; then
        echo "\n"
        if [[ ! -f $HOMEBREW_BUNDLE_FILE_GLOBAL ]]; then
            _v_log_error $__context "$(_v_fmt_u Brewfile) not found"
            exit 1
        fi

        _v_log_info $__context "Installing $(_v_fmt_u Homebrew bundle)"
        brew bundle install -v --global --cleanup --zap

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u Homebrew bundle) installed"
        fi

        _v_log_info $__context "Upgrading $(_v_fmt_u Homebrew bundle)"
        brew cu -f

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u Homebrew bundle) upgraded"
        fi
    fi
}

