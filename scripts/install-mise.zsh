#!/usr/bin/env zsh

set -euo pipefail

function {
    local __show_help=false
    local __options
    local __mise_path="$HOME/.local/bin/mise"
    local __code_color=$'\e[36m'
    local __reset_color=$'\e[0m'

    zmodload zsh/zutil
    zparseopts -D -E -F -A __options - \
        h -help ||
        {
            print -u2 -- "error: invalid options"
            exit 1
        }

    for opt arg in "${(kv@)__options}"; do
        case "$opt" in
            -h|--help)
                __show_help=true
                ;;
        esac
    done

    if (( $# > 0 )); then
        print -u2 -- "error: unexpected argument: $1"
        exit 1
    fi

    if [[ "$__show_help" == true ]]; then
        print -r -- ""
        print -r -- "Usage: ${__code_color}$ZSH_ARGZERO [--help]${__reset_color}"
        print -r -- ""
        print -r -- "Installs ${__code_color}mise${__reset_color} if it is not available."
        print -r -- ""
        print -r -- "After installation, review and run the native ${__code_color}mise bootstrap${__reset_color} command shown in the README."
        print -r -- ""
        exit 0
    fi

    if [[ ! -x "$__mise_path" ]]; then
        if command -v mise >/dev/null 2>&1; then
            print -u2 -- "error: mise is installed outside $__mise_path"
            print -u2 -- "error: install mise with this script so the bootstrap uses the supported installation"
            exit 1
        fi

        if ! curl -fsSL https://mise.run | sh; then
            print -u2 -- "error: mise installation failed"
            exit 1
        else
            print -r -- ""
            print -r -- "${__code_color}mise${__reset_color} installed."
        fi
    else
        print -r -- ""
        print -r -- "${__code_color}mise${__reset_color} is already installed."
        "$__mise_path" version -q
    fi

    if [[ ! -x "$__mise_path" ]]; then
        print -u2 -- "error: mise was installed but $__mise_path is not executable"
        exit 1
    fi

    print -r -- ""
    print -r -- "Run ${__code_color}\"$HOME/.local/bin/mise\" bootstrap --from https://github.com/minusfive/dot.git --from-dir ~/dev/personal/dot --config-dir home/.config/mise --dry-run${__reset_color} to review changes."
    print -r -- ""
} "$@"
