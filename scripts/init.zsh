#!/usr/bin/env zsh

set -euo pipefail

function {
    local __root_dir
    local __mise_was_installed=false
    local __profile=""
    local __run_mise=false
    local __show_help=false
    local __options

    local __scripts_dir
    __scripts_dir="$(realpath "$(dirname "$ZSH_ARGZERO")")"
    __root_dir="$(realpath "$__scripts_dir/..")" ||
        {
            print -u2 -- "error: could not resolve the dotfiles repository root"
            exit 1
        }

    zmodload zsh/zutil
    zparseopts -D -E -F -A __options - \
        h -help \
        m -mise \
        p: -profile: ||
        {
            print -u2 -- "error: invalid options"
            exit 1
        }

    for opt arg in "${(kv@)__options}"; do
        case "$opt" in
            -h|--help)
                __show_help=true
                ;;
            -m|--mise)
                __run_mise=true
                ;;
            -p|--profile)
                __profile="$arg"
                __run_mise=true
                ;;
        esac
    done

    if [[ "$__run_mise" != true && "$__show_help" != true ]]; then
        exit 0
    fi

    if [[ "$__show_help" == true && "$__run_mise" != true ]]; then
        if command -v mise >/dev/null 2>&1; then
            exec mise run system:bootstrap --help
        fi
        print -r -- "Usage: $ZSH_ARGZERO [options]"
        print -r -- "  -h, --help              Show this help"
        print -r -- "  -m, --mise              Acquire mise and run system:bootstrap"
        print -r -- "  -p, --profile PROFILE   Apply a work or personal profile"
        print -r -- ""
        print -r -- "mise is not installed; use --mise to acquire it and run bootstrap."
        exit 0
    fi

    if ! command -v mise >/dev/null 2>&1; then
        if ! curl -fsSL https://mise.run | sh; then
            print -u2 -- "error: mise installation failed"
            exit 1
        fi
        __mise_was_installed=true
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

    export DOT_MISE_INSTALLED_DURING_RUN="$__mise_was_installed"
    cd "$__root_dir"

    local -a __task_args
    __task_args=(run system:bootstrap)
    if [[ -n "$__profile" ]]; then
        __task_args+=(--profile "$__profile")
    fi
    if [[ "$__show_help" == true ]]; then
        __task_args+=(--help)
    fi

    exec mise "${__task_args[@]}"
} "$@"
