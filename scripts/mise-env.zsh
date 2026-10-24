#!/usr/bin/env zsh

function {
    emulate -L zsh
    setopt errexit nounset pipefail

    local __source_path="$1"
    shift
    local __scripts_dir="$(realpath "$(dirname "$__source_path")")"
    local __root_dir="$(realpath "$__scripts_dir/..")"
    local __mise_config_dir="$__root_dir/home/.config/mise"

    [[ -d "$__mise_config_dir" ]] ||
        {
            print -u2 -- "error: invalid dotfiles repository root: $__root_dir"
            return 1
        }

    path=("$HOME/.local/bin" $path)
    export PATH
    unset MISE_GLOBAL_CONFIG_FILE MISE_CONFIG_FILE
    export MISE_CONFIG_DIR="$__mise_config_dir"
    export MISE_ENV_CONF_D=true
    unset MISE_AUTO_ENV
    rehash
} "${(%):-%N}" "$@"
