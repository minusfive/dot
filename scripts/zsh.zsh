#!/usr/bin/env zsh
# OhMyZsh and custom plugin/theme setup

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function with the script's path as its only argument
# used to contain variables and functions in a local scope
function {
    local __context=" ZSH"
    local __proceed="$__install_zsh_theme_plugins"

    if [[ "$__proceed" == true ]]; then
        echo "\n"
        _v_log_info $__context "Setting up $(_v_fmt_u OhMyZsh) and its plugins/themes..."
        _v_confirm_proceed
    fi

    if [[ "$__proceed" != true ]]; then
        echo "\n"
        _v_log_warn $__context "Skipping $(_v_fmt_u OhMyZsh) and its plugins/themes setup"
        return 0
    fi

    # Important variables to ensure managed files are not overriden by installers
    export ZSH="$XDG_CONFIG_HOME/oh-my-zsh"
    export ZSH_CUSTOM="$ZSH/custom"
    export CHSH="no"
    export RUNZSH="no"
    export KEEP_ZSHRC="yes"

    # Install OhMyZsh
    if [[ -d ${ZSH} ]]; then
        echo "\n"
        _v_log_ok $__context "$(_v_fmt_u OhMyZsh) already installed"
    else
        echo "\n"
        _v_log_info $__context "Installing $(_v_fmt_u OhMyZsh)"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u OhMyZsh) installed"
        fi
    fi

    # Update OhMyZsh
    if [[ -d ${ZSH} ]]; then
        echo "\n"
        _v_log_info $__context "Updating $(_v_fmt_u OhMyZsh)"
        "${ZSH}/tools/upgrade.sh"

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u OhMyZsh) updated"
        fi

        # Update custom plugins and themes if full-autoupdate is installed
        if [[ -d ${ZSH_CUSTOM}/plugins/ohmyzsh-full-autoupdate ]]; then
            _v_log_info $__context "Updating $(_v_fmt_u OhMyZsh) custom plugins and themes"

            # Set up environment variables needed by the plugin
            export ZSH_CACHE_DIR="${ZSH}/cache"
            mkdir -p "${ZSH_CACHE_DIR}"

            # Remove the update label to force execution
            if [[ -f "${ZSH_CACHE_DIR}/.zsh-update" ]]; then
                sed -i '' '/LABEL_FULL_AUTOUPDATE/d' "${ZSH_CACHE_DIR}/.zsh-update"
            fi

            # Source and run the full-autoupdate plugin
            source "${ZSH_CUSTOM}/plugins/ohmyzsh-full-autoupdate/ohmyzsh-full-autoupdate.plugin.zsh"

            if [[ $? == 0 ]]; then
                _v_log_ok $__context "$(_v_fmt_u OhMyZsh) custom plugins and themes updated"
            fi
        fi
    fi

}
