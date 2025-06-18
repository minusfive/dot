#!/usr/bin/env zsh
# Zsh plugins and themes installation

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function with the script's path as its only argument
# used to contain variables and functions in a local scope
function {
    echo "\n"
    local __context=" ZSH"
    local __proceed="$__install_zsh_theme_plugins"

    if [[ "$__proceed" == true ]]; then
        _v_log_info $__context "Installing $(_v_fmt_u Zsh) plugins and themes..."
        _v_confirm_proceed
    fi

    if [[ "$__proceed" != true ]]; then
        _v_log_warn $__context "Skipping $(_v_fmt_u Zsh) plugins and themes installation"
        return 0
    fi

    export ZSH="$XDG_CONFIG_HOME/oh-my-zsh"
    export ZSH_CUSTOM="$ZSH/custom"
    export CHSH="no"
    export RUNZSH="no"
    export KEEP_ZSHRC="yes"

    # Install OhMyZsh
    if [[ -d ${ZSH} ]]; then
        _v_log_ok $__context "$(_v_fmt_u OhMyZsh) already installed"
    else
        _v_log_info $__context "Installing $(_v_fmt_u OhMyZsh)"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u OhMyZsh) installed"
        fi
    fi
    echo "\n"


    # Install PowerLevel10K
    if [[ -d ${ZSH_CUSTOM}/themes/powerlevel10k ]]; then
        _v_log_ok $__context "$(_v_fmt_u PowerLevel10K) already installed"
    else
        _v_log_info $__context "Installing $(_v_fmt_u PowerLevel10K)"
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
            ${ZSH_CUSTOM}/themes/powerlevel10k

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u PowerLevel10K) installed"
        fi
    fi
    echo "\n"


    # Install fast-syntax-highlighting
    if [[ -d ${ZSH_CUSTOM}/plugins/fast-syntax-highlighting ]]; then
        _v_log_ok $__context "$(_v_fmt_u fast-syntax-highlighting) already installed"
    else
        _v_log_info $__context "Installing $(_v_fmt_u fast-syntax-highlighting)"
        git clone --depth=1 https://github.com/zdharma-continuum/fast-syntax-highlighting.git \
            ${ZSH_CUSTOM}/plugins/fast-syntax-highlighting

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u fast-syntax-highlighting) installed"
        fi
    fi
    echo "\n"


    # Install zsh-autosuggestions
    if [[ -d ${ZSH_CUSTOM}/plugins/zsh-autosuggestions ]]; then
        _v_log_ok $__context "$(_v_fmt_u zsh-autosuggestions) already installed"
    else
        _v_log_info $__context "Installing $(_v_fmt_u zsh-autosuggestions)"
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
            ${ZSH_CUSTOM}/plugins/zsh-autosuggestions

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u fast-syntax-highlighting) installed"
        fi
    fi
    echo "\n"


    # Install fzf-tab
    if [[ -d ${ZSH_CUSTOM}/plugins/fzf-tab ]]; then
        _v_log_ok $__context "$(_v_fmt_u fzf-tab) already installed"
    else
        _v_log_info $__context "Installing $(_v_fmt_u fzf-tab)"
        git clone --depth=1 https://github.com/Aloxaf/fzf-tab \
            ${ZSH_CUSTOM}/plugins/fzf-tab

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u fzf-tab) installed"
        fi
    fi
    echo "\n"


    # Install fzf-tab-source
    if [[ -d ${ZSH_CUSTOM}/plugins/fzf-tab-source ]]; then
        _v_log_ok $__context "$(_v_fmt_u fzf-tab-source) already installed"
    else
        _v_log_info $__context "Installing $(_v_fmt_u fzf-tab-source)"
        git clone --depth=1 https://github.com/Freed-Wu/fzf-tab-source \
            ${ZSH_CUSTOM}/plugins/fzf-tab-source

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u fzf-tab-source) installed"
        fi
    fi
    echo "\n"


    # Install zsh-vi-mode
    if [[ -d ${ZSH_CUSTOM}/plugins/zsh-vi-mode ]]; then
        _v_log_ok $__context "$(_v_fmt_u zsh-vi-mode) already installed"
    else
        _v_log_info $__context "Installing $(_v_fmt_u zsh-vi-mode)"
        git clone --depth=1 https://github.com/jeffreytse/zsh-vi-mode \
            ${ZSH_CUSTOM}/plugins/zsh-vi-mode

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u zsh-vi-mode) installed"
        fi
    fi
    echo "\n"


    # Install OhMyZsh Full-autoupdate
    if [[ -d ${ZSH_CUSTOM}/plugins/ohmyzsh-full-autoupdate ]]; then
        _v_log_ok $__context "$(_v_fmt_u OhMyZsh Full-autoupdate) already installed"
    else
        _v_log_info $__context "Installing $(_v_fmt_u OhMyZsh Full-autoupdate)"
        git clone --depth=1 https://github.com/Pilaton/OhMyZsh-full-autoupdate.git \
            ${ZSH_CUSTOM}/plugins/ohmyzsh-full-autoupdate

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u OhMyZsh Full-autoupdate) installed"
        fi
    fi


    # Update bat theme
    if [[ $(command -v bat) != "" ]]; then
        _v_log_info $__context "Updating $(_v_fmt_u bat) theme"
        wget -O "$(bat --config-dir)/themes/Catppuccin Mocha.tmTheme" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u bat) theme updated"
        fi

        _v_log_info $__context "Refreshing $(_v_fmt_u Bat) cache"
        bat cache --build

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u Bat) cache refreshed"
        fi
    fi


    # Update btop theme
    if [[ $(command -v btop) != "" ]]; then
        _v_log_info $__context "Updating $(_v_fmt_u btop) theme"
        wget -O "$XDG_CONFIG_HOME/btop/themes/catppuccin_mocha.theme" https://github.com/catppuccin/btop/raw/main/themes/catppuccin_mocha.theme

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "$(_v_fmt_u btop) theme updated"
        fi
    fi
}

