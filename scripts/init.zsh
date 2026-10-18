#!/usr/bin/env zsh

set -euo pipefail

function {
    local __dotfiles_scripts_dir="$(realpath "$(dirname "$ZSH_ARGZERO")")"
    local __dotfiles_dir="$(dirname "$__dotfiles_scripts_dir")"
    local __profile_args=()
    local __run_mise=false

    print_help() {
        print -r -- "Usage: $ZSH_ARGZERO [options]"
        print -r -- ""
        print -r -- "Options:"
        print -r -- "  -h, --help              Show this help"
        print -r -- "  -m, --mise              Forward to mise run bootstrap"
        print -r -- "  -p, --profile PROFILE   Forward a profile to the bootstrap task"
    }

    local __arg
    while (( $# > 0 )); do
        __arg="$1"
        shift
        case "$__arg" in
            -h|--help)
                print_help
                exit 0
                ;;
            -m|--mise)
                __run_mise=true
                ;;
            -p|--profile)
                (( $# > 0 )) || {
                    print -u2 -- "error: --profile requires a value"
                    exit 2
                }
                __profile_args+=(--profile "$1")
                shift
                ;;
            --profile=*)
                __profile_args+=(--profile "${__arg#*=}")
                ;;
            *)
                print -u2 -- "error: unknown option: $__arg"
                print_help
                exit 2
                ;;
        esac
    done

    if [[ "$__run_mise" != true ]]; then
        print_help
        exit 0
    fi

    source "$__dotfiles_scripts_dir/utils/mise.zsh"
    local __mise_path="$HOME/.local/bin/mise"
    if [[ -e "$__mise_path" || -L "$__mise_path" ]]; then
        _v_mise_ensure_stable_path "$__mise_path"
    else
        local __existing_mise="$(command -v mise || true)"
        if [[ -n "$__existing_mise" ]]; then
            _v_mise_ensure_stable_path "$__existing_mise"
        else
            print -r -- "mise was not found at $__mise_path. Installing mise..."
            curl -fsSL https://mise.run | sh
        fi
    fi
    [[ -x "$__mise_path" ]] || {
        print -u2 -- "error: mise is not available at $__mise_path"
        exit 1
    }

    export PATH="$HOME/.local/bin:$PATH"
    hash -r
    cd "$__dotfiles_dir"
    exec "$__mise_path" run bootstrap "${__profile_args[@]}"
} "$@"
