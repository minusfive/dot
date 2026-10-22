#!/usr/bin/env zsh
#MISE quiet=true

set -euo pipefail

function {
    local __zsh="${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-zsh"
    local __zsh_custom="$__zsh/custom"

    mise bootstrap repos update --yes "$__zsh"

    if [[ -d "$__zsh_custom/plugins/ohmyzsh-full-autoupdate" ]]; then
        export ZSH="$__zsh"
        export ZSH_CUSTOM="$__zsh_custom"
        export ZSH_CACHE_DIR="$ZSH/cache"
        mkdir -p "$ZSH_CACHE_DIR"

        if [[ -f "$ZSH_CACHE_DIR/.zsh-update" ]]; then
            sed -i.bak '/LABEL_FULL_AUTOUPDATE/d' "$ZSH_CACHE_DIR/.zsh-update"
            rm -f "$ZSH_CACHE_DIR/.zsh-update.bak"
        fi

        source "$ZSH_CUSTOM/plugins/ohmyzsh-full-autoupdate/ohmyzsh-full-autoupdate.plugin.zsh"
    fi
}
