#!/usr/bin/env zsh
# Zsh theme + plugins installation

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function with the script's path as its only argument
# used to contain variables and functions in a local scope
function {
    export ZSH="$XDG_CONFIG_HOME/oh-my-zsh"
    export ZSH_CUSTOM="$ZSH/custom"
    export CHSH="no"
    export RUNZSH="no"
    export KEEP_ZSHRC="yes"

    # Install OhMyZsh
    if [[ -d ${ZSH} ]]; then
        _v::log::ok "$(_v::fmt::u OhMyZsh) already installed"
    else
        _v::log::info "Installing $(_v::fmt::u OhMyZsh)"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

        if [[ $? == 0 ]]; then
            _v::log::ok "$(_v::fmt::u OhMyZsh) installed"

            _v::log::info "Removing generated .zshrc"
        fi
    fi
    echo "\n"


    # Install PowerLevel10K
    if [[ -d ${ZSH_CUSTOM}/themes/powerlevel10k ]]; then
        _v::log::ok "$(_v::fmt::u PowerLevel10K) already installed"
    else
        _v::log::info "Installing $(_v::fmt::u PowerLevel10K)"
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
            ${ZSH_CUSTOM}/themes/powerlevel10k

        if [[ $? == 0 ]]; then
            _v::log::ok "$(_v::fmt::u PowerLevel10K) installed"
        fi
    fi
    echo "\n"


    # Install fast-syntax-highlighting
    if [[ -d ${ZSH_CUSTOM}/plugins/fast-syntax-highlighting ]]; then
        _v::log::ok "$(_v::fmt::u fast-syntax-highlighting) already installed"
    else
        _v::log::info "Installing $(_v::fmt::u fast-syntax-highlighting)"
        git clone --depth=1 https://github.com/zdharma-continuum/fast-syntax-highlighting.git \
            ${ZSH_CUSTOM}/plugins/fast-syntax-highlighting

        if [[ $? == 0 ]]; then
            _v::log::ok "$(_v::fmt::u fast-syntax-highlighting) installed"
        fi
    fi
    echo "\n"


    # Install zsh-autosuggestions
    if [[ -d ${ZSH_CUSTOM}/plugins/zsh-autosuggestions ]]; then
        _v::log::ok "$(_v::fmt::u zsh-autosuggestions) already installed"
    else
        _v::log::info "Installing $(_v::fmt::u zsh-autosuggestions)"
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
            ${ZSH_CUSTOM}/plugins/zsh-autosuggestions

        if [[ $? == 0 ]]; then
            _v::log::ok "$(_v::fmt::u fast-syntax-highlighting) installed"
        fi
    fi
    echo "\n"


    # Install fzf-tab
    if [[ -d ${ZSH_CUSTOM}/plugins/fzf-tab ]]; then
        _v::log::ok "$(_v::fmt::u fzf-tab) already installed"
    else
        _v::log::info "Installing $(_v::fmt::u fzf-tab)"
        git clone --depth=1 https://github.com/Aloxaf/fzf-tab \
            ${ZSH_CUSTOM}/plugins/fzf-tab

        if [[ $? == 0 ]]; then
            _v::log::ok "$(_v::fmt::u fzf-tab) installed"
        fi
    fi
    echo "\n"


    # Install fzf-tab-source
    if [[ -d ${ZSH_CUSTOM}/plugins/fzf-tab-source ]]; then
        _v::log::ok "$(_v::fmt::u fzf-tab-source) already installed"
    else
        _v::log::info "Installing $(_v::fmt::u fzf-tab-source)"
        git clone --depth=1 https://github.com/Freed-Wu/fzf-tab-source \
            ${ZSH_CUSTOM}/plugins/fzf-tab-source

        if [[ $? == 0 ]]; then
            _v::log::ok "$(_v::fmt::u fzf-tab-source) installed"
        fi
    fi
    echo "\n"


    # Install zsh-vi-mode
    if [[ -d ${ZSH_CUSTOM}/plugins/zsh-vi-mode ]]; then
        _v::log::ok "$(_v::fmt::u zsh-vi-mode) already installed"
    else
        _v::log::info "Installing $(_v::fmt::u zsh-vi-mode)"
        git clone --depth=1 https://github.com/jeffreytse/zsh-vi-mode \
            ${ZSH_CUSTOM}/plugins/zsh-vi-mode

        if [[ $? == 0 ]]; then
            _v::log::ok "$(_v::fmt::u zsh-vi-mode) installed"
        fi
    fi
    echo "\n"


    # Install OhMyZsh Full-autoupdate
    if [[ -d ${ZSH_CUSTOM}/plugins/ohmyzsh-full-autoupdate ]]; then
        _v::log::ok "$(_v::fmt::u OhMyZsh Full-autoupdate) already installed"
    else
        _v::log::info "Installing $(_v::fmt::u OhMyZsh Full-autoupdate)"
        git clone --depth=1 https://github.com/Pilaton/OhMyZsh-full-autoupdate.git \
            ${ZSH_CUSTOM}/plugins/ohmyzsh-full-autoupdate

        if [[ $? == 0 ]]; then
            _v::log::ok "$(_v::fmt::u OhMyZsh Full-autoupdate) installed"
        fi
    fi
}

