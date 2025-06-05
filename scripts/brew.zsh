#!/usr/bin/env zsh
# Homebrew and Homebrew packages installation

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

function {
    echo "\n"
    local __context="BREW"
    local __proceed="$__brew"

    if [[ "$__proceed" == true ]]; then
        _v_log_info $__context "Installing $(_v_fmt_u Homebrew) and managed software..."
        _v_confirm_proceed
    fi

    if [[ "$__proceed" != true ]]; then
        _v_log_warn $__context "Skipping $(_v_fmt_u Homebrew) and managed software installation"
        return 0
    fi

    export HOMEBREW_PROFILE="$__profile"
    export HOMEBREW_BUNDLE_FILE_GLOBAL="$__dotfiles_dir/.config/brew/Brewfile"

    _v_log_info $__context "$(_v_fmt_u HOMEBREW_PROFILE)=$(_v_fmt_s " $HOMEBREW_PROFILE ")"
    _v_log_info $__context "$(_v_fmt_u HOMEBREW_BUNDLE_FILE_GLOBAL)=$(_v_fmt_s " $HOMEBREW_BUNDLE_FILE_GLOBAL ")"

    # Install Homebrew
    if [[ $(command -v brew) == "" ]]; then
        _v_log_info $__context "$(_v_fmt_u Homebrew) not installed. Attempting install..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u Homebrew) installed, adding to path..."
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        _v_log_ok $__context "$(_v_fmt_u Homebrew) installed at $(which brew)"
    fi
    echo "\n"


    # Install Homebrew packages and apps
    if [[ $(command -v brew) != "" ]]; then
        if [[ ! -f $HOMEBREW_BUNDLE_FILE_GLOBAL ]]; then
            _v_log_error $__context "$(_v_fmt_u Brewfile) not found"
            exit 1
        fi

        _v_log_info $__context "Installing $(_v_fmt_u Homebrew bundle)"
        brew bundle -v --global --cleanup --zap

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u Homebrew bundle) installed"
        fi

        _v_log_info $__context "Upgrading $(_v_fmt_u Homebrew bundle)"
        brew cu

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u Homebrew bundle) upgraded"
        fi
    fi
}

