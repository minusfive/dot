#!/usr/bin/env zsh

set -euo pipefail

function {
    local __show_help=false
    local __options
    local __mise_command="mise"
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
        print -r -- "After installation, run ${__code_color}mise system:bootstrap --help${__reset_color} for next steps."
        print -r -- ""
        exit 0
    fi

    if ! command -v mise >/dev/null 2>&1; then
        if ! curl -fsSL https://mise.run | sh; then
            print -u2 -- "error: mise installation failed"
            exit 1
        else
            __mise_command="~/.local/bin/mise"
            print -r -- ""
            print -r -- "${__code_color}mise${__reset_color} installed."
        fi
    else
        print -r -- ""
        print -r -- "${__code_color}mise${__reset_color} is already installed."
        mise version -q
    fi

    if [[ -x "$HOME/.local/bin/mise" ]]; then
        path=("$HOME/.local/bin" $path)
        export PATH
        rehash
    fi

    if ! command -v mise >/dev/null 2>&1; then
        print -u2 -- "error: mise was installed but is not available in PATH"
        exit 1
    fi

    print -r -- ""
    print -r -- "Run ${__code_color}${__mise_command} system:bootstrap --help${__reset_color} for next steps."
    print -r -- ""
} "$@"
